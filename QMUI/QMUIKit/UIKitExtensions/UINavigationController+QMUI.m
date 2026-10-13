/**
 * Tencent is pleased to support the open source community by making QMUI_iOS available.
 * Copyright (C) 2016-2021 THL A29 Limited, a Tencent company. All rights reserved.
 * Licensed under the MIT License (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 * http://opensource.org/licenses/MIT
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
 */

//
//  UINavigationController+QMUI.m
//  qmui
//
//  Created by QMUI Team on 16/1/12.
//

#import "UINavigationController+QMUI.h"
#import "QMUICore.h"
#import "QMUILog.h"
#import "UIViewController+QMUI.h"
#import "NSObject+QMUI.h"
#import <UIKit/UIGestureRecognizerSubclass.h>

/// 仅用于建立失败依赖的旁路手势，不取消控件触摸，也不阻止其内部手势。
@interface _QMUINavigationContentPopGestureRecognizer : UIPanGestureRecognizer <UIGestureRecognizerDelegate>
- (BOOL)qmuinc_shouldProtectTouchInView:(UIView *)view;
@end

@interface _QMUINavigationInteractiveGestureDelegator : NSObject <UIGestureRecognizerDelegate>

@property(nonatomic, weak, readonly) UINavigationController *parentViewController;
- (instancetype)initWithParentViewController:(UINavigationController *)parentViewController;
@end

/// 两个独立的许可手势分别对应边缘和内容返回，共享同一次触摸的业务判断。
@interface _QMUINavigationBackGestureRecognizer : UIPanGestureRecognizer
@end

@interface _QMUINavigationEdgeBackGestureRecognizer : UIScreenEdgePanGestureRecognizer
@end

@interface _QMUINavigationBackGestureDelegator : NSObject <UIGestureRecognizerDelegate>
@property(nonatomic, weak) UINavigationController *navigationController;
@property(nonatomic, strong) _QMUINavigationEdgeBackGestureRecognizer *edgeGestureRecognizer;
@property(nonatomic, strong) _QMUINavigationBackGestureRecognizer *contentGestureRecognizer;
@property(nonatomic, weak) UIGestureRecognizer *protectedEdgeGestureRecognizer;
@property(nonatomic, weak) UIGestureRecognizer *protectedContentGestureRecognizer;
@property(nonatomic, weak) UITouch *edgeTouch;
@property(nonatomic, weak) UITouch *contentTouch;
@property(nonatomic, weak) UITouch *currentTouch;
@property(nonatomic, weak) UITouch *decisionTouch;
@property(nonatomic, weak) UIViewController *decisionViewController;
@property(nonatomic, assign) BOOL decisionAllowsPop;
- (void)qmuinc_prepareForTouch:(UITouch *)touch isEdge:(BOOL)isEdge;
- (BOOL)qmuinc_canPopForTouch:(UITouch *)touch;
- (BOOL)qmuinc_shouldBlockPopForTranslation:(CGPoint)translation touch:(UITouch *)touch;
@end

@interface UINavigationController ()

@property(nonatomic, strong) NSMutableArray<QMUINavigationActionDidChangeBlock> *qmuinc_navigationActionDidChangeBlocks;
@property(nullable, nonatomic, readwrite) UIViewController *qmui_endedTransitionTopViewController;
@property(nullable, nonatomic, weak, readonly) id<UIGestureRecognizerDelegate> qmui_interactivePopGestureRecognizerDelegate;
@property(nullable, nonatomic, strong) _QMUINavigationInteractiveGestureDelegator *qmui_interactiveGestureDelegator;
@property(nullable, nonatomic, strong) _QMUINavigationContentPopGestureRecognizer *qmuinc_contentPopProtectionGestureRecognizer;
@property(nullable, nonatomic, weak) UIGestureRecognizer *qmuinc_protectedContentPopGestureRecognizer;
@property(nullable, nonatomic, strong) _QMUINavigationBackGestureDelegator *qmuinc_backGestureDelegator;
@end

@interface UINavigationController (QMUIInteractiveContentPopGesturePrivate)
- (void)qmuinc_updateContentPopGestureProtection;
@end

@implementation UINavigationController (QMUI)

