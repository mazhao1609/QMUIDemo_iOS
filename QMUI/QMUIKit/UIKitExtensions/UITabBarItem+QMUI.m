/**
 * Tencent is pleased to support the open source community by making QMUI_iOS available.
 * Copyright (C) 2016-2021 THL A29 Limited, a Tencent company. All rights reserved.
 * Licensed under the MIT License (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 * http://opensource.org/licenses/MIT
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
 */

//
//  UITabBarItem+QMUI.m
//  qmui
//
//  Created by QMUI Team on 15/7/20.
//

#import "UITabBarItem+QMUI.h"
#import "QMUICore.h"
#import "UIBarItem+QMUI.h"

@implementation UITabBarItem (QMUI)

QMUISynthesizeIdCopyProperty(qmui_doubleTapBlock, setQmui_doubleTapBlock)

- (UIImageView *)qmui_imageView {
    UIView *button = self.qmui_view;
    UIImageView *imageView = [self.class qmui_imageViewInTabBarButton:button];
    if (@available(iOS 26.0, *)) {
        UITabBar *tabBar = nil;
        for (UIView *view = button.superview; view; view = view.superview) {
            if ([view isKindOfClass:UITabBar.class]) {
                tabBar = (UITabBar *)view;
                break;
            }
        }
        if (!tabBar || tabBar.selectedItem != self || !button) return imageView;

        // 液态 TabBar 会同时保留普通、选中两套按钮，item.view 仍指向普通图标。
        // 以相同按钮类型和 TabBar 内的位置定位选中副本，不依赖 UIKit 私有类名或 KVC。
        CGRect buttonRect = [button convertRect:button.bounds toView:tabBar];
        UIImage *selectedImage = self.selectedImage ?: self.image;
        UIImageView *selectedImageView = nil;
        NSMutableArray<UIView *> *views = tabBar.subviews.mutableCopy;
        for (NSUInteger index = 0; index < views.count; index++) {
            UIView *view = views[index];
            if (view.hidden || view.alpha <= 0.01) continue;
            if ([view isKindOfClass:button.class]) {
                CGRect rect = [view convertRect:view.bounds toView:tabBar];
                if (fabs(CGRectGetMidX(rect) - CGRectGetMidX(buttonRect)) < 1
                    && fabs(CGRectGetMidY(rect) - CGRectGetMidY(buttonRect)) < 1
                    && fabs(CGRectGetWidth(rect) - CGRectGetWidth(buttonRect)) < 1
                    && fabs(CGRectGetHeight(rect) - CGRectGetHeight(buttonRect)) < 1) {
                    UIImageView *candidate = [self.class qmui_imageViewInTabBarButton:view];
                    if (candidate) {
                        UIImage *displayedImage = candidate.highlighted && candidate.highlightedImage ? candidate.highlightedImage : candidate.image;
                        if (selectedImage && [displayedImage isEqual:selectedImage]) return candidate;
                        if (!selectedImageView) selectedImageView = candidate;
                    }
                }
            }
            [views addObjectsFromArray:view.subviews];
        }
        // 系统可能重新配置 SF Symbol 或使用相同的普通/选中图片，按镜像位置兜底。
        return selectedImageView ?: imageView;
    }
    return imageView;
}

+ (UIImageView *)qmui_imageViewInTabBarButton:(UIView *)tabBarButton {
    
    if (!tabBarButton) {
        return nil;
    }
    NSMutableArray<UIView *> *views = tabBarButton.subviews.mutableCopy;
    for (NSUInteger index = 0; index < views.count; index++) {
        UIView *view = views[index];
        if (view.hidden || view.alpha <= 0.01) continue;
        if ([view isKindOfClass:UIImageView.class]) {
            UIImageView *imageView = (UIImageView *)view;
            if (imageView.image || (imageView.highlighted && imageView.highlightedImage)) return imageView;
        }
        [views addObjectsFromArray:view.subviews];
    }
    return nil;
}

@end
