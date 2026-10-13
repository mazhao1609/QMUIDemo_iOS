/**
 * Tencent is pleased to support the open source community by making QMUI_iOS available.
 * Copyright (C) 2016-2021 THL A29 Limited, a Tencent company. All rights reserved.
 * Licensed under the MIT License (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 * http://opensource.org/licenses/MIT
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
 */

//
//  UINavigationController+NavigationBarTransition.m
//  qmui
//
//  Created by QMUI Team on 16/2/22.
//

#import "UINavigationController+NavigationBarTransition.h"
#import "QMUINavigationController.h"
#import "QMUICore.h"
#import "UINavigationController+QMUI.h"
#import "UIImage+QMUI.h"
#import "UIViewController+QMUI.h"
#import "UINavigationBar+Transition.h"
#import "QMUINavigationTitleView.h"
#import "UINavigationBar+QMUI.h"
#import "UINavigationBar+QMUIBarProtocol.h"
#import "UIView+QMUI.h"
#import "QMUILog.h"
#import "NSObject+QMUI.h"

/**
 *  为了响应<b>NavigationBarTransition</b>分类的功能，UIViewController需要做一些相应的支持。
 *  @see UINavigationController+NavigationBarTransition.h
 */
@interface UIViewController (NavigationBarTransition)

@property(nonatomic, assign) BOOL qmuinb_shouldShowTransitionBar;

/// 用来模仿真的navBar的，在转场过程中存在的一条假navBar
@property(nonatomic, strong) _QMUITransitionNavigationBar *transitionNavigationBar;

/// 是否要把真的navBar隐藏
@property(nonatomic, assign) BOOL prefersNavigationBarBackgroundViewHidden;

/// 原始containerView的背景色
@property(nonatomic, strong) UIColor *originContainerViewBackgroundColor;

/// iOS 26 保留页面 appearance，背景转场单独处理，不复制玻璃导航栏。
- (void)qmuinb_updateNavigationItemAppearanceForNavigationController:(UINavigationController *)navigationController;
- (void)renderNavigationBarAppearanceAnimated:(BOOL)animated;
- (BOOL)canCustomNavigationBarTransitionIfBarHiddenable;
- (BOOL)hideNavigationBarWhenTransitioning;

@end

/// 只绘制背景，标题、按钮、玻璃控件和返回手势仍由真正的导航栏负责。
@interface _QMUITransitionNavigationBackground : UIView
@property(nonatomic, strong) UINavigationBarAppearance *appearance;
@property(nonatomic, strong) UIVisualEffectView *effectView;
@property(nonatomic, strong) UIView *colorView;
@property(nonatomic, strong) UIImageView *imageView;
@property(nonatomic, strong) UIImageView *shadowView;
@end

@implementation _QMUITransitionNavigationBackground
- (instancetype)initWithFrame:(CGRect)frame {
    if (self = [super initWithFrame:frame]) {
        self.userInteractionEnabled = NO;
        self.effectView = [[UIVisualEffectView alloc] initWithEffect:nil];
        self.colorView = UIView.new;
        self.imageView = UIImageView.new;
        self.shadowView = UIImageView.new;
        [self addSubview:self.effectView];
        [self addSubview:self.colorView];
        [self addSubview:self.imageView];
        [self addSubview:self.shadowView];
    }
    return self;
}
- (void)setAppearance:(UINavigationBarAppearance *)appearance {
    if ([_appearance isEqual:appearance]) return;
    _appearance = [appearance copy];
    // 在加入动画容器前准备材料，避免 effect 从 nil 动画到磨砂产生白闪。
    [UIView performWithoutAnimation:^{
        if (![self.effectView.effect isEqual:appearance.backgroundEffect]) self.effectView.effect = appearance.backgroundEffect;
        self.colorView.backgroundColor = appearance.backgroundColor;
        self.imageView.image = appearance.backgroundImage;
        self.imageView.contentMode = appearance.backgroundImageContentMode;
        self.shadowView.image = appearance.shadowImage;
        self.shadowView.backgroundColor = appearance.shadowImage ? nil : appearance.shadowColor;
        [self setNeedsLayout];
    }];
}
- (void)layoutSubviews {
    [super layoutSubviews];
    self.effectView.frame = self.bounds;
    self.colorView.frame = self.bounds;
    self.imageView.frame = self.bounds;
    CGFloat shadowHeight = self.shadowView.image ? self.shadowView.image.size.height : PixelOne;
    self.shadowView.frame = CGRectMake(0, CGRectGetHeight(self.bounds) - shadowHeight, CGRectGetWidth(self.bounds), shadowHeight);
}
@end

/// 生命周期覆盖 push、pop、set 以及交互返回取消；仅在不同背景转场时创建。
@interface _QMUINavigationBackgroundTransition : NSObject
@property(nonatomic, weak) UINavigationController *navigationController;
@property(nonatomic, weak) UIViewController *fromViewController;
@property(nonatomic, weak) UIViewController *toViewController;
@property(nonatomic, strong) _QMUITransitionNavigationBackground *fromBackground;
@property(nonatomic, strong) _QMUITransitionNavigationBackground *toBackground;
@property(nonatomic, weak) UIView *systemBackground;
@property(nonatomic, strong) CALayer *originalMask;
@property(nonatomic, strong) CALayer *hiddenMask;
@property(nonatomic, assign) BOOL originalBarHidden;
- (void)updateLayout;
- (void)finish;
@end

static NSString *const QMUINavigationBackgroundTransitionKey = @"qmuinb_backgroundTransition";

/// 与页面顶部关联的纵向滚动区域，用于选择独立的 scrollEdge appearance。
static UIScrollView *QMUINavigationTransitionScrollView(UIView *view) {
    if (view.hidden || view.alpha <= 0.01) return nil;
    if ([view isKindOfClass:UIScrollView.class]) {
        UIScrollView *scrollView = (id)view;
        if (scrollView.alwaysBounceVertical || scrollView.contentSize.height + scrollView.adjustedContentInset.top + scrollView.adjustedContentInset.bottom > CGRectGetHeight(scrollView.bounds)) return scrollView;
    }
    for (UIView *subview in view.subviews) {
        UIScrollView *scrollView = QMUINavigationTransitionScrollView(subview);
        if (scrollView) return scrollView;
    }
    return nil;
}