QMUISynthesizeBOOLProperty(qmui_alwaysInvokeAppearanceMethods, setQmui_alwaysInvokeAppearanceMethods)
QMUISynthesizeIdStrongProperty(qmuinc_navigationActionDidChangeBlocks, setQmuinc_navigationActionDidChangeBlocks)
QMUISynthesizeIdWeakProperty(qmui_endedTransitionTopViewController, setQmui_endedTransitionTopViewController)
QMUISynthesizeIdWeakProperty(qmui_interactivePopGestureRecognizerDelegate, setQmui_interactivePopGestureRecognizerDelegate)
QMUISynthesizeIdStrongProperty(qmui_interactiveGestureDelegator, setQmui_interactiveGestureDelegator)
QMUISynthesizeIdStrongProperty(qmuinc_contentPopProtectionGestureRecognizer, setQmuinc_contentPopProtectionGestureRecognizer)
QMUISynthesizeIdWeakProperty(qmuinc_protectedContentPopGestureRecognizer, setQmuinc_protectedContentPopGestureRecognizer)
QMUISynthesizeIdStrongProperty(qmuinc_backGestureDelegator, setQmuinc_backGestureDelegator)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        OverrideImplementation([UINavigationController class], @selector(initWithNibName:bundle:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^UINavigationController *(UINavigationController *selfObject, NSString *firstArgv, NSBundle *secondArgv) {
                
                // call super
                UINavigationController *(*originSelectorIMP)(id, SEL, NSString *, NSBundle *);
                originSelectorIMP = (UINavigationController *(*)(id, SEL, NSString *, NSBundle *))originalIMPProvider();
                UINavigationController *result = originSelectorIMP(selfObject, originCMD, firstArgv, secondArgv);
                
                [selfObject qmui_didInitialize];
                
                return result;
            };
        });
        
        OverrideImplementation([UINavigationController class], @selector(initWithCoder:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^UINavigationController *(UINavigationController *selfObject, NSCoder *firstArgv) {
                
                // call super
                UINavigationController *(*originSelectorIMP)(id, SEL, NSCoder *);
                originSelectorIMP = (UINavigationController *(*)(id, SEL, NSCoder *))originalIMPProvider();
                UINavigationController *result = originSelectorIMP(selfObject, originCMD, firstArgv);
                
                [selfObject qmui_didInitialize];
                
                return result;
            };
        });
        
        // iOS 12 及以前，initWithNavigationBarClass:toolbarClass:、initWithRootViewController: 会调用 initWithNibName:bundle:，所以这两个方法在 iOS 12 下不需要再次调用 qmui_didInitialize 了。
        OverrideImplementation([UINavigationController class], @selector(initWithNavigationBarClass:toolbarClass:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^UINavigationController *(UINavigationController *selfObject, Class firstArgv, Class secondArgv) {
                
                // call super
                UINavigationController *(*originSelectorIMP)(id, SEL, Class, Class);
                originSelectorIMP = (UINavigationController *(*)(id, SEL, Class, Class))originalIMPProvider();
                UINavigationController *result = originSelectorIMP(selfObject, originCMD, firstArgv, secondArgv);
                
                [selfObject qmui_didInitialize];
                
                return result;
            };
        });
        
        OverrideImplementation([UINavigationController class], @selector(initWithRootViewController:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^UINavigationController *(UINavigationController *selfObject, UIViewController *firstArgv) {
                
                // call super
                UINavigationController *(*originSelectorIMP)(id, SEL, UIViewController *);
                originSelectorIMP = (UINavigationController *(*)(id, SEL, UIViewController *))originalIMPProvider();
                UINavigationController *result = originSelectorIMP(selfObject, originCMD, firstArgv);
                
                [selfObject qmui_didInitialize];
                
                return result;
            };
        });
        
        
        ExtendImplementationOfVoidMethodWithoutArguments([UINavigationController class], @selector(viewDidLoad), ^(UINavigationController *selfObject) {
            selfObject.qmui_interactivePopGestureRecognizerDelegate = selfObject.interactivePopGestureRecognizer.delegate;
            selfObject.qmui_interactiveGestureDelegator = [[_QMUINavigationInteractiveGestureDelegator alloc] initWithParentViewController:selfObject];
            selfObject.interactivePopGestureRecognizer.delegate = selfObject.qmui_interactiveGestureDelegator;
            [selfObject qmuinc_updateContentPopGestureProtection];
            
            // 根据 NavBarContainerClasses 的值来决定是否应用 bar.tintColor
            // tintColor 没有被添加 UI_APPEARANCE_SELECTOR，所以没有采用 UIAppearance 的方式去实现（虽然它实际上是支持的）
            if (QMUICMIActivated) {
                BOOL shouldSetTintColor = NO;
                if (NavBarContainerClasses.count) {
                    for (Class class in NavBarContainerClasses) {
                        if ([selfObject isKindOfClass:class]) {
                            shouldSetTintColor = YES;
                            break;
                        }
                    }
                } else {
                    shouldSetTintColor = YES;
                }
                if (shouldSetTintColor) {
                    selfObject.navigationBar.tintColor = NavBarTintColor;
                }
            }
            if (QMUICMIActivated) {
                BOOL shouldSetTintColor = NO;
                if (ToolBarContainerClasses.count) {
                    for (Class class in ToolBarContainerClasses) {
                        if ([selfObject isKindOfClass:class]) {
                            shouldSetTintColor = YES;
                            break;
                        }
                    }
                } else {
                    shouldSetTintColor = YES;
                }
                if (shouldSetTintColor) {
                    selfObject.toolbar.tintColor = ToolBarTintColor;
                }
            }
        });

        ExtendImplementationOfVoidMethodWithoutArguments([UINavigationController class], @selector(viewDidLayoutSubviews), ^(UINavigationController *selfObject) {
            // UIKit 可能延后创建或替换返回手势，布局时补齐两种手势的失败依赖。
            [selfObject qmuinc_updateContentPopGestureProtection];
        });
        
        OverrideImplementation(NSClassFromString([NSString qmui_stringByConcat:@"_", @"UINavigationBar", @"ContentView", nil]), NSSelectorFromString(@"__backButtonAction:"), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^(UIView *selfObject, id firstArgv) {
                
                if ([selfObject.superview isKindOfClass:UINavigationBar.class]) {
                    UINavigationBar *bar = (UINavigationBar *)selfObject.superview;
                    if ([bar.delegate isKindOfClass:UINavigationController.class]) {
                        UINavigationController *navController = (UINavigationController *)bar.delegate;
                        BOOL canPopViewController = [navController canPopViewController:navController.topViewController byPopGesture:NO];
                        if (!canPopViewController) return;
                    }
                }
                
                // call super
                void (*originSelectorIMP)(id, SEL, id);
                originSelectorIMP = (void (*)(id, SEL, id))originalIMPProvider();
                originSelectorIMP(selfObject, originCMD, firstArgv);
            };
        });
        
        OverrideImplementation([UINavigationController class], NSSelectorFromString(@"navigationTransitionView:didEndTransition:fromView:toView:"), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^void(UINavigationController *selfObject, UIView *transitionView, NSInteger transition, UIView *fromView, UIView *toView) {
                
                BOOL (*originSelectorIMP)(id, SEL, UIView *, NSInteger , UIView *, UIView *);
                originSelectorIMP = (BOOL (*)(id, SEL, UIView *, NSInteger , UIView *, UIView *))originalIMPProvider();
                originSelectorIMP(selfObject, originCMD, transitionView, transition, fromView, toView);
                selfObject.qmui_endedTransitionTopViewController = selfObject.topViewController;
            };
        });
        
