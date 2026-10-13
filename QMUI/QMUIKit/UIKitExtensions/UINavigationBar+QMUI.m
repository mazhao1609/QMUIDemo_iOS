/**
 * Tencent is pleased to support the open source community by making QMUI_iOS available.
 * Copyright (C) 2016-2021 THL A29 Limited, a Tencent company. All rights reserved.
 * Licensed under the MIT License (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 * http://opensource.org/licenses/MIT
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
 */

//
//  UINavigationBar+QMUI.m
//  QMUIKit
//
//  Created by QMUI Team on 2018/O/8.
//

#import "UINavigationBar+QMUI.h"
#import "QMUICore.h"
#import "NSObject+QMUI.h"
#import "UIView+QMUI.h"
#import "NSArray+QMUI.h"
#import "UINavigationItem+QMUI.h"

NSString *const kShouldFixTitleViewBugKey = @"kShouldFixTitleViewBugKey";

@implementation UINavigationBar (QMUI)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        // [UIKit Bug] Xcode 14 编译的 App 在 iOS 16.0 上可能存在顶部标题布局错乱
        // https://github.com/Tencent/QMUI_iOS/issues/1457
//#ifdef IOS16_SDK_ALLOWED 有些机子在 Xcode 13 编译的包上也有问题，所以先不做 Xcode 版本判断
            if (@available(iOS 16.0, *)) {
                
                if (@available(iOS 16.1, *)) {
                    // iOS 16.1 系统已修复
                } else {
                    OverrideImplementation([UINavigationItem class], @selector(setTitleView:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
                        return ^(UINavigationItem *selfObject, UIView *firstArgv) {
                            
                            // call super
                            void (*originSelectorIMP)(id, SEL, UIView *);
                            originSelectorIMP = (void (*)(id, SEL, UIView *))originalIMPProvider();
                            originSelectorIMP(selfObject, originCMD, firstArgv);
                            
                            if (!firstArgv) return;
                            
                            UINavigationBar *navigationBar = selfObject.qmui_navigationBar;
                            [navigationBar qmuinb_fixTitleViewLayoutInIOS16];
                        };
                    });
                    
                    OverrideImplementation([UINavigationBar class], @selector(pushNavigationItem:animated:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
                        return ^(UINavigationBar *selfObject, UINavigationItem *navigationItem, BOOL animated) {
                            
                            if (!animated && !selfObject.topItem.titleView && navigationItem.titleView) {
                                [selfObject qmuinb_fixTitleViewLayoutInIOS16];
                            }
                            
                            // call super
                            void (*originSelectorIMP)(id, SEL, UINavigationItem *, BOOL);
                            originSelectorIMP = (void (*)(id, SEL, UINavigationItem *, BOOL))originalIMPProvider();
                            originSelectorIMP(selfObject, originCMD, navigationItem, animated);
                        };
                    });
                    
                    OverrideImplementation([UINavigationBar class], @selector(setItems:animated:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
                        return ^(UINavigationBar *selfObject, NSArray<UINavigationItem *> *items, BOOL animated) {
                            
                            if (!animated && !selfObject.topItem.titleView && items.lastObject.titleView) {
                                [selfObject qmuinb_fixTitleViewLayoutInIOS16];
                            }
                            
                            // call super
                            void (*originSelectorIMP)(id, SEL, NSArray<UINavigationItem *> *, BOOL);
                            originSelectorIMP = (void (*)(id, SEL, NSArray<UINavigationItem *> *, BOOL))originalIMPProvider();
                            originSelectorIMP(selfObject, originCMD, items, animated);
                        };
                    });
                }
            }
