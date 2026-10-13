/**
 * Tencent is pleased to support the open source community by making QMUI_iOS available.
 * Copyright (C) 2016-2021 THL A29 Limited, a Tencent company. All rights reserved.
 * Licensed under the MIT License (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 * http://opensource.org/licenses/MIT
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
 */
//
//  UISlider+QMUI.m
//  QMUIKit
//
//  Created by MoLice on 2021/D/10.
//

#import "UISlider+QMUI.h"
#import "QMUICore.h"
#import "NSNumber+QMUI.h"
#import "UIImage+QMUI.h"
#import "UIView+QMUI.h"
#import "UILabel+QMUI.h"
#import "CALayer+QMUI.h"
#import "NSShadow+QMUI.h"

// 只记录 QMUI 生成的导轨图片，业务设置的图片不会被覆盖或恢复成错误的值。
@interface QMUISliderTrackImageState : NSObject
@property(nonatomic, strong) UIImage *minimumImage;
@property(nonatomic, strong) UIImage *maximumImage;
@property(nonatomic, strong) UIColor *minimumColor;
@property(nonatomic, strong) UIColor *maximumColor;
@property(nonatomic, assign) CGFloat minimumHeight;
@property(nonatomic, assign) CGFloat maximumHeight;
@property(nonatomic, assign) CGFloat minimumScale;
@property(nonatomic, assign) CGFloat maximumScale;
@property(nonatomic, assign) BOOL updating;
@end

@implementation QMUISliderTrackImageState
@end

/// 仅裁剪已启用自定义高度的 Steps 导轨，保留 UIKit 已有的 mask。
@interface QMUISliderTrackClipLayer : CAShapeLayer
@property(nonatomic, weak) UIImageView *imageView;
@end

@implementation QMUISliderTrackClipLayer
@end

@interface UISlider (QMUI_Steps_Private)

@property(nonatomic, strong) NSMutableArray<QMUISliderStepControl *> *qmuisl_stepControls;
@property(nonatomic, assign) NSUInteger qmuisl_precedingStep;
@property(nonatomic, strong) QMUISliderTrackImageState *qmuisl_trackImageState;
@property(nonatomic, strong) NSArray<QMUISliderTrackClipLayer *> *qmuisl_trackClipLayers;
@property(nonatomic, weak) UIView *qmuisl_shadowedThumbView;
- (float)qmuisl_valueForStep:(NSUInteger)step;
- (void)qmuisl_snapToStep;
- (void)qmuisl_swizzleLayoutIfNeeded;
- (void)qmuisl_updateTrackImagesIfNeeded;
- (void)qmuisl_clearGeneratedTrackImageForMinimumTrack:(BOOL)minimumTrack;
- (void)qmuisl_updateTrackClippingIfNeeded;
- (void)qmuisl_updateThumbShadow;
@end

@implementation UISlider (QMUI)

QMUISynthesizeIdStrongProperty(qmuisl_stepControls, setQmuisl_stepControls)
QMUISynthesizeNSUIntegerProperty(qmuisl_precedingStep, setQmuisl_precedingStep)
QMUISynthesizeIdCopyProperty(qmui_stepDidChangeBlock, setQmui_stepDidChangeBlock)
QMUISynthesizeIdStrongProperty(qmuisl_trackImageState, setQmuisl_trackImageState)
QMUISynthesizeIdStrongProperty(qmuisl_trackClipLayers, setQmuisl_trackClipLayers)
QMUISynthesizeIdWeakProperty(qmuisl_shadowedThumbView, setQmuisl_shadowedThumbView)

- (UIView *)qmui_thumbView {
    // 从真实视图树查询滑块，不依赖 visualElement 的私有属性。
    UIImage *thumbImage = self.currentThumbImage;
    CGRect track = [self trackRectForBounds:self.bounds];
    CGRect thumb = [self thumbRectForBounds:self.bounds trackRect:track value:self.value];
    UIView *thumbView = nil;
    NSMutableArray<UIView *> *views = self.subviews.mutableCopy;
    for (NSUInteger index = 0; index < views.count; index++) {
        UIView *view = views[index];
        if ([view isKindOfClass:UIImageView.class] && thumbImage) {
            UIImageView *imageView = (UIImageView *)view;
            UIImage *image = imageView.highlighted && imageView.highlightedImage ? imageView.highlightedImage : imageView.image;
            CGRect rect = [imageView convertRect:imageView.bounds toView:self];
            // iOS 26 自定义圆点使用 UISliderImageView，名称不含 Thumb；按图片及实际圆点位置识别。
            if ([image isEqual:thumbImage]
                && fabs(CGRectGetMidX(rect) - CGRectGetMidX(thumb)) < 1
                && fabs(CGRectGetMidY(rect) - CGRectGetMidY(thumb)) < 1) return imageView;
        }
        NSString *name = NSStringFromClass(view.class);
        if ([name localizedCaseInsensitiveContainsString:@"Thumb"]) {
            thumbView = view;
            if ([name localizedCaseInsensitiveContainsString:@"InnerThumb"]) return view;
        }
        [views addObjectsFromArray:view.subviews];
    }
    return thumbView;
}

