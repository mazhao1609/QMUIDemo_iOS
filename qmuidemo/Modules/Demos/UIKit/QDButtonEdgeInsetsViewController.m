//
//  QDButtonEdgeInsetsViewController.m
//  qmuidemo
//
//  Created by QMUI Team on 2017/7/12.
//  Copyright © 2017年 QMUI Team. All rights reserved.
//

#import "QDButtonEdgeInsetsViewController.h"

const NSInteger TagForStaticSizeView = 111;
const CGSize SizeForStaticSizeView = {140, 60};

@interface QDButtonConfigurePopupView : QMUIPopupContainerView

@property(nonatomic, weak) UIButton *bindButton;
@end

@interface QDButtonEdgeInsetsViewController ()

@property(nonatomic, strong) UIScrollView *scrollView;
@property(nonatomic, strong) QDButtonConfigurePopupView *configurePopupView;
@end

@implementation QDButtonEdgeInsetsViewController

- (void)initSubviews {
    [super initSubviews];
    
    self.scrollView = [[UIScrollView alloc] initWithFrame:self.view.bounds];
    [self.view addSubview:self.scrollView];
    
    ({
        [self generateLabelWithTitle:@"sizeToFit，无内边距"];
        [self generateSystemButton];
        [self generateQMUIButton];
    });
    
    ({
        [self generateLabelWithTitle:@"sizeToFit\n左右内边距 8，图文间距 16\nUIButtonConfiguration / QMUIButton"];
        UIButton *systemButton = [self generateSystemButton];
        UIButtonConfiguration *configuration = systemButton.configuration;
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(0, 8, 0, 8);
        configuration.imagePadding = 16;
        systemButton.configuration = configuration;
        QMUIButton *qmuiButton = [self generateQMUIButton];
        [self copyButtonPropertyFromButton:systemButton toButton:qmuiButton];
    });
    
    ({
        [self generateLabelWithTitle:@"固定宽高\n左右内边距 8，图文间距 16\nUIButtonConfiguration / QMUIButton"];
        UIButton *systemButton = [self generateSystemButton];
        systemButton.tag = TagForStaticSizeView;
        UIButtonConfiguration *configuration = systemButton.configuration;
        configuration.contentInsets = NSDirectionalEdgeInsetsMake(0, 8, 0, 8);
        configuration.imagePadding = 16;
        systemButton.configuration = configuration;
        QMUIButton *qmuiButton = [self generateQMUIButton];
        [self copyButtonPropertyFromButton:systemButton toButton:qmuiButton];
    });
    
    self.configurePopupView = [[QDButtonConfigurePopupView alloc] init];
    self.configurePopupView.automaticallyHidesWhenUserTap = YES;
}

- (UIButton *)generateSystemButton {
    return [self generateButtonWithClass:[UIButton class]];
}

- (QMUIButton *)generateQMUIButton {
    return [self generateButtonWithClass:[QMUIButton class]];
}

- (__kindof UIButton *)generateButtonWithClass:(Class)buttonClass {
    UIButton *button = [[buttonClass alloc] init];
    UIImage *image = [UIImage qmui_imageWithColor:UIColorBlue size:CGSizeMake(20, 20) cornerRadius:0];
    if ([button isKindOfClass:QMUIButton.class]) {
        [button setTitle:@"短标题" forState:UIControlStateNormal];
        [button setImage:image forState:UIControlStateNormal];
        [button setTitleColor:UIColorWhite forState:UIControlStateNormal];
        button.titleLabel.font = UIFontMake(18);
    }
    button.backgroundColor = UIColorTestRed;
    button.imageView.layer.borderWidth = PixelOne;
    button.imageView.layer.borderColor = UIColorTestBlue.CGColor;
    button.titleLabel.layer.borderWidth = PixelOne;
    button.titleLabel.layer.borderColor = UIColorRed.CGColor;
    if (![button isKindOfClass:QMUIButton.class]) {
        // 系统按钮使用现代配置；QMUIButton 继续使用自定义布局以支持副标题等能力。
        UIButtonConfiguration *configuration = UIButtonConfiguration.plainButtonConfiguration;
        configuration.contentInsets = NSDirectionalEdgeInsetsZero;
        configuration.imagePadding = 0;
        configuration.title = @"短标题";
        configuration.image = image;
        configuration.baseForegroundColor = UIColorWhite;
        configuration.titleTextAttributesTransformer = ^NSDictionary<NSAttributedStringKey, id> *(NSDictionary<NSAttributedStringKey, id> *attributes) {
            NSMutableDictionary *result = attributes.mutableCopy;
            result[NSFontAttributeName] = UIFontMake(18);
            return result;
        };
        button.configuration = configuration;
    }
    [button addTarget:self action:@selector(handleButtonEvent:) forControlEvents:UIControlEventTouchUpInside];
    [self.scrollView addSubview:button];
    if ([button isKindOfClass:QMUIButton.class]) {
        QMUIButton *b = (QMUIButton *)button;
        b.subtitleLabel.font = UIFontMake(14);
        b.subtitleLabel.textColor = UIColorWhite;
        b.subtitleLabel.layer.borderWidth = PixelOne;
        b.subtitleLabel.layer.borderColor = UIColorRed.CGColor;
    }
    return button;
}