//#endif
        
        // 旧标题补丁只用于旧导航栏，iOS 26 及以后由系统负责玻璃布局和转场。
        if (@available(iOS 26.0, *)) {
        } else {
        // [UIKit Bug] iOS 12 及以上的系统，如果设置了自己的 leftBarButtonItem，且 title 很长时，则当 pop 的时候，title 会瞬间跳到左边，与 leftBarButtonItem 重叠
        // https://github.com/Tencent/QMUI_iOS/issues/1217
        // _UITAMICAdaptorView
        Class adaptorClass = NSClassFromString([NSString qmui_stringByConcat:@"_", @"UITAMIC", @"Adaptor", @"View", nil]);
        
        // -[_UINavigationBarContentView didAddSubview:]
        OverrideImplementation(NSClassFromString([NSString qmui_stringByConcat:@"_", @"UINavigationBar", @"ContentView", nil]), @selector(didAddSubview:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^(UIView *selfObject, UIView *firstArgv) {
                
                // call super
                void (*originSelectorIMP)(id, SEL, UIView *);
                originSelectorIMP = (void (*)(id, SEL, UIView *))originalIMPProvider();
                originSelectorIMP(selfObject, originCMD, firstArgv);
                
                if ([firstArgv isKindOfClass:adaptorClass] || [firstArgv isKindOfClass:UILabel.class]) {
                    firstArgv.qmui_frameWillChangeBlock = ^CGRect(__kindof UIView * _Nonnull view, CGRect followingFrame) {
                        if ([view qmui_getBoundObjectForKey:kShouldFixTitleViewBugKey]) {
                            followingFrame = [[view qmui_getBoundObjectForKey:kShouldFixTitleViewBugKey] CGRectValue];
                        }
                        return followingFrame;
                    };
                }
            };
        });
        
        void (^boundTitleViewMinXBlock)(UINavigationBar *, BOOL) = ^void(UINavigationBar *navigationBar, BOOL cleanup) {
            
            if (!navigationBar.topItem.leftBarButtonItem) return;
            
            UIView *titleView = nil;
            UIView *adapterView = navigationBar.topItem.titleView.superview;
            if ([adapterView isKindOfClass:adaptorClass]) {
                titleView = adapterView;
            } else {
                titleView = [navigationBar.qmui_contentView.subviews qmui_filterWithBlock:^BOOL(__kindof UIView * _Nonnull item) {
                    return [item isKindOfClass:UILabel.class];
                }].firstObject;
            }
            if (!titleView) return;
            
            if (cleanup) {
                [titleView qmui_bindObject:nil forKey:kShouldFixTitleViewBugKey];
            } else if (CGRectGetWidth(titleView.frame) > CGRectGetWidth(navigationBar.bounds) / 2) {
                [titleView qmui_bindObject:[NSValue valueWithCGRect:titleView.frame] forKey:kShouldFixTitleViewBugKey];
            }
        };
        
        // // - [UINavigationBar _popNavigationItemWithTransition:]
        // - (id) _popNavigationItemWithTransition:(int)arg1; (0x1a15513a0)
        OverrideImplementation([UINavigationBar class], NSSelectorFromString([NSString qmui_stringByConcat:@"_", @"popNavigationItem", @"With", @"Transition:", nil]), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^id(UINavigationBar *selfObject, NSInteger firstArgv) {
                
                boundTitleViewMinXBlock(selfObject, NO);
                
                // call super
                id (*originSelectorIMP)(id, SEL, NSInteger);
                originSelectorIMP = (id (*)(id, SEL, NSInteger))originalIMPProvider();
                id result = originSelectorIMP(selfObject, originCMD, firstArgv);
                return result;
            };
        });
        
        // - (void) _completePopOperationAnimated:(BOOL)arg1 transitionAssistant:(id)arg2; (0x1a1551668)
        OverrideImplementation([UINavigationBar class], NSSelectorFromString([NSString qmui_stringByConcat:@"_", @"complete", @"PopOperationAnimated:", @"transitionAssistant:", nil]), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^(UINavigationBar *selfObject, BOOL firstArgv, id secondArgv) {
                
                // call super
                void (*originSelectorIMP)(id, SEL, BOOL, id);
                originSelectorIMP = (void (*)(id, SEL, BOOL, id))originalIMPProvider();
                originSelectorIMP(selfObject, originCMD, firstArgv, secondArgv);
                
                boundTitleViewMinXBlock(selfObject, YES);
            };
        });
        
        }

        // 以下是将 iOS 12 修改 UINavigationBar 样式的接口转换成用 iOS 13 的新接口去设置（因为新旧方法是互斥的，所以统一在新系统都用新方法）
        // 虽然系统的新接口是 iOS 13 就已经存在，但由于 iOS 13、14 都没必要用新接口，所以 QMUI 里在 iOS 15 才开始使用新接口，所以下方的 @available 填的是 iOS 15 而非 iOS 13（与 QMUIConfiguration.m 对应）。
        // 但这样有个风险，因为 QMUIConfiguration 配置表里都是用 appearance 的方式去设置 standardAppearance，所以如果在 UINavigationBar 实例被添加到 window 之前修改过旧版任意一个样式接口，就会导致一个新的 UINavigationBarAppearance 对象被设置给 standardAppearance 属性，这样系统就会认为你这个 UINavigationBar 实例自定义了 standardAppearance，那么当它被 moveToWindow 时就不会自动应用 appearance 的值了，因此需要保证在添加到 window 前不要自行修改属性