static char kAssociatedObjectKey_trackHeight;
- (void)setQmui_trackHeight:(CGFloat)trackHeight {
    trackHeight = isfinite(trackHeight) ? MAX(0, trackHeight) : 0;
    objc_setAssociatedObject(self, &kAssociatedObjectKey_trackHeight, @(trackHeight), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (trackHeight <= 0) {
        [self qmuisl_clearGeneratedTrackImageForMinimumTrack:YES];
        [self qmuisl_clearGeneratedTrackImageForMinimumTrack:NO];
        [self qmuisl_setNeedsLayout];
        return;
    }
    
    [QMUIHelper executeBlock:^{
        OverrideImplementation([UISlider class], @selector(trackRectForBounds:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^CGRect(UISlider *selfObject, CGRect bounds) {
                
                // call super
                CGRect (*originSelectorIMP)(id, SEL, CGRect);
                originSelectorIMP = (CGRect (*)(id, SEL, CGRect))originalIMPProvider();
                CGRect result = originSelectorIMP(selfObject, originCMD, bounds);
                
                if (selfObject.qmui_trackHeight > 0) {
                    // 保留系统导轨的中心线，不将半像素高度的上下边分别取整。
                    CGFloat height = selfObject.qmui_trackHeight;
                    result = CGRectMake(result.origin.x, CGRectGetMidY(result) - height / 2, result.size.width, height);
                }
                
                return result;
            };
        });

        for (NSNumber *minimumTrack in @[@YES, @NO]) {
            BOOL isMinimum = minimumTrack.boolValue;
            SEL selector = isMinimum ? @selector(setMinimumTrackImage:forState:) : @selector(setMaximumTrackImage:forState:);
            OverrideImplementation(UISlider.class, selector, ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
                return ^(UISlider *selfObject, UIImage *image, UIControlState state) {
                    // 外部设置自定义图片时，先移除 QMUI 的其他状态图片，避免拖动时切回旧图。
                    if (!selfObject.qmuisl_trackImageState.updating) {
                        [selfObject qmuisl_clearGeneratedTrackImageForMinimumTrack:isMinimum];
                    }
                    void (*originSelectorIMP)(id, SEL, UIImage *, UIControlState);
                    originSelectorIMP = (void (*)(id, SEL, UIImage *, UIControlState))originalIMPProvider();
                    originSelectorIMP(selfObject, originCMD, image, state);
                };
            });
        }
    } oncePerIdentifier:@"UISlider (QMUI) trackHeight"];

    [self qmuisl_swizzleLayoutIfNeeded];
    [self qmuisl_updateTrackImagesIfNeeded];
    [self qmuisl_setNeedsLayout];
}

- (CGFloat)qmui_trackHeight {
    return [((NSNumber *)objc_getAssociatedObject(self, &kAssociatedObjectKey_trackHeight)) qmui_CGFloatValue];
}

- (void)qmuisl_clearGeneratedTrackImageForMinimumTrack:(BOOL)minimumTrack {
    QMUISliderTrackImageState *imageState = self.qmuisl_trackImageState;
    UIImage *generatedImage = minimumTrack ? imageState.minimumImage : imageState.maximumImage;
    if (!generatedImage) return;
    imageState.updating = YES;
    for (NSNumber *stateNumber in @[@(UIControlStateNormal), @(UIControlStateHighlighted), @(UIControlStateDisabled)]) {
        UIControlState state = stateNumber.unsignedIntegerValue;
        UIImage *image = minimumTrack ? [self minimumTrackImageForState:state] : [self maximumTrackImageForState:state];
        if (image != generatedImage) continue;
        if (minimumTrack) [self setMinimumTrackImage:nil forState:state];
        else [self setMaximumTrackImage:nil forState:state];
    }
    if (minimumTrack) imageState.minimumImage = nil;
    else imageState.maximumImage = nil;
    imageState.updating = NO;
}