@implementation _QMUINavigationBackgroundTransition
- (void)updateLayout {
    UINavigationController *nav = self.navigationController;
    UIViewController *from = self.fromViewController;
    UIViewController *to = self.toViewController;
    if (!nav || !from || !to) return;
    UINavigationBar *bar = nav.navigationBar;
    UIView *systemBackground = bar.qmui_backgroundView;
    if (!systemBackground) return;
    if (self.systemBackground != systemBackground) {
        if (self.systemBackground.layer.mask == self.hiddenMask) self.systemBackground.layer.mask = self.originalMask;
        self.systemBackground = systemBackground;
        self.originalMask = systemBackground.layer.mask;
    }
    if (!self.hiddenMask) self.hiddenMask = CALayer.new;
    // 只遮住背景容器，不触碰 iOS 26 的按钮玻璃层和内容层。
    systemBackground.layer.mask = self.hiddenMask;
    CGRect rect = [nav.view convertRect:systemBackground.bounds fromView:systemBackground];
    NSArray<UIViewController *> *pages = @[from, to];
    NSArray<_QMUITransitionNavigationBackground *> *backgrounds = @[self.fromBackground, self.toBackground];
    for (NSUInteger index = 0; index < pages.count; index++) {
        UIViewController *page = pages[index];
        _QMUITransitionNavigationBackground *background = backgrounds[index];
        // 横坐标固定在各页自身，不能 convert 后跟着共享导航栏停留在屏幕原地。
        CGPoint origin = [page.view convertPoint:rect.origin fromView:nav.view];
        background.frame = CGRectMake(CGRectGetMinX(page.view.bounds), origin.y, CGRectGetWidth(page.view.bounds), CGRectGetHeight(rect));
        // 目标页隐藏共享 bar 时，原页背景仍须随原页退出。
        background.hidden = [page canCustomNavigationBarTransitionIfBarHiddenable] ? [page hideNavigationBarWhenTransitioning] : self.originalBarHidden;
        UINavigationBarAppearance *appearance = page.navigationItem.standardAppearance ?: bar.standardAppearance;
        BOOL compact = CGRectGetHeight(bar.bounds) < 44;
        if (compact) appearance = page.navigationItem.compactAppearance ?: bar.compactAppearance ?: appearance;
        UIScrollView *scrollView = QMUINavigationTransitionScrollView(page.view);
        if (scrollView && scrollView.contentOffset.y <= -scrollView.adjustedContentInset.top + PixelOne) {
            UINavigationBarAppearance *edge = compact ? page.navigationItem.compactScrollEdgeAppearance ?: bar.compactScrollEdgeAppearance : page.navigationItem.scrollEdgeAppearance ?: bar.scrollEdgeAppearance;
            if (!edge && compact) edge = page.navigationItem.scrollEdgeAppearance ?: bar.scrollEdgeAppearance;
            if (!edge) {
                edge = [appearance copy];
                [edge configureWithTransparentBackground];
            }
            appearance = edge;
        }
        background.appearance = appearance;
        [page.view bringSubviewToFront:background];
        [background layoutIfNeeded];
    }
}
- (void)finish {
    [UIView performWithoutAnimation:^{
        if (self.systemBackground.layer.mask == self.hiddenMask) self.systemBackground.layer.mask = self.originalMask;
        [self.fromBackground removeFromSuperview];
        [self.toBackground removeFromSuperview];
    }];
}
@end

@interface UILabel (NavigationBarTransition)
@property(nonatomic, strong) UIColor *qmui_specifiedTextColor;
@end

@implementation UILabel (NavigationBarTransition)

QMUISynthesizeIdStrongProperty(qmui_specifiedTextColor, setQmui_specifiedTextColor)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        OverrideImplementation(NSClassFromString(@"UIButtonLabel"), @selector(setAttributedText:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^(UILabel *selfObject, NSAttributedString *attributedText) {
                
                if (selfObject.qmui_specifiedTextColor) {
                    NSMutableAttributedString *mutableAttributedText = [attributedText isKindOfClass:NSMutableAttributedString.class] ? attributedText : [attributedText mutableCopy];
                    [mutableAttributedText addAttributes:@{ NSForegroundColorAttributeName : selfObject.qmui_specifiedTextColor} range:NSMakeRange(0, mutableAttributedText.length)];
                    attributedText = mutableAttributedText;
                }
                
                void (*originSelectorIMP)(id, SEL, NSAttributedString *);
                originSelectorIMP = (void (*)(id, SEL, NSAttributedString *))originalIMPProvider();
                originSelectorIMP(selfObject, originCMD, attributedText);
            };
        });
    });
}

@end

@implementation UINavigationBar (NavigationBarTransition)

/// 获取系统自带的返回按钮 Label，如果在转场时，会获取到最上面控制器的。
- (UILabel *)qmui_backButtonLabel {
    // 玻璃导航栏的返回标签由系统管理，不对其内部视图施加旧版转场样式。
    if (@available(iOS 26.0, *)) return nil;
    UILabel *backButtonLabel = nil;
    NSMutableArray<UIView *> *pendingViews = self.qmui_contentView.subviews.mutableCopy;
    for (NSUInteger index = 0; index < pendingViews.count; index++) {
        UIView *view = pendingViews[index];
        if ([NSStringFromClass(view.class) isEqualToString:@"_UIButtonBarButton"]) {
            NSMutableArray<UIView *> *buttonViews = view.subviews.mutableCopy;
            for (NSUInteger buttonIndex = 0; buttonIndex < buttonViews.count; buttonIndex++) {
                UIView *buttonView = buttonViews[buttonIndex];
                if ([buttonView isKindOfClass:UIButton.class]) {
                    backButtonLabel = ((UIButton *)buttonView).titleLabel;
                    break;
                }
                [buttonViews addObjectsFromArray:buttonView.subviews];
            }
        }
        [pendingViews addObjectsFromArray:view.subviews];
    }
    return backButtonLabel;
}

@end


@implementation UIViewController (NavigationBarTransition)