#pragma mark - pushViewController:animated:
        OverrideImplementation([UINavigationController class], @selector(pushViewController:animated:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^(UINavigationController *selfObject, UIViewController *viewController, BOOL animated) {
                
                BOOL shouldInvokeAppearanceMethod = NO;
                
                if (selfObject.isViewLoaded && !selfObject.view.window) {
                    QMUILogWarn(NSStringFromClass(originClass), @"push 的时候 navigationController 不可见（例如上面盖着一个 present vc，或者切到别的 tab，可能导致 vc 的生命周期方法或者 UINavigationControllerDelegate 不会被调用");
                    if (selfObject.qmui_alwaysInvokeAppearanceMethods) {
                        shouldInvokeAppearanceMethod = YES;
                    }
                }
                
                if ([selfObject.viewControllers containsObject:viewController]) {
                    QMUIAssert(NO, @"UINavigationController (QMUI)", @"不允许重复 push 相同的 viewController 实例，会产生 crash。当前 viewController：%@", viewController);
                    return;
                }
                
                // call super
                void (^callSuperBlock)(void) = ^void(void) {
                    void (*originSelectorIMP)(id, SEL, UIViewController *, BOOL);
                    originSelectorIMP = (void (*)(id, SEL, UIViewController *, BOOL))originalIMPProvider();
                    originSelectorIMP(selfObject, originCMD, viewController, animated);
                };
                
                BOOL willPushActually = viewController && ![selfObject.viewControllers containsObject:viewController];
                
                if (!willPushActually) {
                    QMUIAssert(NO, @"UINavigationController (QMUI)", @"调用了 pushViewController 但实际上没 push 成功，viewController：%@", viewController);
                    callSuperBlock();
                    return;
                }
                
                UIViewController *appearingViewController = viewController;
                NSArray<UIViewController *> *disappearingViewControllers = selfObject.topViewController ? @[selfObject.topViewController] : nil;
                
                [selfObject setQmui_navigationAction:QMUINavigationActionWillPush animated:animated appearingViewController:appearingViewController disappearingViewControllers:disappearingViewControllers];
                
                if (shouldInvokeAppearanceMethod) {
                    [disappearingViewControllers.lastObject beginAppearanceTransition:NO animated:animated];
                    [appearingViewController beginAppearanceTransition:YES animated:animated];
                }
                
                callSuperBlock();
                
                [selfObject setQmui_navigationAction:QMUINavigationActionDidPush animated:animated appearingViewController:appearingViewController disappearingViewControllers:disappearingViewControllers];
                
                [selfObject qmui_animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
                    [selfObject setQmui_navigationAction:QMUINavigationActionPushCompleted animated:animated appearingViewController:appearingViewController disappearingViewControllers:disappearingViewControllers];
                    [selfObject setQmui_navigationAction:QMUINavigationActionUnknow animated:animated appearingViewController:nil disappearingViewControllers:nil];
                    
                    if (shouldInvokeAppearanceMethod) {
                        [disappearingViewControllers.lastObject endAppearanceTransition];
                        [appearingViewController endAppearanceTransition];
                    }
                }];
            };
        });
        
#pragma mark - popViewControllerAnimated:
        OverrideImplementation([UINavigationController class], @selector(popViewControllerAnimated:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^UIViewController *(UINavigationController *selfObject, BOOL animated) {
                
                // call super
                UIViewController *(^callSuperBlock)(void) = ^UIViewController *(void) {
                    UIViewController *(*originSelectorIMP)(id, SEL, BOOL);
                    originSelectorIMP = (UIViewController *(*)(id, SEL, BOOL))originalIMPProvider();
                    UIViewController *result = originSelectorIMP(selfObject, originCMD, animated);
                    return result;
                };
                
                QMUINavigationAction action = selfObject.qmui_navigationAction;
                if (action != QMUINavigationActionUnknow) {
                    QMUILogWarn(@"UINavigationController (QMUI)", @"popViewController 时上一次的转场尚未完成，系统会忽略本次 pop，等上一次转场完成后再重新执行 pop, viewControllers = %@", selfObject.viewControllers);
                }
                BOOL willPopActually = selfObject.viewControllers.count > 1 && action == QMUINavigationActionUnknow;// 系统文档里说 rootViewController 是不能被 pop 的，当只剩下 rootViewController 时当前方法什么事都不会做
                
                if (!willPopActually) {
                    return callSuperBlock();
                }
                
                BOOL shouldInvokeAppearanceMethod = NO;
                
                if (selfObject.isViewLoaded && !selfObject.view.window) {
                    QMUILogWarn(NSStringFromClass(originClass), @"pop 的时候 navigationController 不可见（例如上面盖着一个 present vc，或者切到别的 tab，可能导致 vc 的生命周期方法或者 UINavigationControllerDelegate 不会被调用");
                    if (selfObject.qmui_alwaysInvokeAppearanceMethods) {
                        shouldInvokeAppearanceMethod = YES;
                    }
                }
                
                UIViewController *appearingViewController = selfObject.viewControllers[selfObject.viewControllers.count - 2];
                NSArray<UIViewController *> *disappearingViewControllers = selfObject.viewControllers.lastObject ? @[selfObject.viewControllers.lastObject] : nil;
                
                [selfObject setQmui_navigationAction:QMUINavigationActionWillPop animated:animated appearingViewController:appearingViewController disappearingViewControllers:disappearingViewControllers];
                
                if (shouldInvokeAppearanceMethod) {
                    [disappearingViewControllers.lastObject beginAppearanceTransition:NO animated:animated];
                    [appearingViewController beginAppearanceTransition:YES animated:animated];
                }
                
                UIViewController *result = callSuperBlock();
                
                // UINavigationController 不可见时 return 值可能为 nil
                // https://github.com/Tencent/QMUI_iOS/issues/1180
                QMUIAssert(result && disappearingViewControllers && disappearingViewControllers.firstObject == result, @"UINavigationController (QMUI)", @"QMUI 认为 popViewController 会成功，但实际上失败了，result = %@, disappearingViewControllers = %@", result, disappearingViewControllers);
                disappearingViewControllers = result ? @[result] : disappearingViewControllers;
                
                [selfObject setQmui_navigationAction:QMUINavigationActionDidPop animated:animated appearingViewController:appearingViewController disappearingViewControllers:disappearingViewControllers];
                
                void (^transitionCompletion)(void) = ^void(void) {
                    [selfObject setQmui_navigationAction:QMUINavigationActionPopCompleted animated:animated appearingViewController:appearingViewController disappearingViewControllers:disappearingViewControllers];
                    [selfObject setQmui_navigationAction:QMUINavigationActionUnknow animated:animated appearingViewController:nil disappearingViewControllers:nil];
                    
                    if (shouldInvokeAppearanceMethod) {
                        [disappearingViewControllers.lastObject endAppearanceTransition];
                        [appearingViewController endAppearanceTransition];
                    }
                };
                if (!result) {
                    // 如果系统的 pop 没有成功，实际上提交给 animateAlongsideTransition:completion: 的 completion 并不会被执行，所以这里改为手动调用
                    if (transitionCompletion) {
                        transitionCompletion();
                    }
                } else {
                    [selfObject qmui_animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
                        if (transitionCompletion) {
                            transitionCompletion();
                        }
                    }];
                }
                
                return result;
            };
        });
        
