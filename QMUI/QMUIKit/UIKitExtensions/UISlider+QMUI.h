/**
 * Tencent is pleased to support the open source community by making QMUI_iOS available.
 * Copyright (C) 2016-2021 THL A29 Limited, a Tencent company. All rights reserved.
 * Licensed under the MIT License (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 * http://opensource.org/licenses/MIT
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
 */
//
//  UISlider+QMUI.h
//  QMUIKit
//
//  Created by MoLice on 2021/D/10.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@class QMUISliderStepControl;

@interface UISlider (QMUI)

/// 中间圆球的实际视图，自定义圆点通常是 UIImageView；未生成或无法识别时返回 nil。
@property(nullable, nonatomic, strong, readonly) UIView *qmui_thumbView;

/// 背后导轨的高度，默认为 0，表示使用系统默认的高度。
/// 自定义高度使用固定尺寸导轨图片；设置回 0 会移除 QMUI 生成的图片，业务自定义导轨图片仍保留。
/// iOS 26+ 同时启用 Steps 时，导轨的可见两端对齐首尾档位的圆点中心，不改变系统圆点坐标。
@property(nonatomic, assign) IBInspectable CGFloat qmui_trackHeight UI_APPEARANCE_SELECTOR;

/// 中间圆球的大小，默认为 CGSizeZero
/// @warning 注意若设置了 thumbSize 但没设置 thumbColor，则圆点的颜色会使用 self.tintColor 的颜色（而系统 UISlider 默认的圆点颜色是白色带阴影，不跟 tintColor 走）
/// @warning iOS 26 系统玻璃绘制路径会忽略自定义圆点图片，需要自定义圆点时请配合 qmui_trackHeight > 0 或业务自定义导轨图片。
@property(nonatomic, assign) IBInspectable CGSize qmui_thumbSize UI_APPEARANCE_SELECTOR;

/// 中间圆球的颜色，仅当设置了 qmui_thumbSize 时才有效。默认为 nil，nil 表示用 self.tintColor。
/// @warning 注意在使用了 qmui_thumbSize 时请勿使用系统的 thumbTintColor，后者会导致 qmui_thumbSize 无效。
@property(nullable, nonatomic, strong) IBInspectable UIColor *qmui_thumbColor UI_APPEARANCE_SELECTOR;

/// 中间圆球的阴影样式，默认为 nil，也即没有阴影。
/// 需在圆点视图生成后呈现；布局、圆点图片重建和动态修改颜色时自动重新应用。
@property(nullable, nonatomic, strong) NSShadow *qmui_thumbShadow UI_APPEARANCE_SELECTOR;

/// 用于实现只有若干个离散数值的 slider 交互，该属性可控制圆点停靠的位置数量，默认为0，当设置为大于等于2的值时才启用该交互模式。
/// 启用后圆点、进度条和实际 value 对齐到最近档位；松手或取消拖动时也会归档，不改变 continuous 的事件发送规则。
@property(nonatomic, assign) NSUInteger qmui_numberOfSteps;

/// 当使用了 step 功能时，可通过这个属性设置当前在第几档，或者获取当前的值。
@property(nonatomic, assign) NSUInteger qmui_step;

/// 在设置 qmui_numberOfSteps 时会创建对应个数的 QMUISliderStepControl，而通过这个 configuration block 可以配置每一个 stepControl 的属性
@property(nullable, nonatomic, copy) void (^qmui_stepControlConfiguration)(__kindof UISlider *slider, QMUISliderStepControl *stepControl, NSUInteger index);

/// 当使用了 step 功能时，可通过这个 block 监听 step 的变化（只有 step 的值改变时才会触发），获取当前 step 的值请调用 slider.qmui_step，获取变化前的 step 值请访问参数 precedingStep。
/// @note 在系统的 UIControlEventValueChanged 里获取 slider.qmui_step 也可以，但因为 slider.continuous 默认是 YES，所以拖动过程中 UIControlEventValueChanged 会触发很多次，但 step 不一定有变化，所以用专门的 block 监听会更方便高效一点。
@property(nullable, nonatomic, copy) void (^qmui_stepDidChangeBlock)(__kindof UISlider *slider, NSUInteger precedingStep);
@end

@interface QMUISliderStepControl : UIControl

@property(nonatomic, strong, readonly) UILabel *titleLabel;
@property(nonatomic, strong, readonly) UIView *indicator;
@property(nonatomic, assign) CGSize indicatorSize UI_APPEARANCE_SELECTOR;
@property(nonatomic, assign) CGFloat spacingBetweenTitleAndIndicator UI_APPEARANCE_SELECTOR;
@end

NS_ASSUME_NONNULL_END