#pragma mark - 主流程

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        ExtendImplementationOfVoidMethodWithoutArguments([UINavigationController class], @selector(qmui_didInitialize), ^(UINavigationController *selfObject) {
            [selfObject qmui_addNavigationActionDidChangeBlock:^(QMUINavigationAction action, BOOL animated, __kindof UINavigationController * _Nullable weakNavigationController, __kindof UIViewController * _Nullable appearingViewController, NSArray<__kindof UIViewController *> * _Nullable disappearingViewControllers) {
                
                if (@available(iOS 26.0, *)) {
                    // 必须早于 UIKit 的 push/pop/set，保证转场捕获的是两页各自的样式。
                    if (action == QMUINavigationActionWillPush || action == QMUINavigationActionWillPop || action == QMUINavigationActionWillSet) {
                        UIViewController *from = weakNavigationController.topViewController;
                        [from qmuinb_updateNavigationItemAppearanceForNavigationController:weakNavigationController];
                        [appearingViewController qmuinb_updateNavigationItemAppearanceForNavigationController:weakNavigationController];
                        UINavigationControllerOperation operation = action == QMUINavigationActionWillPop ? UINavigationControllerOperationPop : action == QMUINavigationActionWillSet ? weakNavigationController.qmui_lastOperation : UINavigationControllerOperationPush;
                        if (animated && from && appearingViewController && weakNavigationController.view.window &&
                            [weakNavigationController shouldCustomTransitionAutomaticallyForOperation:operation firstViewController:from secondViewController:appearingViewController] && weakNavigationController.navigationBar.qmui_backgroundView) {
                            [appearingViewController loadViewIfNeeded];
                            _QMUINavigationBackgroundTransition *transition = _QMUINavigationBackgroundTransition.new;
                            transition.navigationController = weakNavigationController;
                            transition.fromViewController = from;
                            transition.toViewController = appearingViewController;
                            transition.originalBarHidden = weakNavigationController.navigationBarHidden;
                            transition.fromBackground = _QMUITransitionNavigationBackground.new;
                            transition.toBackground = _QMUITransitionNavigationBackground.new;
                            [from.view addSubview:transition.fromBackground];
                            [appearingViewController.view addSubview:transition.toBackground];
                            [weakNavigationController.navigationBar qmui_bindObject:transition forKey:QMUINavigationBackgroundTransitionKey];
                            [transition updateLayout];
                        }
                    } else if (action == QMUINavigationActionPushCompleted || action == QMUINavigationActionPopCompleted || action == QMUINavigationActionSetCompleted) {
                        _QMUINavigationBackgroundTransition *transition = [weakNavigationController.navigationBar qmui_getBoundObjectForKey:QMUINavigationBackgroundTransitionKey];
                        // 取消后 top 已恢复为原页，同步按钮颜色，不能遗留目标页颜色。
                        if (transition) [weakNavigationController.topViewController renderNavigationBarAppearanceAnimated:NO];
                        [transition finish];
                        [weakNavigationController.navigationBar qmui_bindObject:nil forKey:QMUINavigationBackgroundTransitionKey];
                    }
                    return;
                }

                // 左右两个界面都必须存在
                UIViewController *disappearingViewController = disappearingViewControllers.lastObject;
                if (!appearingViewController || !disappearingViewController) {
                    return;
                }
                
                switch (action) {
                    case QMUINavigationActionDidPush:
                    case QMUINavigationActionWillPop:
                    case QMUINavigationActionDidSet: {
                        BOOL shouldCustomNavigationBarTransition =
                        [weakNavigationController shouldCustomTransitionAutomaticallyForOperation:UINavigationControllerOperationPush firstViewController:disappearingViewController secondViewController:appearingViewController];
                        if (shouldCustomNavigationBarTransition) {
                            disappearingViewController.qmuinb_shouldShowTransitionBar = YES;
                            appearingViewController.qmuinb_shouldShowTransitionBar = YES;
                            
                            // 只绑定即将显示的 vc 的 bar，注意可能在 setNavigationBarHidden: 里被覆盖，引起下述问题：
                            // https://github.com/Tencent/QMUI_iOS/issues/1335
                            weakNavigationController.navigationBar.qmuinb_copyStylesToBar = appearingViewController.transitionNavigationBar;
                        }
                    }
                        break;
                    case QMUINavigationActionPushCompleted:
                    case QMUINavigationActionPopCompleted:
                    case QMUINavigationActionSetCompleted: {
                        disappearingViewController.qmuinb_shouldShowTransitionBar = NO;
                        appearingViewController.qmuinb_shouldShowTransitionBar = NO;
                        weakNavigationController.navigationBar.qmuinb_copyStylesToBar = nil;
                    }
                        break;
                    default:
                        break;
                }
            }];
        });

        if (@available(iOS 26.0, *)) {
            ExtendImplementationOfVoidMethodWithoutArguments(UINavigationBar.class, @selector(layoutSubviews), ^(UINavigationBar *bar) {
                _QMUINavigationBackgroundTransition *transition = [bar qmui_getBoundObjectForKey:QMUINavigationBackgroundTransitionKey];
                [transition updateLayout];
            });
            ExtendImplementationOfVoidMethodWithoutArguments(UIViewController.class, @selector(viewDidLayoutSubviews), ^(UIViewController *vc) {
                _QMUINavigationBackgroundTransition *transition = [vc.navigationController.navigationBar qmui_getBoundObjectForKey:QMUINavigationBackgroundTransitionKey];
                if (vc == transition.fromViewController || vc == transition.toViewController) [transition updateLayout];
            });
        }
        
        OverrideImplementation([UINavigationController class], @selector(setNavigationBarHidden:animated:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^(UINavigationController *selfObject, BOOL hidden, BOOL animated) {
                
                // call super
                void (*originSelectorIMP)(id, SEL, BOOL, BOOL);
                originSelectorIMP = (void (*)(id, SEL, BOOL, BOOL))originalIMPProvider();
                originSelectorIMP(selfObject, originCMD, hidden, animated);
                
                if ((selfObject.qmui_isPushing || selfObject.qmui_isPopping) && selfObject.topViewController.qmuinb_shouldShowTransitionBar) {
                    if (hidden) {
                        [selfObject.topViewController removeTransitionNavigationBar];
                    } else {
                        [selfObject.topViewController addTransitionNavigationBarAndBindNavigationBar:YES];
                    }
                }
            };
        });
        
        OverrideImplementation([UIViewController class], @selector(viewWillAppear:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^(UIViewController *selfObject, BOOL firstArgv) {
                
                // 放在最前面，留一个时机给业务可以覆盖
                [selfObject renderNavigationBarStyleAnimated:firstArgv];
                
                // call super
                void (*originSelectorIMP)(id, SEL, BOOL);
                originSelectorIMP = (void (*)(id, SEL, BOOL))originalIMPProvider();
                originSelectorIMP(selfObject, originCMD, firstArgv);
            };
        });
        
        OverrideImplementation([UIViewController class], @selector(viewWillLayoutSubviews), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^(UIViewController *selfObject) {
                [selfObject.transitionNavigationBar updateLayout];
                
                // call super
                void (*originSelectorIMP)(id, SEL);
                originSelectorIMP = (void (*)(id, SEL))originalIMPProvider();
                originSelectorIMP(selfObject, originCMD);
            };
        });
        
        // 修复 UISearchController push 到导航栏隐藏的界面时，会强制把导航栏重新显示出来的 bug
        // https://github.com/Tencent/QMUI_iOS/issues/479
        // _navigationControllerWillShowViewController:
        SEL selector = NSSelectorFromString([NSString stringWithFormat:@"_%@%@:", @"navigationController", @"WillShowViewController"]);
        QMUIAssert([[UISearchController class] instancesRespondToSelector:selector], @"UIViewController (NavigationBarTransition)", @"iOS 版本更新导致 UISearchController 无法响应方法 %@", NSStringFromSelector(selector));
        OverrideImplementation([UISearchController class], selector, ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^(UISearchController *selfObject, NSNotification *firstArgv) {
                UIViewController *nextViewController = firstArgv.userInfo[@"UINavigationControllerNextVisibleViewController"];
                if (![nextViewController canCustomNavigationBarTransitionIfBarHiddenable]) {
                    void (*originSelectorIMP)(id, SEL, NSNotification *);
                    originSelectorIMP = (void (*)(id, SEL, NSNotification *))originalIMPProvider();
                    originSelectorIMP(selfObject, originCMD, firstArgv);
                }
            };
        });
        
        if (@available(iOS 15.0, *)) {
            // - [UINavigationBar didMoveToWindow]
            OverrideImplementation([UINavigationBar class], @selector(didMoveToWindow), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
                return ^(UINavigationBar *selfObject) {
                    
                    // call super
                    void (*originSelectorIMP)(id, SEL);
                    originSelectorIMP = (void (*)(id, SEL))originalIMPProvider();
                    originSelectorIMP(selfObject, originCMD);
                    
                    // 由于 renderNavigationBarStyleAnimated: 里对导航栏尚未添加到 window 上（UIAppearance 尚未被应用）的情况，跳过了 renderNavigationBarAppearanceAnimated:，所以这里在导航栏添加到 window 上时刷新一下导航栏样式
                    // https://github.com/Tencent/QMUI_iOS/issues/1437
                    if (selfObject.window) {
                        UINavigationController *nav = (UINavigationController *)selfObject.qmui_viewController;
                        if (![nav isKindOfClass:UINavigationController.class]) return;
                        UIViewController *topViewController = nav.topViewController;
                        if (topViewController.qmui_visibleState & QMUIViewControllerVisible) {// 加上这个 visibleState 的判断是因为一个普通的 UINavigationController 被初始化后导航栏默认就有一个 didMoveToWindow 的时机，这个时机里 topViewController 尚未触发 viewWillAppear:，如果不判断 visibleState，就会导致在过早的时候去设置导航栏样式，然后 viewWillAppear: 时又设置了一次。
                            [topViewController renderNavigationBarAppearanceAnimated:NO];
                        }
                    }
                };
            });
        }
    });
}