#pragma mark - popToViewController:animated:
        OverrideImplementation([UINavigationController class], @selector(popToViewController:animated:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^NSArray<UIViewController *> *(UINavigationController *selfObject, UIViewController *viewController, BOOL animated) {
                
                // call super
                NSArray<UIViewController *> *(^callSuperBlock)(void) = ^NSArray<UIViewController *> *(void) {
                    NSArray<UIViewController *> *(*originSelectorIMP)(id, SEL, UIViewController *, BOOL);
                    originSelectorIMP = (NSArray<UIViewController *> * (*)(id, SEL, UIViewController *, BOOL))originalIMPProvider();
                    NSArray<UIViewController *> *poppedViewControllers = originSelectorIMP(selfObject, originCMD, viewController, animated);
                    return poppedViewControllers;
                };
                
                QMUINavigationAction action = selfObject.qmui_navigationAction;
                if (action != QMUINavigationActionUnknow) {
                    QMUILogWarn(@"UINavigationController (QMUI)", @"popToViewController 时上一次的转场尚未完成，系统会忽略本次 pop，等上一次转场完成后再重新执行 pop, currentViewControllers = %@, viewController = %@", selfObject.viewControllers, viewController);
                }
                BOOL willPopActually = selfObject.viewControllers.count > 1 && [selfObject.viewControllers containsObject:viewController] && selfObject.topViewController != viewController && action == QMUINavigationActionUnknow;// 系统文档里说 rootViewController 是不能被 pop 的，当只剩下 rootViewController 时当前方法什么事都不会做
                
                if (!willPopActually) {
                    return callSuperBlock();
                }
                
                UIViewController *appearingViewController = viewController;
                NSArray<UIViewController *> *disappearingViewControllers = nil;
                NSUInteger index = [selfObject.viewControllers indexOfObject:appearingViewController];
                if (index != NSNotFound) {
                    disappearingViewControllers = [selfObject.viewControllers subarrayWithRange:NSMakeRange(index + 1, selfObject.viewControllers.count - index - 1)];
                }

                [selfObject setQmui_navigationAction:QMUINavigationActionWillPop animated:animated appearingViewController:appearingViewController disappearingViewControllers:disappearingViewControllers];
                
                NSArray<UIViewController *> *result = callSuperBlock();
                
                QMUIAssert(!(selfObject.isViewLoaded && selfObject.view.window) || [result isEqualToArray:disappearingViewControllers], @"UINavigationController (QMUI)", @"QMUI 计算得到的 popToViewController 结果和系统的不一致");
                disappearingViewControllers = result ?: disappearingViewControllers;
                
                [selfObject setQmui_navigationAction:QMUINavigationActionDidPop animated:animated appearingViewController:appearingViewController disappearingViewControllers:disappearingViewControllers];
                
                [selfObject qmui_animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
                    [selfObject setQmui_navigationAction:QMUINavigationActionPopCompleted animated:animated appearingViewController:appearingViewController disappearingViewControllers:disappearingViewControllers];
                    [selfObject setQmui_navigationAction:QMUINavigationActionUnknow animated:animated appearingViewController:nil disappearingViewControllers:nil];
                }];
                
                return result;
            };
        });

#pragma mark - popToRootViewControllerAnimated:
        OverrideImplementation([UINavigationController class], @selector(popToRootViewControllerAnimated:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^NSArray<UIViewController *> *(UINavigationController *selfObject, BOOL animated) {
                
                // call super
                NSArray<UIViewController *> *(^callSuperBlock)(void) = ^NSArray<UIViewController *> *(void) {
                    NSArray<UIViewController *> *(*originSelectorIMP)(id, SEL, BOOL);
                    originSelectorIMP = (NSArray<UIViewController *> * (*)(id, SEL, BOOL))originalIMPProvider();
                    NSArray<UIViewController *> *result = originSelectorIMP(selfObject, originCMD, animated);
                    return result;
                };
                
                QMUINavigationAction action = selfObject.qmui_navigationAction;
                if (action != QMUINavigationActionUnknow) {
                    QMUILogWarn(@"UINavigationController (QMUI)", @"popToRootViewController 时上一次的转场尚未完成，系统会忽略本次 pop，等上一次转场完成后再重新执行 pop, viewControllers = %@", selfObject.viewControllers);
                }
                BOOL willPopActually = selfObject.viewControllers.count > 1 && action == QMUINavigationActionUnknow;
                
                if (!willPopActually) {
                    return callSuperBlock();
                }
                
                UIViewController *appearingViewController = selfObject.qmui_rootViewController;
                NSArray<UIViewController *> *disappearingViewControllers = [selfObject.viewControllers subarrayWithRange:NSMakeRange(1, selfObject.viewControllers.count - 1)];
                
                [selfObject setQmui_navigationAction:QMUINavigationActionWillPop animated:animated appearingViewController:appearingViewController disappearingViewControllers:disappearingViewControllers];
                
                NSArray<UIViewController *> *result = callSuperBlock();
                
                // UINavigationController 不可见时 return 值可能为 nil
                // https://github.com/Tencent/QMUI_iOS/issues/1180
                QMUIAssert(!(selfObject.isViewLoaded && selfObject.view.window) || [result isEqualToArray:disappearingViewControllers], @"UINavigationController (QMUI)", @"QMUI 计算得到的 popToRootViewController 结果和系统的不一致");
                disappearingViewControllers = result ?: disappearingViewControllers;
                
                [selfObject setQmui_navigationAction:QMUINavigationActionDidPop animated:animated appearingViewController:appearingViewController disappearingViewControllers:disappearingViewControllers];
                
                [selfObject qmui_animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
                    [selfObject setQmui_navigationAction:QMUINavigationActionPopCompleted animated:animated appearingViewController:appearingViewController disappearingViewControllers:disappearingViewControllers];
                    [selfObject setQmui_navigationAction:QMUINavigationActionUnknow animated:animated appearingViewController:nil disappearingViewControllers:nil];
                }];
                
                return result;
            };
        });