- (void)qmuisl_updateTrackImagesIfNeeded {
    CGFloat height = self.qmui_trackHeight;
    if (height <= 0 || !isfinite(height)) return;
    // iOS 26 的玻璃导轨会随交互改变厚度；自定义高度通过公开图片 API 固定，默认控件不介入。
    if (!self.qmuisl_trackImageState) self.qmuisl_trackImageState = QMUISliderTrackImageState.new;
    QMUISliderTrackImageState *imageState = self.qmuisl_trackImageState;
    if (imageState.updating) return;
    CGFloat scale = self.window.screen.scale ?: self.traitCollection.displayScale;
    if (scale <= 0) scale = 1;
    height = MAX(1, round(height * scale)) / scale;
    NSArray<NSNumber *> *states = @[@(UIControlStateNormal), @(UIControlStateHighlighted), @(UIControlStateDisabled)];
    for (NSNumber *track in @[@YES, @NO]) {
        BOOL minimumTrack = track.boolValue;
        UIImage *generatedImage = minimumTrack ? imageState.minimumImage : imageState.maximumImage;
        BOOL hasCustomImage = NO;
        BOOL allStatesMatch = generatedImage != nil;
        for (NSNumber *stateNumber in states) {
            UIControlState state = stateNumber.unsignedIntegerValue;
            UIImage *image = minimumTrack ? [self minimumTrackImageForState:state] : [self maximumTrackImageForState:state];
            if (image && image != generatedImage) hasCustomImage = YES;
            if (image != generatedImage) allStatesMatch = NO;
        }
        if (hasCustomImage) continue;
        UIColor *color = minimumTrack ? (self.minimumTrackTintColor ?: self.tintColor) : (self.maximumTrackTintColor ?: UIColor.systemGray3Color);
        color = [color resolvedColorWithTraitCollection:self.traitCollection];
        UIColor *cachedColor = minimumTrack ? imageState.minimumColor : imageState.maximumColor;
        CGFloat cachedHeight = minimumTrack ? imageState.minimumHeight : imageState.maximumHeight;
        CGFloat cachedScale = minimumTrack ? imageState.minimumScale : imageState.maximumScale;
        if (allStatesMatch && [color isEqual:cachedColor] && height == cachedHeight && scale == cachedScale) continue;
        // 两侧各留一个像素帽，中间一个像素拉伸；高亮和普通状态使用同一张图，不再变细。
        UIImage *image = [UIImage qmui_imageWithSize:CGSizeMake(3 / scale, height) opaque:NO scale:scale actions:^(CGContextRef context) {
            CGContextSetFillColorWithColor(context, color.CGColor);
            CGContextFillRect(context, CGRectMake(0, 0, 3 / scale, height));
        }];
        image = [image resizableImageWithCapInsets:UIEdgeInsetsMake(0, 1 / scale, 0, 1 / scale) resizingMode:UIImageResizingModeStretch];
        if (!image) continue;
        imageState.updating = YES;
        for (NSNumber *stateNumber in states) {
            UIControlState state = stateNumber.unsignedIntegerValue;
            if (minimumTrack) [self setMinimumTrackImage:image forState:state];
            else [self setMaximumTrackImage:image forState:state];
        }
        imageState.updating = NO;
        if (minimumTrack) {
            imageState.minimumImage = image;
            imageState.minimumColor = color;
            imageState.minimumHeight = height;
            imageState.minimumScale = scale;
        } else {
            imageState.maximumImage = image;
            imageState.maximumColor = color;
            imageState.maximumHeight = height;
            imageState.maximumScale = scale;
        }
    }
}

- (void)qmuisl_swizzleLayoutIfNeeded {
    [QMUIHelper executeBlock:^{
        OverrideImplementation(UISlider.class, @selector(layoutSubviews), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^(UISlider *selfObject) {
                [selfObject qmuisl_updateTrackImagesIfNeeded];
                void (*originSelectorIMP)(id, SEL);
                originSelectorIMP = (void (*)(id, SEL))originalIMPProvider();
                originSelectorIMP(selfObject, originCMD);
                [selfObject qmuisl_updateTrackClippingIfNeeded];
                [selfObject qmuisl_updateThumbShadow];
                [selfObject qmuisl_layoutStepControls];
            };
        });
    } oncePerIdentifier:@"UISlider (QMUI) layout"];
}

