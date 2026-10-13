//
//  UISliderTests.m
//  QMUIKitTests
//
//  Created by Ma on 2026/10/10.
//

#import <XCTest/XCTest.h>
#import <QMUIKit/QMUIKit.h>

@interface UISlider (QMUIStepsTesting)
- (void)qmuisl_handleValueChanged:(UISlider *)slider;
@end

// 模拟新版 UIKit 在跟踪过程中绕过公开 setter 保存连续值的情况。
@interface QMUISliderTrackingValueTestSlider : UISlider
@property(nonatomic, assign) float qmui_testTrackingValue;
@property(nonatomic, assign) BOOL qmui_testHasTrackingValue;
- (void)simulateTrackingValue:(float)value;
@end

@implementation QMUISliderTrackingValueTestSlider
- (void)simulateTrackingValue:(float)value {
    self.qmui_testTrackingValue = value;
    self.qmui_testHasTrackingValue = YES;
}
- (float)value {
    return self.qmui_testHasTrackingValue ? self.qmui_testTrackingValue : [super value];
}
- (void)setValue:(float)value animated:(BOOL)animated {
    self.qmui_testHasTrackingValue = NO;
    [super setValue:value animated:animated];
}
@end

@interface QMUISliderValueTestObserver : NSObject
@property(nonatomic, assign) float observedValue;
@property(nonatomic, assign) NSUInteger actionCount;
- (void)handleValueChanged:(UISlider *)slider;
@end

@implementation QMUISliderValueTestObserver
- (void)handleValueChanged:(UISlider *)slider {
    self.observedValue = slider.value;
    self.actionCount++;
}
@end

@interface UISliderTests : XCTestCase
@end

@implementation UISliderTests

- (void)testTrackingValueIsSnappedBeforeBusinessActions {
    QMUISliderTrackingValueTestSlider *slider = QMUISliderTrackingValueTestSlider.new;
    slider.qmui_numberOfSteps = 5;
    slider.qmui_step = 1;
    // 为无宿主测试补齐初始事件处理，使后续 precedingStep 与实际 App 一致。
    [slider qmuisl_handleValueChanged:slider];
    __block NSUInteger stepChangeCount = 0;
    slider.qmui_stepDidChangeBlock = ^(UISlider *sender, NSUInteger precedingStep) {
        stepChangeCount++;
        XCTAssertEqual(precedingStep, 1);
        XCTAssertEqualWithAccuracy(sender.value, .5f, .00001f);
    };
    for (NSNumber *value in @[@(.39f), @(.41f)]) {
        [slider simulateTrackingValue:value.floatValue];
        // 直接调用 QMUI 的控制事件处理，避免无 UIApplication 的单元测试环境丢弃 control action。
        [slider qmuisl_handleValueChanged:slider];
        XCTAssertEqualWithAccuracy(slider.value, .5f, .00001f);
        XCTAssertEqual(slider.qmui_step, 2);
    }
    XCTAssertEqual(stepChangeCount, 1);
}

- (void)testTouchEndAndCancellationSnapWithoutContinuousEvents {
    for (NSNumber *event in @[@(UIControlEventTouchUpInside), @(UIControlEventTouchUpOutside), @(UIControlEventTouchCancel)]) {
        QMUISliderTrackingValueTestSlider *slider = QMUISliderTrackingValueTestSlider.new;
        slider.continuous = NO;
        slider.qmui_numberOfSteps = 5;
        slider.qmui_step = 1;
        QMUISliderValueTestObserver *observer = QMUISliderValueTestObserver.new;
        [slider addTarget:observer action:@selector(handleValueChanged:) forControlEvents:UIControlEventValueChanged];
        // 即使结束前没有 valueChanged，松手及取消也要归档。
        [slider simulateTrackingValue:.39f];
        [slider sendActionsForControlEvents:(UIControlEvents)event.unsignedIntegerValue];
        XCTAssertEqualWithAccuracy(slider.value, .5f, .00001f);
        XCTAssertEqual(slider.qmui_step, 2);
        XCTAssertEqual(observer.actionCount, 0);
    }
}