#pragma mark - setViewControllers:animated:
        OverrideImplementation([UINavigationController class], @selector(setViewControllers:animated:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^(UINavigationController *selfObject, NSArray<UIViewController *> *viewControllers, BOOL animated) {
                
                if (viewControllers.count != [NSSet setWithArray:viewControllers].count) {
                    QMUIAssert(NO, @"UINavigationController (QMUI)", @"setViewControllers 数组里不允许出现重复元素：%@", viewControllers);
                    viewControllers = [NSOrderedSet orderedSetWithArray:viewControllers].array;// 这里会保留该 vc 第一次出现的位置不变
                }

                UIViewController *appearingViewController = selfObject.topViewController != viewControllers.lastObject ? viewControllers.lastObject : nil;// setViewControllers 执行前后 topViewController 没有变化，则赋值为 nil，表示没有任何界面有“重新显示”，这个 nil 的值也用于在 QMUINavigationController 里实现 viewControllerKeepingAppearWhenSetViewControllersWithAnimated:
                NSMutableArray<UIViewController *> *disappearingViewControllers = selfObject.viewControllers.mutableCopy;
                [disappearingViewControllers removeObjectsInArray:viewControllers];
                disappearingViewControllers = disappearingViewControllers.count ? disappearingViewControllers : nil;

                [selfObject setQmui_navigationAction:QMUINavigationActionWillSet animated:animated appearingViewController:appearingViewController disappearingViewControllers:disappearingViewControllers];

                // call super
                void (*originSelectorIMP)(id, SEL, NSArray<UIViewController *> *, BOOL);
                originSelectorIMP = (void (*)(id, SEL, NSArray<UIViewController *> *, BOOL))originalIMPProvider();
                originSelectorIMP(selfObject, originCMD, viewControllers, animated);

                [selfObject setQmui_navigationAction:QMUINavigationActionDidSet animated:animated appearingViewController:appearingViewController disappearingViewControllers:disappearingViewControllers];

                [selfObject qmui_animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
                    [selfObject setQmui_navigationAction:QMUINavigationActionSetCompleted animated:animated appearingViewController:appearingViewController disappearingViewControllers:disappearingViewControllers];
                    [selfObject setQmui_navigationAction:QMUINavigationActionUnknow animated:animated appearingViewController:nil disappearingViewControllers:nil];
                }];
            };
        });
    });
}

- (void)qmui_didInitialize {
}

static char kAssociatedObjectKey_navigationAction;
- (void)setQmui_navigationAction:(QMUINavigationAction)qmui_navigationAction
                        animated:(BOOL)animated
         appearingViewController:(UIViewController *)appearingViewController
     disappearingViewControllers:(NSArray<UIViewController *> *)disappearingViewControllers {
    BOOL valueChanged = self.qmui_navigationAction != qmui_navigationAction;
    objc_setAssociatedObject(self, &kAssociatedObjectKey_navigationAction, @(qmui_navigationAction), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (valueChanged && self.qmuinc_navigationActionDidChangeBlocks.count) {
        [self.qmuinc_navigationActionDidChangeBlocks enumerateObjectsUsingBlock:^(QMUINavigationActionDidChangeBlock  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            obj(qmui_navigationAction, animated, self, appearingViewController, disappearingViewControllers);
        }];
    }
}

- (QMUINavigationAction)qmui_navigationAction {
    return [((NSNumber *)objc_getAssociatedObject(self, &kAssociatedObjectKey_navigationAction)) unsignedIntegerValue];
}

- (void)qmui_addNavigationActionDidChangeBlock:(QMUINavigationActionDidChangeBlock)block {
    if (!self.qmuinc_navigationActionDidChangeBlocks) {
        self.qmuinc_navigationActionDidChangeBlocks = NSMutableArray.new;
    }
    [self.qmuinc_navigationActionDidChangeBlocks addObject:block];
}

- (BOOL)qmui_isPushing {
    BOOL isPushing = self.qmui_navigationAction > QMUINavigationActionWillPush && self.qmui_navigationAction <= QMUINavigationActionPushCompleted;
    return isPushing;
}

- (BOOL)qmui_isPopping {
    BOOL isPopping = self.qmui_navigationAction > QMUINavigationActionWillPop && self.qmui_navigationAction <= QMUINavigationActionPopCompleted;
    return isPopping;
}

- (UINavigationControllerOperation)qmui_lastOperation {
    // -[UINavigationController lastOperation]
    SEL operationSEL = NSSelectorFromString([NSString qmui_stringByConcat:@"last", @"Operation", nil]);
    if ([self respondsToSelector:operationSEL]) {
        UINavigationControllerOperation operation = UINavigationControllerOperationNone;
        [self qmui_performSelector:operationSEL withPrimitiveReturnValue:&operation];
        return operation;
    }
    return UINavigationControllerOperationNone;
}

- (UIViewController *)qmui_topViewController {
    if (self.qmui_isPushing) {
        return self.topViewController;
    }
    return self.qmui_endedTransitionTopViewController ? self.qmui_endedTransitionTopViewController : self.topViewController;
}

- (nullable UIViewController *)qmui_rootViewController {
    UIViewController *rootViewController = self.viewControllers.firstObject;
    // 系统 UINavigationController 的 popToViewController、popToRootViewController、setViewControllers 三种 pop 的方式都有一个共同的特点，假如此时有3个及以上的 vc 例如 [A,B,C]，从当前界面 pop 到非相邻的界面，例如C到A，执行完 pop 操作后立马访问 UINavigationController.viewControllers 预期应该得到 [A]，实际上会得到 [C,A]，过一会（nav.view layoutIfNeeded 之后）才变成正确的 [A]。同理，[A,B,C,D]时从 D pop 到 B，预期得到[A,B]，实际得到[D,A,B]，也即这种情况它总是会把当前界面塞到 viewControllers 数组里的第一个，这就导致这期间访问基于 viewControllers 数组实现的功能（例如 qmui_rootViewController、qmui_previousViewController），都可能出错，所以这里对上述情况做特殊保护。
    // 如果 pop 操作时只有2个vc，则没这种问题。
    if (self.viewControllers.count > 1 && self.qmui_isPopping && self.transitionCoordinator) {
        id<UIViewControllerTransitionCoordinator> transitionCoordinator = self.transitionCoordinator;
        UIViewController *fromVc = [transitionCoordinator viewControllerForKey:UITransitionContextFromViewControllerKey];
        if (rootViewController == fromVc) {
            rootViewController = self.viewControllers[1];
        }
    }
    return rootViewController;
}

- (void)qmui_pushViewController:(UIViewController *)viewController animated:(BOOL)animated completion:(void (^)(void))completion {
    // 要先进行转场操作才能产生 self.transitionCoordinator，然后才能用 qmui_animateAlongsideTransition:completion:，所以不能把转场操作放在 animation block 里。
    [self pushViewController:viewController animated:animated];
    if (completion) {
        [self qmui_animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
            completion();
        }];
    }
}

