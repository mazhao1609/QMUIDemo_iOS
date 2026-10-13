/**
 * Tencent is pleased to support the open source community by making QMUI_iOS available.
 * Copyright (C) 2016-2021 THL A29 Limited, a Tencent company. All rights reserved.
 * Licensed under the MIT License (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 * http://opensource.org/licenses/MIT
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
 */

//
//  QMUINavigationButton.m
//  QMUIKit
//
//  Created by QMUI Team on 2018/4/9.
//

#import "QMUINavigationButton.h"
#import "QMUICore.h"
#import "UIImage+QMUI.h"
#import "UIColor+QMUI.h"
#import "UIViewController+QMUI.h"
#import "QMUINavigationController.h"
#import "UIControl+QMUI.h"
#import "UIView+QMUI.h"
#import "NSString+QMUI.h"
#import "UINavigationController+QMUI.h"
#import "UINavigationItem+QMUI.h"
#import "UINavigationBar+QMUI.h"
#import "NSArray+QMUI.h"
#import "NSObject+QMUI.h"

@interface UINavigationController (QMUIPlainBackButtonPrivate)
- (BOOL)canPopViewController:(UIViewController *)viewController byPopGesture:(BOOL)byPopGesture;
@end

@interface UIViewController (QMUIPlainBackButtonPrivate)
- (void)qmuinb_handlePlainBackButton;
- (BOOL)qmuinb_popToViewControllerFromPlainBackButton:(UIViewController *)viewController;
@end

@interface UIBarButtonItem (QMUINavigationButtonLegacyPrivate)
+ (void)qmuinb_refreshLegacyNavigationButtons;
@end

/// 统一缩放普通图标，返回和关闭图标继续使用各自的配置图片尺寸。
static UIImage *QMUINavigationButtonConfiguredImage(UIImage *image) {
    CGSize size = NavBarButtonImageSize;
    if (!image || size.width <= 0 || size.height <= 0 || !isfinite(size.width) || !isfinite(size.height)) return image;
    return [[image qmui_imageResizedInLimitedSize:size] imageWithRenderingMode:image.renderingMode];
}

static UIFont *QMUINavigationButtonConfiguredFont(BOOL bold) {
    return (bold ? NavBarButtonFontBold : NavBarButtonFont) ?: [UIFont systemFontOfSize:17 weight:bold ? UIFontWeightSemibold : UIFontWeightRegular];
}

static UIImage *QMUINavigationButtonBackImage(UINavigationBar *bar) {
    UIImage *image = bar.backIndicatorImage ?: NavBarBackIndicatorImage ?: UINavigationBar.qmui_appearanceConfigured.backIndicatorImage;
    return image ?: [UIImage qmui_imageWithShape:QMUIImageShapeNavBack size:CGSizeMake(13, 21) lineWidth:2.5 tintColor:UIColor.blackColor];
}

typedef NS_ENUM(NSInteger, QMUINavigationButtonPosition) {
    QMUINavigationButtonPositionNone = -1,  // 不处于navigationBar最左（右）边的按钮，则使用None。用None则不会在alignmentRectInsets里调整位置
    QMUINavigationButtonPositionLeft,       // 用于leftBarButtonItem，如果用于leftBarButtonItems，则只对最左边的item使用，其他item使用QMUINavigationButtonPositionNone
    QMUINavigationButtonPositionRight,      // 用于rightBarButtonItem，如果用于rightBarButtonItems，则只对最右边的item使用，其他item使用QMUINavigationButtonPositionNone
};

@interface QMUINavigationButton()

@property(nonatomic, assign) QMUINavigationButtonPosition buttonPosition;
@property(nonatomic, strong) UIImage *defaultHighlightedImage;// 在 set normal image 时自动拿 normal image 加 alpha 作为 highlighted image
@property(nonatomic, strong) UIImage *defaultDisabledImage;// 在 set normal image 时自动拿 normal image 加 alpha 作为 disabled image
@property(nonatomic, strong) NSMutableDictionary<NSNumber *, UIImage *> *sourceImages;
@property(nonatomic, weak) UINavigationBar *legacyNavigationBar;
@property(nonatomic, weak) UIBarButtonItem *legacyBarButtonItem;
- (void)qmuinb_refreshConfiguration;
@end


@implementation QMUINavigationButton

- (instancetype)init {
    return [self initWithType:QMUINavigationButtonTypeNormal];
}

- (instancetype)initWithType:(QMUINavigationButtonType)type {
    return [self initWithType:type title:nil];
}

- (instancetype)initWithType:(QMUINavigationButtonType)type title:(NSString *)title {
    if (self = [super initWithFrame:CGRectZero]) {
        _type = type;
        self.buttonPosition = QMUINavigationButtonPositionNone;
        [self setTitle:title forState:UIControlStateNormal];
        [self renderButtonStyle];
        [self sizeToFit];
    }
    return self;
}

- (instancetype)initWithImage:(UIImage *)image {
    if (self = [self initWithType:QMUINavigationButtonTypeImage]) {
        [self setImage:image forState:UIControlStateNormal];
        [self sizeToFit];
    }
    return self;
}

- (void)renderButtonStyle {
    UIFont *font = QMUINavigationButtonConfiguredFont(NO);
    if (font) {
        self.titleLabel.font = font;
    }
    self.titleLabel.backgroundColor = UIColorClear;
    self.titleLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    self.contentMode = UIViewContentModeCenter;
    self.contentHorizontalAlignment = UIControlContentHorizontalAlignmentCenter;
    self.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    self.qmui_automaticallyAdjustTouchHighlightedInScrollView = YES;
    
    // UIBarButtonItem 默认都是跟随 tintColor 的，所以这里让图片也是用 alwaysTemplate 模式
    self.adjustsImageTintColorAutomatically = YES;
    
    if (self.type == QMUINavigationButtonTypeImage) {
        // 让 iOS 11 及以后也能走到 alignmentRectInsets，iOS 10 及以前的系统就算不置为 NO 也可以走到 alignmentRectInsets，从而保证 image 类型的按钮的布局、间距与系统的保持一致
        self.translatesAutoresizingMaskIntoConstraints = NO;
    }
    
    // 导航按钮使用公开配置接口，图片的各状态仍沿用 QMUI 生成的 alpha 效果。
    UIButtonConfiguration *configuration = [UIButtonConfiguration plainButtonConfiguration];
    configuration.contentInsets = NSDirectionalEdgeInsetsZero;
    
    switch (self.type) {
        case QMUINavigationButtonTypeNormal:
            break;
        case QMUINavigationButtonTypeImage:
            // 拓展宽度，以保证用 leftBarButtonItems/rightBarButtonItems 时，按钮与按钮之间间距与系统的保持一致
            configuration.contentInsets = NSDirectionalEdgeInsetsMake(0, NavBarButtonContentHorizontalPadding, 0, NavBarButtonContentHorizontalPadding);
            break;
        case QMUINavigationButtonTypeBold: {
            font = QMUINavigationButtonConfiguredFont(YES);
            if (font) {
                self.titleLabel.font = font;
            }
        }
            break;
        case QMUINavigationButtonTypeBack: {
            self.qmui_outsideEdge = UIEdgeInsetsMake(-12, -12, -24, -24);
            UIImage *backIndicatorImage = QMUINavigationButtonBackImage(nil);
            [self setImage:backIndicatorImage forState:UIControlStateNormal];
            [self setImage:[backIndicatorImage qmui_imageWithAlpha:NavBarHighlightedAlpha] forState:UIControlStateHighlighted];
            [self setImage:[backIndicatorImage qmui_imageWithAlpha:NavBarDisabledAlpha] forState:UIControlStateDisabled];
            
            self.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
            
            // @warning 这些数值都是每个iOS版本核对过没问题的，如果修改则要检查要每个版本里与系统UIBarButtonItem的布局是否一致
            UIOffset titleOffsetBaseOnSystem = UIOffsetMake(NavBarButtonImagePadding, 0);
            UIOffset configurationOffset = NavBarBarBackButtonTitlePositionAdjustment;
            configuration.imagePadding = MAX(0, titleOffsetBaseOnSystem.horizontal + configurationOffset.horizontal);
        }
            break;
            
        default:
            break;
    }
    self.configuration = configuration;
    __weak QMUINavigationButton *weakSelf = self;
    self.configurationUpdateHandler = ^(UIButton *button) {
        QMUINavigationButton *strongSelf = weakSelf;
        if (!strongSelf) return;
        UIButtonConfiguration *updatedConfiguration = [button.configuration copy];
        updatedConfiguration.title = button.currentTitle;
        UIImage *image = strongSelf.sourceImages[@(button.state)] ?: strongSelf.sourceImages[@(UIControlStateNormal)];
        if (strongSelf.type == QMUINavigationButtonTypeImage) {
            if (strongSelf.legacyNavigationBar) image = QMUINavigationButtonConfiguredImage(image);
            CGFloat padding = MAX(0, NavBarButtonContentHorizontalPadding);
            updatedConfiguration.contentInsets = NSDirectionalEdgeInsetsMake(0, padding, 0, padding);
        }
        updatedConfiguration.imagePadding = MAX(0, NavBarButtonImagePadding + (strongSelf.type == QMUINavigationButtonTypeBack ? NavBarBarBackButtonTitlePositionAdjustment.horizontal : 0));
        UIColor *color = strongSelf.legacyBarButtonItem.tintColor ?: strongSelf.legacyNavigationBar.tintColor ?: button.tintColor;
        UIColor *titleColor = [button titleColorForState:button.state] ?: color;
        if (strongSelf.legacyNavigationBar) {
            CGFloat alpha = !button.enabled ? NavBarDisabledAlpha : button.highlighted ? NavBarHighlightedAlpha : 1;
            titleColor = [color colorWithAlphaComponent:alpha];
        }
        // 显式配置颜色，避免 iOS 26 将自定义粗体文字和 template 图片显示成黑色。
        updatedConfiguration.baseForegroundColor = titleColor;
        updatedConfiguration.image = image && strongSelf.adjustsImageTintColorAutomatically ? [image imageWithTintColor:color renderingMode:UIImageRenderingModeAlwaysOriginal] : image;
        UIFont *titleFont = QMUINavigationButtonConfiguredFont(strongSelf.type == QMUINavigationButtonTypeBold);
        updatedConfiguration.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey, id> *(NSDictionary<NSAttributedStringKey, id> *attributes) {
            NSMutableDictionary *result = attributes.mutableCopy;
            result[NSFontAttributeName] = titleFont;
            if (titleColor) result[NSForegroundColorAttributeName] = titleColor;
            return result;
        };
        button.configuration = updatedConfiguration;
    };
}