#ifdef IOS15_SDK_ALLOWED
        if (@available(iOS 15.0, *)) {
            
            void (^syncAppearance)(UINavigationBar *, void(^barActionBlock)(UINavigationBarAppearance *appearance)) = ^void(UINavigationBar *navigationBar, void(^barActionBlock)(UINavigationBarAppearance *appearance)) {
                if (!barActionBlock) return;
                UINavigationItem *item = nil;
                if (@available(iOS 26.0, *)) {
                    if ([navigationBar.topItem qmui_getBoundBOOLForKey:@"qmuinb_usesNavigationItemAppearance"]) item = navigationBar.topItem;
                    if (!QMUICMIActivated && !item) return;
                }
                
                // 需要确保这里获取到的 navigationBar.standardAppearance 是已经被应用了 UIAppearance 全局样式后的值，否则会出现下方 issue 描述的问题
                // https://github.com/Tencent/QMUI_iOS/issues/1437
                UINavigationBarAppearance *appearance = [item.standardAppearance ?: navigationBar.standardAppearance copy];
                barActionBlock(appearance);
                if (QMUICMIActivated && NavBarRemoveBackgroundEffectAutomatically && appearance.backgroundImage) {
                    appearance.backgroundEffect = nil;
                }
                if (item) {
                    // 页面已有独立外观时，旧接口只更新当前页面，不能污染前一页。
                    item.standardAppearance = appearance;
                    if (QMUICMIActivated && NavBarUsesStandardAppearanceOnly) {
                        item.scrollEdgeAppearance = appearance;
                        item.compactAppearance = appearance;
                        item.compactScrollEdgeAppearance = appearance;
                    }
                    return;
                }
                navigationBar.standardAppearance = appearance;
                if (QMUICMIActivated && NavBarUsesStandardAppearanceOnly) {
                    navigationBar.scrollEdgeAppearance = appearance;
                    navigationBar.compactAppearance = appearance;
                    navigationBar.compactScrollEdgeAppearance = appearance;
                }
            };
            
            OverrideImplementation([UINavigationBar class], @selector(setBarTintColor:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
                return ^(UINavigationBar *selfObject, UIColor *barTintColor) {
                    
                    // call super
                    void (*originSelectorIMP)(id, SEL, UIColor *);
                    originSelectorIMP = (void (*)(id, SEL, UIColor *))originalIMPProvider();
                    originSelectorIMP(selfObject, originCMD, barTintColor);
                    
                    syncAppearance(selfObject, ^void(UINavigationBarAppearance *appearance) {
                        appearance.backgroundColor = barTintColor;
                    });
                };
            });
            
            OverrideImplementation([UINavigationBar class], @selector(barTintColor), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
                return ^UIColor *(UINavigationBar *selfObject) {
                    if (@available(iOS 26.0, *)) {
                        if (selfObject.topItem.standardAppearance && [selfObject.topItem qmui_getBoundBOOLForKey:@"qmuinb_usesNavigationItemAppearance"]) return selfObject.topItem.standardAppearance.backgroundColor;
                        if (!QMUICMIActivated) { UIColor *(*origin)(id, SEL) = (UIColor *(*)(id, SEL))originalIMPProvider(); return origin(selfObject, originCMD); }
                    }
                    return selfObject.standardAppearance.backgroundColor;
                };
            });
            
            // 两个公开重载都要同步，不能依赖新版 UIKit 将两参数调用转发给三参数方法。
            OverrideImplementation([UINavigationBar class], @selector(setBackgroundImage:forBarMetrics:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
                return ^(UINavigationBar *selfObject, UIImage *image, UIBarMetrics barMetrics) {
                    void (*originSelectorIMP)(id, SEL, UIImage *, UIBarMetrics) = (void (*)(id, SEL, UIImage *, UIBarMetrics))originalIMPProvider();
                    originSelectorIMP(selfObject, originCMD, image, barMetrics);

                    syncAppearance(selfObject, ^void(UINavigationBarAppearance *appearance) {
                        appearance.backgroundImage = image;
                    });
                };
            });

            OverrideImplementation([UINavigationBar class], @selector(setBackgroundImage:forBarPosition:barMetrics:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
                return ^(UINavigationBar *selfObject, UIImage *image, UIBarPosition barPosition, UIBarMetrics barMetrics) {
                    
                    // call super
                    void (*originSelectorIMP)(id, SEL, UIImage *, UIBarPosition, UIBarMetrics);
                    originSelectorIMP = (void (*)(id, SEL, UIImage *, UIBarPosition, UIBarMetrics))originalIMPProvider();
                    originSelectorIMP(selfObject, originCMD, image, barPosition, barMetrics);
                    
                    syncAppearance(selfObject, ^void(UINavigationBarAppearance *appearance) {
                        appearance.backgroundImage = image;
                    });
                };
            });
            
            OverrideImplementation([UINavigationBar class], @selector(backgroundImageForBarPosition:barMetrics:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
                return ^UIImage *(UINavigationBar *selfObject, UIBarPosition firstArgv, UIBarMetrics secondArgv) {
                    if (@available(iOS 26.0, *)) {
                        if (selfObject.topItem.standardAppearance && [selfObject.topItem qmui_getBoundBOOLForKey:@"qmuinb_usesNavigationItemAppearance"]) return selfObject.topItem.standardAppearance.backgroundImage;
                        if (!QMUICMIActivated) { UIImage *(*origin)(id, SEL, UIBarPosition, UIBarMetrics) = (UIImage *(*)(id, SEL, UIBarPosition, UIBarMetrics))originalIMPProvider(); return origin(selfObject, originCMD, firstArgv, secondArgv); }
                    }
                    return selfObject.standardAppearance.backgroundImage;
                };
            });
            
            OverrideImplementation([UINavigationBar class], @selector(setShadowImage:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
                return ^(UINavigationBar *selfObject, UIImage *shadowImage) {
                    
                    // call super
                    void (*originSelectorIMP)(id, SEL, UIImage *);
                    originSelectorIMP = (void (*)(id, SEL, UIImage *))originalIMPProvider();
                    originSelectorIMP(selfObject, originCMD, shadowImage);
                    
                    syncAppearance(selfObject, ^void(UINavigationBarAppearance *appearance) {
                        appearance.shadowImage = shadowImage;
                    });
                };
            });
            
            OverrideImplementation([UINavigationBar class], @selector(shadowImage), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
                return ^UIImage *(UINavigationBar *selfObject) {
                    if (@available(iOS 26.0, *)) {
                        if (selfObject.topItem.standardAppearance && [selfObject.topItem qmui_getBoundBOOLForKey:@"qmuinb_usesNavigationItemAppearance"]) return selfObject.topItem.standardAppearance.shadowImage;
                        if (!QMUICMIActivated) { UIImage *(*origin)(id, SEL) = (UIImage *(*)(id, SEL))originalIMPProvider(); return origin(selfObject, originCMD); }
                    }
                    return selfObject.standardAppearance.shadowImage;
                };
            });
            
            OverrideImplementation([UINavigationBar class], @selector(setBarStyle:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
                return ^(UINavigationBar *selfObject, UIBarStyle barStyle) {
                    
                    // call super
                    void (*originSelectorIMP)(id, SEL, UIBarStyle);
                    originSelectorIMP = (void (*)(id, SEL, UIBarStyle))originalIMPProvider();
                    originSelectorIMP(selfObject, originCMD, barStyle);
                    
                    syncAppearance(selfObject, ^void(UINavigationBarAppearance *appearance) {
                        appearance.backgroundEffect = [UIBlurEffect effectWithStyle:barStyle == UIBarStyleDefault ? UIBlurEffectStyleSystemChromeMaterialLight : UIBlurEffectStyleSystemChromeMaterialDark];
                    });
                };
            });
            
            // iOS 15 没有对应的属性