- (void)qmuisl_updateTrackClippingIfNeeded {
    if (!self.qmuisl_trackClipLayers.count && (self.qmui_trackHeight <= 0 || self.qmui_numberOfSteps < 2)) return;
    NSMutableArray<QMUISliderTrackClipLayer *> *activeLayers = NSMutableArray.new;
    if (@available(iOS 26.0, *)) {
        if (self.qmui_trackHeight > 0 && self.qmui_numberOfSteps >= 2 && !CGRectIsEmpty(self.bounds)) {
            CGRect track = [self trackRectForBounds:self.bounds];
            CGRect first = [self thumbRectForBounds:self.bounds trackRect:track value:self.minimumValue];
            CGRect last = [self thumbRectForBounds:self.bounds trackRect:track value:self.maximumValue];
            CGFloat left = MIN(CGRectGetMidX(first), CGRectGetMidX(last));
            CGFloat right = MAX(CGRectGetMidX(first), CGRectGetMidX(last));
            CGRect clipRect = CGRectMake(left, CGRectGetMinY(self.bounds), MAX(0, right - left), CGRectGetHeight(self.bounds));
            UIImage *minimumImage = self.currentMinimumTrackImage;
            UIImage *maximumImage = self.currentMaximumTrackImage;
            UIView *thumbView = self.qmui_thumbView;
            NSMutableArray<UIView *> *views = self.subviews.mutableCopy;
            for (NSUInteger index = 0; index < views.count; index++) {
                UIView *view = views[index];
                if ([view isKindOfClass:UIImageView.class]) {
                    UIImageView *imageView = (UIImageView *)view;
                    UIImage *image = imageView.highlighted && imageView.highlightedImage ? imageView.highlightedImage : imageView.image;
                    if (imageView != thumbView && image && ([image isEqual:minimumImage] || [image isEqual:maximumImage])) {
                        QMUISliderTrackClipLayer *clip = nil;
                        for (QMUISliderTrackClipLayer *layer in self.qmuisl_trackClipLayers) {
                            if (layer.imageView == imageView) { clip = layer; break; }
                        }
                        if (!clip) {
                            clip = QMUISliderTrackClipLayer.layer;
                            clip.imageView = imageView;
                        }
                        // 不改变原生轨道/圆点的坐标；普通、高亮和 RTL 状态使用同一裁剪边界。
                        [CALayer qmui_performWithoutAnimation:^{
                            if (imageView.layer.mask != clip) {
                                clip.mask = imageView.layer.mask;
                                imageView.layer.mask = clip;
                            }
                            clip.frame = imageView.bounds;
                            CGRect rect = CGRectIntersection(imageView.bounds, [self convertRect:clipRect toView:imageView]);
                            clip.path = [UIBezierPath bezierPathWithRect:CGRectIsNull(rect) ? CGRectZero : rect].CGPath;
                        }];
                        [activeLayers addObject:clip];
                    }
                }
                [views addObjectsFromArray:view.subviews];
            }
        }
    }
    // 关闭 Steps、自定义高度或更换系统图片后，只清理 QMUI 自己安装的裁剪。
    for (QMUISliderTrackClipLayer *clip in self.qmuisl_trackClipLayers) {
        if ([activeLayers containsObject:clip]) continue;
        if (clip.imageView.layer.mask == clip) {
            CALayer *originalMask = clip.mask;
            clip.mask = nil;
            clip.imageView.layer.mask = originalMask;
        }
    }
    self.qmuisl_trackClipLayers = activeLayers.count ? activeLayers : nil;
}

static char kAssociatedObjectKey_thumbSize;
- (void)setQmui_thumbSize:(CGSize)thumbSize {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_thumbSize, @(thumbSize), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (CGSizeIsEmpty(thumbSize)) return;
    [self qmuisl_updateThumbImage];
}

- (CGSize)qmui_thumbSize {
    return [((NSNumber *)objc_getAssociatedObject(self, &kAssociatedObjectKey_thumbSize)) CGSizeValue];
}

static char kAssociatedObjectKey_thumbColor;
- (void)setQmui_thumbColor:(UIColor *)thumbColor {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_thumbColor, thumbColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self qmuisl_updateThumbImage];
}

- (UIColor *)qmui_thumbColor {
    return (UIColor *)objc_getAssociatedObject(self, &kAssociatedObjectKey_thumbColor);
}