- (void)addTransitionNavigationBarAndBindNavigationBar:(BOOL)shouldBind {
    // add 时虽然过滤了 navigationBarHidden 的条件，但可能在 push/pop 时，新界面暂时还没刷新导航栏的显隐状态，所以还是需要在 viewWillLayoutSubviews 那边再重新根据 navigationBarHidden 的值来决定是否隐藏假 bar
    if (!self.qmuinb_shouldShowTransitionBar || self.transitionNavigationBar || !self.navigationController.navigationBar || self.navigationController.navigationBarHidden) {
        return;
    }
    
    _QMUITransitionNavigationBar *customBar = [[_QMUITransitionNavigationBar alloc] init];
    customBar.parentViewController = self;
    self.transitionNavigationBar = customBar;
    
    // iOS 15 里，假 bar 在 add 到界面上时会被强制同步为 UIAppearance 的值，不管你之前是否设置过自己的样式。而且在那个 runloop 内不管你后续怎么更新 standardAppearance，都会呈现出 UIAppearance 里的统一的值的样式。所以这里一方面屏蔽 didMoveToWindow，从而避免在这时候应用 UIAppearance，另一方面要保证先 add 到界面上再同步当前导航栏的样式。
    // 经测试只有 push 或 push 动画的 set 需要这么处理，pop 及 pop 动画的 set 没问题
    // iOS 14 及以下没这种问题。
    // https://github.com/Tencent/QMUI_iOS/issues/1501
    if (@available(iOS 15.0, *)) {
        BOOL isPush = self.navigationController.qmui_navigationAction == QMUINavigationActionDidPush;
        BOOL isSet = self.navigationController.qmui_navigationAction == QMUINavigationActionDidSet;
        BOOL isPopAnimation = isSet && self.navigationController.qmui_lastOperation == UINavigationControllerOperationPop;
        if (isPush || (isSet && !isPopAnimation)) {
            customBar.shouldPreventAppearance = YES;
        }
    }
    [self.view addSubview:customBar];
    customBar.originalNavigationBar = self.navigationController.navigationBar;// 注意这里内部不会保留真 bar 和假 bar 的 copy 关系
    if (shouldBind) {
        self.navigationController.navigationBar.qmuinb_copyStylesToBar = customBar;
    }
}

- (void)removeTransitionNavigationBar {
    if (self.transitionNavigationBar) {
        [self.transitionNavigationBar removeFromSuperview];
        self.transitionNavigationBar = nil;
        id <UIViewControllerTransitionCoordinator> transitionCoordinator = self.transitionCoordinator;
        if (self.navigationController.navigationBar.translucent && self.originContainerViewBackgroundColor) {
            [transitionCoordinator containerView].backgroundColor = self.originContainerViewBackgroundColor;
        }
    }
}

#pragma mark - 工具方法

// 根据当前的viewController，统一处理导航栏的显隐、样式
- (void)renderNavigationBarStyleAnimated:(BOOL)animated {
    
    // 屏蔽不处于 UINavigationController 里的 viewController，以及 custom containerViewController 里的 childViewController
    if (![self.navigationController.viewControllers containsObject:self]) {
        return;
    }
    
    if (![self conformsToProtocol:@protocol(QMUINavigationControllerAppearanceDelegate)]) {
        return;
    }
    
    // 以下用于控制 vc 的外观样式，如果某个方法有实现则用方法的返回值，否则再看配置表对应的值是否有配置，有配置就使用配置表，没配置则什么都不做，维持系统原生样式
    UIViewController<QMUINavigationControllerAppearanceDelegate> *vc = (UIViewController<QMUINavigationControllerAppearanceDelegate> *)self;
    UINavigationController *navigationController = vc.navigationController;
    
    // 显示/隐藏 导航栏
    if ([vc canCustomNavigationBarTransitionIfBarHiddenable]) {
        if ([vc hideNavigationBarWhenTransitioning]) {
            if (!navigationController.isNavigationBarHidden) {
                [navigationController setNavigationBarHidden:YES animated:animated];
            }
        } else {
            if (navigationController.isNavigationBarHidden) {
                [navigationController setNavigationBarHidden:NO animated:animated];
            }
        }
    }
    
    // 仅当导航栏被添加到 window 之后（UIAppearance 被应用之后），业务才可以设置导航栏的样式，否则在 UINavigationBar (QMUI) 里获取到的 navigationBar.standardAppearance 是系统默认的样式而不是 App 全局配置的样式，导致后续导航栏样式都是错的。
    // https://github.com/Tencent/QMUI_iOS/issues/1437
    if (@available(iOS 26.0, *)) {
        // 页面 appearance 可在加入 window 前配置，避免首帧显示上一页或系统默认样式。
    } else if (@available(iOS 15.0, *)) {
        if (!navigationController.navigationBar.window) {
            return;
        }
    }
    
    [self renderNavigationBarAppearanceAnimated:animated];
}