//            OverrideImplementation([UINavigationBar class], @selector(barStyle), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
//                return ^UIBarStyle(UINavigationBar *selfObject) {
//
//                    if (@available(iOS 15.0, *)) {
//                        return ???;
//                    }
//
//
//                    // call super
//                    UIBarStyle (*originSelectorIMP)(id, SEL);
//                    originSelectorIMP = (UIBarStyle (*)(id, SEL))originalIMPProvider();
//                    UIBarStyle result = originSelectorIMP(selfObject, originCMD);
//
//                    return result;
//                };
//            });
            
            OverrideImplementation([UINavigationBar class], @selector(setTitleTextAttributes:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
                return ^(UINavigationBar *selfObject, NSDictionary<NSAttributedStringKey, id> *titleTextAttributes) {
                    
                    // call super
                    void (*originSelectorIMP)(id, SEL, NSDictionary<NSAttributedStringKey, id> *);
                    originSelectorIMP = (void (*)(id, SEL, NSDictionary<NSAttributedStringKey, id> *))originalIMPProvider();
                    originSelectorIMP(selfObject, originCMD, titleTextAttributes);
                    
                    syncAppearance(selfObject, ^void(UINavigationBarAppearance *appearance) {
                        appearance.titleTextAttributes = titleTextAttributes;
                    });
                };
            });
        }
        
        if (@available(iOS 15.0, *)) {
            if (!QMUICMIActivated) return;
            if (!(NavBarRemoveBackgroundEffectAutomatically || TabBarRemoveBackgroundEffectAutomatically || ToolBarRemoveBackgroundEffectAutomatically)
                && !(NavBarUsesStandardAppearanceOnly || TabBarUsesStandardAppearanceOnly || ToolBarUsesStandardAppearanceOnly)) return;
            
            // 背景效果通过公开 appearance 配置，不再读取或隐藏系统私有背景子视图。

            // 尚未应用 UIAppearance 就已经修改 bar 的样式的场景，可能导致 bar 样式无法与全局保持一致，所以这里做个提醒
            // https://github.com/Tencent/QMUI_iOS/issues/1451
            // - [UINavigationBar setStandardAppearance:]
            OverrideImplementation([UINavigationBar class], @selector(setStandardAppearance:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
                return ^(UINavigationBar *selfObject, UINavigationBarAppearance * firstArgv) {
                    
                    // call super
                    void (*originSelectorIMP)(id, SEL, UINavigationBarAppearance *);
                    originSelectorIMP = (void (*)(id, SEL, UINavigationBarAppearance *))originalIMPProvider();
                    originSelectorIMP(selfObject, originCMD, firstArgv);
                    
                    // 这里只希望识别 UINavigationController 自带的 navigationBar，不希望处理业务自己 new 的 bar，所以用 superview 是否为 UILayoutContainerView 来作为判断条件。
                    BOOL isSystemBar = [NSStringFromClass(selfObject.superview.class) hasPrefix:@"UILayoutContainer"];
                    BOOL alreadyMoveToWindow = !!selfObject.window;
                    BOOL isPresenting = NO;
                    if (!alreadyMoveToWindow) {
                        UINavigationController *nav = [selfObject.qmui_viewController isKindOfClass:UINavigationController.class] ? selfObject.qmui_viewController : nil;
                         isPresenting = nav && nav.presentedViewController;
                    }
                    if (isSystemBar && !alreadyMoveToWindow && !isPresenting) {
                        QMUIAssert(NO, @"UINavigationBar (QMUI)", @"试图在 UINavigationBar 尚未添加到 window 上时就修改它的样式，可能导致 UINavigationBar 的样式无法与全局保持一致。");
                    }
                };
            });
        }
