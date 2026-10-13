//
//  QDPopupMenuViewController.m
//  qmuidemo
//
//  Created by molice on 2024/8/1.
//  Copyright © 2024 QMUI Team. All rights reserved.
//

#import "QDPopupMenuViewController.h"
#import "QMUIInteractiveDebugger.h"

@interface QDPopupMenuViewController ()
@property(nonatomic, strong) UIScrollView *scrollView;
@property(nonatomic, strong) QMUIButton *actionButton;
@property(nonatomic, strong) QMUIInteractiveDebugPanelViewController *debugViewController;

@property(nonatomic, strong) QMUIPopupMenuView *menu;
@property(nonatomic, assign) BOOL shouldShowMultipleSections;
@property(nonatomic, assign) BOOL shouldShowSectionTitles;
@property(nonatomic, assign) BOOL useBigData;
@end

@implementation QDPopupMenuViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.scrollView = UIScrollView.new;
    [self.view addSubview:self.scrollView];
    
    self.actionButton = QDUIHelper.generateLightBorderedButton;
    [self.actionButton setTitle:@"显示浮层" forState:UIControlStateNormal];
    [self.actionButton addTarget:self action:@selector(handleButtonEvent:) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:self.actionButton];
    
    self.menu = [[QMUIPopupMenuView alloc] init];
    self.menu.maskViewBackgroundColor = nil;
    self.menu.automaticallyHidesWhenUserTap = NO;
    self.menu.maximumHeight = 400;
    [self updateMenu];
    self.menu.sourceView = self.actionButton;
    self.menu.hidden = YES;
    [self.scrollView addSubview:self.menu];
    
    __weak __typeof(self)weakSelf = self;
    __weak __typeof(self.menu)weakMenu = self.menu;
    
    self.menu.willShowBlock = ^(BOOL animated) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((animated ? .3 : 0) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [weakSelf.actionButton setTitle:weakMenu.isShowing ? @"隐藏 Menu" : @"显示 Menu" forState:UIControlStateNormal];
            [weakSelf updateLayoutAnimated:YES];
        });
    };
    self.menu.didHideBlock = ^(BOOL hidesByUserTap) {
        [weakSelf.actionButton setTitle:weakMenu.isShowing ? @"隐藏 Menu" : @"显示 Menu" forState:UIControlStateNormal];
        [weakSelf updateLayoutAnimated:YES];
    };
    
    self.debugViewController = [QDUIHelper generateDebugViewControllerWithTitle:@"配置参数" items:@[
        [QMUIInteractiveDebugPanelItem boolItemWithTitle:@"显示箭头" valueGetter:^(UISwitch * _Nonnull actionView) {
        actionView.on = weakMenu.arrowSize.height > 0;
    } valueSetter:^(UISwitch * _Nonnull actionView) {
        weakMenu.arrowSize = actionView.on ? QMUIPopupContainerView.appearance.arrowSize : CGSizeZero;
        [weakSelf updateLayoutAnimated:YES];
    }],
        [QMUIInteractiveDebugPanelItem enumItemWithTitle:@"item 高度" items:@[@"固定(44)", @"内容自适应"] valueGetter:^(QMUIButton * _Nonnull actionView, NSArray<NSString *> * _Nonnull items) {
        [actionView setTitle:items[weakMenu.itemHeight == QMUIViewSelfSizingHeight ? 1 : 0] forState:UIControlStateNormal];
    } valueSetter:^(QMUIButton * _Nonnull actionView, NSArray<NSString *> * _Nonnull items) {
        NSInteger index = [items indexOfObject:actionView.currentTitle];
        weakMenu.itemHeight = index == 1 ? QMUIViewSelfSizingHeight : 44;
        [weakSelf updateLayoutAnimated:YES];
    }],
        [QMUIInteractiveDebugPanelItem boolItemWithTitle:@"显示 item 分隔线" valueGetter:^(UISwitch * _Nonnull actionView) {
        actionView.on = weakMenu.shouldShowItemSeparator;
    } valueSetter:^(UISwitch * _Nonnull actionView) {
        weakMenu.shouldShowItemSeparator = actionView.on;
    }],
        [QMUIInteractiveDebugPanelItem boolItemWithTitle:@"分段" valueGetter:^(UISwitch * _Nonnull actionView) {
        actionView.on = weakSelf.shouldShowMultipleSections;
    } valueSetter:^(UISwitch * _Nonnull actionView) {
        weakSelf.shouldShowMultipleSections = actionView.on;
        [weakSelf updateLayoutAnimated:YES];
    }],
        [QMUIInteractiveDebugPanelItem boolItemWithTitle:@"显示分段分隔线" valueGetter:^(UISwitch * _Nonnull actionView) {
        actionView.on = weakMenu.shouldShowSectionSeparator;
    } valueSetter:^(UISwitch * _Nonnull actionView) {
        weakMenu.shouldShowSectionSeparator = actionView.on;
        [weakSelf updateLayoutAnimated:YES];
    }],
        [QMUIInteractiveDebugPanelItem numbericItemWithTitle:@"分段分隔大小" valueGetter:^(QMUITextField * _Nonnull actionView) {
        actionView.text = [NSString stringWithFormat:@"%.0f", weakMenu.sectionSpacing];
    } valueSetter:^(QMUITextField * _Nonnull actionView) {
        weakMenu.sectionSpacing = actionView.text.doubleValue;
        [weakSelf updateLayoutAnimated:YES];
    }],
        [QMUIInteractiveDebugPanelItem boolItemWithTitle:@"支持选中(默认单选)" valueGetter:^(UISwitch * _Nonnull actionView) {
        actionView.on = weakMenu.allowsSelection;
    } valueSetter:^(UISwitch * _Nonnull actionView) {
        weakMenu.allowsSelection = actionView.on;
        if (weakMenu.allowsSelection) {
            weakMenu.selectedItemIndex = 0;
        }
        if (!weakMenu.allowsSelection) {
            UISwitch *switcher = (UISwitch *)[weakSelf.debugViewController itemMatched:^BOOL(__kindof QMUIInteractiveDebugPanelItem * _Nonnull item) {
                return [item.title isEqualToString:@"多选"];
            }].actionView;
            switcher.on = NO;
        }
    }],
        [QMUIInteractiveDebugPanelItem boolItemWithTitle:@"多选" valueGetter:^(UISwitch * _Nonnull actionView) {
        actionView.on = weakMenu.allowsMultipleSelection;
    } valueSetter:^(UISwitch * _Nonnull actionView) {
        weakMenu.allowsMultipleSelection = actionView.on;
        if (weakMenu.allowsMultipleSelection) {
            weakMenu.selectedItemIndexPaths = @[
                [NSIndexPath indexPathForRow:0 inSection:0],
                [NSIndexPath indexPathForRow:1 inSection:0],
            ];
        }
        UISwitch *switcher = (UISwitch *)[weakSelf.debugViewController itemMatched:^BOOL(__kindof QMUIInteractiveDebugPanelItem * _Nonnull item) {
            return [item.title isEqualToString:@"支持选中(默认单选)"];
        }].actionView;
        switcher.on = weakMenu.allowsSelection;
    }],
        [QMUIInteractiveDebugPanelItem boolItemWithTitle:@"指定 item 不支持选中" valueGetter:^(UISwitch * _Nonnull actionView) {
        actionView.on = !!weakMenu.shouldSelectItemBlock;
    } valueSetter:^(UISwitch * _Nonnull actionView) {
        if (actionView.on) {
            weakMenu.shouldSelectItemBlock = ^BOOL(__kindof QMUIPopupMenuItem * _Nonnull aItem, __kindof UIControl<QMUIPopupMenuItemViewProtocol> * _Nonnull aItemView, NSInteger section, NSInteger index) {
                return section != 0 || index != 0;// 第一个 item 不支持选中
            };
            if ([weakMenu.selectedItemIndexPaths containsObject:[NSIndexPath indexPathForRow:0 inSection:0]]) {
                NSMutableArray *indexPaths = weakMenu.selectedItemIndexPaths.mutableCopy;
                [indexPaths removeObject:[NSIndexPath indexPathForRow:0 inSection:0]];
                weakMenu.selectedItemIndexPaths = indexPaths.copy;
            }
        } else {
            weakMenu.shouldSelectItemBlock = nil;
        }
        [weakSelf updateMenu];
    }],
        [QMUIInteractiveDebugPanelItem enumItemWithTitle:@"选中样式" items:@[@"Checkmark", @"Checkbox"] valueGetter:^(QMUIButton * _Nonnull actionView, NSArray<NSString *> * _Nonnull items) {
        [actionView setTitle:items[weakMenu.selectedStyle] forState:UIControlStateNormal];
    } valueSetter:^(QMUIButton * _Nonnull actionView, NSArray<NSString *> * _Nonnull items) {
        NSInteger index = [items indexOfObject:actionView.currentTitle];
        weakMenu.selectedStyle = index;
    }],
        [QMUIInteractiveDebugPanelItem enumItemWithTitle:@"选中布局" items:@[@"AtEnd", @"AtStart"] valueGetter:^(QMUIButton * _Nonnull actionView, NSArray<NSString *> * _Nonnull items) {
        [actionView setTitle:items[weakMenu.selectedLayout] forState:UIControlStateNormal];
    } valueSetter:^(QMUIButton * _Nonnull actionView, NSArray<NSString *> * _Nonnull items) {
        NSInteger index = [items indexOfObject:actionView.currentTitle];
        weakMenu.selectedLayout = index;
    }],
        [QMUIInteractiveDebugPanelItem boolItemWithTitle:@"宽度自适应内容" valueGetter:^(UISwitch * _Nonnull actionView) {
        actionView.on = weakMenu.adjustsWidthAutomatically;
    } valueSetter:^(UISwitch * _Nonnull actionView) {
        weakMenu.adjustsWidthAutomatically = actionView.on;
        [weakSelf updateLayoutAnimated:YES];
    }],
        [QMUIInteractiveDebugPanelItem numbericItemWithTitle:@"最小宽度" valueGetter:^(QMUITextField * _Nonnull actionView) {
        actionView.text = [NSString stringWithFormat:@"%.0f", weakMenu.minimumWidth];
    } valueSetter:^(QMUITextField * _Nonnull actionView) {
        weakMenu.minimumWidth = actionView.text.doubleValue;
    }],
        [QMUIInteractiveDebugPanelItem numbericItemWithTitle:@"最大宽度" valueGetter:^(QMUITextField * _Nonnull actionView) {
        actionView.text = weakMenu.maximumWidth == CGFLOAT_MAX ? @"CGFLOAT_MAX" : [NSString stringWithFormat:@"%.0f", weakMenu.maximumWidth];
    } valueSetter:^(QMUITextField * _Nonnull actionView) {
        weakMenu.maximumWidth = [actionView.text isEqualToString:@"CGFLOAT_MAX"] ? CGFLOAT_MAX : actionView.text.doubleValue;
    }],
        [QMUIInteractiveDebugPanelItem enumItemWithTitle:@"对齐目标位置" items:@[@"Center", @"Leading", @"Trailing"] valueGetter:^(QMUIButton * _Nonnull actionView, NSArray<NSString *> * _Nonnull items) {
        [actionView setTitle:items[weakMenu.preferLayoutAlignment] forState:UIControlStateNormal];
    } valueSetter:^(QMUIButton * _Nonnull actionView, NSArray<NSString *> * _Nonnull items) {
        QMUIPopupContainerViewLayoutAlignment alignment = (QMUIPopupContainerViewLayoutAlignment)[items indexOfObject:actionView.currentTitle];
        weakMenu.preferLayoutAlignment = alignment;
    }],
        [QMUIInteractiveDebugPanelItem boolItemWithTitle:@"显示底部附加 view" valueGetter:^(UISwitch * _Nonnull actionView) {
        actionView.on = !!weakMenu.bottomAccessoryView;
    } valueSetter:^(UISwitch * _Nonnull actionView) {
        if (actionView.on) {
            QMUIButton *button = [[QMUIButton alloc] qmui_initWithImage:[UIImageMake(@"icon_nav_about") imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] title:@"其他"];
            button.titleLabel.font = UIFontMake(16);
            button.qmui_contentInsets = UIEdgeInsetsMake(8, weakMenu.padding.left, 8, weakMenu.padding.right);
            button.contentHorizontalAlignment = UIControlContentHorizontalAlignmentLeft;
            button.spacingBetweenImageAndTitle = 12;
            button.highlightedBackgroundColor = TableViewCellSelectedBackgroundColor;
            button.adjustsTitleTintColorAutomatically = YES;
            button.tintColor = UIColorBlue;
            button.qmui_borderPosition = QMUIViewBorderPositionTop;
            button.qmui_tapBlock = ^(__kindof UIControl *sender) {
                [weakMenu hideWithAnimated:YES];
            };
            weakMenu.bottomAccessoryView = button;
        } else {
            weakMenu.bottomAccessoryView = nil;
        }
        [weakSelf updateLayoutAnimated:YES];
    }],
        [QMUIInteractiveDebugPanelItem boolItemWithTitle:@"测试大数据" valueGetter:^(UISwitch * _Nonnull actionView) {
        actionView.on = weakSelf.useBigData;
    } valueSetter:^(UISwitch * _Nonnull actionView) {
        weakSelf.useBigData = actionView.on;
        [weakSelf updateLayoutAnimated:YES];
    }],
    ]];
    [self.scrollView addSubview:self.debugViewController.view];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [self.menu showWithAnimated:NO];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.menu hideWithAnimated:NO];
}