- (void)copyButtonPropertyFromButton:(UIButton *)fromButton toButton:(QMUIButton *)toButton {
    toButton.tag = fromButton.tag;
    // 将系统配置映射到 QMUI 的布局属性，不再读写 UIButton 的弃用内边距。
    NSDirectionalEdgeInsets insets = fromButton.configuration.contentInsets;
    BOOL isRTL = fromButton.effectiveUserInterfaceLayoutDirection == UIUserInterfaceLayoutDirectionRightToLeft;
    toButton.qmui_contentInsets = UIEdgeInsetsMake(insets.top, isRTL ? insets.trailing : insets.leading, insets.bottom, isRTL ? insets.leading : insets.trailing);
    toButton.spacingBetweenImageAndTitle = fromButton.configuration.imagePadding;
}

- (UILabel *)generateLabelWithTitle:(NSString *)title {
    UILabel *label = [[UILabel alloc] qmui_initWithFont:UIFontMake(14) textColor:UIColor.qd_mainTextColor];
    label.numberOfLines = 0;
    label.qmui_lineHeight = 20;
    label.text = title;
    [self.scrollView addSubview:label];
    return label;
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.scrollView.frame = self.view.bounds;
    
    CGFloat paddingLeft = 24;
    CGFloat minY = 0;
    for (NSInteger i = 0; i < self.scrollView.subviews.count; i++) {
        UIView *subview = self.scrollView.subviews[i];
        if (subview.tag == TagForStaticSizeView) {
            subview.frame = CGRectSetSize(subview.frame, SizeForStaticSizeView);
        } else {
            [subview sizeToFit];
        }
        if (i % 3 == 0) {
            subview.frame = CGRectSetXY(subview.frame, paddingLeft, minY + 24);
            minY = CGRectGetMaxY(subview.frame);
        } else if (i % 3 == 1) {
            subview.frame = CGRectSetXY(subview.frame, paddingLeft, minY + 10);
        } else if (i % 3 == 2) {
            UIView *leftView = self.scrollView.subviews[i - 1];
            subview.frame = CGRectSetXY(subview.frame, CGRectGetMaxX(leftView.frame) + 24, CGRectGetMinY(leftView.frame));
            minY = CGRectGetMaxY(subview.frame);
        }
    }
    
    self.scrollView.contentSize = CGSizeMake(CGRectGetWidth(self.view.bounds), minY);
}

- (void)setupNavigationItems {
    [super setupNavigationItems];
    self.title = @"Button EdgeInsets Testing";
    if (self.qmui_isPresented) {
        self.navigationItem.leftBarButtonItem = [UIBarButtonItem qmui_closeItemWithTarget:self action:@selector(handleCloseItemEvent)];
    }
}

- (void)handleCloseItemEvent {
    [self dismissViewControllerAnimated:YES completion:NULL];
}

- (void)handleButtonEvent:(UIButton *)button {
    self.configurePopupView.bindButton = button;
    self.configurePopupView.sourceView = button;
    [self.configurePopupView showWithAnimated:YES];
}