// 仅处理导航栏的样式，不涉及显隐
- (void)renderNavigationBarAppearanceAnimated:(BOOL)animated {
    
    // 屏蔽不处于 UINavigationController 里的 viewController，以及 custom containerViewController 里的 childViewController
    if (![self.navigationController.viewControllers containsObject:self]) {
        return;
    }
    
    if (![self conformsToProtocol:@protocol(QMUINavigationControllerAppearanceDelegate)]) {
        return;
    }
    
    // 以下用于控制 vc 的外观样式，如果某个方法有实现则用方法的返回值，否则再看配置表对应的值是否有配置，有配置就使用配置表，没配置则什么都不做，维持系统原生样式
    UIViewController<QMUINavigationControllerAppearanceDelegate> *vc = (UIViewController<QMUINavigationControllerAppearanceDelegate> *)self;
    UINavigationController *navigationController = vc.navigationController;

    BOOL usesNavigationItemAppearance = NO;
    if (@available(iOS 26.0, *)) {
        usesNavigationItemAppearance = YES;
        [self qmuinb_updateNavigationItemAppearanceForNavigationController:navigationController];
    }

    if (!usesNavigationItemAppearance) {
    
        // 导航栏的背景色
        if ([vc respondsToSelector:@selector(qmui_navigationBarBarTintColor)]) {
            UIColor *barTintColor = [vc qmui_navigationBarBarTintColor];
            navigationController.navigationBar.barTintColor = barTintColor;
        } else if (QMUICMIActivated) {
            navigationController.navigationBar.barTintColor = UINavigationBar.qmui_appearanceConfigured.barTintColor;
        }
    
        // 导航栏的背景
        if ([vc respondsToSelector:@selector(qmui_navigationBarBackgroundImage)]) {
            UIImage *backgroundImage = [vc qmui_navigationBarBackgroundImage];
            [navigationController.navigationBar setBackgroundImage:backgroundImage forBarMetrics:UIBarMetricsDefault];
        } else if (QMUICMIActivated) {
            [navigationController.navigationBar setBackgroundImage:[UINavigationBar.qmui_appearanceConfigured backgroundImageForBarMetrics:UIBarMetricsDefault] forBarMetrics:UIBarMetricsDefault];
        }
    
        //  导航栏的 style
        if ([vc respondsToSelector:@selector(qmui_navigationBarStyle)]) {
            UIBarStyle barStyle = [vc qmui_navigationBarStyle];
            navigationController.navigationBar.barStyle = barStyle;
        } else if (QMUICMIActivated) {
            navigationController.navigationBar.barStyle = UINavigationBar.qmui_appearanceConfigured.barStyle;
        }

        // 导航栏底部的分隔线
        if ([vc respondsToSelector:@selector(qmui_navigationBarShadowImage)]) {
            navigationController.navigationBar.shadowImage = [vc qmui_navigationBarShadowImage];
        } else if (QMUICMIActivated) {
            navigationController.navigationBar.shadowImage = NavBarShadowImage;
        }
    }
    
    // 导航栏上控件的主题色
    UIColor *tintColor =
    [vc respondsToSelector:@selector(qmui_navigationBarTintColor)] ? [vc qmui_navigationBarTintColor] :
                                             QMUICMIActivated ? NavBarTintColor : nil;
    if (tintColor) {
        // https://github.com/Tencent/QMUI_iOS/issues/654
        // 改变 navigationBar.tintColor 后会同步改变返回按钮的文字颜色，在 iOS 10及以下，把修改 tintColor 的代码包裹在 animateAlongsideTransition 中能实现转场过渡，而从 iOS 11 开始不生效，现象是：修改了 navigationBar.tintColor 后，返回按钮的文字颜色瞬间变化。
        // 为了实现转场过渡，不要让返回按钮的文字瞬间变化，在转场前锁定 topViewController 所属的 backButtonLabel 颜色，这样在转场过程中改变了 navBar 的 tintColor 不会影响到他。
        if (navigationController.qmui_isPopping) {
            UILabel *backButtonLabel = navigationController.navigationBar.qmui_backButtonLabel;
            if (backButtonLabel) {
                backButtonLabel.qmui_specifiedTextColor = backButtonLabel.textColor;
                [vc qmui_animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
                    backButtonLabel.qmui_specifiedTextColor = nil;
                }];
            }
        }
       
        [vc qmui_animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
            navigationController.navigationBar.tintColor = tintColor;
        } completion:nil];
    }
    
    // iOS 13 及以上，title 的更新只在 viewWillAppear 这里进行就可以了，但 iOS 12 及以下还要靠 popViewController 那边
    // iOS 12 及以下系统，在不使用自定义 titleView 的情况下，在 viewWillAppear 时通过修改 navigationBar.titleTextAttributes 来设置新界面的导航栏标题样式，push 时是生效的，但 pop 时右边界面的样式会覆盖左边界面的样式，所以 pop 时的 titleTextAttributes 改为在 did pop 时处理
    // 如果用自定义 titleView 则没这种问题，只是为了代码简单，时机的选择不区分是否自定义 title
    if (!usesNavigationItemAppearance) {
        [vc renderNavigationBarTitleAppearanceAnimated:animated];
    }
}