- (void)handleButtonEvent:(QMUIButton *)button {
    if (self.menu.isShowing) {
        [self.menu hideWithAnimated:YES];
    } else {
        self.menu.sourceBarItem = nil;
        self.menu.sourceView = button;
        [self.menu showWithAnimated:YES];
    }
}

- (void)setShouldShowMultipleSections:(BOOL)shouldShowMultipleSections {
    _shouldShowMultipleSections = shouldShowMultipleSections;
    [self updateMenu];
}

- (void)setShouldShowSectionTitles:(BOOL)shouldShowSectionTitles {
    _shouldShowSectionTitles = shouldShowSectionTitles;
    if (shouldShowSectionTitles) {
        _shouldShowMultipleSections = YES;
    }
    [self updateMenu];
}

- (void)setUseBigData:(BOOL)useBigData {
    _useBigData = useBigData;
    [self updateMenu];
}

- (void)updateMenu {
    void (^handler)(__kindof QMUIPopupMenuItem * _Nonnull aItem, __kindof UIControl<QMUIPopupMenuItemViewProtocol> * _Nonnull aItemView, NSInteger section, NSInteger index) = ^void(__kindof QMUIPopupMenuItem * _Nonnull aItem, __kindof UIControl<QMUIPopupMenuItemViewProtocol> * _Nonnull aItemView, NSInteger section, NSInteger index) {
        if (!aItem.menuView.allowsSelection) {
            [aItem.menuView hideWithAnimated:YES];
        }
    };
    
    NSMutableArray *items = NSMutableArray.new;
    
    if (self.shouldShowMultipleSections) {
        // section0
        [items addObject:@[
            [QMUIPopupMenuItem itemWithImage:[UIImageMake(@"icon_tabbar_uikit") imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] title:self.menu.shouldSelectItemBlock ? @"我不可被选中" : @"选项0" handler:handler],
        ]];
        
        // section1
        NSMutableArray<QMUIPopupMenuItem *> *section1 = NSMutableArray.new;
        if (self.useBigData) {
            for (NSInteger i = 0; i < 200; i++) {
                [section1 addObject:[QMUIPopupMenuItem itemWithImage:[UIImageMake(@"icon_tabbar_component") imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] title:[NSString stringWithFormat:@"选项%@", @(i)] subtitle:i % 2 == 0 ? @"副标题" : nil handler:handler]];
            }
        } else {
            [section1 addObjectsFromArray:@[
                [QMUIPopupMenuItem itemWithImage:[UIImageMake(@"icon_tabbar_component") imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] title:@"选项0" handler:handler],
                [QMUIPopupMenuItem itemWithImage:[UIImageMake(@"icon_tabbar_lab") imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] title:@"选项1" subtitle:@"第二行文字" handler:handler],
            ]];
        }
        
        [items addObject:section1];
        self.menu.itemSections = items;
        self.menu.sectionTitles = @[
            @"标题",
            @"",// 不需要标题的 section 则用空字符串代替
        ];
    } else {
        if (self.useBigData) {
            for (NSInteger i = 0; i < 200; i++) {
                [items addObject:[QMUIPopupMenuItem itemWithImage:[UIImageMake(@"icon_tabbar_component") imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] title:(self.menu.shouldSelectItemBlock && i == 0) ? @"我不可被选中" : [NSString stringWithFormat:@"选项%@", @(i)] subtitle:i % 2 == 0 ? @"副标题" : nil handler:handler]];
            }
        } else {
            [items addObjectsFromArray:@[
                [QMUIPopupMenuItem itemWithImage:[UIImageMake(@"icon_tabbar_uikit") imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] title:self.menu.shouldSelectItemBlock ? @"我不可被选中" : @"选项0" handler:handler],
                [QMUIPopupMenuItem itemWithImage:[UIImageMake(@"icon_tabbar_component") imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] title:@"选项1" handler:handler],
                [QMUIPopupMenuItem itemWithImage:[UIImageMake(@"icon_tabbar_lab") imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate] title:@"选项2" subtitle:@"第二行文字" handler:handler],
            ]];
        }
        self.menu.items = items;
        self.menu.sectionTitles = nil;
    }
    [self updateLayoutAnimated:YES];
}

- (void)updateLayoutAnimated:(BOOL)animated {
    [UIView qmui_animateWithAnimated:animated duration:.25 delay:0 options:QMUIViewAnimationOptionsCurveOut animations:^{
        [self.view setNeedsLayout];
        [self.view layoutIfNeeded];
    } completion:nil];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.scrollView.frame = self.view.bounds;
    self.actionButton.qmui_left = self.actionButton.qmui_leftWhenCenterInSuperview;
    self.actionButton.qmui_top = 32;
    
    CGFloat y = self.actionButton.qmui_bottom + 24;
    if (self.menu.isShowing) {
        y = CGRectGetMaxY([self.menu qmui_convertRect:self.menu.bounds toView:self.scrollView]) + 24;
    }
    CGSize size = [self.debugViewController contentSizeThatFits:CGSizeMake(320, CGFLOAT_MAX)];
    self.debugViewController.view.frame = CGRectMake(CGFloatGetCenter(CGRectGetWidth(self.view.bounds), 320), y, 320, size.height);
    self.scrollView.contentSize = CGSizeMake(CGRectGetWidth(self.view.bounds), CGRectGetMaxY(self.debugViewController.view.frame) + 32);
}

@end