- (void)testStepsCanBeDisabledAndReconfigured {
    QMUISliderTrackingValueTestSlider *slider = QMUISliderTrackingValueTestSlider.new;
    slider.qmui_numberOfSteps = 5;
    slider.qmui_numberOfSteps = 2;
    NSUInteger controlCount = 0;
    for (UIView *view in slider.subviews) {
        if ([view isKindOfClass:QMUISliderStepControl.class]) controlCount++;
    }
    XCTAssertEqual(controlCount, 2);
    slider.qmui_numberOfSteps = 0;
    [slider simulateTrackingValue:.39f];
    [slider sendActionsForControlEvents:UIControlEventTouchUpInside];
    XCTAssertEqualWithAccuracy(slider.value, .39f, .00001f);
}

- (void)testStepSnappingUsesActualValueRange {
    QMUISliderTrackingValueTestSlider *slider = QMUISliderTrackingValueTestSlider.new;
    slider.qmui_numberOfSteps = 5;
    slider.maximumValue = 20;
    slider.minimumValue = 10;
    [slider simulateTrackingValue:13.9f];
    [slider sendActionsForControlEvents:UIControlEventValueChanged];
    XCTAssertEqualWithAccuracy(slider.value, 15, .00001f);
    XCTAssertEqual(slider.qmui_step, 2);
}

- (void)testTrackImagesKeepHeightAcrossStatesAndCanBeRestored {
    // 旧系统的默认导轨本身就有图片；以同一原生控件的初始状态作对照，不能要求图片为 nil。
    UISlider *systemSlider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 372, 44)];
    [systemSlider layoutIfNeeded];
    UIImage *systemMinimum = systemSlider.currentMinimumTrackImage;
    UIImage *systemMaximum = systemSlider.currentMaximumTrackImage;
    CGRect systemTrack = [systemSlider trackRectForBounds:systemSlider.bounds];
    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 372, 44)];
    slider.qmui_trackHeight = 1;
    UIImage *minimumImage = [slider minimumTrackImageForState:UIControlStateNormal];
    UIImage *maximumImage = [slider maximumTrackImageForState:UIControlStateNormal];
    XCTAssertNotNil(minimumImage);
    XCTAssertNotNil(maximumImage);
    // 高亮与普通状态共享相同图，拖动不会换成不同高度的导轨。
    XCTAssertEqual(minimumImage, [slider minimumTrackImageForState:UIControlStateHighlighted]);
    XCTAssertEqual(maximumImage, [slider maximumTrackImageForState:UIControlStateHighlighted]);
    XCTAssertEqualWithAccuracy(minimumImage.size.height, maximumImage.size.height, .00001);
    slider.qmui_trackHeight = 3;
    [slider layoutIfNeeded];
    XCTAssertEqualWithAccuracy(slider.currentMinimumTrackImage.size.height, 3, .00001);
    XCTAssertEqualWithAccuracy(slider.currentMaximumTrackImage.size.height, 3, .00001);
    slider.qmui_trackHeight = 0;
    XCTAssertNil([slider minimumTrackImageForState:UIControlStateNormal]);
    XCTAssertNil([slider maximumTrackImageForState:UIControlStateNormal]);
    [systemSlider layoutIfNeeded];
    XCTAssertEqualObjects(systemSlider.currentMinimumTrackImage, systemMinimum);
    XCTAssertEqualObjects(systemSlider.currentMaximumTrackImage, systemMaximum);
    XCTAssertTrue(CGRectEqualToRect([systemSlider trackRectForBounds:systemSlider.bounds], systemTrack));
}

- (void)testTrackHeightPreservesBusinessImages {
    UISlider *slider = UISlider.new;
    UIImage *customImage = [UIImage qmui_imageWithColor:UIColor.redColor size:CGSizeMake(4, 4) cornerRadius:0];
    [slider setMinimumTrackImage:customImage forState:UIControlStateNormal];
    slider.qmui_trackHeight = 1;
    XCTAssertEqual([slider minimumTrackImageForState:UIControlStateNormal], customImage);
    UIImage *otherImage = [UIImage qmui_imageWithColor:UIColor.greenColor size:CGSizeMake(4, 4) cornerRadius:0];
    // 后设置的业务图片同样优先，不被 QMUI 生成的高亮图覆盖。
    [slider setMaximumTrackImage:otherImage forState:UIControlStateNormal];
    slider.qmui_trackHeight = 0;
    XCTAssertEqual([slider minimumTrackImageForState:UIControlStateNormal], customImage);
    XCTAssertEqual([slider maximumTrackImageForState:UIControlStateNormal], otherImage);
}