#pragma mark - <QMUINavigationControllerDelegate>

- (UIImage *)qmui_navigationBarBackgroundImage {
    // debug warning
    return [UIImage qmui_imageWithColor:UIColorMake(232, 46, 46)];
}

@end

@implementation QDButtonConfigurePopupView {
    UILabel *_shouldShowImageLabel;
    UISwitch *_shouldShowImageSwitch;
    CALayer *_shouldShowImageSeparatorLayer;
    
    UILabel *_shouldShowTitleLabel;
    UISwitch *_shouldShowTitleSwitch;
    CALayer *_shouldShowTitleSeparatorLayer;
    
    UILabel *_shouldShowSubtitleLabel;
    UISwitch *_shouldShowSubtitleSwitch;
    CALayer *_shouldShowSubtitleSeparatorLayer;
    
    UILabel *_bigImageLabel;
    UISwitch *_bigImageSwitch;
    CALayer *_bigImageSeparatorLayer;
    
    UILabel *_longTitleLabel;
    UISwitch *_longTitleSwitch;
    CALayer *_longTitleSeparatorLayer;
    
    UILabel *_imagePositionLabel;
    UISegmentedControl *_imagePositionSegmented;
    CALayer *_imagePositionSeparatorLayer;
    
    UILabel *_horizontalAlignmentLabel;
    UISegmentedControl *_horizontalAlignmentSegmented;
    CALayer *_horizontalAlignmentSeparatorLayer;
    
    UILabel *_verticalAlignmentLabel;
    UISegmentedControl *_verticalAlignmentSegmented;
    CALayer *_verticalAlignmentSeparatorLayer;
}

- (void)didInitialize {
    [super didInitialize];
    
    self.contentEdgeInsets = UIEdgeInsetsSetTop(self.contentEdgeInsets, 0);
    
    // 是否要显示图片
    _shouldShowImageLabel = [self generateLabelWithText:@"setImage"];
    _shouldShowImageSwitch = [self generateSwitch];
    _shouldShowImageSeparatorLayer = [CALayer qmui_separatorLayer];
    [self.contentView.layer addSublayer:_shouldShowImageSeparatorLayer];
    
    // 是否要显示标题
    _shouldShowTitleLabel = [self generateLabelWithText:@"setTitle"];
    _shouldShowTitleSwitch = [self generateSwitch];
    _shouldShowTitleSeparatorLayer = [CALayer qmui_separatorLayer];
    [self.contentView.layer addSublayer:_shouldShowTitleSeparatorLayer];
    
    // 是否要显示副标题
    _shouldShowSubtitleLabel = [self generateLabelWithText:@"setSubtitle"];
    _shouldShowSubtitleSwitch = [self generateSwitch];
    _shouldShowSubtitleSeparatorLayer = [CALayer qmui_separatorLayer];
    [self.contentView.layer addSublayer:_shouldShowSubtitleSeparatorLayer];
    
    // 是否要显示超大图片
    _bigImageLabel = [self generateLabelWithText:@"bigImage"];
    _bigImageSwitch = [self generateSwitch];
    _bigImageSeparatorLayer = [CALayer qmui_separatorLayer];
    [self.contentView.layer addSublayer:_bigImageSeparatorLayer];
    
    // 是否要显示超长标题
    _longTitleLabel = [self generateLabelWithText:@"longTitle"];
    _longTitleSwitch = [self generateSwitch];
    _longTitleSeparatorLayer = [CALayer qmui_separatorLayer];
    [self.contentView.layer addSublayer:_longTitleSeparatorLayer];
    
    // 改变图片的位置（仅对 QMUIButton 生效）
    _imagePositionLabel = [self generateLabelWithText:@"imagePosition"];
    _imagePositionSegmented = [self generateSegmentedWithItems:@[@"Top", @"Left", @"Bottom", @"Right"]];
    _imagePositionSeparatorLayer = [CALayer qmui_separatorLayer];
    [self.contentView.layer addSublayer:_imagePositionSeparatorLayer];
    
    // 内容的水平对齐方式
    _horizontalAlignmentLabel = [self generateLabelWithText:@"horizontal"];
    _horizontalAlignmentSegmented = [self generateSegmentedWithItems:@[@"Center", @"Left", @"Right", @"Fill"]];
    _horizontalAlignmentSeparatorLayer = [CALayer qmui_separatorLayer];
    [self.contentView.layer addSublayer:_horizontalAlignmentSeparatorLayer];
    
    // 内容的垂直对齐方式
    _verticalAlignmentLabel = [self generateLabelWithText:@"vertical"];
    _verticalAlignmentSegmented = [self generateSegmentedWithItems:@[@"Center", @"Top", @"Bottom", @"Fill"]];
    _verticalAlignmentSeparatorLayer = [CALayer qmui_separatorLayer];
    [self.contentView.layer addSublayer:_verticalAlignmentSeparatorLayer];
}