// 基于公开的页面 appearance 一次写入完整样式，不逐项修改共享导航栏。
- (void)qmuinb_updateNavigationItemAppearanceForNavigationController:(UINavigationController *)navigationController {
    if (![self conformsToProtocol:@protocol(QMUINavigationControllerAppearanceDelegate)] || !navigationController) return;
    UIViewController<QMUINavigationControllerAppearanceDelegate> *vc = (id)self;
    BOOL configured = QMUICMIActivated;
    BOOL updatesBackgroundColor = configured || [vc respondsToSelector:@selector(qmui_navigationBarBarTintColor)];
    BOOL updatesBackgroundImage = configured || [vc respondsToSelector:@selector(qmui_navigationBarBackgroundImage)];
    BOOL updatesBarStyle = configured || [vc respondsToSelector:@selector(qmui_navigationBarStyle)];
    BOOL updatesShadowImage = configured || [vc respondsToSelector:@selector(qmui_navigationBarShadowImage)];
    BOOL updatesTitleColor = configured || [vc respondsToSelector:@selector(qmui_titleViewTintColor)];
    BOOL updatesTintColor = configured || [vc respondsToSelector:@selector(qmui_navigationBarTintColor)];
    if (!(updatesBackgroundColor || updatesBackgroundImage || updatesBarStyle || updatesShadowImage || updatesTitleColor || updatesTintColor)) return;

    // 每个业务 getter 只读取一次，四种显示状态使用同一份业务结果。
    UIColor *backgroundColor = [vc respondsToSelector:@selector(qmui_navigationBarBarTintColor)] ? [vc qmui_navigationBarBarTintColor] : configured ? NavBarBarTintColor : nil;
    UIImage *backgroundImage = [vc respondsToSelector:@selector(qmui_navigationBarBackgroundImage)] ? [vc qmui_navigationBarBackgroundImage] : configured ? NavBarBackgroundImage : nil;
    UIBarStyle barStyle = [vc respondsToSelector:@selector(qmui_navigationBarStyle)] ? [vc qmui_navigationBarStyle] : configured ? NavBarStyle : UIBarStyleDefault;
    UIImage *shadowImage = [vc respondsToSelector:@selector(qmui_navigationBarShadowImage)] ? [vc qmui_navigationBarShadowImage] : configured ? NavBarShadowImage : nil;
    UIColor *titleColor = [vc respondsToSelector:@selector(qmui_titleViewTintColor)] ? [vc qmui_titleViewTintColor] : configured ? NavBarTitleColor : nil;
    UIColor *largeTitleColor = [vc respondsToSelector:@selector(qmui_titleViewTintColor)] ? titleColor : configured ? NavBarLargeTitleColor : nil;
    UIColor *tintColor = [vc respondsToSelector:@selector(qmui_navigationBarTintColor)] ? [vc qmui_navigationBarTintColor] : configured ? NavBarTintColor : nil;

    // 同一材料重复创建和赋值会让 UIKit 重建背景，转场中可能出现先白后磨砂。
    static UIBlurEffect *lightEffect;
    static UIBlurEffect *darkEffect;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        lightEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialLight];
        darkEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterialDark];
    });

    UINavigationBarAppearance *(^appearanceWithStyle)(UINavigationBarAppearance *, BOOL) = ^UINavigationBarAppearance *(UINavigationBarAppearance *source, BOOL standard) {
        UINavigationBarAppearance *appearance = [source copy] ?: UINavigationBarAppearance.new;
        // 配置表默认值只覆盖标准状态，独立的滚动/紧凑外观仅应用页面显式声明的覆盖。
        if (updatesBackgroundColor && (standard || [vc respondsToSelector:@selector(qmui_navigationBarBarTintColor)])) appearance.backgroundColor = backgroundColor;
        if (updatesBackgroundImage && (standard || [vc respondsToSelector:@selector(qmui_navigationBarBackgroundImage)])) appearance.backgroundImage = backgroundImage;
        if (updatesBarStyle && (standard || [vc respondsToSelector:@selector(qmui_navigationBarStyle)])) {
            appearance.backgroundEffect = barStyle == UIBarStyleDefault ? lightEffect : darkEffect;
        }
        BOOL overridesBackground = standard || [vc respondsToSelector:@selector(qmui_navigationBarBackgroundImage)] || [vc respondsToSelector:@selector(qmui_navigationBarBarTintColor)] || [vc respondsToSelector:@selector(qmui_navigationBarStyle)];
        if (overridesBackground && configured && NavBarRemoveBackgroundEffectAutomatically && appearance.backgroundImage) appearance.backgroundEffect = nil;
        if (updatesShadowImage && (standard || [vc respondsToSelector:@selector(qmui_navigationBarShadowImage)])) appearance.shadowImage = shadowImage;
        NSMutableDictionary<NSAttributedStringKey, id> *titleAttributes = appearance.titleTextAttributes.mutableCopy ?: NSMutableDictionary.new;
        NSMutableDictionary<NSAttributedStringKey, id> *largeTitleAttributes = appearance.largeTitleTextAttributes.mutableCopy ?: NSMutableDictionary.new;
        if (updatesTitleColor && (standard || [vc respondsToSelector:@selector(qmui_titleViewTintColor)])) {
            titleAttributes[NSForegroundColorAttributeName] = titleColor;
            largeTitleAttributes[NSForegroundColorAttributeName] = largeTitleColor;
        }
        if (standard && configured && NavBarTitleFont) titleAttributes[NSFontAttributeName] = NavBarTitleFont;
        if (standard && configured && NavBarLargeTitleFont) largeTitleAttributes[NSFontAttributeName] = NavBarLargeTitleFont;
        appearance.titleTextAttributes = titleAttributes;
        appearance.largeTitleTextAttributes = largeTitleAttributes;
        if (updatesTintColor && tintColor && (standard || [vc respondsToSelector:@selector(qmui_navigationBarTintColor)])) {
            for (UIBarButtonItemAppearance *button in @[appearance.buttonAppearance, appearance.doneButtonAppearance, appearance.backButtonAppearance]) {
                NSMutableDictionary<NSAttributedStringKey, id> *attributes = button.normal.titleTextAttributes.mutableCopy ?: NSMutableDictionary.new;
                attributes[NSForegroundColorAttributeName] = tintColor;
                button.normal.titleTextAttributes = attributes;
            }
        }
        return appearance;
    };

    // 首次显示时 UIAppearance 可能尚未应用，启用配置表则从配置样式取默认值。
    UINavigationBar *defaultBar = configured && !navigationController.navigationBar.window ? UINavigationBar.qmui_appearanceConfigured : navigationController.navigationBar;
    UINavigationItem *item = self.navigationItem;
    // 旧样式 setter 与 qmui_effect 仅对 QMUI 管理的页面同步，系统页面保持原有行为。
    [item qmui_bindBOOL:YES forKey:@"qmuinb_usesNavigationItemAppearance"];
    void (^assignAppearance)(NSString *, UINavigationBarAppearance *) = ^(NSString *key, UINavigationBarAppearance *appearance) {
        UINavigationBarAppearance *previous = [item valueForKey:key];
        if (previous == appearance || [previous isEqual:appearance]) return;
        // 业务样式在动画开始前一次提交，不对材料本身做隐式动画。
        [UIView performWithoutAnimation:^{ [item setValue:appearance forKey:key]; }];
    };
    assignAppearance(@"standardAppearance", appearanceWithStyle(item.standardAppearance ?: defaultBar.standardAppearance, YES));
    if (configured && NavBarUsesStandardAppearanceOnly) {
        assignAppearance(@"scrollEdgeAppearance", item.standardAppearance);
        assignAppearance(@"compactAppearance", item.standardAppearance);
        assignAppearance(@"compactScrollEdgeAppearance", item.standardAppearance);
    } else {
        // 未统一四种状态时保留业务的独立外观及 UIKit 的 nil 回退规则。
        UINavigationBarAppearance *edge = item.scrollEdgeAppearance ?: defaultBar.scrollEdgeAppearance;
        UINavigationBarAppearance *compact = item.compactAppearance ?: defaultBar.compactAppearance;
        UINavigationBarAppearance *compactEdge = item.compactScrollEdgeAppearance ?: defaultBar.compactScrollEdgeAppearance;
        assignAppearance(@"scrollEdgeAppearance", edge ? appearanceWithStyle(edge, NO) : nil);
        assignAppearance(@"compactAppearance", compact ? appearanceWithStyle(compact, NO) : nil);
        assignAppearance(@"compactScrollEdgeAppearance", compactEdge ? appearanceWithStyle(compactEdge, NO) : nil);
    }
    if (updatesTitleColor && item.titleView.qmui_useAsNavigationTitleView) {
        item.titleView.tintColor = titleColor;
    }
}

// 仅处理导航栏标题
- (void)renderNavigationBarTitleAppearanceAnimated:(BOOL)animated {
    
    // 屏蔽不处于 UINavigationController 里的 viewController，以及 custom containerViewController 里的 childViewController
    if (![self.navigationController.viewControllers containsObject:self]) {
        return;
    }
    
    if (![self conformsToProtocol:@protocol(QMUINavigationControllerAppearanceDelegate)]) {
        return;
    }

    if (@available(iOS 26.0, *)) {
        [self qmuinb_updateNavigationItemAppearanceForNavigationController:self.navigationController];
        return;
    }
    
    // 以下用于控制 vc 的外观样式，如果某个方法有实现则用方法的返回值，否则再看配置表对应的值是否有配置，有配置就使用配置表，没配置则什么都不做，维持系统原生样式
    UIViewController<QMUINavigationControllerAppearanceDelegate> *vc = (UIViewController<QMUINavigationControllerAppearanceDelegate> *)self;
    UINavigationController *navigationController = vc.navigationController;
    
    // 导航栏title的颜色
    if ([vc respondsToSelector:@selector(qmui_titleViewTintColor)]) {
        UIColor *tintColor = [vc qmui_titleViewTintColor];
        if (vc.navigationItem.titleView.qmui_useAsNavigationTitleView) {
            vc.navigationItem.titleView.tintColor = tintColor;
        } else if (!vc.navigationItem.titleView) {
            NSMutableDictionary<NSAttributedStringKey, id> *titleTextAttributes = (navigationController.navigationBar.titleTextAttributes ?: @{}).mutableCopy;
            titleTextAttributes[NSForegroundColorAttributeName] = tintColor;
            navigationController.navigationBar.titleTextAttributes = titleTextAttributes.copy;
        } else {
            // 设置了自定义的 navigationItem.titleView，则不处理
        }
    } else if (QMUICMIActivated) {
        UIColor *tintColor = NavBarTitleColor;
        if (vc.navigationItem.titleView.qmui_useAsNavigationTitleView) {
            vc.navigationItem.titleView.tintColor = tintColor;
        } else if (!vc.navigationItem.titleView) {
            NSMutableDictionary<NSAttributedStringKey, id> *titleTextAttributes = (navigationController.navigationBar.titleTextAttributes ?: @{}).mutableCopy;
            titleTextAttributes[NSForegroundColorAttributeName] = tintColor;
            navigationController.navigationBar.titleTextAttributes = titleTextAttributes.copy;
        } else {
            // 设置了自定义的 navigationItem.titleView，则不处理
        }
    }
}