- (void)testStepIndicatorsFollowNativeThumbCenters {
    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 372, 44)];
    slider.qmui_trackHeight = 1;
    slider.qmui_thumbSize = CGSizeMake(14, 14);
    slider.qmui_numberOfSteps = 5;
    slider.qmui_stepControlConfiguration = ^(UISlider *sender, QMUISliderStepControl *control, NSUInteger index) {
        control.titleLabel.text = [NSString stringWithFormat:@"第%lu档", (unsigned long)index];
    };
    NSArray<QMUISliderStepControl *> *controls = [slider.subviews filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(UIView *view, NSDictionary *bindings) {
        return [view isKindOfClass:QMUISliderStepControl.class];
    }]];
    // 改变尺寸及布局方向时，每个刻度仍对应系统计算的圆点中心。
    for (NSNumber *width in @[@372, @230]) {
        slider.frame = CGRectMake(0, 0, width.doubleValue, 44);
        for (NSNumber *direction in @[@(UISemanticContentAttributeForceLeftToRight), @(UISemanticContentAttributeForceRightToLeft)]) {
            slider.semanticContentAttribute = direction.integerValue;
            [slider setNeedsLayout];
            [slider layoutIfNeeded];
            CGRect track = [slider trackRectForBounds:slider.bounds];
            for (NSUInteger index = 0; index < controls.count; index++) {
                QMUISliderStepControl *control = controls[index];
                [control layoutIfNeeded];
                CGRect indicator = [control.indicator convertRect:control.indicator.bounds toView:slider];
                CGRect thumb = [slider thumbRectForBounds:slider.bounds trackRect:track value:(float)index / (controls.count - 1)];
                XCTAssertEqualWithAccuracy(CGRectGetMidX(indicator), CGRectGetMidX(thumb), PixelOne);
                XCTAssertEqualWithAccuracy(CGRectGetMidY(indicator), CGRectGetMidY(thumb), PixelOne);
            }
        }
    }
}

- (void)testCustomThumbShadowSurvivesImageAndColorUpdates {
    UIWindowScene *scene = (id)[UIApplication.sharedApplication.connectedScenes.allObjects qmui_filterWithBlock:^BOOL(UIScene *item) { return [item isKindOfClass:UIWindowScene.class]; }].firstObject;
    XCTAssertNotNil(scene);
    if (!scene) return;
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:scene];
    UIViewController *root = UIViewController.new;
    window.rootViewController = root;
    UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 372, 44)];
    [root.view addSubview:slider];
    window.hidden = NO;
    @try {
        // 使用截图中 Demo 的自定义导轨路径，系统玻璃滑块不会呈现自定义圆点图片。
        slider.qmui_trackHeight = 1;
        NSShadow *shadow = [NSShadow qmui_shadowWithColor:UIColor.blueColor shadowOffset:CGSizeZero shadowRadius:5];
        // 先设置阴影，再生成圆点，验证不依赖私有 visualElement 的 didAddSubview:。
        slider.qmui_thumbShadow = shadow;
        slider.qmui_thumbSize = CGSizeMake(14, 14);
        [slider layoutIfNeeded];
        UIView *thumb = slider.qmui_thumbView;
        XCTAssertNotNil(thumb);
        XCTAssertEqualWithAccuracy(thumb.layer.shadowOpacity, 1, .00001);
        XCTAssertTrue(CGColorEqualToColor(thumb.layer.shadowColor, UIColor.blueColor.CGColor));
        slider.qmui_thumbSize = CGSizeMake(20, 20);
        slider.qmui_thumbColor = UIColor.greenColor;
        shadow.shadowColor = UIColor.redColor;
        slider.qmui_thumbShadow = shadow;
        slider.highlighted = YES;
        [slider layoutIfNeeded];
        thumb = slider.qmui_thumbView;
        XCTAssertNotNil(thumb);
        XCTAssertTrue(CGColorEqualToColor(thumb.layer.shadowColor, UIColor.redColor.CGColor));
        XCTAssertEqualWithAccuracy(thumb.layer.shadowRadius, 5, .00001);
        XCTAssertEqualWithAccuracy(slider.currentThumbImage.size.width, 20, .00001);
        slider.qmui_thumbShadow = nil;
        [slider layoutIfNeeded];
        XCTAssertEqualWithAccuracy(thumb.layer.shadowOpacity, 0, .00001);
    } @finally {
        window.hidden = YES;
    }
}