- (void)layoutSubviews {
    [super layoutSubviews];
    if (self.class == QMUINavigationButton.class && self.legacyNavigationBar && self.type == QMUINavigationButtonTypeImage && self.configuration.image) {
        // 旧系统可能把纯图片 configuration 的内容放在顶部；仅校正自己的公开 imageView，
        // 按统一的 44pt 按钮高度居中，不修改导航栏或系统按钮容器。
        CGPoint center = self.imageView.center;
        center.y = [self convertPoint:CGPointMake(CGRectGetMidX(self.bounds), CGRectGetMidY(self.bounds)) toView:self.imageView.superview].y;
        self.imageView.center = center;
    }
    if (self.type == QMUINavigationButtonTypeBack) {
        // 配置接口不提供标题纵向偏移，仅移动自定义按钮自己的标签。
        self.titleLabel.frame = CGRectOffset(self.titleLabel.frame, 0, NavBarBarBackButtonTitlePositionAdjustment.vertical);
    }
}

- (void)setImage:(UIImage *)image forState:(UIControlState)state {
    if (image && self.adjustsImageTintColorAutomatically) {
        image = [image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    
    if (image && self.sourceImages[@(state)] != image) {
        if (state == UIControlStateNormal) {
            // 将 normal image 处理成对应的 highlighted image 和 disabled image
            self.defaultHighlightedImage = [[image qmui_imageWithAlpha:NavBarHighlightedAlpha] imageWithRenderingMode:image.renderingMode];
            [self setImage:self.defaultHighlightedImage forState:UIControlStateHighlighted];
            
            self.defaultDisabledImage = [[image qmui_imageWithAlpha:NavBarDisabledAlpha] imageWithRenderingMode:image.renderingMode];
            [self setImage:self.defaultDisabledImage forState:UIControlStateDisabled];
        } else {
            // 如果业务主动设置了非 normal 状态的 image，则把之前 QMUI 自动加上的两个 image 去掉，相当于认为业务希望完全控制这个按钮在所有 state 下的图片
            if (image != self.defaultHighlightedImage && image != self.defaultDisabledImage) {
                if (self.sourceImages[@(UIControlStateHighlighted)] == self.defaultHighlightedImage && state != UIControlStateHighlighted) {
                    [self setImage:nil forState:UIControlStateHighlighted];
                }
                if (self.sourceImages[@(UIControlStateDisabled)] == self.defaultDisabledImage && state != UIControlStateDisabled) {
                    [self setImage:nil forState:UIControlStateDisabled];
                }
            }
        }
    }
    
    if (!self.sourceImages) self.sourceImages = NSMutableDictionary.new;
    self.sourceImages[@(state)] = image;
    if (self.type == QMUINavigationButtonTypeImage && self.legacyNavigationBar) image = QMUINavigationButtonConfiguredImage(image);
    [super setImage:image forState:state];
}

- (void)qmuinb_refreshConfiguration {
    if (self.type == QMUINavigationButtonTypeImage) {
        // iOS 15/16 的 UIButton 同时参考旧状态图片和 configuration 计算位置，
        // 两者尺寸必须一致；原图单独保存，改尺寸和关闭开关时不会反复缩放损失清晰度。
        for (NSNumber *state in self.sourceImages.allKeys) {
            UIImage *image = self.sourceImages[state];
            if (self.legacyNavigationBar) image = QMUINavigationButtonConfiguredImage(image);
            [super setImage:image forState:state.unsignedIntegerValue];
        }
    }
    [self setNeedsUpdateConfiguration];
    [self updateConfiguration];
    [self invalidateIntrinsicContentSize];
    [self setNeedsLayout];
}

- (CGSize)intrinsicContentSize {
    CGSize size = [super intrinsicContentSize];
    return self.legacyNavigationBar ? CGSizeMake(MAX(1, size.width), 44) : size;
}

- (void)setAdjustsImageTintColorAutomatically:(BOOL)adjustsImageTintColorAutomatically {
    BOOL valueDifference = _adjustsImageTintColorAutomatically != adjustsImageTintColorAutomatically;
    _adjustsImageTintColorAutomatically = adjustsImageTintColorAutomatically;
    
    if (valueDifference) {
        [self updateImageRenderingModeIfNeeded];
    }
}

- (void)updateImageRenderingModeIfNeeded {
    if (self.currentImage) {
        NSArray<NSNumber *> *states = @[@(UIControlStateNormal), @(UIControlStateHighlighted), @(UIControlStateSelected), @(UIControlStateSelected|UIControlStateHighlighted), @(UIControlStateDisabled)];
        
        for (NSNumber *number in states) {
            UIImage *image = self.sourceImages[number];
            if (!image) {
                return;
            }
            
            if (self.adjustsImageTintColorAutomatically) {
                // 这里的 setImage: 操作不需要使用 renderingMode 对 image 重新处理，而是放到重写的 setImage:forState 里去做就行了
                [self setImage:image forState:[number unsignedIntegerValue]];
            } else {
                // 如果不需要用 template 的模式渲染，并且之前是使用 template 的，则把 renderingMode 改回 original
                [self setImage:[image imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal] forState:[number unsignedIntegerValue]];
            }
        }
    }
}

// 自定义nav按钮，需要根据这个来修改title的三态颜色。
- (void)tintColorDidChange {
    [super tintColorDidChange];
    [self setTitleColor:self.tintColor forState:UIControlStateNormal];
    [self setTitleColor:[self.tintColor colorWithAlphaComponent:NavBarHighlightedAlpha] forState:UIControlStateHighlighted];
    [self setTitleColor:[self.tintColor colorWithAlphaComponent:NavBarDisabledAlpha] forState:UIControlStateDisabled];
    [self setNeedsUpdateConfiguration];
}

// 对按钮内容添加偏移，让UIBarButtonItem适配最新设备的系统行为，统一位置。注意 iOS 11 及以后，只有 image 类型的才会走进来
- (UIEdgeInsets)alignmentRectInsets {
    
    UIEdgeInsets insets = [super alignmentRectInsets];
    // 普通按钮布局按最终可见内容定位，无需旧版系统布局的额外像素偏移。
    if (self.legacyNavigationBar) return insets;
    
    if (self.type == QMUINavigationButtonTypeNormal || self.type == QMUINavigationButtonTypeBold) {
        // 对于奇数大小的字号，不同 iOS 版本的偏移策略不同，统一一下
        if (self.titleLabel.font.pointSize / 2.0 > 0) {
            insets.top = -PixelOne;
            insets.bottom = PixelOne;
        }
    } else if (self.type == QMUINavigationButtonTypeImage) {
        // 图片类型的按钮，分别对最左、最右那个按钮调整 inset（这里与 UINavigationItem(QMUINavigationButton) 里的 position 赋值配合使用）
        if (self.buttonPosition == QMUINavigationButtonPositionLeft) {
            insets.left = NavBarButtonContentHorizontalPadding;
        } else if (self.buttonPosition == QMUINavigationButtonPositionRight) {
            insets.right = NavBarButtonContentHorizontalPadding;
        }
        
        insets.top = 1;
    } else if (self.type == QMUINavigationButtonTypeBack) {
        insets.top = PixelOne;
    }
    
    return insets;
}

@end

@interface UINavigationController (QMUILegacyNavigationButtonPrivate)
- (void)qmuinb_updateLegacyNavigationButtons;
- (void)qmuinb_layoutLegacyNavigationButtons;
@end

/// 保存业务原始视图和变换，关闭开关时完整恢复。
@interface _QMUINBLegacyBarItemState : NSObject
@property(nonatomic, weak) UINavigationController *navigationController;
@property(nonatomic, strong) UIView *originalCustomView;
@property(nonatomic, assign) CGAffineTransform originalTransform;
@property(nonatomic, assign) BOOL originalHidesSharedBackground;
@property(nonatomic, strong) UIButton *generatedButton;
@property(nonatomic, copy) void (^originalLayoutSubviewsBlock)(__kindof UIView *view);
@property(nonatomic, copy) void (^legacyLayoutSubviewsBlock)(__kindof UIView *view);
@property(nonatomic, copy) void (^originalFrameDidChangeBlock)(__kindof UIView *view, CGRect precedingFrame);
@property(nonatomic, copy) void (^legacyFrameDidChangeBlock)(__kindof UIView *view, CGRect precedingFrame);
@property(nonatomic, assign) BOOL updating;
@end
@implementation _QMUINBLegacyBarItemState
@end

@interface _QMUINBLegacyNavigationItemState : NSObject
@property(nonatomic, weak) UINavigationController *navigationController;
@property(nonatomic, strong) UIBarButtonItem *generatedBackItem;
@property(nonatomic, copy) NSArray<NSValue *> *backHistory;
@property(nonatomic, assign) BOOL suppressesSystemBackButton;
@property(nonatomic, assign) BOOL requestedHidesBackButton;
@property(nonatomic, assign) BOOL updating;
@end
@implementation _QMUINBLegacyNavigationItemState
@end

static char kQMUINBLegacyBarItemState;
static char kQMUINBLegacyNavigationItemState;
static char kQMUINBLegacySystemItem;
static char kQMUINBLegacyManagedItems;
static char kQMUINBLegacyLayingOut;
static void (*QMUINBLegacySetSystemBackButtonHidden)(id, SEL, BOOL, BOOL);

static void QMUINBLegacyRestoreSystemBackButton(UINavigationItem *item, _QMUINBLegacyNavigationItemState *state) {
    if (!state.suppressesSystemBackButton) return;
    state.suppressesSystemBackButton = NO;
    // 仅恢复框架临时隐藏的系统箭头，不经过业务 setter，避免被 Demo 记成用户主动隐藏返回按钮。
    QMUINBLegacySetSystemBackButtonHidden(item, @selector(setHidesBackButton:animated:), state.requestedHidesBackButton, NO);
}

static NSHashTable<UIBarButtonItem *> *QMUINBLegacyManagedItems(UINavigationController *nav) {
    NSHashTable *items = objc_getAssociatedObject(nav, &kQMUINBLegacyManagedItems);
    if (!items) {
        items = NSHashTable.weakObjectsHashTable;
        objc_setAssociatedObject(nav, &kQMUINBLegacyManagedItems, items, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return items;
}

static NSHashTable<UINavigationController *> *QMUINBLegacyNavigationControllers(void) {
    static NSHashTable *controllers;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ controllers = NSHashTable.weakObjectsHashTable; });
    return controllers;
}

static NSArray<UIViewController *> *QMUINBLegacyNavigationStack(UINavigationController *nav) {
    NSArray<UIViewController *> *controllers = nav.viewControllers;
    // 跨多级返回时 UIKit 会暂时把离场页放在数组首位，不能据此给根页面添加返回按钮。
    if (controllers.count > 1 && controllers.firstObject != nav.qmui_rootViewController) {
        return [controllers subarrayWithRange:NSMakeRange(1, controllers.count - 1)];
    }
    return controllers;
}

static BOOL QMUINBLegacyManagesNavigationController(UINavigationController *nav) {
    if (!nav) return NO;
    NSArray<Class> *classes = NavBarContainerClasses.count ? NavBarContainerClasses : @[QMUINavigationController.class];
    for (Class containerClass in classes) {
        if ([containerClass isSubclassOfClass:UINavigationController.class] && [nav isKindOfClass:containerClass]) return YES;
    }
    return NO;
}

static _QMUINBLegacyNavigationItemState *QMUINBLegacyNavigationItemState(UINavigationItem *item) {
    _QMUINBLegacyNavigationItemState *state = objc_getAssociatedObject(item, &kQMUINBLegacyNavigationItemState);
    if (!state) {
        state = _QMUINBLegacyNavigationItemState.new;
        objc_setAssociatedObject(item, &kQMUINBLegacyNavigationItemState, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    return state;
}

/// 仅记录公开初始化参数，不通过私有 KVC 获取系统按钮类型。
static UIImage *QMUINBLegacySystemImage(UIBarButtonItem *item) {
    NSNumber *value = objc_getAssociatedObject(item, &kQMUINBLegacySystemItem);
    if (!value) return nil;
    NSDictionary<NSNumber *, NSString *> *symbols = @{
        @(UIBarButtonSystemItemAdd): @"plus", @(UIBarButtonSystemItemCompose): @"square.and.pencil",
        @(UIBarButtonSystemItemReply): @"arrowshape.turn.up.left", @(UIBarButtonSystemItemAction): @"square.and.arrow.up",
        @(UIBarButtonSystemItemOrganize): @"folder", @(UIBarButtonSystemItemBookmarks): @"book",
        @(UIBarButtonSystemItemSearch): @"magnifyingglass", @(UIBarButtonSystemItemRefresh): @"arrow.clockwise",
        @(UIBarButtonSystemItemStop): @"stop.fill", @(UIBarButtonSystemItemCamera): @"camera",
        @(UIBarButtonSystemItemTrash): @"trash", @(UIBarButtonSystemItemPlay): @"play.fill",
        @(UIBarButtonSystemItemPause): @"pause.fill", @(UIBarButtonSystemItemRewind): @"backward.fill",
        @(UIBarButtonSystemItemFastForward): @"forward.fill", @(UIBarButtonSystemItemUndo): @"arrow.uturn.backward",
        @(UIBarButtonSystemItemRedo): @"arrow.uturn.forward", @(UIBarButtonSystemItemClose): @"xmark"
    };
    NSString *name = symbols[value];
    return name ? [UIImage systemImageNamed:name withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightRegular]] : nil;
}

static NSString *QMUINBLegacySystemTitle(UIBarButtonItem *item) {
    NSNumber *value = objc_getAssociatedObject(item, &kQMUINBLegacySystemItem);
    if (!value) return nil;
    // 系统文字优先使用 item.title，此处仅补齐初始化时没有公开文字的常用按钮。
    BOOL chinese = [NSLocale.preferredLanguages.firstObject hasPrefix:@"zh"];
    switch (value.integerValue) {
        case UIBarButtonSystemItemDone: return chinese ? @"完成" : @"Done";
        case UIBarButtonSystemItemCancel: return chinese ? @"取消" : @"Cancel";
        case UIBarButtonSystemItemEdit: return chinese ? @"编辑" : @"Edit";
        case UIBarButtonSystemItemSave: return chinese ? @"保存" : @"Save";
        default: return nil;
    }
}

@interface _QMUINBLegacyButton : UIButton
@property(nonatomic, weak) UIBarButtonItem *barButtonItem;
@property(nonatomic, weak) UINavigationController *navigationController;
@property(nonatomic, strong) UIColor *renderedImageTintColor;
@property(nonatomic, assign) BOOL rendersTemplateImage;
- (void)refreshFromBarButtonItem;
- (void)updateNavigationTintColor;
@end

@implementation _QMUINBLegacyButton

- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.translatesAutoresizingMaskIntoConstraints = NO;
        [self addTarget:self action:@selector(handlePrimaryAction) forControlEvents:UIControlEventTouchUpInside];
    }
    return self;
}

- (void)refreshFromBarButtonItem {
    UIBarButtonItem *item = self.barButtonItem;
    UIButtonConfiguration *configuration = UIButtonConfiguration.plainButtonConfiguration;
    configuration.contentInsets = NSDirectionalEdgeInsetsZero;
    configuration.imagePadding = MAX(0, NavBarButtonImagePadding);
    configuration.title = item.title ?: QMUINBLegacySystemTitle(item);
    configuration.image = item.image ?: QMUINBLegacySystemImage(item);
    // 返回与关闭图标各自有配置项，不能按普通图标尺寸再次放大。
    if (![item qmui_getBoundBOOLForKey:@"qmuinb_plainBackButton"] && ![item qmui_getBoundBOOLForKey:@"qmuinb_closeButton"]) {
        configuration.image = QMUINavigationButtonConfiguredImage(configuration.image);
    }
    self.rendersTemplateImage = configuration.image.renderingMode != UIImageRenderingModeAlwaysOriginal;
    if (configuration.image && !configuration.title.length && ![item qmui_getBoundBOOLForKey:@"qmuinb_plainBackButton"]) {
        CGFloat padding = MAX(0, NavBarButtonContentHorizontalPadding);
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(0, padding, 0, padding);
    }
    NSDictionary *attributes = [item titleTextAttributesForState:UIControlStateNormal];
    UIFont *font = attributes[NSFontAttributeName] ?: (item.style == UIBarButtonItemStylePlain ? NavBarButtonFont : NavBarButtonFontBold);
    font = font ?: QMUINavigationButtonConfiguredFont(item.style != UIBarButtonItemStylePlain);
    configuration.titleTextAttributesTransformer = ^NSDictionary *(NSDictionary *incoming) {
        NSMutableDictionary *result = incoming.mutableCopy;
        [result addEntriesFromDictionary:attributes ?: @{}];
        result[NSFontAttributeName] = font;
        return result;
    };
    self.renderedImageTintColor = nil;
    self.configuration = configuration;
    [self updateNavigationTintColor];
    self.enabled = item.enabled;
    self.selected = item.selected;
    self.menu = item.menu;
    self.showsMenuAsPrimaryAction = item.menu && !item.primaryAction && !item.action;
    self.changesSelectionAsPrimaryAction = item.changesSelectionAsPrimaryAction;
    if (@available(iOS 16.0, *)) {
        self.hidden = item.hidden;
        self.preferredMenuElementOrder = item.preferredMenuElementOrder;
    }
    self.accessibilityLabel = item.accessibilityLabel ?: configuration.title;
    self.accessibilityHint = item.accessibilityHint;
    self.accessibilityIdentifier = item.accessibilityIdentifier;
    self.accessibilityTraits = item.accessibilityTraits | UIAccessibilityTraitButton;
    [self invalidateIntrinsicContentSize];
    [self sizeToFit];
}

- (CGSize)intrinsicContentSize {
    CGSize size = [super intrinsicContentSize];
    return CGSizeMake(MAX(1, size.width), 44);
}

- (void)layoutSubviews {
    // 页面样式常在按钮创建后才应用，布局时同步最新颜色，避免保留上一页的 tint。
    [self updateNavigationTintColor];
    [super layoutSubviews];
    // UIKit 会在导航栏布局后再次调整图片/文字，此时也要按最终内容位置对齐。
    _QMUINBLegacyBarItemState *state = objc_getAssociatedObject(self.barButtonItem, &kQMUINBLegacyBarItemState);
    [state.navigationController qmuinb_layoutLegacyNavigationButtons];
}

- (void)updateNavigationTintColor {
    if (!self.navigationController) return;
    UIColor *color = self.barButtonItem.tintColor ?: self.navigationController.navigationBar.tintColor ?: (QMUICMIActivated ? NavBarTintColor : UIColor.qmui_systemTintColor);
    // 显式指定配置前景色，避免普通按钮从 iOS 26 的系统按钮容器继承另一套颜色。
    if (![self.tintColor isEqual:color]) self.tintColor = color;
    // 系统 UIBarButtonItem 的图片本身会跟随导航栏 tintColor，旧版兼容按钮也统一保持这一点。
    BOOL shouldTintImage = self.rendersTemplateImage && self.configuration.image != nil;
    if (![self.configuration.baseForegroundColor isEqual:color] || (shouldTintImage && ![self.renderedImageTintColor isEqual:color])) {
        UIButtonConfiguration *configuration = self.configuration.copy;
        configuration.baseForegroundColor = color;
        if (shouldTintImage && configuration.image) {
            // UIButtonConfiguration 在 iOS 26 可能直接采用图片原色，旧版系统按钮的
            // template 图标统一转为已着色图片，确保返回箭头和普通图标跟随导航栏颜色。
            configuration.image = [configuration.image imageWithTintColor:color renderingMode:UIImageRenderingModeAlwaysOriginal];
            self.renderedImageTintColor = color;
        }
        self.configuration = configuration;
    }
}

- (void)handlePrimaryAction {
    UIBarButtonItem *item = self.barButtonItem;
    if (!item.enabled) return;
    if (item.changesSelectionAsPrimaryAction) item.selected = self.selected;
    // 保留原 UIBarButtonItem 的动作和 responder chain，不复制或替换业务 target。
    if (item.primaryAction) [self sendAction:item.primaryAction];
    else if (item.action) [UIApplication.sharedApplication sendAction:item.action to:item.target from:item forEvent:nil];
}

@end

static void QMUINBLegacyRestoreCustomView(_QMUINBLegacyBarItemState *state) {
    UIView *view = state.originalCustomView;
    if (!view) return;
    if (view.class == QMUINavigationButton.class) {
        QMUINavigationButton *button = (id)view;
        button.legacyNavigationBar = nil;
        button.legacyBarButtonItem = nil;
        [button qmuinb_refreshConfiguration];
    }
    if (state.legacyLayoutSubviewsBlock && view.qmui_layoutSubviewsBlock == state.legacyLayoutSubviewsBlock) {
        view.qmui_layoutSubviewsBlock = state.originalLayoutSubviewsBlock;
    }
    if (state.legacyFrameDidChangeBlock && view.qmui_frameDidChangeBlock == state.legacyFrameDidChangeBlock) {
        view.qmui_frameDidChangeBlock = state.originalFrameDidChangeBlock;
    }
    view.transform = state.originalTransform;
    state.legacyLayoutSubviewsBlock = nil;
    state.originalLayoutSubviewsBlock = nil;
    state.legacyFrameDidChangeBlock = nil;
    state.originalFrameDidChangeBlock = nil;
}

static void QMUINBLegacyRestoreItem(UIBarButtonItem *item) {
    _QMUINBLegacyBarItemState *state = objc_getAssociatedObject(item, &kQMUINBLegacyBarItemState);
    if (!state) return;
    objc_setAssociatedObject(item, &kQMUINBLegacyBarItemState, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    QMUINBLegacyRestoreCustomView(state);
    if (state.generatedButton && item.customView == state.generatedButton) item.customView = state.originalCustomView;
    item.qmui_hidesSharedBackground = state.originalHidesSharedBackground;
    UIViewController *controller = [item.target isKindOfClass:UIViewController.class] ? item.target : nil;
    _QMUINBLegacyNavigationItemState *owner = objc_getAssociatedObject(controller.navigationItem, &kQMUINBLegacyNavigationItemState);
    if (owner.generatedBackItem == item) {
        // 离栈但被业务保留的页面也要清理自动箭头，重新使用时再按当前配置生成。
        BOOL updating = owner.updating;
        owner.updating = YES;
        NSMutableArray *items = controller.navigationItem.leftBarButtonItems.mutableCopy;
        [items removeObjectIdenticalTo:item];
        controller.navigationItem.leftBarButtonItems = items;
        QMUINBLegacyRestoreSystemBackButton(controller.navigationItem, owner);
        owner.generatedBackItem = nil;
        owner.backHistory = nil;
        owner.updating = updating;
    }
}

static void QMUINBLegacyPrepareItem(UIBarButtonItem *item, UINavigationController *nav) {
    [QMUINBLegacyManagedItems(nav) addObject:item];
    _QMUINBLegacyBarItemState *state = objc_getAssociatedObject(item, &kQMUINBLegacyBarItemState);
    if (!state) {
        state = _QMUINBLegacyBarItemState.new;
        state.originalCustomView = item.customView;
        state.originalTransform = item.customView ? item.customView.transform : CGAffineTransformIdentity;
        state.originalHidesSharedBackground = item.qmui_hidesSharedBackground;
        state.navigationController = nav;
        objc_setAssociatedObject(item, &kQMUINBLegacyBarItemState, state, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
    if (state.updating) return;
    state.updating = YES;
    if (item.customView != (state.generatedButton ?: state.originalCustomView)) {
        // 业务动态替换 customView 时，保留新视图，撤销旧视图上的布局变换。
        QMUINBLegacyRestoreCustomView(state);
        state.originalCustomView = item.customView;
        state.originalTransform = item.customView ? item.customView.transform : CGAffineTransformIdentity;
        state.generatedButton = nil;
    }
    if (!item.customView && (item.title.length || item.image || QMUINBLegacySystemTitle(item) || QMUINBLegacySystemImage(item))) {
        _QMUINBLegacyButton *button = [[_QMUINBLegacyButton alloc] initWithFrame:CGRectZero];
        button.barButtonItem = item;
        button.navigationController = nav;
        state.generatedButton = button;
        item.customView = button;
    }
    [(_QMUINBLegacyButton *)state.generatedButton refreshFromBarButtonItem];
    if (item.customView.class == QMUINavigationButton.class) {
        QMUINavigationButton *button = (id)item.customView;
        button.legacyNavigationBar = nav.navigationBar;
        button.legacyBarButtonItem = item;
        if (button.type == QMUINavigationButtonTypeBack) {
            [button setImage:QMUINavigationButtonBackImage(nav.navigationBar) forState:UIControlStateNormal];
        }
        [button qmuinb_refreshConfiguration];
    }
    if (state.originalCustomView && (!state.legacyLayoutSubviewsBlock || state.originalCustomView.qmui_layoutSubviewsBlock != state.legacyLayoutSubviewsBlock)) {
        // 业务子类布局完成后再次定位，避免 UIKit 在导航栏布局之后把 customView 移回原位。
        // 串接并保存原回调，关闭开关或更换视图时恢复，弱引用避免视图与状态互相持有。
        state.originalLayoutSubviewsBlock = state.originalCustomView.qmui_layoutSubviewsBlock;
        __weak _QMUINBLegacyBarItemState *weakState = state;
        state.legacyLayoutSubviewsBlock = ^(__kindof UIView *view) {
            _QMUINBLegacyBarItemState *strongState = weakState;
            if (strongState.originalLayoutSubviewsBlock) strongState.originalLayoutSubviewsBlock(view);
            [strongState.navigationController qmuinb_layoutLegacyNavigationButtons];
        };
        state.originalCustomView.qmui_layoutSubviewsBlock = state.legacyLayoutSubviewsBlock;
    }
    if (state.originalCustomView && (!state.legacyFrameDidChangeBlock || state.originalCustomView.qmui_frameDidChangeBlock != state.legacyFrameDidChangeBlock)) {
        // UIKit 也会在 layoutSubviews 之后重新写入 customView 的 frame，最终位置变化时同步校正。
        state.originalFrameDidChangeBlock = state.originalCustomView.qmui_frameDidChangeBlock;
        __weak _QMUINBLegacyBarItemState *weakState = state;
        state.legacyFrameDidChangeBlock = ^(__kindof UIView *view, CGRect precedingFrame) {
            _QMUINBLegacyBarItemState *strongState = weakState;
            if (strongState.originalFrameDidChangeBlock) strongState.originalFrameDidChangeBlock(view, precedingFrame);
            if (!strongState.updating) [strongState.navigationController qmuinb_layoutLegacyNavigationButtons];
        };
        state.originalCustomView.qmui_frameDidChangeBlock = state.legacyFrameDidChangeBlock;
    }
#ifdef IOS26_SDK_ALLOWED
    if (@available(iOS 26.0, *)) item.hidesSharedBackground = YES;
#endif
    state.updating = NO;
}

static void QMUINBLegacyItemDidChange(UIBarButtonItem *item) {
    _QMUINBLegacyBarItemState *state = objc_getAssociatedObject(item, &kQMUINBLegacyBarItemState);
    if (!state || state.updating) return;
    QMUINBLegacyPrepareItem(item, state.navigationController);
    [state.navigationController.navigationBar setNeedsLayout];
}

static void QMUINBLegacyNavigationItemDidChange(UINavigationItem *item) {
    _QMUINBLegacyNavigationItemState *state = objc_getAssociatedObject(item, &kQMUINBLegacyNavigationItemState);
    if (!state.updating) [state.navigationController qmuinb_updateLegacyNavigationButtons];
}

static CGRect QMUINBLegacyVisibleContentRect(UIView *view, _QMUINBLegacyBarItemState *state) {
    // 业务子类可能增加未读数、徽标等内容，必须按完整视图预留空间，不能只计算继承的箭头和标题。
    if (state.generatedButton || view.class == QMUINavigationButton.class) {
        UIButton *button = (id)view;
        // UIButtonConfiguration 会把图片和标题放入自己的容器，先转换到按钮坐标再计算内容范围。
        CGRect imageRect = (button.configuration.image || button.currentImage) ? [button.imageView convertRect:button.imageView.bounds toView:button] : CGRectNull;
        CGRect titleRect = (button.configuration.title.length || button.currentTitle.length) ? [button.titleLabel convertRect:button.titleLabel.bounds toView:button] : CGRectNull;
        CGRect content = CGRectUnion(imageRect, titleRect);
        if (!CGRectIsNull(content) && !CGRectIsEmpty(content)) return content;
    }
    return view.bounds;
}

@implementation UIBarButtonItem (QMUINavigationButton)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // 通过公开初始化参数识别图标型系统按钮，空间项保持系统实现。
        OverrideImplementation(self, @selector(initWithBarButtonSystemItem:target:action:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^UIBarButtonItem *(UIBarButtonItem *selfObject, UIBarButtonSystemItem systemItem, id target, SEL action) {
                UIBarButtonItem *(*original)(id, SEL, UIBarButtonSystemItem, id, SEL) = (void *)originalIMPProvider();
                UIBarButtonItem *result = original(selfObject, originCMD, systemItem, target, action);
                objc_setAssociatedObject(result, &kQMUINBLegacySystemItem, @(systemItem), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                return result;
            };
        });
        OverrideImplementation(self, @selector(initWithBarButtonSystemItem:primaryAction:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^UIBarButtonItem *(UIBarButtonItem *selfObject, UIBarButtonSystemItem systemItem, UIAction *action) {
                UIBarButtonItem *(*original)(id, SEL, UIBarButtonSystemItem, UIAction *) = (void *)originalIMPProvider();
                UIBarButtonItem *result = original(selfObject, originCMD, systemItem, action);
                objc_setAssociatedObject(result, &kQMUINBLegacySystemItem, @(systemItem), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                return result;
            };
        });
        OverrideImplementation(self, @selector(initWithBarButtonSystemItem:menu:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^UIBarButtonItem *(UIBarButtonItem *selfObject, UIBarButtonSystemItem systemItem, UIMenu *menu) {
                UIBarButtonItem *(*original)(id, SEL, UIBarButtonSystemItem, UIMenu *) = (void *)originalIMPProvider();
                UIBarButtonItem *result = original(selfObject, originCMD, systemItem, menu);
                objc_setAssociatedObject(result, &kQMUINBLegacySystemItem, @(systemItem), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                return result;
            };
        });
        if ([self instancesRespondToSelector:@selector(initWithBarButtonSystemItem:primaryAction:menu:)]) {
            OverrideImplementation(self, @selector(initWithBarButtonSystemItem:primaryAction:menu:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
                return ^UIBarButtonItem *(UIBarButtonItem *selfObject, UIBarButtonSystemItem systemItem, UIAction *action, UIMenu *menu) {
                    UIBarButtonItem *(*original)(id, SEL, UIBarButtonSystemItem, UIAction *, UIMenu *) = (void *)originalIMPProvider();
                    UIBarButtonItem *result = original(selfObject, originCMD, systemItem, action, menu);
                    objc_setAssociatedObject(result, &kQMUINBLegacySystemItem, @(systemItem), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                    return result;
                };
            });
        }
        // 页面外观可能在按钮生成后才设置导航栏 tintColor，及时刷新旧版按钮的配置颜色。
        ExtendImplementationOfVoidMethodWithSingleArgument(UINavigationBar.class, @selector(setTintColor:), UIColor *, ^(UINavigationBar *bar, UIColor *color) {
            [UIBarButtonItem qmuinb_refreshLegacyNavigationButtons];
        });
        SEL objectSetters[] = {@selector(setTitle:), @selector(setImage:), @selector(setTintColor:), @selector(setMenu:), @selector(setPrimaryAction:), @selector(setCustomView:), @selector(setAccessibilityLabel:), @selector(setAccessibilityHint:)};
        for (NSUInteger index = 0; index < sizeof(objectSetters) / sizeof(SEL); index++) {
            ExtendImplementationOfVoidMethodWithSingleArgument(self, objectSetters[index], id, ^(UIBarButtonItem *item, id value) { QMUINBLegacyItemDidChange(item); });
        }
        SEL boolSetters[] = {@selector(setEnabled:), @selector(setSelected:), @selector(setHidden:), @selector(setChangesSelectionAsPrimaryAction:)};
        for (NSUInteger index = 0; index < sizeof(boolSetters) / sizeof(SEL); index++) {
            if ([self instancesRespondToSelector:boolSetters[index]]) ExtendImplementationOfVoidMethodWithSingleArgument(self, boolSetters[index], BOOL, ^(UIBarButtonItem *item, BOOL value) { QMUINBLegacyItemDidChange(item); });
        }
        ExtendImplementationOfVoidMethodWithSingleArgument(self, @selector(setStyle:), UIBarButtonItemStyle, ^(UIBarButtonItem *item, UIBarButtonItemStyle value) { QMUINBLegacyItemDidChange(item); });
        ExtendImplementationOfVoidMethodWithTwoArguments(self, @selector(setTitleTextAttributes:forState:), NSDictionary *, UIControlState, ^(UIBarButtonItem *item, NSDictionary *attributes, UIControlState state) { QMUINBLegacyItemDidChange(item); });
    });
}

+ (void)qmuinb_refreshLegacyNavigationButtons {
    for (UINavigationController *nav in QMUINBLegacyNavigationControllers().allObjects) {
        [nav qmuinb_updateLegacyNavigationButtons];
        [nav.navigationBar setNeedsLayout];
    }
}

static char kAssociatedObjectKey_hidesSharedBackground;
- (void)setQmui_hidesSharedBackground:(BOOL)hidesSharedBackground {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_hidesSharedBackground, @(hidesSharedBackground), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    _QMUINBLegacyBarItemState *state = objc_getAssociatedObject(self, &kQMUINBLegacyBarItemState);
    if (state) state.originalHidesSharedBackground = hidesSharedBackground;
#ifdef IOS26_SDK_ALLOWED
    if (@available(iOS 26.0, *)) {
        // 只隐藏系统共享玻璃背景，不拆分按钮组或替换系统按钮视图。
        self.hidesSharedBackground = state ? YES : hidesSharedBackground;
    }
#endif
}

- (BOOL)qmui_hidesSharedBackground {
#ifdef IOS26_SDK_ALLOWED
    if (@available(iOS 26.0, *)) return self.hidesSharedBackground;
#endif
    return [objc_getAssociatedObject(self, &kAssociatedObjectKey_hidesSharedBackground) boolValue];
}

+ (instancetype)qmui_itemWithButton:(QMUINavigationButton *)button target:(nullable id)target action:(nullable SEL)action {
    if (!button) return nil;
    [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    return [[self alloc] initWithCustomView:button];
}

+ (instancetype)qmui_itemWithImage:(UIImage *)image target:(nullable id)target action:(nullable SEL)action {
    if (!image) return nil;
    return [[self alloc] initWithImage:image style:UIBarButtonItemStylePlain target:target action:action];
}

+ (instancetype)qmui_itemWithTitle:(NSString *)title target:(nullable id)target action:(nullable SEL)action {
    if (!title) return nil;
    return [[self alloc] initWithTitle:title style:UIBarButtonItemStylePlain target:target action:action];
}

+ (instancetype)qmui_itemWithBoldTitle:(NSString *)title target:(nullable id)target action:(nullable SEL)action {
    if (!title) return nil;
    return [[self alloc] initWithTitle:title style:UIBarButtonItemStyleDone target:target action:action];
}

+ (instancetype)qmui_backItemWithTitle:(nullable NSString *)title target:(nullable id)target action:(nullable SEL)action {
    QMUINavigationButton *button = [[QMUINavigationButton alloc] initWithType:QMUINavigationButtonTypeBack title:title];
    [button addTarget:target action:action forControlEvents:UIControlEventTouchUpInside];
    UIBarButtonItem *barButtonItem = [[self alloc] initWithCustomView:button];
    return barButtonItem;
}

+ (instancetype)qmui_backItemWithTarget:(nullable id)target action:(nullable SEL)action {
    NSString *backTitle = nil;
    if (NeedsBackBarButtonItemTitle) {
        backTitle = @"返回"; // 默认文字用返回
        if ([target isKindOfClass:[UIViewController class]]) {
            UIViewController *viewController = (UIViewController *)target;
            UIViewController *previousViewController = viewController.qmui_previousViewController;
            if (previousViewController.navigationItem.backBarButtonItem) {
                // 如果前一个界面有主动设置返回按钮的文字，则取这个文字
                backTitle = previousViewController.navigationItem.backBarButtonItem.title;
            } else if ([viewController respondsToSelector:@selector(qmui_backBarButtonItemTitleWithPreviousViewController:)]) {
                // 否则看是否有通过 QMUI 提供的接口来设置返回按钮的文字，有就用它的值
                backTitle = [((UIViewController<QMUINavigationControllerAppearanceDelegate> *)viewController) qmui_backBarButtonItemTitleWithPreviousViewController:previousViewController];
            } else if (previousViewController.title) {
                // 否则取上一个界面的标题
                backTitle = previousViewController.title;
            }
        }
    }
    
    return [self qmui_backItemWithTitle:backTitle target:target action:action];
}

+ (instancetype)qmui_plainBackItemWithViewController:(UIViewController *)viewController {
    UINavigationController *nav = viewController.navigationController;
    NSArray<UIViewController *> *controllers = QMUINBLegacyNavigationStack(nav);
    NSUInteger index = [controllers indexOfObject:viewController];
    _QMUINBLegacyNavigationItemState *state = objc_getAssociatedObject(viewController.navigationItem, &kQMUINBLegacyNavigationItemState);
    BOOL hidesBackButton = state.suppressesSystemBackButton ? state.requestedHidesBackButton : viewController.navigationItem.hidesBackButton;
    if (!nav || index == NSNotFound || index == 0 || hidesBackButton) return nil;
    if (@available(iOS 16.0, *)) {
        if (viewController.navigationItem.backAction) return nil;
    }
    UIImage *image = NavBarUsesLegacyButtonLayout ? QMUINavigationButtonBackImage(nav.navigationBar) : nav.navigationBar.backIndicatorImage ?: (QMUICMIActivated ? NavBarBackIndicatorImage : nil);
    if (!image) image = [UIImage systemImageNamed:@"chevron.backward" withConfiguration:[UIImageSymbolConfiguration configurationWithPointSize:20 weight:UIImageSymbolWeightSemibold]];
    UIBarButtonItem *item = [[self alloc] initWithImage:[image imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] style:UIBarButtonItemStylePlain target:viewController action:@selector(qmuinb_handlePlainBackButton)];
    item.qmui_hidesSharedBackground = YES;
    item.accessibilityLabel = @"返回";
    // 仅识别本工厂生成的按钮，不能强制放行其他业务按钮的手势。
    [item qmui_bindBOOL:YES forKey:@"qmuinb_plainBackButton"];
#ifdef IOS26_SDK_ALLOWED
    if (@available(iOS 26.0, *)) item.identifier = @"qmui.plainBackButton";
#endif
    __weak UIViewController *weakController = viewController;
    NSMutableArray<UIAction *> *actions = NSMutableArray.new;
    for (NSInteger previousIndex = (NSInteger)index - 1; previousIndex >= 0; previousIndex--) {
        UIViewController *destination = controllers[previousIndex];
        __weak UIViewController *weakDestination = destination;
        UIAction *action = [UIAction actionWithTitle:destination.title ?: destination.navigationItem.title ?: @"返回" image:nil identifier:nil handler:^(__kindof UIAction *action) {
            UIViewController *strongDestination = weakDestination;
            if (strongDestination) [weakController qmuinb_popToViewControllerFromPlainBackButton:strongDestination];
        }];
        [actions addObject:action];
    }
    item.menu = [UIMenu menuWithTitle:@"" children:actions];
    return item;
}

+ (instancetype)qmui_closeItemWithTarget:(nullable id)target action:(nullable SEL)action {
    UIBarButtonItem *closeItem = [[self alloc] initWithImage:NavBarCloseButtonImage style:UIBarButtonItemStylePlain target:target action:action];
    [closeItem qmui_bindBOOL:YES forKey:@"qmuinb_closeButton"];
    closeItem.accessibilityLabel = @"关闭";
    return closeItem;
}

+ (instancetype)qmui_fixedSpaceItemWithWidth:(CGFloat)width {
    UIBarButtonItem *item = [[self alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:NULL];
    item.width = width;
    return item;
}

+ (instancetype)qmui_flexibleSpaceItem {
    return [[self alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:NULL];
}

@end

@implementation UINavigationController (QMUILegacyNavigationButtonPrivate)

- (void)qmuinb_updateLegacyNavigationButtons {
    if (@available(iOS 15.0, *)) {
        BOOL enabled = NavBarUsesLegacyButtonLayout && QMUINBLegacyManagesNavigationController(self);
        if (QMUINBLegacyManagesNavigationController(self)) [QMUINBLegacyNavigationControllers() addObject:self];
        NSMutableSet<UIBarButtonItem *> *currentItems = NSMutableSet.new;
        NSArray<UIViewController *> *controllers = QMUINBLegacyNavigationStack(self);
        for (UIViewController *controller in controllers) {
            UINavigationItem *item = controller.navigationItem;
            _QMUINBLegacyNavigationItemState *state = QMUINBLegacyNavigationItemState(item);
            state.navigationController = self;
            if (state.updating) continue;
            state.updating = YES;
            NSArray<UIBarButtonItem *> *leftItems = item.leftBarButtonItems;
            BOOL ownsBackItem = leftItems.count && leftItems.firstObject == state.generatedBackItem;
            NSArray<UIBarButtonItem *> *businessLeftItems = ownsBackItem ? [leftItems subarrayWithRange:NSMakeRange(1, leftItems.count - 1)] : leftItems;
            BOOL hidesBackButton = state.suppressesSystemBackButton ? state.requestedHidesBackButton : item.hidesBackButton;
            BOOL hasBackAction = NO;
            if (@available(iOS 16.0, *)) hasBackAction = item.backAction != nil;
            UIBarButtonItem *firstBusinessItem = businessLeftItems.firstObject;
            BOOL hasCustomBackButton = [firstBusinessItem qmui_getBoundBOOLForKey:@"qmuinb_customBackButton"] || ([firstBusinessItem.customView isKindOfClass:QMUINavigationButton.class] && ((QMUINavigationButton *)firstBusinessItem.customView).type == QMUINavigationButtonTypeBack);
            // 附加左按钮时系统也会显示返回箭头，必须把它纳入同一组紧凑布局，不能把左按钮移到系统箭头的位置。
            BOOL needsBackItem = enabled && controller != controllers.firstObject && !hidesBackButton && !hasBackAction && !hasCustomBackButton && (!businessLeftItems.count || item.leftItemsSupplementBackButton);
            if (needsBackItem) {
                NSMutableArray<NSValue *> *history = NSMutableArray.new;
                for (UIViewController *destination in controllers) {
                    if (destination == controller) break;
                    // 不强持有历史页面，避免导航项反向持有自己的控制器。
                    [history addObject:[NSValue valueWithPointer:(__bridge const void *)destination]];
                }
                if (!ownsBackItem || ![state.backHistory isEqualToArray:history]) {
                    state.generatedBackItem = [UIBarButtonItem qmui_plainBackItemWithViewController:controller];
                    state.backHistory = history;
                    NSMutableArray *updatedLeftItems = businessLeftItems.mutableCopy ?: NSMutableArray.new;
                    if (state.generatedBackItem) [updatedLeftItems insertObject:state.generatedBackItem atIndex:0];
                    item.leftBarButtonItems = updatedLeftItems;
                }
                // 配置表动态替换返回图标时，已生成的箭头也同步更新。
                state.generatedBackItem.image = [QMUINavigationButtonBackImage(self.navigationBar) imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            } else if (state.generatedBackItem) {
                if ([leftItems containsObject:state.generatedBackItem]) item.leftBarButtonItems = businessLeftItems;
                state.generatedBackItem = nil;
                state.backHistory = nil;
            }
            BOOL suppressSystemBackButton = needsBackItem && item.leftItemsSupplementBackButton && state.generatedBackItem && [item.leftBarButtonItems containsObject:state.generatedBackItem];
            if (suppressSystemBackButton) {
                // 使用刷新开始时的业务状态，插入左按钮触发的组件内部显隐更新不能覆盖它。
                if (!state.suppressesSystemBackButton) state.requestedHidesBackButton = hidesBackButton;
                state.suppressesSystemBackButton = YES;
                // 直接调用原公开 setter，跳过业务 hook；保留 supplement=YES 供业务和自定义返回组件判断。
                QMUINBLegacySetSystemBackButtonHidden(item, @selector(setHidesBackButton:animated:), YES, NO);
            } else {
                QMUINBLegacyRestoreSystemBackButton(item, state);
            }
            NSArray<UIBarButtonItem *> *buttons = [(item.leftBarButtonItems ?: @[]) arrayByAddingObjectsFromArray:item.rightBarButtonItems ?: @[]];
            for (UIBarButtonItem *button in buttons) {
                [currentItems addObject:button];
                if (enabled) QMUINBLegacyPrepareItem(button, self);
                else if (!enabled) QMUINBLegacyRestoreItem(button);
            }
            state.updating = NO;
        }
        // 转场中的离栈按钮仍需参与系统动画，结束后再恢复；关闭开关则立即恢复全部快照。
        if (!enabled || (!self.transitionCoordinator && self.qmui_navigationAction == QMUINavigationActionUnknow)) {
            for (UIBarButtonItem *button in QMUINBLegacyManagedItems(self).allObjects) {
                if (!enabled || ![currentItems containsObject:button]) {
                    QMUINBLegacyRestoreItem(button);
                    [QMUINBLegacyManagedItems(self) removeObject:button];
                }
            }
        }
        [self.navigationBar setNeedsLayout];
    }
}

- (void)qmuinb_layoutLegacyNavigationButtons {
    if (@available(iOS 15.0, *)) {
        if (!NavBarUsesLegacyButtonLayout || !QMUINBLegacyManagesNavigationController(self)) return;
        if ([objc_getAssociatedObject(self, &kQMUINBLegacyLayingOut) boolValue]) return;
        objc_setAssociatedObject(self, &kQMUINBLegacyLayingOut, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        @try {
            UINavigationBar *bar = self.navigationBar;
            BOOL leftToRight = [UIView userInterfaceLayoutDirectionForSemanticContentAttribute:bar.semanticContentAttribute] == UIUserInterfaceLayoutDirectionLeftToRight;
            NSArray<NSArray<UIBarButtonItem *> *> *sides = @[bar.topItem.leftBarButtonItems ?: @[], bar.topItem.rightBarButtonItems ?: @[]];
            NSMapTable<UIBarButtonItem *, NSValue *> *contentRects = NSMapTable.strongToStrongObjectsMapTable;
            // 先完成所有按钮的系统布局，再统一移动。逐个边布局边移动会让后一个按钮的布局重置前一个的位置。
            for (NSArray<UIBarButtonItem *> *items in sides) {
                for (UIBarButtonItem *item in items) {
                    _QMUINBLegacyBarItemState *state = objc_getAssociatedObject(item, &kQMUINBLegacyBarItemState);
                    if (state && [item.customView isDescendantOfView:bar]) item.customView.transform = state.originalTransform;
                }
            }
            for (NSArray<UIBarButtonItem *> *items in sides) {
                for (UIBarButtonItem *item in items) {
                    _QMUINBLegacyBarItemState *state = objc_getAssociatedObject(item, &kQMUINBLegacyBarItemState);
                    if (!state || ![item.customView isDescendantOfView:bar]) continue;
                    [item.customView layoutIfNeeded];
                    [contentRects setObject:[NSValue valueWithCGRect:QMUINBLegacyVisibleContentRect(item.customView, state)] forKey:item];
                }
            }
            for (NSUInteger side = 0; side < sides.count; side++) {
                BOOL leading = side == 0 ? leftToRight : !leftToRight;
                CGFloat edge = MAX(0, NavBarButtonContentEdgeDistance);
                CGFloat cursor = leading ? bar.safeAreaInsets.left + edge : CGRectGetWidth(bar.bounds) - bar.safeAreaInsets.right - edge;
                for (UIBarButtonItem *item in sides[side]) {
                    if (@available(iOS 16.0, *)) { if (item.hidden) continue; }
                    _QMUINBLegacyBarItemState *state = objc_getAssociatedObject(item, &kQMUINBLegacyBarItemState);
                    UIView *view = item.customView;
                    if (!state || !view || ![view isDescendantOfView:bar]) {
                        // 业务提供的空间项保留宽度；无法取得公开内容的归档按钮保持原样。
                        if (item.width > 0) cursor += (leading ? 1 : -1) * item.width;
                        continue;
                    }
                    // UIKit 仍可能给 customView 保留最小宽度，以内容边缘计算才能真正去除旧位置的留白。
                    CGRect contentRect = [contentRects objectForKey:item].CGRectValue;
                    CGRect currentRect = [view convertRect:contentRect toView:bar];
                    CGFloat targetX = leading ? cursor : cursor - CGRectGetWidth(currentRect);
                    CGFloat delta = targetX - CGRectGetMinX(currentRect);
                    CGPoint start = [bar convertPoint:CGPointZero toView:view.superview];
                    CGPoint end = [bar convertPoint:CGPointMake(delta, 0) toView:view.superview];
                    // 仅调整业务/框架自己的 customView，不能修改 UIKit 的按钮容器或布局约束。
                    view.transform = CGAffineTransformConcat(state.originalTransform, CGAffineTransformMakeTranslation(end.x - start.x, end.y - start.y));
                    cursor += (leading ? 1 : -1) * (CGRectGetWidth(currentRect) + MAX(0, NavBarButtonItemSpacing));
                }
            }
        } @finally {
            objc_setAssociatedObject(self, &kQMUINBLegacyLayingOut, @NO, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
}

@end

@interface UIBarButtonItem (QMUINavigationButton_Private)

/// 判断当前的 UIBarButtonItem 是否是 QMUINavigationButton
@property(nonatomic, assign, readonly) BOOL qmui_isCustomizedBarButtonItem;

/// 判断当前的 UIBarButtonItem 是否是用 QMUINavigationButton 自定义返回按钮生成的
@property(nonatomic, assign, readonly) BOOL qmui_isCustomizedBackBarButtonItem;

/// 获取内部的 QMUINavigationButton（如果有的话）
@property(nonatomic, strong, readonly) QMUINavigationButton *qmui_navigationButton;
@end

@interface UIViewController (QMUINavigationButton)

@end

@interface UINavigationBar (QMUINavigationButton)

/// 判断当前的 UINavigationBar 的返回按钮是不是自定义的
@property(nonatomic, readonly) BOOL qmui_customizingBackBarButtonItem;
@end

@implementation UIBarButtonItem (QMUINavigationButton_Private)

- (BOOL)qmui_isCustomizedBarButtonItem {
    if (!self.customView) {
        return NO;
    }
    return [self.customView isKindOfClass:[QMUINavigationButton class]];
}

- (BOOL)qmui_isCustomizedBackBarButtonItem {
    return self.qmui_isCustomizedBarButtonItem && ((QMUINavigationButton *)self.customView).type == QMUINavigationButtonTypeBack;
}

- (QMUINavigationButton *)qmui_navigationButton {
    if ([self.customView isKindOfClass:[QMUINavigationButton class]]) {
        return (QMUINavigationButton *)self.customView;
    }
    return nil;
}

@end

@implementation UINavigationItem (QMUINavigationButton)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        SEL selectors[] = {
            @selector(setLeftBarButtonItem:animated:),
            @selector(setLeftBarButtonItems:animated:),
            @selector(setRightBarButtonItem:animated:),
            @selector(setRightBarButtonItems:animated:),
        };
        for (NSUInteger index = 0; index < sizeof(selectors) / sizeof(SEL); index++) {
            SEL originalSelector = selectors[index];
            SEL swizzledSelector = NSSelectorFromString([@"qmui_" stringByAppendingString:NSStringFromSelector(originalSelector)]);
            ExchangeImplementations([UINavigationItem class], originalSelector, swizzledSelector);
        }
        QMUINBLegacySetSystemBackButtonHidden = (void *)class_getMethodImplementation(self, @selector(setHidesBackButton:animated:));
        OverrideImplementation(self, @selector(setHidesBackButton:animated:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^(UINavigationItem *item, BOOL hidden, BOOL animated) {
                _QMUINBLegacyNavigationItemState *state = objc_getAssociatedObject(item, &kQMUINBLegacyNavigationItemState);
                // 临时隐藏期间仍记录业务新设置，关闭开关、切换左按钮或恢复自定义返回时按最新值还原。
                if (state.suppressesSystemBackButton && !state.updating) state.requestedHidesBackButton = hidden;
                void (*original)(id, SEL, BOOL, BOOL) = (void *)originalIMPProvider();
                original(item, originCMD, hidden, animated);
                QMUINBLegacyNavigationItemDidChange(item);
            };
        });
        ExtendImplementationOfVoidMethodWithSingleArgument(self, @selector(setLeftItemsSupplementBackButton:), BOOL, ^(UINavigationItem *item, BOOL supplement) { QMUINBLegacyNavigationItemDidChange(item); });
        if ([self instancesRespondToSelector:@selector(setBackAction:)]) ExtendImplementationOfVoidMethodWithSingleArgument(self, @selector(setBackAction:), UIAction *, ^(UINavigationItem *item, UIAction *action) { QMUINBLegacyNavigationItemDidChange(item); });
    });
}

- (void)qmui_setLeftBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated {
    [self qmui_setLeftBarButtonItem:item animated:animated];
    
    // 自动给 position 赋值
    item.qmui_navigationButton.buttonPosition = QMUINavigationButtonPositionLeft;
    QMUINBLegacyNavigationItemDidChange(self);
}

- (void)qmui_setLeftBarButtonItems:(NSArray<UIBarButtonItem *> *)items animated:(BOOL)animated {
    [self qmui_setLeftBarButtonItems:items animated:animated];
    
    // 自动给 position 赋值
    for (NSInteger i = 0; i < items.count; i++) {
        if (i == 0) {
            items[i].qmui_navigationButton.buttonPosition = QMUINavigationButtonPositionLeft;
        } else {
            items[i].qmui_navigationButton.buttonPosition = QMUINavigationButtonPositionNone;
        }
    }
    QMUINBLegacyNavigationItemDidChange(self);
}

- (void)qmui_setRightBarButtonItem:(UIBarButtonItem *)item animated:(BOOL)animated {
    [self qmui_setRightBarButtonItem:item animated:animated];
    
    // 自动给 position 赋值
    item.qmui_navigationButton.buttonPosition = QMUINavigationButtonPositionRight;
    QMUINBLegacyNavigationItemDidChange(self);
}

- (void)qmui_setRightBarButtonItems:(NSArray<UIBarButtonItem *> *)items animated:(BOOL)animated {
    [self qmui_setRightBarButtonItems:items animated:animated];
    
    // 自动给 position 赋值
    for (NSInteger i = 0; i < items.count; i++) {
        if (i == 0) {
            items[i].qmui_navigationButton.buttonPosition = QMUINavigationButtonPositionRight;
        } else {
            items[i].qmui_navigationButton.buttonPosition = QMUINavigationButtonPositionNone;
        }
    }
    QMUINBLegacyNavigationItemDidChange(self);
}

@end

@implementation UIViewController (QMUINavigationButton)

- (void)qmuinb_handlePlainBackButton {
    NSArray<UIViewController *> *controllers = self.navigationController.viewControllers;
    if (controllers.count > 1) [self qmuinb_popToViewControllerFromPlainBackButton:controllers[controllers.count - 2]];
}

- (BOOL)qmuinb_popToViewControllerFromPlainBackButton:(UIViewController *)viewController {
    UINavigationController *nav = self.navigationController;
    UIBarButtonItem *item = self.navigationItem.leftBarButtonItem;
    if (!nav || nav.topViewController != self || nav.viewControllers.count < 2 ||
        ![item qmui_getBoundBOOLForKey:@"qmuinb_plainBackButton"] || item.target != self || !item.enabled ||
        nav.qmui_navigationAction != QMUINavigationActionUnknow || nav.transitionCoordinator || nav.presentedViewController ||
        ![nav.viewControllers containsObject:viewController] || viewController == self) return NO;
    // 自定义按钮不能用手动 pop 绕过原先的业务返回拦截；历史菜单也只判断一次。
    if (![nav canPopViewController:self byPopGesture:NO]) return NO;
    // 确认回调可能修改导航栈或弹出页面，必须再次核对本次返回仍有效。
    if (nav.topViewController != self || ![nav.viewControllers containsObject:viewController] ||
        nav.qmui_navigationAction != QMUINavigationActionUnknow || nav.transitionCoordinator || nav.presentedViewController) return NO;
    return [nav popToViewController:viewController animated:YES].count > 0;
}

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{

        ExtendImplementationOfVoidMethodWithSingleArgument(self, @selector(viewWillAppear:), BOOL, ^(UIViewController *controller, BOOL animated) {
            [controller.navigationController qmuinb_updateLegacyNavigationButtons];
        });
        ExtendImplementationOfVoidMethodWithSingleArgument(self, @selector(viewDidAppear:), BOOL, ^(UIViewController *controller, BOOL animated) {
            [controller.navigationController qmuinb_updateLegacyNavigationButtons];
        });
        ExtendImplementationOfVoidMethodWithoutArguments(UINavigationController.class, @selector(viewDidLayoutSubviews), ^(UINavigationController *nav) {
            [nav qmuinb_layoutLegacyNavigationButtons];
        });
        // UIKit 的布局发生在导航栏本身，旋转和动态修改按钮后也需应用紧凑位置。
        ExtendImplementationOfVoidMethodWithoutArguments(UINavigationBar.class, @selector(layoutSubviews), ^(UINavigationBar *bar) {
            _QMUINBLegacyNavigationItemState *state = objc_getAssociatedObject(bar.topItem, &kQMUINBLegacyNavigationItemState);
            [state.navigationController qmuinb_layoutLegacyNavigationButtons];
        });
        OverrideImplementation(UINavigationBar.class, @selector(hitTest:withEvent:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^UIView *(UINavigationBar *bar, CGPoint point, UIEvent *event) {
                _QMUINBLegacyNavigationItemState *owner = objc_getAssociatedObject(bar.topItem, &kQMUINBLegacyNavigationItemState);
                if (@available(iOS 15.0, *)) {
                    if (NavBarUsesLegacyButtonLayout && QMUINBLegacyManagesNavigationController(owner.navigationController) && bar.userInteractionEnabled && !bar.hidden && bar.alpha > .01 && [bar pointInside:point withEvent:event]) {
                        NSArray<UIBarButtonItem *> *items = [(bar.topItem.leftBarButtonItems ?: @[]) arrayByAddingObjectsFromArray:bar.topItem.rightBarButtonItems ?: @[]];
                        for (UIBarButtonItem *item in items) {
                            _QMUINBLegacyBarItemState *state = objc_getAssociatedObject(item, &kQMUINBLegacyBarItemState);
                            UIView *view = item.customView;
                            BOOL hidden = NO;
                            if (@available(iOS 16.0, *)) hidden = item.hidden;
                            if (!state || !view || !item.enabled || hidden || !view.userInteractionEnabled || ![view isDescendantOfView:bar]) continue;
                            BOOL visible = YES;
                            for (UIView *ancestor = view; ancestor && ancestor != bar; ancestor = ancestor.superview) {
                                if (ancestor.hidden || ancestor.alpha <= .01) { visible = NO; break; }
                            }
                            if (!visible) continue;
                            CGPoint localPoint = [bar convertPoint:point toView:view];
                            // 统一按内容间隔的中点限制命中范围，业务返回按钮的 outsideEdge 不能覆盖相邻关闭按钮。
                            CGRect content = QMUINBLegacyVisibleContentRect(view, state);
                            CGRect touchRect = CGRectInset(content, -MAX(0, NavBarButtonItemSpacing) / 2, -MAX(0, (44 - content.size.height) / 2));
                            if (!CGRectContainsPoint(touchRect, localPoint)) continue;
                            if (state.generatedButton) {
                                return view;
                            } else {
                                UIView *hit = [view hitTest:localPoint withEvent:event];
                                if (hit) return hit;
                            }
                        }
                    }
                }
                UIView *(*original)(id, SEL, CGPoint, UIEvent *) = (void *)originalIMPProvider();
                return original(bar, originCMD, point, event);
            };
        });
        
        // 当使用自定义返回按钮时，无法使用 VoiceOver 或者 iOS 13.4 新增的 Full Keyboard Access 返回
        OverrideImplementation([UIViewController class], @selector(accessibilityPerformEscape), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^BOOL(UIViewController *selfObject) {

                UIBarButtonItem *plainItem = selfObject.navigationItem.leftBarButtonItem;
                if ([plainItem qmui_getBoundBOOLForKey:@"qmuinb_plainBackButton"] && plainItem.target == selfObject && plainItem.enabled && selfObject.navigationController.topViewController == selfObject) {
                    [selfObject qmuinb_handlePlainBackButton];
                    // 拒绝返回也是已处理，避免继续落到系统退出路径绕过业务确认。
                    return YES;
                }
                
                if (selfObject.navigationItem.leftBarButtonItem.qmui_isCustomizedBackBarButtonItem
                    && ((QMUINavigationButton *)selfObject.navigationItem.leftBarButtonItem.customView).enabled
                    && selfObject.navigationController.qmui_rootViewController != selfObject
                    && selfObject.navigationController.interactivePopGestureRecognizer.enabled
                    && selfObject.navigationController.view.userInteractionEnabled) {
                    [selfObject.navigationController popViewControllerAnimated:YES];
                    return YES;
                }
                
                // call super
                BOOL (*originSelectorIMP)(id, SEL);
                originSelectorIMP = (BOOL (*)(id, SEL))originalIMPProvider();
                BOOL result = originSelectorIMP(selfObject, originCMD);
                return result;
            };
        });
    });
}

@end

@implementation UINavigationBar (QMUINavigationButton)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        // 强制修改 contentView 的 directionalLayoutMargins.leading，在使用自定义返回按钮时减小 8
        // Xcode11 beta2 修改私有 view 的 directionalLayoutMargins 会 crash，换个方式
        // -[_UINavigationBarContentView directionalLayoutMargins]
        // 液态玻璃导航栏的间距由系统管理，旧版补丁不能修改新布局。
        if (@available(iOS 26.0, *)) {
        } else {
        NSString *barContentViewString = [NSString qmui_stringByConcat:@"_", @"UINavigationBar", @"ContentView", nil];
        
        OverrideImplementation(NSClassFromString(barContentViewString), @selector(directionalLayoutMargins), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^NSDirectionalEdgeInsets(UIView *selfObject) {
                
                // call super
                NSDirectionalEdgeInsets (*originSelectorIMP)(id, SEL);
                originSelectorIMP = (NSDirectionalEdgeInsets (*)(id, SEL))originalIMPProvider();
                NSDirectionalEdgeInsets originResult = originSelectorIMP(selfObject, originCMD);
                
                // get navbar
                UINavigationBar *navBar = nil;
                if ([NSStringFromClass([selfObject class]) isEqualToString:barContentViewString] &&
                    [selfObject.superview isKindOfClass:[UINavigationBar class]]) {
                    navBar = (UINavigationBar *)selfObject.superview;
                }
                
                // change insets
                if (navBar) {
                    NSDirectionalEdgeInsets value = originResult;
                    value.leading -= (navBar.qmui_customizingBackBarButtonItem ? 8 : 0);
                    return value;
                }
                
                return originResult;
            };
        });
        
        }

        // 系统的 UIBarButtonItem 响应区域比较大，如果用 customView 则响应区域只有 customView.frame 的大小，这里专门扩大它
        // 对没用 customView 的不处理
        OverrideImplementation([UINavigationBar class], @selector(hitTest:withEvent:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^UIView *(UINavigationBar *selfObject, CGPoint firstArgv, UIEvent *secondArgv) {
                
                // call super
                UIView * (*originSelectorIMP)(id, SEL, CGPoint, UIEvent *);
                originSelectorIMP = (UIView * (*)(id, SEL, CGPoint, UIEvent *))originalIMPProvider();
                UIView * result = originSelectorIMP(selfObject, originCMD, firstArgv, secondArgv);
                
                // result 有值意味着该事件本应属于 bar 的，这时候才干预。
                // 属于 bar 但又分配给容器而不是精准的某个内容 view，此时才考虑扩大点击范围的识别。
                BOOL hitNothing = result && (result == selfObject.qmui_contentView || [NSStringFromClass(result.class) containsString:@"StackView"]);
                if (!hitNothing) return result;
                
                NSMutableArray<UIView *> *customViews = [[NSMutableArray alloc] init];
                if (selfObject.topItem.titleView) {
                    [customViews addObject:selfObject.topItem.titleView];
                }
                [customViews addObjectsFromArray:[selfObject.topItem.leftBarButtonItems qmui_compactMapWithBlock:^id _Nullable(UIBarButtonItem * _Nonnull item) {
                    return item.customView ?: nil;
                }]];
                [customViews addObjectsFromArray:[selfObject.topItem.rightBarButtonItems qmui_compactMapWithBlock:^id _Nullable(UIBarButtonItem * _Nonnull item) {
                    return item.customView ?: nil;
                }]];
                UIView *hitTestingView = [customViews qmui_firstMatchWithBlock:^BOOL(UIView * _Nonnull item) {
                    if (!CGRectIsEmpty(item.frame) && !item.hidden && item.alpha > 0.01 && item.window) {
                        if ([item isKindOfClass:UIControl.class] && !((UIControl *)item).enabled) {
                            return NO;
                        }
                        CGRect rect = [selfObject convertRect:item.bounds fromView:item];
                        rect = CGRectInsetEdges(rect, item.qmui_outsideEdge);
                        if (CGRectContainsPoint(rect, firstArgv)) {
                            return YES;
                        }
                    }
                    return NO;
                }];
                if (hitTestingView) {
                    return hitTestingView;
                }
                return result;
            };
        });
    });
}

- (BOOL)qmui_customizingBackBarButtonItem {
    if (self.topItem.leftBarButtonItem) {
        return self.topItem.leftBarButtonItem.qmui_isCustomizedBackBarButtonItem;
    }
    return NO;
}

@end