- (BOOL)respondCustomNavigationBarTransitionIfBarHiddenable {
    BOOL respondIfBarHiddenable = NO;
    
    // 如果当前界面正在搜索，由于 UISearchController 会自动把 navigationBar 移上去，所以这种时候 QMUI 就不应该再去操作 bar 的显隐了
    if ([self.presentedViewController isKindOfClass:[UISearchController class]] && ((UISearchController *)self.presentedViewController).hidesNavigationBarDuringPresentation) {
        return NO;
    }
    
    if ([self conformsToProtocol:@protocol(QMUICustomNavigationBarTransitionDelegate)]) {
        UIViewController<QMUICustomNavigationBarTransitionDelegate> *vc = (UIViewController<QMUICustomNavigationBarTransitionDelegate> *)self;
        if ([vc respondsToSelector:@selector(shouldCustomizeNavigationBarTransitionIfHideable)]) {
            respondIfBarHiddenable = YES;
        }
    }
    return respondIfBarHiddenable;
}

- (BOOL)respondCustomNavigationBarTransitionWithBarHiddenState {
    BOOL respondWithBarHidden = NO;
    if ([self conformsToProtocol:@protocol(QMUICustomNavigationBarTransitionDelegate)]) {
        UIViewController<QMUICustomNavigationBarTransitionDelegate> *vc = (UIViewController<QMUICustomNavigationBarTransitionDelegate> *)self;
        if ([vc respondsToSelector:@selector(preferredNavigationBarHidden)]) {
            respondWithBarHidden = YES;
        }
    }
    return respondWithBarHidden;
}

- (BOOL)canCustomNavigationBarTransitionIfBarHiddenable {
    if ([self respondCustomNavigationBarTransitionIfBarHiddenable]) {
        UIViewController<QMUICustomNavigationBarTransitionDelegate> *vc = (UIViewController<QMUICustomNavigationBarTransitionDelegate> *)self;
        return [vc shouldCustomizeNavigationBarTransitionIfHideable];
    }
    return NO;
}

- (BOOL)hideNavigationBarWhenTransitioning {
    if ([self respondCustomNavigationBarTransitionWithBarHiddenState]) {
        UIViewController<QMUICustomNavigationBarTransitionDelegate> *vc = (UIViewController<QMUICustomNavigationBarTransitionDelegate> *)self;
        BOOL hidden = [vc preferredNavigationBarHidden];
        return hidden;
    }
    return NO;
}

/// 获取当前页面实际导航栏占位，避免转场判断依赖固定机型高度。
static CGFloat QMUIExpectedNavigationContentTop(UIViewController *viewController) {
    UINavigationController *navigationController = viewController.navigationController;
    if (navigationController.navigationBarHidden) {
        return 0;
    }
    return SafeAreaInsetsForView(viewController.view).top + NavigationBarHeightForViewController(viewController);
}