- (CGSize)sizeThatFitsInContentView:(CGSize)size {
    NSInteger rowCount = 8;
    return CGSizeMake(size.width, (45 + PixelOne * 2) * rowCount);
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    CGFloat minY = 14;
    CGPoint switchCenter = CGPointMake(flat(CGRectGetWidth(self.contentView.bounds) - CGRectGetWidth(_shouldShowImageSwitch.frame) / 2), 0);
    
    _shouldShowImageLabel.frame = CGRectSetY(_shouldShowImageLabel.frame, minY);
    _shouldShowImageSwitch.center = CGPointMake(switchCenter.x, _shouldShowImageLabel.center.y);
    _shouldShowImageSeparatorLayer.frame = CGRectMake(0, CGRectGetMaxY(_shouldShowImageLabel.frame) + 14, CGRectGetWidth(self.contentView.bounds), PixelOne);
    minY = ceil(CGRectGetMaxY(_shouldShowImageSeparatorLayer.frame));
    
    _shouldShowTitleLabel.frame = CGRectSetY(_shouldShowTitleLabel.frame, minY + 14);
    _shouldShowTitleSwitch.center = CGPointMake(switchCenter.x, _shouldShowTitleLabel.center.y);
    _shouldShowTitleSeparatorLayer.frame = CGRectSetY(_shouldShowImageSeparatorLayer.frame, CGRectGetMaxY(_shouldShowTitleLabel.frame) + 14);
    minY = ceil(CGRectGetMaxY(_shouldShowTitleSeparatorLayer.frame));
    
    _shouldShowSubtitleLabel.frame = CGRectSetY(_shouldShowSubtitleLabel.frame, minY + 14);
    _shouldShowSubtitleSwitch.center = CGPointMake(switchCenter.x, _shouldShowSubtitleLabel.center.y);
    _shouldShowSubtitleSeparatorLayer.frame = CGRectSetY(_shouldShowImageSeparatorLayer.frame, CGRectGetMaxY(_shouldShowSubtitleLabel.frame) + 14);
    minY = ceil(CGRectGetMaxY(_shouldShowSubtitleSeparatorLayer.frame));
    
    _bigImageLabel.frame = CGRectSetY(_bigImageLabel.frame, minY + 14);
    _bigImageSwitch.center = CGPointMake(switchCenter.x, _bigImageLabel.center.y);
    _bigImageSeparatorLayer.frame = CGRectSetY(_shouldShowImageSeparatorLayer.frame, CGRectGetMaxY(_bigImageLabel.frame) + 14);
    minY = ceil(CGRectGetMaxY(_bigImageSeparatorLayer.frame));
    
    _longTitleLabel.frame = CGRectSetY(_longTitleLabel.frame, minY + 14);
    _longTitleSwitch.center = CGPointMake(switchCenter.x, _longTitleLabel.center.y);
    _longTitleSeparatorLayer.frame = CGRectSetY(_shouldShowImageSeparatorLayer.frame, CGRectGetMaxY(_longTitleLabel.frame) + 14);
    minY = ceil(CGRectGetMaxY(_longTitleSeparatorLayer.frame));
    
    _imagePositionLabel.frame = CGRectSetY(_imagePositionLabel.frame, minY + 14);
    _imagePositionSegmented.center = CGPointMake(flat(CGRectGetWidth(self.contentView.bounds) - CGRectGetWidth(_imagePositionSegmented.frame) / 2), _imagePositionLabel.center.y);
    _imagePositionSeparatorLayer.frame = CGRectSetY(_shouldShowImageSeparatorLayer.frame, CGRectGetMaxY(_imagePositionLabel.frame) + 14);
    minY = ceil(CGRectGetMaxY(_imagePositionSeparatorLayer.frame));
    
    _horizontalAlignmentLabel.frame = CGRectSetY(_horizontalAlignmentLabel.frame, minY + 14);
    _horizontalAlignmentSegmented.center = CGPointMake(flat(CGRectGetWidth(self.contentView.bounds) - CGRectGetWidth(_horizontalAlignmentSegmented.frame) / 2), _horizontalAlignmentLabel.center.y);
    _horizontalAlignmentSeparatorLayer.frame = CGRectSetY(_shouldShowImageSeparatorLayer.frame, CGRectGetMaxY(_horizontalAlignmentLabel.frame) + 14);
    minY = ceil(CGRectGetMaxY(_horizontalAlignmentSeparatorLayer.frame));
    
    _verticalAlignmentLabel.frame = CGRectSetY(_verticalAlignmentLabel.frame, minY + 14);
    _verticalAlignmentSegmented.center = CGPointMake(flat(CGRectGetWidth(self.contentView.bounds) - CGRectGetWidth(_verticalAlignmentSegmented.frame) / 2), _verticalAlignmentLabel.center.y);
    _verticalAlignmentSeparatorLayer.frame = CGRectSetY(_shouldShowImageSeparatorLayer.frame, CGRectGetMaxY(_verticalAlignmentLabel.frame) + 14);
    minY = ceil(CGRectGetMaxY(_verticalAlignmentSeparatorLayer.frame));
}