- (UIViewController *)qmui_popViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion {
    // 要先进行转场操作才能产生 self.transitionCoordinator，然后才能用 qmui_animateAlongsideTransition:completion:，所以不能把转场操作放在 animation block 里。
    UIViewController *result = [self popViewControllerAnimated:animated];
    if (completion) {
        [self qmui_animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
            completion();
        }];
    }
    return result;
}

- (NSArray<UIViewController *> *)qmui_popToViewController:(UIViewController *)viewController animated:(BOOL)animated completion:(void (^)(void))completion {
    // 要先进行转场操作才能产生 self.transitionCoordinator，然后才能用 qmui_animateAlongsideTransition:completion:，所以不能把转场操作放在 animation block 里。
    NSArray<UIViewController *> *result = [self popToViewController:viewController animated:animated];
    if (completion) {
        [self qmui_animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
            completion();
        }];
    }
    return result;
}

- (NSArray<UIViewController *> *)qmui_popToRootViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion {
    // 要先进行转场操作才能产生 self.transitionCoordinator，然后才能用 qmui_animateAlongsideTransition:completion:，所以不能把转场操作放在 animation block 里。
    NSArray<UIViewController *> *result = [self popToRootViewControllerAnimated:animated];
    if (completion) {
        [self qmui_animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext>  _Nonnull context) {
            completion();
        }];
    }
    return result;
}

- (void)qmuinc_updateContentPopGestureProtection {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) {
        UIGestureRecognizer *contentPop = self.interactiveContentPopGestureRecognizer;
        if (!self.qmuinc_contentPopProtectionGestureRecognizer) {
            _QMUINavigationContentPopGestureRecognizer *protection = [[_QMUINavigationContentPopGestureRecognizer alloc] initWithTarget:nil action:NULL];
            [self.view addGestureRecognizer:protection];
            self.qmuinc_contentPopProtectionGestureRecognizer = protection;
        }
        if (contentPop && self.qmuinc_protectedContentPopGestureRecognizer != contentPop) {
            // Apple 对该系统手势仅开放失败依赖配置，保留其原有 delegate、enabled 与转场逻辑。
            [contentPop requireGestureRecognizerToFail:self.qmuinc_contentPopProtectionGestureRecognizer];
            self.qmuinc_protectedContentPopGestureRecognizer = contentPop;
        }

        if (!self.qmuinc_backGestureDelegator) {
            _QMUINavigationBackGestureDelegator *delegator = _QMUINavigationBackGestureDelegator.new;
            delegator.navigationController = self;
            delegator.edgeGestureRecognizer = [[_QMUINavigationEdgeBackGestureRecognizer alloc] initWithTarget:nil action:NULL];
            delegator.contentGestureRecognizer = [[_QMUINavigationBackGestureRecognizer alloc] initWithTarget:nil action:NULL];
            for (UIPanGestureRecognizer *gesture in @[delegator.edgeGestureRecognizer, delegator.contentGestureRecognizer]) {
                gesture.delegate = delegator;
                gesture.cancelsTouchesInView = NO;
                gesture.delaysTouchesBegan = NO;
                gesture.delaysTouchesEnded = NO;
                gesture.maximumNumberOfTouches = 1;
                [self.view addGestureRecognizer:gesture];
            }
            self.qmuinc_backGestureDelegator = delegator;
        }
        _QMUINavigationBackGestureDelegator *delegator = self.qmuinc_backGestureDelegator;
        delegator.edgeGestureRecognizer.edges = self.view.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft ? UIRectEdgeRight : UIRectEdgeLeft;
        UIGestureRecognizer *edgePop = self.interactivePopGestureRecognizer;
        if (edgePop && edgePop.delegate != self.qmui_interactiveGestureDelegator) {
            // UIKit 可能在转场后重设边缘代理，保存当前代理并恢复业务拦截，继续转发系统判断。
            self.qmui_interactivePopGestureRecognizerDelegate = edgePop.delegate;
            edgePop.delegate = self.qmui_interactiveGestureDelegator;
        }
        if (edgePop && delegator.protectedEdgeGestureRecognizer != edgePop) {
            [edgePop requireGestureRecognizerToFail:delegator.edgeGestureRecognizer];
            delegator.protectedEdgeGestureRecognizer = edgePop;
        }
        if (contentPop && delegator.protectedContentGestureRecognizer != contentPop) {
            // 新系统通过公开失败依赖执行拦截，不接管内容返回的 delegate、enabled 或私有 target。
            [contentPop requireGestureRecognizerToFail:delegator.contentGestureRecognizer];
            delegator.protectedContentGestureRecognizer = contentPop;
        }
    }
#endif
}

- (BOOL)canPopViewController:(UIViewController *)viewController byPopGesture:(BOOL)byPopGesture {
    BOOL canPopViewController = YES;
    
    if ([viewController respondsToSelector:@selector(shouldPopViewControllerByBackButtonOrPopGesture:)] &&
        [viewController shouldPopViewControllerByBackButtonOrPopGesture:byPopGesture] == NO) {
        canPopViewController = NO;
    }
    
    return canPopViewController;
}

