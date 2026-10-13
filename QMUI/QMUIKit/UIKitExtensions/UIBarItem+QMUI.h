/**
 * Tencent is pleased to support the open source community by making QMUI_iOS available.
 * Copyright (C) 2016-2021 THL A29 Limited, a Tencent company. All rights reserved.
 * Licensed under the MIT License (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 * http://opensource.org/licenses/MIT
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
 */

//
//  UIBarItem+QMUI.h
//  QMUIKit
//
//  Created by QMUI Team on 2018/4/5.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIBarItem (QMUI)

/**
 获取 UIBarItem（UIBarButtonItem、UITabBarItem） 内部的 view，通常对于 navigationItem 而言，需要在设置了 navigationItem 后并且在 navigationBar 可见时（例如 viewDidAppear: 及之后）获取 UIBarButtonItem.qmui_view 才有值。
 
 @return 返回 UIKit 当前提供的按钮容器，未创建或无法获取时为 nil。内部类型可能随系统改变，请勿依赖私有类名。iOS 26 的液态 UITabBarItem 容器对应普通按钮，获取当前状态的图标请使用 qmui_imageView。
 
 @note 可以通过 qmui_viewDidSetBlock 监听 qmui_view 值的变化，从而无需等待 viewDidAppear: 之类的时机。
 
 @warning 仅对 UIBarButtonItem、UITabBarItem 有效
 */
@property(nullable, nonatomic, weak, readonly) UIView *qmui_view;

/**
 当 item 内的 view 生成后就会调用这个 block。
 
 @note 该方法的本质是系统的 setView:/setCustomView: 被调用时就会调用，但系统在横竖屏旋转时也会再次走到 setView:（即便此时 view 的实例并没有发生变化），所以 QMUI 对这种情况做了屏蔽，以保证这个 block 对于同一个 view 实例只会被调用一次。
 
 @warning 仅对 UIBarButtonItem、UITabBarItem 有效
 */
@property(nullable, nonatomic, copy) void (^qmui_viewDidSetBlock)(__kindof UIBarItem *item,  UIView * _Nullable view);

/**
 当 item 内的 view 的 layoutSubviews 被调用后就会调用这个 block，如果某些需求需要依赖于 subviews 的位置，则使用这个 block。如果只是依赖于 item 的 view 的 frame 变化，则可以使用 qmui_viewLayoutDidChangeBlock。
 
 @warning 仅对 UIBarButtonItem、UITabBarItem 有效
 */
@property(nullable, nonatomic, copy) void (^qmui_viewDidLayoutSubviewsBlock)(__kindof UIBarItem *item, UIView * _Nullable view);

/**
 当 item 内的 view 的 frame 发生变化时就会调用这个 block。
 
 @warning 仅对 UIBarButtonItem、UITabBarItem 有效
 */
@property(nullable, nonatomic, copy) void (^qmui_viewLayoutDidChangeBlock)(__kindof UIBarItem *item, UIView * _Nullable view);

@end

NS_ASSUME_NONNULL_END