- (void)qmuisl_updateThumbImage {
    if (!CGSizeIsEmpty(self.qmui_thumbSize)) {
        UIColor *thumbColor = self.qmui_thumbColor ?: self.tintColor;
        UIImage *thumbImage = [UIImage qmui_imageWithShape:QMUIImageShapeOval size:self.qmui_thumbSize tintColor:thumbColor];
        [self setThumbImage:thumbImage forState:UIControlStateNormal];
        [self setThumbImage:thumbImage forState:UIControlStateHighlighted];
        [self qmuisl_updateThumbShadow];
        [self setNeedsLayout];
    }
}

static char kAssociatedObjectKey_thumbShadow;
- (void)setQmui_thumbShadow:(NSShadow *)thumbShadow {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_thumbShadow, thumbShadow, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self qmuisl_swizzleLayoutIfNeeded];
    [self qmuisl_updateThumbShadow];
    [self setNeedsLayout];
}

- (NSShadow *)qmui_thumbShadow {
    return (NSShadow *)objc_getAssociatedObject(self, &kAssociatedObjectKey_thumbShadow);
}

- (void)qmuisl_updateThumbShadow {
    NSShadow *shadow = self.qmui_thumbShadow;
    UIView *precedingView = self.qmuisl_shadowedThumbView;
    if (!shadow && !precedingView) return;
    UIView *thumbView = shadow ? self.qmui_thumbView : nil;
    [CALayer qmui_performWithoutAnimation:^{
        if (precedingView != thumbView) precedingView.layer.qmui_shadow = nil;
        if (thumbView) {
            // 每次布局在真实圆点上重应用，兼容系统重建视图及业务动态修改阴影颜色。
            NSShadow *resolvedShadow = shadow.copy;
            if ([shadow.shadowColor isKindOfClass:UIColor.class]) {
                resolvedShadow.shadowColor = [(UIColor *)shadow.shadowColor resolvedColorWithTraitCollection:self.traitCollection];
            }
            thumbView.layer.qmui_shadow = resolvedShadow;
        }
    }];
    self.qmuisl_shadowedThumbView = thumbView;
}

#pragma mark - Steps

static char kAssociatedObjectKey_numberOfSteps;
- (void)setQmui_numberOfSteps:(NSUInteger)numberOfSteps {
    // 拖动结束不一定再触发 valueChanged，需同时处理松手和取消事件。
    UIControlEvents stepEvents = UIControlEventValueChanged | UIControlEventTouchUpInside | UIControlEventTouchUpOutside | UIControlEventTouchCancel;
    objc_setAssociatedObject(self, &kAssociatedObjectKey_numberOfSteps, @(numberOfSteps), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (numberOfSteps < 2) {
        [self.qmuisl_stepControls enumerateObjectsUsingBlock:^(QMUISliderStepControl * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            [obj removeFromSuperview];
        }];
        self.qmuisl_stepControls = nil;
        [self removeTarget:self action:@selector(qmuisl_handleValueChanged:) forControlEvents:stepEvents];
        [self qmuisl_updateTrackClippingIfNeeded];
        [self setNeedsLayout];
        return;
    }
    
    [self qmuisl_swizzleForStepsIfNeeded];
    
    // step 的逻辑都是基于 [0, 1] 来计算的，所以这里强制保证一下值
    self.minimumValue = 0;
    self.maximumValue = 1;
    
    if (!self.qmuisl_stepControls) {
        self.qmuisl_stepControls = NSMutableArray.new;
    }
    NSInteger diff = self.qmuisl_stepControls.count - numberOfSteps;
    if (diff < 0) {
        for (NSInteger i = 0; i < diff * -1; i++) {
            QMUISliderStepControl *stepControl = QMUISliderStepControl.new;
            [stepControl addTarget:self action:@selector(qmuisl_handleStepControlEvent:) forControlEvents:UIControlEventTouchUpInside];
            [self addSubview:stepControl];// stepControl 要在最前面，才能做到点击 stepControl 时响应到点击事件
            [self.qmuisl_stepControls addObject:stepControl];
        }
    } else if (diff > 0) {
        // 减少档位时只移除多余项，避免原来的闭区间多删一个控件。
        while (self.qmuisl_stepControls.count > numberOfSteps) {
            [self.qmuisl_stepControls.lastObject removeFromSuperview];
            [self.qmuisl_stepControls removeLastObject];
        }
    }
    if (self.qmui_stepControlConfiguration) {
        [self.qmuisl_stepControls enumerateObjectsUsingBlock:^(QMUISliderStepControl * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            self.qmui_stepControlConfiguration(self, obj, idx);
        }];
    }
    [self qmuisl_snapToStep];
    self.qmuisl_precedingStep = self.qmui_step;
    [self qmuisl_setNeedsLayout];
    
    [self removeTarget:self action:@selector(qmuisl_handleValueChanged:) forControlEvents:stepEvents];
    [self addTarget:self action:@selector(qmuisl_handleValueChanged:) forControlEvents:stepEvents];
}

- (NSUInteger)qmui_numberOfSteps {
    return [((NSNumber *)objc_getAssociatedObject(self, &kAssociatedObjectKey_numberOfSteps)) unsignedIntValue];
}

- (void)setQmui_step:(NSUInteger)step {
    if (self.qmui_numberOfSteps < 2) return;
    [self setValue:[self qmuisl_valueForStep:step] animated:NO];
    [self sendActionsForControlEvents:UIControlEventValueChanged];
}

- (NSUInteger)qmui_step {
    NSUInteger step = [self qmuisl_stepWithValue:self.value];
    return step;
}

static char kAssociatedObjectKey_stepControlConfiguration;
- (void)setQmui_stepControlConfiguration:(void (^)(__kindof UISlider * _Nonnull, QMUISliderStepControl * _Nonnull, NSUInteger))stepControlConfiguration {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_stepControlConfiguration, stepControlConfiguration, OBJC_ASSOCIATION_COPY_NONATOMIC);
    if (stepControlConfiguration) {
        [self.qmuisl_stepControls enumerateObjectsUsingBlock:^(QMUISliderStepControl * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            stepControlConfiguration(self, obj, idx);
        }];
        [self qmuisl_setNeedsLayout];
    }
}