- (BOOL)shouldForceEnableInteractivePopGestureRecognizer {
    UIViewController *viewController = [self topViewController];
    UIBarButtonItem *item = viewController.navigationItem.leftBarButtonItem;
    BOOL plainBackButton = [item qmui_getBoundBOOLForKey:@"qmuinb_plainBackButton"] && item.target == viewController && item.enabled;
    BOOL requested = [viewController respondsToSelector:@selector(forceEnableInteractivePopGestureRecognizer)] && [viewController forceEnableInteractivePopGestureRecognizer];
    if (!requested && plainBackButton) {
        // 自动兼容只针对原系统代理，不绕过业务额外安装的代理判断。
        id<UIGestureRecognizerDelegate> originalDelegate = self.qmui_interactivePopGestureRecognizerDelegate;
        requested = originalDelegate && [[NSBundle bundleForClass:[originalDelegate class]] isEqual:[NSBundle bundleForClass:UINavigationController.class]];
    }
    return requested && self.viewControllers.count > 1 && self.interactivePopGestureRecognizer.enabled &&
        self.qmui_navigationAction == QMUINavigationActionUnknow && !self.transitionCoordinator && !self.presentedViewController;
}

@end


@implementation _QMUINavigationInteractiveGestureDelegator

- (instancetype)initWithParentViewController:(UINavigationController *)parentViewController {
    if (self = [super init]) {
        _parentViewController = parentViewController;
    }
    return self;
}

#pragma mark - <UIGestureRecognizerDelegate>

// iOS 13.4 开始会优先询问该方法，只有返回 YES 后才会继续后续的逻辑
- (BOOL)_gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveEvent:(UIEvent *)event {
    if (gestureRecognizer == self.parentViewController.interactivePopGestureRecognizer) {
        NSObject <UIGestureRecognizerDelegate> *originGestureDelegate = self.parentViewController.qmui_interactivePopGestureRecognizerDelegate;
        if ([originGestureDelegate respondsToSelector:_cmd]) {
            BOOL originalValue = YES;
            [originGestureDelegate qmui_performSelector:_cmd withPrimitiveReturnValue:&originalValue arguments:&gestureRecognizer, &event, nil];
            if (!originalValue
                // 在开启 forceEnableInteractivePopGestureRecognizer 的界面被 push 的过程中快速手势返回，容易导致 App 卡死
                // https://github.com/Tencent/QMUI_iOS/issues/1498
                && self.parentViewController.qmui_navigationAction == QMUINavigationActionUnknow
                && [self.parentViewController shouldForceEnableInteractivePopGestureRecognizer]) {
                return YES;
            }
            
            return originalValue;
        }
    }
    return YES;
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if (gestureRecognizer == self.parentViewController.interactivePopGestureRecognizer) {
        _QMUINavigationBackGestureDelegator *backDelegator = self.parentViewController.qmuinc_backGestureDelegator;
        // 边缘返回必须直接应用业务否决，不能仅依赖旁路手势；共用缓存避免再次弹窗。
        BOOL canPopViewController = backDelegator.protectedEdgeGestureRecognizer == gestureRecognizer
            ? [backDelegator qmuinc_canPopForTouch:backDelegator.edgeTouch ?: backDelegator.contentTouch]
            : [self.parentViewController canPopViewController:self.parentViewController.topViewController byPopGesture:YES];
        if (canPopViewController) {
            if ([self.parentViewController.qmui_interactivePopGestureRecognizerDelegate respondsToSelector:_cmd]) {
                BOOL result = [self.parentViewController.qmui_interactivePopGestureRecognizerDelegate gestureRecognizerShouldBegin:gestureRecognizer];
                if (!result && [self.parentViewController shouldForceEnableInteractivePopGestureRecognizer]) {
                    id<UIGestureRecognizerDelegate> originalDelegate = self.parentViewController.qmui_interactivePopGestureRecognizerDelegate;
                    // 仅补齐系统因自定义左按钮拒绝的情况，不覆盖业务自定义代理的 NO。
                    if ([[NSBundle bundleForClass:[originalDelegate class]] isEqual:[NSBundle bundleForClass:UINavigationController.class]]) return YES;
                }
                return result;
            } else {
                return NO;
            }
        } else {
            return NO;
        }
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    if (gestureRecognizer == self.parentViewController.interactivePopGestureRecognizer) {
        [self.parentViewController.qmuinc_backGestureDelegator qmuinc_prepareForTouch:touch isEdge:YES];
        id<UIGestureRecognizerDelegate>originGestureDelegate = self.parentViewController.qmui_interactivePopGestureRecognizerDelegate;
        if ([originGestureDelegate respondsToSelector:_cmd]) {
            BOOL originalValue = [originGestureDelegate gestureRecognizer:gestureRecognizer shouldReceiveTouch:touch];
            if (!originalValue && [self.parentViewController shouldForceEnableInteractivePopGestureRecognizer]) {
                return YES;
            }
            return originalValue;
        }
    }
    return YES;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (gestureRecognizer == self.parentViewController.interactivePopGestureRecognizer) {
        if ([self.parentViewController.qmui_interactivePopGestureRecognizerDelegate respondsToSelector:_cmd]) {
            BOOL result = [self.parentViewController.qmui_interactivePopGestureRecognizerDelegate gestureRecognizer:gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:otherGestureRecognizer];
            return result;
        }
    }
    return NO;
}

// 是否要gestureRecognizer检测失败了，才去检测otherGestureRecognizer
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldBeRequiredToFailByGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    if (gestureRecognizer == self.parentViewController.interactivePopGestureRecognizer) {
        _QMUINavigationBackGestureDelegator *backDelegator = self.parentViewController.qmuinc_backGestureDelegator;
        // 系统返回已经等待许可手势失败，不能再让许可手势反向等待系统返回，否则形成循环依赖。
        if (otherGestureRecognizer == backDelegator.edgeGestureRecognizer || otherGestureRecognizer == backDelegator.contentGestureRecognizer) return NO;
        // 如果只是实现了上面几个手势的delegate，那么返回的手势和当前界面上的scrollview或者其他存在的手势会冲突，所以如果判断是返回手势，则优先响应返回手势再响应其他手势。
        // 不知道为什么，系统竟然没有实现这个delegate，那么它是怎么处理返回手势和其他手势的优先级的
        return YES;
    }
    return NO;
}

@end


@implementation _QMUINavigationBackGestureRecognizer
- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)preventedGestureRecognizer {
    return NO;
}
- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)preventingGestureRecognizer {
    return NO;
}
@end

@implementation _QMUINavigationEdgeBackGestureRecognizer
- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)preventedGestureRecognizer {
    return NO;
}
- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)preventingGestureRecognizer {
    return NO;
}
@end

