//
//  QDInteractiveDebugViewController.m
//  qmuidemo
//
//  Created by MoLice on 2020/6/18.
//  Copyright © 2020 QMUI Team. All rights reserved.
//

#import "QDInteractiveDebugViewController.h"
#import "QMUIInteractiveDebugger.h"

@interface QDInteractiveDebugViewController ()

@property(nonatomic, strong) QMUIButton *presentButton;
@property(nonatomic, strong) QMUIInteractiveDebugPanelViewController *asViewController;
@end

@implementation QDInteractiveDebugViewController

- (void)initSubviews {
    [super initSubviews];
    self.presentButton = [QDUIHelper generateLightBorderedButton];
    self.presentButton.qmui_contentInsets = UIEdgeInsetsMake(8, 20, 8, 20);
    [self.presentButton setTitle:@"点击打开 Debug 面板" forState:UIControlStateNormal];
    self.presentButton.spacingBetweenImageAndTitle = 4;
    [self.presentButton addTarget:self action:@selector(handlePresentButtonEvent) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:self.presentButton];
    
    self.asViewController = [self generateDebugController];
    [self.view addSubview:self.asViewController.view];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    UIEdgeInsets padding = UIEdgeInsetsMake(32 + self.qmui_navigationBarMaxYInViewCoordinator, 32, 32, 32);
    [self.presentButton sizeToFit];
    self.presentButton.frame = CGRectSetXY(self.presentButton.frame, CGRectGetMinXHorizontallyCenterInParentRect(self.view.bounds, self.presentButton.frame), padding.top);
    CGSize size = [self.asViewController contentSizeThatFits:CGSizeMake(320, CGFLOAT_MAX)];
    self.asViewController.view.frame = CGRectMake(CGFloatGetCenter(CGRectGetWidth(self.view.bounds), 320), CGRectGetMaxY(self.presentButton.frame) + 32, 320, size.height);
}

- (void)handlePresentButtonEvent {
    QMUIInteractiveDebugPanelViewController *vc = [self generateDebugController];
    [vc presentInViewController:self];
}

- (QMUIInteractiveDebugPanelViewController *)generateDebugController {
    __weak __typeof(self)weakSelf = self;
    QMUIInteractiveDebugPanelViewController *vc = [QDUIHelper generateDebugViewControllerWithTitle:@"修改按钮信息" items:@[
        [QMUIInteractiveDebugPanelItem textItemWithTitle:@"文字" valueGetter:^(QMUITextField * _Nonnull actionView) {
        actionView.text = weakSelf.presentButton.currentTitle;
    } valueSetter:^(QMUITextField * _Nonnull actionView) {
        [weakSelf.presentButton setTitle:actionView.text forState:UIControlStateNormal];
    }],
        [QMUIInteractiveDebugPanelItem sliderItemWithTitle:@"字号" minValue:8 maxValue:20 valueGetter:^(UISlider * _Nonnull actionView) {
        actionView.value = weakSelf.presentButton.titleLabel.font.pointSize;
    } valueSetter:^(UISlider * _Nonnull actionView) {
        weakSelf.presentButton.titleLabel.font = [weakSelf.presentButton.titleLabel.font fontWithSize:actionView.value];
        [weakSelf.view setNeedsLayout];
    }],
        [QMUIInteractiveDebugPanelItem colorItemWithTitle:@"背景色" valueGetter:^(QMUITextField * _Nonnull actionView) {
        actionView.text = weakSelf.presentButton.backgroundColor.qmui_RGBAString;
    } valueSetter:^(QMUITextField * _Nonnull actionView) {
        weakSelf.presentButton.backgroundColor = [UIColor qmui_colorWithRGBAString:actionView.text];
    }],
        [QMUIInteractiveDebugPanelItem boolItemWithTitle:@"显示图标" valueGetter:^(UISwitch * _Nonnull actionView) {
        actionView.on = !!weakSelf.presentButton.currentImage;
    } valueSetter:^(UISwitch * _Nonnull actionView) {
        [weakSelf.presentButton setImage:actionView.on ? [UIImageMake(@"icon_nav_about") qmui_imageResizedInLimitedSize:CGSizeMake(16, 16)] : nil forState:UIControlStateNormal];
        [weakSelf.view setNeedsLayout];
    }],
        ({
        QMUIOrderedDictionary<NSNumber *, NSString *> *stateMap = [[QMUIOrderedDictionary alloc] initWithKeysAndObjects:
                                                                   @(UIControlStateNormal), @"Normal",
                                                                   @(UIControlStateSelected), @"Selected",
                                                                   @(UIControlStateDisabled), @"Disabled", nil
        ];
        QMUIInteractiveDebugPanelItem *item = [QMUIInteractiveDebugPanelItem enumItemWithTitle:@"切换状态" items:stateMap.allValues valueGetter:^(QMUIButton * _Nonnull actionView, NSArray<NSString *> * _Nonnull items) {
            NSString *title = stateMap[@(weakSelf.presentButton.state)] ?: @"Normal";
            [actionView setTitle:title forState:UIControlStateNormal];
        } valueSetter:^(QMUIButton * _Nonnull actionView, NSArray<NSString *> * _Nonnull items) {
            NSString *title = actionView.currentTitle;
            [stateMap.allValues enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                if ([title isEqualToString:obj]) {
                    UIControlState state = stateMap.allKeys[idx].integerValue;
                    if (state == UIControlStateSelected) {
                        weakSelf.presentButton.selected = YES;
                        weakSelf.presentButton.enabled = YES;
                    } else if (state == UIControlStateDisabled) {
                        weakSelf.presentButton.selected = NO;
                        weakSelf.presentButton.enabled = NO;
                    } else {
                        // Normal
                        weakSelf.presentButton.selected = NO;
                        weakSelf.presentButton.enabled = YES;
                    }
                }
            }];
        }];
        item;
    }),
    ]];
    return vc;
}

@end