- (void (^)(__kindof UISlider * _Nonnull, QMUISliderStepControl * _Nonnull, NSUInteger))qmui_stepControlConfiguration {
    return (void (^)(UISlider * _Nonnull, QMUISliderStepControl * _Nonnull, NSUInteger))objc_getAssociatedObject(self, &kAssociatedObjectKey_stepControlConfiguration);
}

- (void)qmuisl_handleValueChanged:(UISlider *)slider {
    if (slider.qmui_numberOfSteps < 2) return;
    [slider qmuisl_snapToStep];
    
    NSUInteger step = [slider qmuisl_stepWithValue:slider.value];
    if (step != slider.qmuisl_precedingStep) {
        if (slider.qmui_stepDidChangeBlock) {
            slider.qmui_stepDidChangeBlock(slider, slider.qmuisl_precedingStep);
        }
        // 即便不存在 qmui_stepDidChangeBlock 也要记录 precedingStep
        // https://github.com/Tencent/QMUI_iOS/issues/1413
        slider.qmuisl_precedingStep = step;
    }
}

- (void)qmuisl_handleStepControlEvent:(QMUISliderStepControl *)stepControl {
    NSInteger step = [self.qmuisl_stepControls indexOfObject:stepControl];
    self.qmui_step = step;
}

- (NSUInteger)qmuisl_stepWithValue:(float)value {
    if (self.qmui_numberOfSteps < 2 || self.maximumValue <= self.minimumValue) return 0;
    CGFloat progress = (value - self.minimumValue) / (self.maximumValue - self.minimumValue);
    progress = fmin(fmax(progress, 0), 1);
    NSUInteger step = round(progress * (self.qmui_numberOfSteps - 1));
    return step;
}

- (float)qmuisl_valueForStep:(NSUInteger)step {
    if (self.qmui_numberOfSteps < 2) return self.value;
    step = MIN(step, self.qmui_numberOfSteps - 1);
    return self.minimumValue + (self.maximumValue - self.minimumValue) * ((CGFloat)step / (self.qmui_numberOfSteps - 1));
}

- (void)qmuisl_snapToStep {
    if (self.qmui_numberOfSteps < 2) return;
    float value = [self qmuisl_valueForStep:self.qmui_step];
    // 修改真实 value，让 UIKit 同时更新圆点与进度条，不能只修正圆点绘制位置。
    // 即使数值已归档，结束事件仍需刷新布局，避免进度条保留拖动时的显示状态。
    [self setValue:value animated:NO];
    [self setNeedsLayout];
}