@implementation _QMUINavigationBackGestureDelegator

- (void)qmuinc_prepareForTouch:(UITouch *)touch isEdge:(BOOL)isEdge {
    if (isEdge) self.edgeTouch = touch;
    else self.contentTouch = touch;
    // 系统代理和两个许可手势收到同一触摸时，只清理一次上一轮判断。
    if (self.currentTouch != touch) {
        self.currentTouch = touch;
        self.decisionTouch = nil;
    }
}

- (BOOL)qmuinc_canCheckPop {
    UINavigationController *navigationController = self.navigationController;
    // 根页面、转场中或被模态页面覆盖时，不触发业务确认。
    return navigationController.viewControllers.count > 1
        && navigationController.qmui_navigationAction == QMUINavigationActionUnknow
        && !navigationController.transitionCoordinator
        && !navigationController.presentedViewController
        && [navigationController.topViewController respondsToSelector:@selector(shouldPopViewControllerByBackButtonOrPopGesture:)];
}

- (BOOL)qmuinc_canPopForTouch:(UITouch *)touch {
    UIViewController *viewController = self.navigationController.topViewController;
    if (touch && self.decisionTouch == touch && self.decisionViewController == viewController) return self.decisionAllowsPop;
    if (![viewController respondsToSelector:@selector(shouldPopViewControllerByBackButtonOrPopGesture:)]) return YES;
    if (![self qmuinc_canCheckPop]) return NO;
    self.decisionTouch = touch;
    self.decisionViewController = viewController;
    self.decisionAllowsPop = [self.navigationController canPopViewController:viewController byPopGesture:YES];
    return self.decisionAllowsPop;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    BOOL isEdge = gestureRecognizer == self.edgeGestureRecognizer;
    UIGestureRecognizer *systemGesture = isEdge ? self.protectedEdgeGestureRecognizer : self.protectedContentGestureRecognizer;
    if (!systemGesture.enabled || ![self qmuinc_canCheckPop]) return NO;
    if (!isEdge) {
        // 横向控件仍优先响应自身拖动；边缘返回由独立的边缘许可手势处理。
        if ([self.navigationController.qmuinc_contentPopProtectionGestureRecognizer qmuinc_shouldProtectTouchInView:touch.view]) return NO;
    }
    [self qmuinc_prepareForTouch:touch isEdge:isEdge];
    return YES;
}

- (BOOL)gestureRecognizerShouldBegin:(UIPanGestureRecognizer *)gestureRecognizer {
    CGPoint translation = [gestureRecognizer translationInView:gestureRecognizer.view];
    if (CGPointEqualToPoint(translation, CGPointZero)) translation = [gestureRecognizer velocityInView:gestureRecognizer.view];
    UITouch *touch = gestureRecognizer == self.edgeGestureRecognizer ? self.edgeTouch : self.contentTouch;
    return [self qmuinc_shouldBlockPopForTranslation:translation touch:touch];
}

- (BOOL)qmuinc_shouldBlockPopForTranslation:(CGPoint)translation touch:(UITouch *)touch {
    if (self.navigationController.view.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft) translation.x = -translation.x;
    // 只在向返回方向拖动时询问业务，点按、纵向滚动及反方向拖动不会弹出确认。
    if (translation.x <= 0 || translation.x <= fabs(translation.y)) return NO;
    if (!touch) return NO;
    BOOL hasDecision = self.decisionTouch == touch && self.decisionViewController == self.navigationController.topViewController;
    if (!hasDecision && ![self qmuinc_canCheckPop]) return NO;
    // 允许返回时立即失败，让系统手势开始；拒绝时识别许可手势，使系统返回失败。
    return ![self qmuinc_canPopForTouch:touch];
}

@end


@implementation UIViewController (BackBarButtonSupport)
@end

@implementation UIView (QMUIInteractiveContentPopGesture)
QMUISynthesizeBOOLProperty(qmui_preventsInteractiveContentPopGestureRecognizer, setQmui_preventsInteractiveContentPopGestureRecognizer)
@end

@implementation _QMUINavigationContentPopGestureRecognizer

- (instancetype)initWithTarget:(id)target action:(SEL)action {
    if (self = [super initWithTarget:target action:action]) {
        self.delegate = self;
        self.cancelsTouchesInView = NO;
        self.delaysTouchesBegan = NO;
        self.delaysTouchesEnded = NO;
        self.maximumNumberOfTouches = 1;
    }
    return self;
}

- (BOOL)qmuinc_shouldProtectTouchInView:(UIView *)view {
    // 沿触摸起点向上判断，可覆盖滑块内部子视图、嵌套列表及自定义拖动区域。
    // 从保护区域开始的拖动即使移出控件，也继续让内容交互优先。
    for (UIView *candidate = view; candidate; candidate = candidate.superview) {
        if (candidate.qmui_preventsInteractiveContentPopGestureRecognizer) return YES;
        if ([candidate isKindOfClass:UISlider.class] && ((UISlider *)candidate).enabled) return YES;
        if ([candidate isKindOfClass:UIScrollView.class]) {
            UIScrollView *scrollView = (UIScrollView *)candidate;
            if (scrollView.scrollEnabled && scrollView.panGestureRecognizer.enabled) {
                UIEdgeInsets insets = scrollView.adjustedContentInset;
                CGFloat horizontalExtent = scrollView.contentSize.width + insets.left + insets.right;
                // 每次触摸实时判断，数据、内边距或滚动开关变化后无需重新绑定手势。
                if ((scrollView.bounces && scrollView.alwaysBounceHorizontal) || horizontalExtent > CGRectGetWidth(scrollView.bounds) + PixelOne) return YES;
            }
        }
        if (candidate == self.view) break;
    }
    return NO;
}

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    return [self qmuinc_shouldProtectTouchInView:touch.view];
}

- (BOOL)canPreventGestureRecognizer:(UIGestureRecognizer *)preventedGestureRecognizer {
    // 内容返回通过显式失败依赖等待本手势，其余系统手势（包括边缘返回）仍照常竞争。
    return NO;
}

- (BOOL)canBePreventedByGestureRecognizer:(UIGestureRecognizer *)preventingGestureRecognizer {
    // 滑块的内部拖动手势先识别时，仍保持内容返回的保护关系。
    return NO;
}

@end
