/**
 * Tencent is pleased to support the open source community by making QMUI_iOS available.
 * Copyright (C) 2016-2021 THL A29 Limited, a Tencent company. All rights reserved.
 * Licensed under the MIT License (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 * http://opensource.org/licenses/MIT
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
 */

//
//  QMUINavigationButton.h
//  QMUIKit
//
//  Created by QMUI Team on 2018/4/9.
//

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, QMUINavigationButtonType) {
    QMUINavigationButtonTypeNormal,         // 普通导航栏文字按钮
    QMUINavigationButtonTypeBold,           // 导航栏加粗按钮
    QMUINavigationButtonTypeImage,          // 图标按钮
    QMUINavigationButtonTypeBack            // 自定义返回按钮(可以同时带有title)
};

/**
 *  QMUINavigationButton 有两部分组成：
 *  一部分是 UIBarButtonItem (QMUINavigationButton)，提供比系统更便捷的类方法来快速初始化一个 UIBarButtonItem，推荐首选这种方式（原则是能用系统的尽量用系统的，不满足才用自定义的）。
 *  另一部分就是 QMUINavigationButton，会提供一个按钮，作为 customView 给 UIBarButtonItem 使用，这种常用于自定义的返回按钮。
 *  对于第二种按钮，会尽量保证样式、布局看起来都和系统的 UIBarButtonItem 一致，所以内部做了许多 iOS 版本兼容的微调。
 *  开启 NavBarUsesLegacyButtonLayout 时，iOS 15 及以后使用同一套普通按钮指标；字体、图标尺寸及内容间距可在 QMUIConfiguration 中统一修改。
 */
@interface QMUINavigationButton : UIButton

/**
 *  获取当前按钮的`QMUINavigationButtonType`
 */
@property(nonatomic, assign, readonly) QMUINavigationButtonType type;

/**
 * UIBarButtonItem 默认都是跟随 tintColor 的，所以这里声明是否让图片也是用 AlwaysTemplate 模式
 * 默认为 YES
 */
@property(nonatomic, assign) BOOL adjustsImageTintColorAutomatically;

/**
 *  导航栏按钮的初始化函数，指定的初始化方法
 *  @param type 按钮类型
 *  @param title 按钮的title
 */
- (instancetype)initWithType:(QMUINavigationButtonType)type title:(nullable NSString *)title;

/**
 *  导航栏按钮的初始化函数
 *  @param type 按钮类型
 */
- (instancetype)initWithType:(QMUINavigationButtonType)type;

/**
 *  导航栏按钮的初始化函数
 *  @param image 按钮的image
 */
- (instancetype)initWithImage:(nullable UIImage *)image;

@end

@interface UIBarButtonItem (QMUINavigationButton)

/**
 隐藏按钮的系统共享背景，iOS 26 上可将普通导航栏按钮显示为纯文字或图标，默认 NO。
 仅使用公开 API，不修改导航栏背景、按钮内容、系统布局、点击行为或返回手势；iOS 15–25 保存设置但外观保持原样。
 建议搭配 UIBarButtonItemStylePlain 使用。多按钮 UIBarButtonItemGroup 会忽略该属性，这是系统 API 的限制，普通 left/rightBarButtonItems 数组不受此限制。

 本属性不保证对系统自动返回按钮生效（iOS 26.3 实测忽略 backBarButtonItem 上的设置）。需要普通返回箭头时，可使用 qmui_plainBackItemWithViewController:。
 本属性不移除 customView 自身绘制的背景或按钮自己的突出样式。
 */
@property(nonatomic, assign) BOOL qmui_hidesSharedBackground;

+ (instancetype)qmui_itemWithButton:(QMUINavigationButton *)button target:(nullable id)target action:(nullable SEL)action;
+ (instancetype)qmui_itemWithImage:(UIImage *)image target:(nullable id)target action:(nullable SEL)action;
+ (instancetype)qmui_itemWithTitle:(NSString *)title target:(nullable id)target action:(nullable SEL)action;
+ (instancetype)qmui_itemWithBoldTitle:(NSString *)title target:(nullable id)target action:(nullable SEL)action;
+ (instancetype)qmui_backItemWithTitle:(nullable NSString *)title target:(nullable id)target action:(nullable SEL)action;

/// 返回一个返回按钮，该返回按钮的文字由配置表 NeedsBackBarButtonItemTitle 和 target 的值决定，如果 NeedsBackBarButtonItemTitle 为 NO，则返回按钮不显示文字，若为 YES，则默认文字为“返回”，但如果 target 为 UIViewController 则会自动获取上一个界面的 title 作为当前返回按钮的文字。
+ (instancetype)qmui_backItemWithTarget:(nullable id)target action:(nullable SEL)action;

/**
 返回无玻璃背景的返回箭头，作为当前页 leftBarButtonItem 使用，建议在 viewWillAppear 中创建。
 项目统一使用普通按钮与紧凑间距时，请设置 QMUICMI.navBarUsesLegacyButtonLayout = YES，无需逐页调用本方法。
 使用公开的普通 UIBarButtonItem 替换自动返回按钮，导航栏背景及转场仍由系统管理。
 点击和历史菜单接入 shouldPopViewControllerByBackButtonOrPopGesture:NO，VoiceOver 退出也执行同一判断；边缘返回通过 QMUI 的自定义按钮兼容逻辑处理，不修改内容返回手势的 delegate、enabled 或 target。
 长按菜单按当前导航栈生成，使用标准 UIMenu 展示，不是系统自动返回按钮的私有菜单。
 根页面、没有导航控制器、隐藏返回按钮或声明 backAction 时返回 nil，不覆盖业务自己的返回动作；已有的左侧按钮由业务自行决定是否替换。
 */
+ (nullable instancetype)qmui_plainBackItemWithViewController:(UIViewController *)viewController;

/// 返回一个以“×”为图片的关闭按钮，“x”的图片使用配置表 NavBarCloseButtonImage 设置
+ (instancetype)qmui_closeItemWithTarget:(nullable id)target action:(nullable SEL)action;

+ (instancetype)qmui_fixedSpaceItemWithWidth:(CGFloat)width;
+ (instancetype)qmui_flexibleSpaceItem;
@end

NS_ASSUME_NONNULL_END