- (UILabel *)generateLabelWithText:(NSString *)text {
    UILabel *label = [[UILabel alloc] qmui_initWithFont:UIFontMake(14) textColor:UIColor.qd_mainTextColor];
    label.text = text;
    [label sizeToFit];
    [self.contentView addSubview:label];
    return label;
}

- (UISwitch *)generateSwitch {
    UISwitch *switchControl = [[UISwitch alloc] init];
    [switchControl sizeToFit];
    switchControl.transform = CGAffineTransformMakeScale(.7, .7);
    [switchControl addTarget:self action:@selector(handleSwitchControlEvent:) forControlEvents:UIControlEventValueChanged];
    [self.contentView addSubview:switchControl];
    return switchControl;
}

- (UISegmentedControl *)generateSegmentedWithItems:(NSArray<NSString *> *)items {
    UISegmentedControl *segmentedControl = [[UISegmentedControl alloc] initWithItems:items];
    segmentedControl.tintColor = UIColor.qd_tintColor;
    segmentedControl.frame = CGRectSetWidth(segmentedControl.frame, 240);// 统一按照最长的来就行啦
    segmentedControl.transform = CGAffineTransformMakeScale(.8, .8);
    [segmentedControl addTarget:self action:@selector(handleSegmentedControlEvent:) forControlEvents:UIControlEventValueChanged];
    [self.contentView addSubview:segmentedControl];
    return segmentedControl;
}

- (void)setBindButton:(UIButton *)bindButton {
    _bindButton = bindButton;
    // 配置按钮直接读取 configuration，避免与旧 state 存储的图片、标题不同步。
    UIImage *image = bindButton.configuration ? bindButton.configuration.image : bindButton.currentImage;
    NSString *title = bindButton.configuration ? bindButton.configuration.title : bindButton.currentTitle;
    _shouldShowImageSwitch.on = !!image;
    _shouldShowTitleSwitch.on = !!title;
    _shouldShowSubtitleSwitch.enabled = [bindButton isKindOfClass:QMUIButton.class];
    _shouldShowSubtitleSwitch.on = _shouldShowSubtitleSwitch.enabled && ((QMUIButton *)bindButton).subtitle.length;
    _bigImageSwitch.on = image.size.width >= 80;
    _longTitleSwitch.on = title.length >= 20;
    _imagePositionSegmented.enabled = [bindButton isKindOfClass:[QMUIButton class]];
    _imagePositionSegmented.selectedSegmentIndex = [bindButton isKindOfClass:[QMUIButton class]] ? ((QMUIButton *)bindButton).imagePosition : -1;
    _horizontalAlignmentSegmented.selectedSegmentIndex = bindButton.contentHorizontalAlignment;
    _verticalAlignmentSegmented.selectedSegmentIndex = bindButton.contentVerticalAlignment;
}