#endif
    });
}

- (UIView *)qmui_contentView {
    // iOS 26 调整了 visualProvider，沿实际视图树查找，避免私有 KVC 路径失效导致闪退。
    NSMutableArray<UIView *> *pendingViews = self.subviews.mutableCopy;
    for (NSUInteger index = 0; index < pendingViews.count; index++) {
        UIView *view = pendingViews[index];
        if ([NSStringFromClass(view.class) containsString:@"NavigationBarContentView"]) {
            return view;
        }
        [pendingViews addObjectsFromArray:view.subviews];
    }
    // 容器改名时，从公开的自定义标题或按钮沿父视图回溯，避免固定私有类名成为唯一入口。
    NSMutableArray<UIView *> *anchors = NSMutableArray.new;
    if (self.topItem.titleView) [anchors addObject:self.topItem.titleView];
    for (UIBarButtonItem *item in self.topItem.leftBarButtonItems) {
        if (item.customView) [anchors addObject:item.customView];
    }
    for (UIBarButtonItem *item in self.topItem.rightBarButtonItems) {
        if (item.customView) [anchors addObject:item.customView];
    }
    for (UIView *anchor in anchors) {
        UIView *container = anchor;
        while (container.superview && container.superview != self) container = container.superview;
        if (container.superview == self && container != anchor) return container;
    }
    // 尚未布局或系统采用其他结构时允许为空，不把整条导航栏误当成内容容器。
    return nil;
}

- (void)qmuinb_fixTitleViewLayoutInIOS16 {
    // _UINavigationBarTitleControl，在每次转场动画时都会被重建，但无动画则一直都是这个实例（横竖屏切换也是同一个实例）
    Class titleControlClass = NSClassFromString([NSString qmui_stringByConcat:@"_", @"UINavigationBar", @"TitleControl", nil]);
    UIView *titleControl = [self.qmui_contentView.subviews qmui_filterWithBlock:^BOOL(__kindof UIView * _Nonnull item) {
        return [item isKindOfClass:titleControlClass];
    }].firstObject;
    titleControl.qmui_frameWillChangeBlock = ^CGRect(__kindof UIView * _Nonnull view, CGRect followingFrame) {
        followingFrame = CGRectSetY(followingFrame, CGRectGetMinYVerticallyCenterInParentRect(view.superview.bounds, followingFrame));
        return followingFrame;
    };
}

@end
