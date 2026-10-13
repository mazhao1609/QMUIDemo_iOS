/**
 * Tencent is pleased to support the open source community by making QMUI_iOS available.
 * Copyright (C) 2016-2021 THL A29 Limited, a Tencent company. All rights reserved.
 * Licensed under the MIT License (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 * http://opensource.org/licenses/MIT
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
 */

//
//  UITabBarItem+QMUI.h
//  qmui
//
//  Created by QMUI Team on 15/7/20.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UITabBarItem (QMUI)

/**
 *  双击 tabBarItem 时的回调，默认为 nil。
 *  @param tabBarItem 被双击的 UITabBarItem，若需要拿到当前的 view 则通过 qmui_view 获取。
 *  @param index 被双击的 UITabBarItem 的序号
 */
@property(nonatomic, copy, nullable) void (^qmui_doubleTapBlock)(UITabBarItem *tabBarItem, NSInteger index);

/**
 * 获取 UITabBarItem 当前状态的图标视图，需在 TabBar 完成布局后调用，找不到则返回 nil。
 * iOS 26 的液态 TabBar 有普通、选中两套图标，选中时返回选中副本；切换状态后应重新获取，不要缓存。
 * 获取业务原图请使用 image / selectedImage；本接口返回的视图和图片可能由系统重新创建或配置。
 */
- (nullable UIImageView *)qmui_imageView;
/// 仅在传入按钮的子视图中查找图标，不跨到液态 TabBar 的另一套按钮。
+ (nullable UIImageView *)qmui_imageViewInTabBarButton:(nullable UIView *)tabBarButton;

@end

NS_ASSUME_NONNULL_END