// 对于有一个界面隐藏了导航栏的情况，我们也要做自定义的动画去干预，因为如果左右两个界面导航栏样式不同，你不去干预的话，push/pop 瞬间导航栏会变成即将显示的那个界面的样式，这不符合预期
- (BOOL)shouldCustomTransitionAutomaticallyForOperation:(UINavigationControllerOperation)operation firstViewController:(UIViewController *)viewController1 secondViewController:(UIViewController *)viewController2 {
    
    UIViewController<QMUINavigationControllerDelegate> *vc1 = (UIViewController<QMUINavigationControllerDelegate> *)viewController1;
    UIViewController<QMUINavigationControllerDelegate> *vc2 = (UIViewController<QMUINavigationControllerDelegate> *)viewController2;
    
    if (![vc1 conformsToProtocol:@protocol(QMUINavigationControllerDelegate)] || ![vc2 conformsToProtocol:@protocol(QMUINavigationControllerDelegate)]) {
        return NO;// 只处理前后两个界面都是 QMUI 系列的场景
    }
    
    CGFloat vc1NavigationContentTop = vc1.isViewLoaded ? QMUIExpectedNavigationContentTop(vc1) : 0;
    CGFloat vc2NavigationContentTop = vc2.isViewLoaded ? QMUIExpectedNavigationContentTop(vc2) : 0;
    BOOL vc1Clips = vc1.isViewLoaded && vc1.view.clipsToBounds && vc1.qmui_navigationBarMaxYInViewCoordinator < vc1NavigationContentTop;
    BOOL vc2Clips = vc2.isViewLoaded && vc2.view.clipsToBounds && vc2.qmui_navigationBarMaxYInViewCoordinator < vc2NavigationContentTop;
    if (vc1Clips || vc2Clips) {
        QMUILogWarn(@"UINavigationController (NavigationBarTransition)", @"因界面布局原因导致无法优化导航栏动画，vc1 = %@，maxY1 = %.0f, vc2 = %@，maxY2 = %.0f", vc1, vc1.qmui_navigationBarMaxYInViewCoordinator, vc2, vc2.qmui_navigationBarMaxYInViewCoordinator);
        return NO;// 左右两个界面只要其中某个界面无法完整显示 navigationBar，都不进行动画优化
    }
    
    if ([vc1.navigationController.delegate respondsToSelector:@selector(navigationController:animationControllerForOperation:fromViewController:toViewController:)]) {
        // 说明可能有自定义的系统转场动画
        BOOL a = [vc1 respondsToSelector:@selector(shouldCustomizeNavigationBarTransitionIfUsingCustomTransitionForOperation:fromViewController:toViewController:)] ? [vc1 shouldCustomizeNavigationBarTransitionIfUsingCustomTransitionForOperation:operation fromViewController:vc1 toViewController:vc2] : NO;
        BOOL b = [vc2 respondsToSelector:@selector(shouldCustomizeNavigationBarTransitionIfUsingCustomTransitionForOperation:fromViewController:toViewController:)] ? [vc2 shouldCustomizeNavigationBarTransitionIfUsingCustomTransitionForOperation:operation fromViewController:vc1 toViewController:vc2] : NO;
        if (!a && !b) {
            return NO;
        }
    }
    
    if ([vc1 respondsToSelector:@selector(customNavigationBarTransitionKey)] || [vc2 respondsToSelector:@selector(customNavigationBarTransitionKey)]) {
        NSString *key1 = [vc1 respondsToSelector:@selector(customNavigationBarTransitionKey)] ? [vc1 customNavigationBarTransitionKey] : nil;
        NSString *key2 = [vc2 respondsToSelector:@selector(customNavigationBarTransitionKey)] ? [vc2 customNavigationBarTransitionKey] : nil;
        BOOL result = (key1 || key2) && ![key1 isEqualToString:key2];
        return result;
    }
    
    if (!AutomaticCustomNavigationBarTransitionStyle) {
        return NO;
    }
    

    
    UIImage *bg1 = [vc1 respondsToSelector:@selector(qmui_navigationBarBackgroundImage)] ? [vc1 qmui_navigationBarBackgroundImage] : [UINavigationBar.qmui_appearanceConfigured backgroundImageForBarMetrics:UIBarMetricsDefault];
    UIImage *bg2 = [vc2 respondsToSelector:@selector(qmui_navigationBarBackgroundImage)] ? [vc2 qmui_navigationBarBackgroundImage] : [UINavigationBar.qmui_appearanceConfigured backgroundImageForBarMetrics:UIBarMetricsDefault];
    if (bg1 || bg2) {
        if (!bg1 || !bg2) {
            return YES;// 一个有一个没有，则需要自定义
        }
        if (![bg1.qmui_averageColor isEqual:bg2.qmui_averageColor]) {
            return YES;// 目前只能判断图片颜色是否相等了
        }
    }
    
    // 如果存在 backgroundImage，则 barTintColor、barStyle 就算存在也不会被显示出来，所以这里只判断两个 backgroundImage 都不存在的时候
    if (!bg1 && !bg2) {
        UIColor *barTintColor1 = [vc1 respondsToSelector:@selector(qmui_navigationBarBarTintColor)] ? [vc1 qmui_navigationBarBarTintColor] : UINavigationBar.qmui_appearanceConfigured.barTintColor;
        UIColor *barTintColor2 = [vc2 respondsToSelector:@selector(qmui_navigationBarBarTintColor)] ? [vc2 qmui_navigationBarBarTintColor] : UINavigationBar.qmui_appearanceConfigured.barTintColor;
        if (barTintColor1 || barTintColor2) {
            if (!barTintColor1 || !barTintColor2) {
                return YES;
            }
            if (![barTintColor1 isEqual:barTintColor2]) {
                return YES;
            }
        }
        
        UIBarStyle barStyle1 = [vc1 respondsToSelector:@selector(qmui_navigationBarStyle)] ? [vc1 qmui_navigationBarStyle] : UINavigationBar.qmui_appearanceConfigured.barStyle;
        UIBarStyle barStyle2 = [vc2 respondsToSelector:@selector(qmui_navigationBarStyle)] ? [vc2 qmui_navigationBarStyle] : UINavigationBar.qmui_appearanceConfigured.barStyle;
        if (barStyle1 != barStyle2) {
            return YES;
        }
    }
    
    UIImage *shadowImage1 = [vc1 respondsToSelector:@selector(qmui_navigationBarShadowImage)] ? [vc1 qmui_navigationBarShadowImage] : (vc1.navigationController.navigationBar ? vc1.navigationController.navigationBar.shadowImage : (QMUICMIActivated ? NavBarShadowImage : nil));
    UIImage *shadowImage2 = [vc2 respondsToSelector:@selector(qmui_navigationBarShadowImage)] ? [vc2 qmui_navigationBarShadowImage] : (vc2.navigationController.navigationBar ? vc2.navigationController.navigationBar.shadowImage : (QMUICMIActivated ? NavBarShadowImage : nil));
    if (shadowImage1 || shadowImage2) {
        if (!shadowImage1 || !shadowImage2) {
            return YES;
        }
        if (![shadowImage1.qmui_averageColor isEqual:shadowImage2.qmui_averageColor]) {
            return YES;
        }
    }
    
    return NO;
}

- (UIColor *)containerViewBackgroundColor {
    if ([self conformsToProtocol:@protocol(QMUICustomNavigationBarTransitionDelegate)]) {
        UIViewController<QMUICustomNavigationBarTransitionDelegate> *vc = (UIViewController<QMUICustomNavigationBarTransitionDelegate> *)self;
        if ([vc respondsToSelector:@selector(containerViewBackgroundColorWhenTransitioning)]) {
            return [vc containerViewBackgroundColorWhenTransitioning];
        }
    }
    return self.isViewLoaded && self.view.backgroundColor ? self.view.backgroundColor : UIColorWhite;
}

#pragma mark - Setter / Getter

QMUISynthesizeIdStrongProperty(transitionNavigationBar, setTransitionNavigationBar)
QMUISynthesizeIdStrongProperty(originContainerViewBackgroundColor, setOriginContainerViewBackgroundColor)

static char kAssociatedObjectKey_backgroundViewHidden;
- (void)setPrefersNavigationBarBackgroundViewHidden:(BOOL)prefersNavigationBarBackgroundViewHidden {
    // 从某个版本开始，发现从有 navBar 的界面返回无 navBar 的界面，backgroundView 会跑出来，发现是被系统重新设置了显示，所以改用其他的方法来隐藏 backgroundView，就是 mask。
    if (prefersNavigationBarBackgroundViewHidden) {
        self.navigationController.navigationBar.qmui_backgroundView.layer.mask = [CALayer layer];
    } else {
        self.navigationController.navigationBar.qmui_backgroundView.layer.mask = nil;
    }
    objc_setAssociatedObject(self, &kAssociatedObjectKey_backgroundViewHidden, @(prefersNavigationBarBackgroundViewHidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)prefersNavigationBarBackgroundViewHidden {
    return [((NSNumber *)objc_getAssociatedObject(self, &kAssociatedObjectKey_backgroundViewHidden)) boolValue];
}

static char kAssociatedObjectKey_shouldShowTransitionBar;
- (void)setQmuinb_shouldShowTransitionBar:(BOOL)shouldShowTransitionBar {
    objc_setAssociatedObject(self, &kAssociatedObjectKey_shouldShowTransitionBar, @(shouldShowTransitionBar), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (shouldShowTransitionBar) {
        [self addTransitionNavigationBarAndBindNavigationBar:NO];// 这里不绑定 bar，因为不知道此时是两个 vc 里的哪一个
        self.prefersNavigationBarBackgroundViewHidden = YES;
    } else {
        [self removeTransitionNavigationBar];
        // 屏蔽一些 childViewController 触发的场景，只关心堆栈里的
        if ([self.navigationController.viewControllers containsObject:self]) {
            self.prefersNavigationBarBackgroundViewHidden = NO;
        }
    }
}

- (BOOL)qmuinb_shouldShowTransitionBar {
    return [((NSNumber *)objc_getAssociatedObject(self, &kAssociatedObjectKey_shouldShowTransitionBar)) boolValue];
}

@end
