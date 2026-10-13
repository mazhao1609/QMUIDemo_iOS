//
//  QDChangeNavBarStyleViewController.m
//  qmuidemo
//
//  Created by QMUI Team on 16/9/5.
//  Copyright © 2016年 QMUI Team. All rights reserved.
//

#import "QDChangeNavBarStyleViewController.h"

@interface QDChangeNavBarStyleViewController ()

@property(nonatomic, assign) QDNavigationBarStyle barStyle;
@property(nonatomic, strong) UIBarButtonItem *buttonStyleItem;
@property(nonatomic, strong) UISwitch *buttonStyleSwitch;

@end

@implementation QDChangeNavBarStyleViewController

- (instancetype)initWithBarStyle:(QDNavigationBarStyle)barStyle {
    if (self = [super init]) {
        self.barStyle = barStyle;
    }
    return self;
}

- (void)viewDidLoad {
    if (@available(iOS 26.0, *)) {
        // 先准备开关，保证父类创建首行单元格时已经有 accessoryView。
        self.buttonStyleSwitch = UISwitch.new;
        self.buttonStyleSwitch.accessibilityLabel = @"全局旧版导航栏按钮";
        [self.buttonStyleSwitch addTarget:self action:@selector(handleButtonStyleSwitch:) forControlEvents:UIControlEventValueChanged];
        self.buttonStyleSwitch.on = NavBarUsesLegacyButtonLayout;
    }
    [super viewDidLoad];
    if (@available(iOS 26.0, *)) {
        self.buttonStyleItem = [UIBarButtonItem qmui_itemWithTitle:@"普通按钮" target:self action:@selector(handleToggleNavigationButtons)];
        self.buttonStyleItem.accessibilityLabel = @"切换导航栏按钮样式";
        UIBarButtonItem *imageItem = [UIBarButtonItem qmui_itemWithImage:[UIImage systemImageNamed:@"circle.lefthalf.filled"] target:self action:@selector(handleToggleNavigationButtons)];
        imageItem.accessibilityLabel = @"切换按钮样式";
        self.navigationItem.rightBarButtonItems = @[self.buttonStyleItem, imageItem];
        [self updateNavigationButtonStyle];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self updateNavigationButtonStyle];
}

- (void)handleToggleNavigationButtons {
    QMUICMI.navBarUsesLegacyButtonLayout = !NavBarUsesLegacyButtonLayout;
    [self updateNavigationButtonStyle];
}

- (void)handleButtonStyleSwitch:(UISwitch *)sender {
    QMUICMI.navBarUsesLegacyButtonLayout = sender.on;
    [self updateNavigationButtonStyle];
}

- (void)updateNavigationButtonStyle {
    self.buttonStyleItem.title = NavBarUsesLegacyButtonLayout ? @"普通按钮" : @"玻璃按钮";
    self.buttonStyleSwitch.on = NavBarUsesLegacyButtonLayout;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [super tableView:tableView cellForRowAtIndexPath:indexPath];
    BOOL isSwitch = [self.dataSource[indexPath.row] isEqualToString:@"全局旧版导航栏按钮"];
    cell.accessoryView = isSwitch ? self.buttonStyleSwitch : nil;
    cell.accessoryType = isSwitch ? UITableViewCellAccessoryNone : UITableViewCellAccessoryDisclosureIndicator;
    cell.selectionStyle = isSwitch ? UITableViewCellSelectionStyleNone : UITableViewCellSelectionStyleDefault;
    return cell;
}

- (void)initDataSource {
    [super initDataSource];
    self.dataSource = @[@"默认",
                        @"深色",
                        @"浅色（磨砂）"];
    if (@available(iOS 26.0, *)) self.dataSource = [@[@"全局旧版导航栏按钮"] arrayByAddingObjectsFromArray:self.dataSource];
}