/// 按公开的当前导轨图片获取实际图像视图，不绑定系统内部类名。
- (NSArray<UIImageView *> *)trackImageViewsForSlider:(UISlider *)slider {
    NSMutableArray<UIImageView *> *result = NSMutableArray.new;
    NSMutableArray<UIView *> *views = slider.subviews.mutableCopy;
    for (NSUInteger index = 0; index < views.count; index++) {
        UIView *view = views[index];
        if ([view isKindOfClass:UIImageView.class]) {
            UIImageView *imageView = (UIImageView *)view;
            if (imageView.image && ([imageView.image isEqual:slider.currentMinimumTrackImage] || [imageView.image isEqual:slider.currentMaximumTrackImage])) [result addObject:imageView];
        }
        [views addObjectsFromArray:view.subviews];
    }
    return result;
}

- (void)testStepsTrackClippingMatchesEndpointsAndRestoresExistingMask {
    if (@available(iOS 26.0, *)) {
        UISlider *slider = [[UISlider alloc] initWithFrame:CGRectMake(0, 0, 372, 44)];
        slider.minimumTrackTintColor = UIColor.blueColor;
        slider.maximumTrackTintColor = UIColor.grayColor;
        slider.qmui_trackHeight = 1;
        slider.qmui_thumbSize = CGSizeMake(14, 14);
        slider.qmui_numberOfSteps = 5;
        slider.qmui_step = 2;
        for (NSNumber *width in @[@372, @230]) {
            slider.frame = CGRectMake(0, 0, width.doubleValue, 44);
            for (NSNumber *direction in @[@(UISemanticContentAttributeForceLeftToRight), @(UISemanticContentAttributeForceRightToLeft)]) {
                slider.semanticContentAttribute = direction.integerValue;
                for (NSNumber *highlighted in @[@NO, @YES]) {
                    slider.highlighted = highlighted.boolValue;
                    [slider setNeedsLayout];
                    [slider layoutIfNeeded];
                    CGRect track = [slider trackRectForBounds:slider.bounds];
                    CGRect first = [slider thumbRectForBounds:slider.bounds trackRect:track value:slider.minimumValue];
                    CGRect last = [slider thumbRectForBounds:slider.bounds trackRect:track value:slider.maximumValue];
                    NSArray<UIImageView *> *images = [self trackImageViewsForSlider:slider];
                    XCTAssertEqual(images.count, 2);
                    for (UIImageView *imageView in images) {
                        XCTAssertTrue([imageView.layer.mask isKindOfClass:CAShapeLayer.class]);
                        CAShapeLayer *clip = (CAShapeLayer *)imageView.layer.mask;
                        if (![clip isKindOfClass:CAShapeLayer.class]) continue;
                        CGRect rect = [imageView convertRect:CGPathGetBoundingBox(clip.path) toView:slider];
                        XCTAssertEqualWithAccuracy(CGRectGetMinX(rect), MIN(CGRectGetMidX(first), CGRectGetMidX(last)), .001);
                        XCTAssertEqualWithAccuracy(CGRectGetMaxX(rect), MAX(CGRectGetMidX(first), CGRectGetMidX(last)), .001);
                    }
                }
            }
        }
        XCTAssertEqualObjects(slider.minimumTrackTintColor, UIColor.blueColor);
        XCTAssertEqualObjects(slider.maximumTrackTintColor, UIColor.grayColor);
        UIImageView *imageView = [self trackImageViewsForSlider:slider].firstObject;
        CALayer *businessMask = CALayer.layer;
        imageView.layer.mask = businessMask;
        [slider setNeedsLayout];
        [slider layoutIfNeeded];
        XCTAssertEqual(imageView.layer.mask.mask, businessMask);
        slider.qmui_numberOfSteps = 0;
        XCTAssertEqual(imageView.layer.mask, businessMask);
        // 恢复另一侧的原 mask；高度重置时也能退出裁剪。
        imageView.layer.mask = nil;
        slider.qmui_numberOfSteps = 5;
        [slider layoutIfNeeded];
        slider.qmui_trackHeight = 0;
        [slider layoutIfNeeded];
        XCTAssertNil(imageView.layer.mask);
    }
}

@end