- (void)qmuisl_swizzleForStepsIfNeeded {
    [self qmuisl_swizzleLayoutIfNeeded];
    [QMUIHelper executeBlock:^{
        OverrideImplementation([UISlider class], @selector(sendAction:to:forEvent:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^(UISlider *selfObject, SEL action, id target, UIEvent *event) {
                // 新版 UISlider 的触摸更新可能绕过 setValue:animated:，在业务收到事件前统一归档。
                // setValue 不发送控制事件，保持 continuous 的事件频率及取消事件语义。
                [selfObject qmuisl_snapToStep];
                void (*originSelectorIMP)(id, SEL, SEL, id, UIEvent *);
                originSelectorIMP = (void (*)(id, SEL, SEL, id, UIEvent *))originalIMPProvider();
                originSelectorIMP(selfObject, originCMD, action, target, event);
            };
        });

        OverrideImplementation([UISlider class], @selector(setEnabled:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^(UISlider *selfObject, BOOL enabled) {
                
                // call super
                void (*originSelectorIMP)(id, SEL, BOOL);
                originSelectorIMP = (void (*)(id, SEL, BOOL))originalIMPProvider();
                originSelectorIMP(selfObject, originCMD, enabled);
                
                if (selfObject.qmui_stepControlConfiguration) {
                    [selfObject.qmuisl_stepControls enumerateObjectsUsingBlock:^(QMUISliderStepControl * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        selfObject.qmui_stepControlConfiguration(selfObject, obj, idx);
                    }];
                }
            };
        });
        
        OverrideImplementation([UISlider class], @selector(tintColorDidChange), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^(UISlider *selfObject) {
                
                // call super
                void (*originSelectorIMP)(id, SEL);
                originSelectorIMP = (void (*)(id, SEL))originalIMPProvider();
                originSelectorIMP(selfObject, originCMD);
                
                [selfObject qmuisl_tintColorDidChange];
            };
        });
        
        OverrideImplementation([UISlider class], @selector(pointInside:withEvent:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^BOOL(UISlider *selfObject, CGPoint point, UIEvent *event) {
                
                // call super
                BOOL (*originSelectorIMP)(id, SEL, CGPoint, UIEvent *);
                originSelectorIMP = (BOOL (*)(id, SEL, CGPoint, UIEvent *))originalIMPProvider();
                BOOL result = originSelectorIMP(selfObject, originCMD, point, event);
                
                if (!result && selfObject.qmuisl_stepControls.count) {
                    __block BOOL pointInStepControl = NO;
                    [selfObject.qmuisl_stepControls enumerateObjectsUsingBlock:^(QMUISliderStepControl * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                        CGPoint p = [selfObject convertPoint:point toView:obj];
                        if ([obj pointInside:p withEvent:event]) {
                            pointInStepControl = YES;
                            *stop = YES;
                        }
                    }];
                    if (pointInStepControl) return YES;
                }
                
                return result;
            };
        });
        
        // - (CGRect)thumbRectForBounds:(CGRect)bounds trackRect:(CGRect)rect value:(float)value;
        OverrideImplementation([UISlider class], @selector(thumbRectForBounds:trackRect:value:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^CGRect(UISlider *selfObject, CGRect bounds, CGRect trackRect, float value) {
                
                // call super
                CGRect (*originSelectorIMP)(id, SEL, CGRect, CGRect, float);
                originSelectorIMP = (CGRect (*)(id, SEL, CGRect, CGRect, float))originalIMPProvider();
                // 将归档后的值交给系统计算圆点，避免手动覆盖 x 导致导轨与圆点采用不同坐标。
                if (selfObject.qmui_numberOfSteps >= 2) {
                    value = [selfObject qmuisl_valueForStep:[selfObject qmuisl_stepWithValue:value]];
                }
                return originSelectorIMP(selfObject, originCMD, bounds, trackRect, value);
            };
        });
        
        OverrideImplementation([UISlider class], @selector(setValue:animated:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^(UISlider *selfObject, float value, BOOL animated) {
                
                // 程序设置的值也转换到最近档位；触摸更新另由控制事件归档。
                if (selfObject.qmui_numberOfSteps >= 2) {
                    NSUInteger step = [selfObject qmuisl_stepWithValue:value];
                    value = [selfObject qmuisl_valueForStep:step];
                }
                
                // call super
                void (*originSelectorIMP)(id, SEL, float, BOOL);
                originSelectorIMP = (void (*)(id, SEL, float, BOOL))originalIMPProvider();
                originSelectorIMP(selfObject, originCMD, value, animated);
                
                
            };
        });
    } oncePerIdentifier:@"UISlider (QMUI) stepControl"];
}

