/**
 * Tencent is pleased to support the open source community by making QMUI_iOS available.
 * Copyright (C) 2016-2021 THL A29 Limited, a Tencent company. All rights reserved.
 * Licensed under the MIT License (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 * http://opensource.org/licenses/MIT
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
 */

//
//  UINavigationController+NavigationBarTransition.h
//  qmui
//
//  Created by QMUI Team on 16/2/22.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 *  iOS 15–25 通过独立的转场导航栏保留前后页面各自的背景，避免共享导航栏的样式瞬间切换；可通过 QMUICustomNavigationBarTransitionDelegate 控制此行为。
 *  iOS 26 及以后使用每个页面的 UINavigationItem appearance。需要自定义转场时只将前后页背景放到各自页面上随页面移动，标题、按钮、玻璃控件和手势继续使用系统转场；完成或取消后恢复系统背景，不复制玻璃导航栏。
 */
@interface UINavigationController (NavigationBarTransition)

@end