- (void)didSelectCellWithTitle:(NSString *)title {
    if ([title isEqualToString:@"全局旧版导航栏按钮"]) return;
    QDChangeNavBarStyleViewController *viewController = nil;
    if ([title isEqualToString:@"默认"]) {
        viewController = [[QDChangeNavBarStyleViewController alloc] initWithBarStyle:QDNavigationBarStyleOrigin];
    }
    else if ([title isEqualToString:@"深色"]) {
        viewController = [[QDChangeNavBarStyleViewController alloc] initWithBarStyle:QDNavigationBarStyleDark];
    }
    else if ([title isEqualToString:@"浅色（磨砂）"]) {
        viewController = [[QDChangeNavBarStyleViewController alloc] initWithBarStyle:QDNavigationBarStyleLight];
    }
    viewController.title = title;
    [self.navigationController pushViewController:viewController animated:YES];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    if (self.barStyle == QDNavigationBarStyleOrigin || self.barStyle == QDNavigationBarStyleDark) {
        return UIStatusBarStyleLightContent;
    } else {
        return UIStatusBarStyleDefault;
    }
}

#pragma mark - QMUINavigationControllerDelegate

- (UIBarStyle)qmui_navigationBarStyle {
    // 浅色磨砂不继承深色主题或上一页的材料样式。
    return self.barStyle == QDNavigationBarStyleLight ? UIBarStyleDefault : NavBarStyle;
}

- (UIColor *)qmui_navigationBarBarTintColor {
    // 显式提供半透明主题色，两版系统都呈现有色磨砂，不继承上一页残留的背景图。
    if (self.barStyle == QDNavigationBarStyleLight) {
        return [(NavBarBarTintColor ?: UIColor.qd_tintColor) colorWithAlphaComponent:.55];
    }
    return NavBarBarTintColor;
}

- (UIImage *)qmui_navigationBarBackgroundImage {
    if (self.barStyle == QDNavigationBarStyleOrigin) {
        return NavBarBackgroundImage;
    } else if (self.barStyle == QDNavigationBarStyleLight) {
        return nil; // 使用系统磨砂与上面声明的半透明背景色，不用不透明背景图遮挡材料。
    } else if (self.barStyle == QDNavigationBarStyleDark) {
        return [UIImage qmui_imageWithColor:UIColorMake(66, 66, 66)];
    } else {
        return NavBarBackgroundImage;
    }
}

- (UIImage *)qmui_navigationBarShadowImage {
    if (self.barStyle == QDNavigationBarStyleLight) {
        return nil; // nil则用系统默认颜色
    }
    return NavBarShadowImage;
}

- (UIColor *)qmui_navigationBarTintColor {
    if (self.barStyle == QDNavigationBarStyleOrigin) {
        return NavBarTintColor;
    } else if (self.barStyle == QDNavigationBarStyleLight) {
        return UIColorBlack;
    } else if (self.barStyle == QDNavigationBarStyleDark) {
        return UIColorWhite;
    } else {
        return NavBarTintColor;
    }
}

- (UIColor *)qmui_titleViewTintColor {
    return [self qmui_navigationBarTintColor];
}

#pragma mark - <QMUICustomNavigationBarTransitionDelegate>

- (NSString *)customNavigationBarTransitionKey {
    // 不同的 barStyle 返回不同的 key，这样在不同 barStyle 的界面之间切换时就能使用自定义的 navigationBar 样式，会带来更好的视觉体验
    // 返回 nil 则表示当前界面没有修改过导航栏样式
    // 注意，如果你使用配置表，建议打开 AutomaticCustomNavigationBarTransitionStyle，由 QMUI 自动帮你判断是否需要使用自定义样式，这样就无需再实现 customNavigationBarTransitionKey 方法。QMUI Demo 里为了展示接口的使用，没有打开这个开关。
    return self.barStyle == QDNavigationBarStyleOrigin ? nil : [NSString qmui_stringWithNSInteger:self.barStyle];
}

@end