- (void)qmuisl_layoutStepControls {
    NSInteger count = self.qmuisl_stepControls.count;
    if (!count) return;
    
    // 使用真实档位判断重叠项，不依赖新版 UISlider 内部圆点视图的层级和坐标。
    CGRect trackRect = [self trackRectForBounds:self.bounds];
    NSUInteger step = self.qmui_step;
    [self.qmuisl_stepControls enumerateObjectsUsingBlock:^(QMUISliderStepControl * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.userInteractionEnabled = idx != step;// 让 stepControl 不要影响 thumbView 的事件
        obj.indicator.hidden = idx == step;
    }];
    
    [self.qmuisl_stepControls enumerateObjectsUsingBlock:^(QMUISliderStepControl * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        // 每个刻度与其档位的系统圆点中心一致，自动适应圆点图片尺寸、布局方向和系统内边距。
        CGRect thumbRect = [self thumbRectForBounds:self.bounds trackRect:trackRect value:[self qmuisl_valueForStep:idx]];
        CGSize stepControlSize = [obj sizeThatFits:CGSizeMax];
        obj.frame = CGRectMake(CGRectGetMidX(thumbRect) - stepControlSize.width / 2, CGRectGetMidY(thumbRect) + obj.indicatorSize.height / 2 - stepControlSize.height, stepControlSize.width, stepControlSize.height);
    }];
}

- (void)qmuisl_tintColorDidChange {
    NSInteger count = self.qmuisl_stepControls.count;
    if (!count) return;
    [self.qmuisl_stepControls enumerateObjectsUsingBlock:^(QMUISliderStepControl * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        obj.tintColor = self.tintColor;
    }];
}

- (void)qmuisl_setNeedsLayout {
    [self setNeedsLayout];
}

@end

@implementation QMUISliderStepControl

- (instancetype)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        _titleLabel = [[UILabel alloc] qmui_initWithFont:UIFontMake(12) textColor:UIColorGray];
        self.titleLabel.userInteractionEnabled = NO;
        [self addSubview:self.titleLabel];
        
        _indicator = [[UIView alloc] init];
        self.indicator.userInteractionEnabled = NO;
        self.indicator.backgroundColor = UIColorGray;
        [self addSubview:self.indicator];
        
        self.indicatorSize = CGSizeMake(1, 8);
        self.spacingBetweenTitleAndIndicator = 8;
        
        // 避免只显示 indicator 时 size 太小，很难点到
        self.qmui_outsideEdge = UIEdgeInsetsMake(-12, -12, -12, -12);
    }
    return self;
}

- (void)setIndicatorSize:(CGSize)indicatorSize {
    _indicatorSize = indicatorSize;
    [((UISlider *)self.superview) qmuisl_setNeedsLayout];
}

- (void)setSpacingBetweenTitleAndIndicator:(CGFloat)spacingBetweenTitleAndIndicator {
    _spacingBetweenTitleAndIndicator = spacingBetweenTitleAndIndicator;
    [((UISlider *)self.superview) qmuisl_setNeedsLayout];
}

- (CGSize)sizeThatFits:(CGSize)size {
    CGSize titleLabelSize = self.titleLabel.text.length ? [self.titleLabel sizeThatFits:CGSizeMax] : CGSizeZero;
    if (CGSizeIsEmpty(titleLabelSize)) return self.indicatorSize;
    
    CGSize result = CGSizeZero;
    result.width = MAX(titleLabelSize.width, self.indicatorSize.width);
    result.height = titleLabelSize.height + self.spacingBetweenTitleAndIndicator + self.indicatorSize.height;
    return result;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    CGSize titleLabelSize = self.titleLabel.text.length ? [self.titleLabel sizeThatFits:CGSizeMax] : CGSizeZero;
    if (CGSizeIsEmpty(titleLabelSize)) {
        self.indicator.frame = CGRectMakeWithSize(self.indicatorSize);
    } else {
        self.titleLabel.frame = CGRectFlatMake(CGFloatGetCenter(CGRectGetWidth(self.bounds), titleLabelSize.width), 0, titleLabelSize.width, titleLabelSize.height);
        self.indicator.frame = CGRectFlatMake(CGFloatGetCenter(CGRectGetWidth(self.bounds), self.indicatorSize.width), CGRectGetMaxY(self.titleLabel.frame) + self.spacingBetweenTitleAndIndicator, self.indicatorSize.width, self.indicatorSize.height);
    }
}

@end
