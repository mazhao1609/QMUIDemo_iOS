/**
 * Tencent is pleased to support the open source community by making QMUI_iOS available.
 * Copyright (C) 2016-2021 THL A29 Limited, a Tencent company. All rights reserved.
 * Licensed under the MIT License (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 * http://opensource.org/licenses/MIT
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
 */
//
//  UINavigationBar+QMUIBarProtocol.m
//  QMUIKit
//
//  Created by molice on 2022/5/18.
//

#import "UINavigationBar+QMUIBarProtocol.h"
#import "QMUIBarProtocolPrivate.h"
#import "QMUICore.h"
#import "UIVisualEffectView+QMUI.h"
#import "NSArray+QMUI.h"
#import "NSObject+QMUI.h"

@interface UINavigationBar ()<QMUIBarProtocolPrivate>
@end

@implementation UINavigationBar (QMUIBarProtocol)

QMUISynthesizeBOOLProperty(qmuibar_hasSetEffect, setQmuibar_hasSetEffect)
QMUISynthesizeBOOLProperty(qmuibar_hasSetEffectForegroundColor, setQmuibar_hasSetEffectForegroundColor)

BeginIgnoreClangWarning(-Wobjc-protocol-method-implementation)
- (void)qmuibar_updateEffect {
    // 使用公开 appearance，分别保留标准、紧凑和滚动边缘样式。
    void (^applyEffect)(UINavigationBarAppearance *) = ^(UINavigationBarAppearance *appearance) {
        if (self.qmuibar_hasSetEffect) appearance.backgroundEffect = self.qmui_effect;
        if (self.qmuibar_hasSetEffectForegroundColor) appearance.backgroundColor = self.qmui_effectForegroundColor;
    };
    if (@available(iOS 26.0, *)) {
        UINavigationItem *item = self.topItem;
        if ([item qmui_getBoundBOOLForKey:@"qmuinb_usesNavigationItemAppearance"]) {
            // 页面 appearance 优先于 bar，自定义磨砂也必须同步到当前页面。
            UINavigationBarAppearance *(^appearanceWithEffect)(UINavigationBarAppearance *) = ^UINavigationBarAppearance *(UINavigationBarAppearance *source) {
                UINavigationBarAppearance *appearance = [source copy];
                if (appearance) applyEffect(appearance);
                return appearance;
            };
            item.standardAppearance = appearanceWithEffect(item.standardAppearance ?: self.standardAppearance);
            item.scrollEdgeAppearance = appearanceWithEffect(item.scrollEdgeAppearance);
            item.compactAppearance = appearanceWithEffect(item.compactAppearance);
            item.compactScrollEdgeAppearance = appearanceWithEffect(item.compactScrollEdgeAppearance);
            return;
        }
    }
    UINavigationBarAppearance *appearance = [self.standardAppearance copy];
    applyEffect(appearance);
    self.standardAppearance = appearance;
    if (self.scrollEdgeAppearance) {
        UINavigationBarAppearance *edgeAppearance = [self.scrollEdgeAppearance copy];
        applyEffect(edgeAppearance);
        self.scrollEdgeAppearance = edgeAppearance;
    }
    if (self.compactAppearance) {
        UINavigationBarAppearance *edgeAppearance = [self.compactAppearance copy];
        applyEffect(edgeAppearance);
        self.compactAppearance = edgeAppearance;
    }
    if (self.compactScrollEdgeAppearance) {
        UINavigationBarAppearance *edgeAppearance = [self.compactScrollEdgeAppearance copy];
        applyEffect(edgeAppearance);
        self.compactScrollEdgeAppearance = edgeAppearance;
    }
}
EndIgnoreClangWarning

#pragma mark - <QMUIBarProtocol>

- (UIView *)qmui_backgroundView {
    // 背景容器只做尽力查询，结构改变时返回 nil，避免私有 KVC 异常。
    for (UIView *view in self.subviews) {
        if ([NSStringFromClass(view.class) containsString:@"BarBackground"]) return view;
    }
    return nil;
}

- (UIImageView *)qmui_shadowImageView {
    NSMutableArray<UIView *> *views = self.qmui_backgroundView.subviews.mutableCopy;
    for (NSUInteger index = 0; index < views.count; index++) {
        UIView *view = views[index];
        if ([view isKindOfClass:UIImageView.class] && [NSStringFromClass(view.class) containsString:@"Shadow"]) return (UIImageView *)view;
        [views addObjectsFromArray:view.subviews];
    }
    return nil;
}

- (UIVisualEffectView *)qmui_effectView {
    NSArray<UIVisualEffectView *> *visibleEffectViews = [self.qmui_effectViews qmui_filterWithBlock:^BOOL(UIVisualEffectView * _Nonnull item) {
        return !item.hidden && item.alpha > 0.01 && item.superview;
    }];
    return visibleEffectViews.lastObject;
}

- (NSArray<UIVisualEffectView *> *)qmui_effectViews {
    NSMutableArray<UIVisualEffectView *> *result = NSMutableArray.new;
    NSMutableArray<UIView *> *views = self.qmui_backgroundView.subviews.mutableCopy;
    for (NSUInteger index = 0; index < views.count; index++) {
        UIView *view = views[index];
        if ([view isKindOfClass:UIVisualEffectView.class]) {
            [result addObject:(UIVisualEffectView *)view];
        } else {
            [views addObjectsFromArray:view.subviews];
        }
    }
    return result.count ? result : nil;
}

static char kAssociatedObjectKey_effect;
- (void)setQmui_effect:(UIBlurEffect *)qmui_effect {
    BOOL valueChanged = self.qmui_effect != qmui_effect;
    objc_setAssociatedObject(self, &kAssociatedObjectKey_effect, qmui_effect, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (valueChanged) {
        self.qmuibar_hasSetEffect = YES;// QMUITheme 切换时会重新赋值，所以可能出现本来就是 nil，还给它又赋值了 nil，这种场景不应该导致 hasSet 标志位改变，所以要把标志位的设置放在 if (valueChanged) 里
        [self qmuibar_updateEffect];
    }
}

- (UIBlurEffect *)qmui_effect {
    return (UIBlurEffect *)objc_getAssociatedObject(self, &kAssociatedObjectKey_effect);
}

static char kAssociatedObjectKey_effectForegroundColor;
- (void)setQmui_effectForegroundColor:(UIColor *)qmui_effectForegroundColor {
    BOOL valueChanged = ![self.qmui_effectForegroundColor isEqual:qmui_effectForegroundColor];
    objc_setAssociatedObject(self, &kAssociatedObjectKey_effectForegroundColor, qmui_effectForegroundColor, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    if (valueChanged) {
        self.qmuibar_hasSetEffectForegroundColor = YES;// QMUITheme 切换时会重新赋值，所以可能出现本来就是 nil，还给它又赋值了 nil，这种场景不应该导致 hasSet 标志位改变，所以要把标志位的设置放在 if (valueChanged) 里
        [self qmuibar_updateEffect];
    }
}

- (UIColor *)qmui_effectForegroundColor {
    return (UIColor *)objc_getAssociatedObject(self, &kAssociatedObjectKey_effectForegroundColor);
}

@end
