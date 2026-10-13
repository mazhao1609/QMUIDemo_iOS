/**
 * Tencent is pleased to support the open source community by making QMUI_iOS available.
 * Copyright (C) 2016-2021 THL A29 Limited, a Tencent company. All rights reserved.
 * Licensed under the MIT License (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 * http://opensource.org/licenses/MIT
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
 */

//
//  UINavigationBar+QMUI.h
//  QMUIKit
//
//  Created by QMUI Team on 2018/O/8.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UINavigationBar (QMUI)

/**
 导航栏内管理标题和按钮的内容容器。通过实际视图树查找，不依赖私有 KVC。
 尚未创建内容容器或系统改变内部结构时返回 nil，调用方应允许为空。
 */
@property(nonatomic, strong, readonly, nullable) UIView *qmui_contentView;

@end

NS_ASSUME_NONNULL_END