- (void)handleSwitchControlEvent:(UISwitch *)switchControl {
    if (switchControl == _shouldShowImageSwitch || switchControl == _bigImageSwitch) {
        [self updateImageForButton:self.bindButton shouldShowImage:_shouldShowImageSwitch.on shouldShowBigImage:_bigImageSwitch.on];
    }
    if (switchControl == _shouldShowTitleSwitch || switchControl == _longTitleSwitch) {
        [self updateTitleForButton:self.bindButton shouldShowTitle:_shouldShowTitleSwitch.on shouldShowLongTitle:_longTitleSwitch.on];
    }
    if (switchControl == _shouldShowSubtitleSwitch || switchControl == _longTitleSwitch) {
        if ([self.bindButton isKindOfClass:QMUIButton.class]) {
            [self updateSubtitleForButton:(QMUIButton *)self.bindButton shouldShowSubtitle:_shouldShowSubtitleSwitch.on shouldShowLongTitle:_longTitleSwitch.on];
        }
    }
    
    [self updateLayoutForButton:self.bindButton];
}

- (void)handleSegmentedControlEvent:(UISegmentedControl *)segmentedControl {
    if (segmentedControl == _imagePositionSegmented) {
        ((QMUIButton *)self.bindButton).imagePosition = segmentedControl.selectedSegmentIndex;
    } else if (segmentedControl == _horizontalAlignmentSegmented) {
        self.bindButton.contentHorizontalAlignment = segmentedControl.selectedSegmentIndex;
    } else if (segmentedControl == _verticalAlignmentSegmented) {
        self.bindButton.contentVerticalAlignment = segmentedControl.selectedSegmentIndex;
    }
    
    [self updateLayoutForButton:self.bindButton];
}

- (void)updateImageForButton:(UIButton *)button shouldShowImage:(BOOL)shouldShowImage shouldShowBigImage:(BOOL)shouldShowBigImage {
    UIImage *image = shouldShowImage ? [UIImage qmui_imageWithColor:UIColorBlue size:shouldShowBigImage ? CGSizeMake(80, 80) : CGSizeMake(20, 20) cornerRadius:0] : nil;
    if (button.configuration) {
        // 更新配置对象后重新赋值，让 UIKit 同步刷新图片。
        UIButtonConfiguration *configuration = button.configuration;
        configuration.image = image;
        button.configuration = configuration;
        return;
    }
    [button setImage:image forState:UIControlStateNormal];
}

- (void)updateTitleForButton:(UIButton *)button shouldShowTitle:(BOOL)shouldShowTitle shouldShowLongTitle:(BOOL)shouldShowLongTitle {
    NSString *title = shouldShowTitle ? (shouldShowLongTitle ? @"很长很长的标题很长很长的标题很长很长的标题" : @"短标题") : nil;
    if (button.configuration) {
        UIButtonConfiguration *configuration = button.configuration;
        configuration.title = title;
        button.configuration = configuration;
        return;
    }
    [button setTitle:title forState:UIControlStateNormal];
}

- (void)updateSubtitleForButton:(QMUIButton *)button shouldShowSubtitle:(BOOL)shouldShowSubtitle shouldShowLongTitle:(BOOL)shouldShowLongTitle {
    if (!shouldShowSubtitle) {
        button.subtitle = nil;
    } else {
        NSString *subtitle = shouldShowLongTitle ? @"很长很长的标题很长很长的标题很长很长的副标题" : @"副标题";
        button.subtitle = subtitle;
    }
}

- (void)updateLayoutForButton:(UIButton *)button {
    if (button.tag != TagForStaticSizeView) {
        [button sizeToFit];
    }
    [button setNeedsLayout];
}

@end
