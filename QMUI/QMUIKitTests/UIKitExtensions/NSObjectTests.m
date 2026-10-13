/**
 * Tencent is pleased to support the open source community by making QMUI_iOS available.
 * Copyright (C) 2016-2021 THL A29 Limited, a Tencent company. All rights reserved.
 * Licensed under the MIT License (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 * http://opensource.org/licenses/MIT
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
 */
//
//  NSObject.m
//  QMUIKitTests
//
//  Created by MoLice on 2019/J/5.  
//

#import <XCTest/XCTest.h>
#import <QMUIKit/QMUIKit.h>
#import <UIKit/UIGestureRecognizerSubclass.h>

/// 通过内部手势的判定方法验证规则，不依赖 UIKit 私有手势类或伪造触摸事件。
@protocol QMUIContentPopProtectionTesting <NSObject>
- (BOOL)qmuinc_shouldProtectTouchInView:(UIView *)view;
@end

@protocol QMUIBackGestureTesting <UIGestureRecognizerDelegate>
@property(nonatomic, strong) UIScreenEdgePanGestureRecognizer *edgeGestureRecognizer;
@property(nonatomic, strong) UIPanGestureRecognizer *contentGestureRecognizer;
@property(nonatomic, weak) UIGestureRecognizer *protectedEdgeGestureRecognizer;
@property(nonatomic, weak) UIGestureRecognizer *protectedContentGestureRecognizer;
@property(nonatomic, weak) UITouch *edgeTouch;
@property(nonatomic, weak) UITouch *contentTouch;
- (BOOL)qmuinc_shouldBlockPopForTranslation:(CGPoint)translation touch:(UITouch *)touch;
@end

@interface UINavigationController (QMUIBackGestureTesting)
@property(nonatomic, readonly) id<QMUIBackGestureTesting> qmuinc_backGestureDelegator;
@end

/// 记录业务确认次数，验证返回拒绝、放行及手动 pop 的边界。
@interface QMUIBackGestureTestViewController : UIViewController
@property(nonatomic, assign) BOOL allowsPop;
@property(nonatomic, assign) NSUInteger popCheckCount;
@end
@implementation QMUIBackGestureTestViewController
- (BOOL)shouldPopViewControllerByBackButtonOrPopGesture:(BOOL)byPopGesture {
    XCTAssertTrue(byPopGesture);
    self.popCheckCount++;
    return self.allowsPop;
}
@end

/// 仅模拟触摸的起点视图；不冒充 UIKit 的真实识别或转场过程。
@interface QMUIBackGestureTestTouch : UITouch
@property(nonatomic, strong) UIView *touchedView;
@end
@implementation QMUIBackGestureTestTouch
- (UIView *)view {
    return self.touchedView;
}
@end

/// 系统许可始终为 YES，以确保业务 NO 能在边缘代理处直接阻止返回。
@interface QMUIBackGestureOriginalDelegate : NSObject <UIGestureRecognizerDelegate>
@property(nonatomic, assign) NSUInteger beginCount;
@end
@implementation QMUIBackGestureOriginalDelegate
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    self.beginCount++;
    return YES;
}
@end

/// 区分按钮和手势来源，避免无玻璃返回按钮绕过业务否决。
@interface QMUIPlainBackTestViewController : UIViewController
@property(nonatomic, assign) BOOL allowsPop;
@property(nonatomic, assign) BOOL lastByGesture;
@property(nonatomic, assign) NSUInteger popCheckCount;
@end
@implementation QMUIPlainBackTestViewController
- (BOOL)shouldPopViewControllerByBackButtonOrPopGesture:(BOOL)byPopGesture {
    self.popCheckCount++;
    self.lastByGesture = byPopGesture;
    return self.allowsPop;
}
@end

@interface QMUIPlainBackDenyGestureDelegate : QMUIBackGestureOriginalDelegate
@end
@implementation QMUIPlainBackDenyGestureDelegate
- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer { return NO; }
@end

/// 用项目子类限定开关范围，验证普通系统导航控制器不会被一起修改。
@interface QMUILegacyButtonTestNavigationController : UINavigationController
@end
@implementation QMUILegacyButtonTestNavigationController
@end

/// 模拟业务在返回箭头旁增加徽标的子类，导航栏需尊重完整尺寸。
@interface QMUILegacyDecoratedBackTestButton : QMUINavigationButton
@end
@implementation QMUILegacyDecoratedBackTestButton
- (CGSize)intrinsicContentSize { return CGSizeMake(75, 32); }
- (CGSize)sizeThatFits:(CGSize)size { return self.intrinsicContentSize; }
@end

@interface QMUILegacyButtonRootTestViewController : UIViewController
@property(nonatomic, assign) BOOL unexpectedBackWhileAppearing;
@end
@implementation QMUILegacyButtonRootTestViewController
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    if (self.navigationController.qmui_rootViewController == self && self.navigationItem.leftBarButtonItem) self.unexpectedBackWhileAppearing = YES;
}
@end

/// 回归用导航栏：访问旧版私有路径时主动失败，确保新实现无需 KVC。
@interface QMUINoPrivateProviderNavigationBar : UINavigationBar
@end
@implementation QMUINoPrivateProviderNavigationBar
- (id)valueForKeyPath:(NSString *)keyPath {
    if ([keyPath isEqualToString:@"visualProvider.contentView"]) {
        [NSException raise:NSUndefinedKeyException format:@"系统已移除旧版导航栏路径"];
    }
    return [super valueForKeyPath:keyPath];
}
@end

/// 模拟 UIKit 不再通过三参数重载更新导航栏背景图的情况。
@interface QMUINoBackgroundImageForwardingNavigationBar : UINavigationBar
@end
@implementation QMUINoBackgroundImageForwardingNavigationBar
- (void)setBackgroundImage:(UIImage *)backgroundImage forBarPosition:(UIBarPosition)barPosition barMetrics:(UIBarMetrics)barMetrics {
}
@end

/// 只模拟观察器输入和协调器的公开回调，不代表真实触摸识别。
@interface QMUIInteractivePopTestGestureRecognizer : UIGestureRecognizer
@property(nonatomic, assign) UIGestureRecognizerState testState;
@end
@implementation QMUIInteractivePopTestGestureRecognizer
- (UIGestureRecognizerState)state {
    return self.testState;
}
@end

@interface QMUIInteractivePopTestCoordinator : NSObject
@property(nonatomic, assign) BOOL initiallyInteractive;
@property(nonatomic, assign, getter=isInteractive) BOOL interactive;
@property(nonatomic, assign, getter=isCancelled) BOOL cancelled;
@property(nonatomic, strong) UIViewController *from;
@property(nonatomic, strong) UIViewController *to;
@property(nonatomic, copy) void (^interactionChange)(id<UIViewControllerTransitionCoordinatorContext>);
@end
@implementation QMUIInteractivePopTestCoordinator
- (UIViewController *)viewControllerForKey:(UITransitionContextViewControllerKey)key {
    return [key isEqualToString:UITransitionContextFromViewControllerKey] ? self.from : self.to;
}
- (void)notifyWhenInteractionChangesUsingBlock:(void (^)(id<UIViewControllerTransitionCoordinatorContext>))handler {
    self.interactionChange = handler;
}
@end

@interface QMUINavigationController (QMUIInteractivePopTesting)
- (void)handleInteractivePopGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer;
@end

@interface QMUIInteractivePopTestNavigationController : QMUINavigationController
@property(nonatomic, strong) QMUIInteractivePopTestCoordinator *testCoordinator;
@end
@implementation QMUIInteractivePopTestNavigationController
- (id<UIViewControllerTransitionCoordinator>)transitionCoordinator {
    return (id)self.testCoordinator;
}
@end

@interface QMUIInteractivePopTestViewController : UIViewController <QMUINavigationControllerTransitionDelegate>
@property(nonatomic, assign) NSUInteger callbackCount;
@property(nonatomic, assign) BOOL lastCancelled;
@property(nonatomic, weak) UIViewController *lastFrom;
@property(nonatomic, weak) UIViewController *lastTo;
@end
@implementation QMUIInteractivePopTestViewController
- (void)navigationController:(QMUINavigationController *)navigationController poppingByInteractiveGestureRecognizer:(UIGestureRecognizer *)gestureRecognizer isCancelled:(BOOL)isCancelled viewControllerWillDisappear:(UIViewController *)from viewControllerWillAppear:(UIViewController *)to {
    self.callbackCount++;
    self.lastCancelled = isCancelled;
    self.lastFrom = from;
    self.lastTo = to;
}
@end

/// 两页返回不同样式，检查转场前准备及后续修改的页面隔离。
@interface QMUINavigationStyleTestViewController : UIViewController <QMUINavigationControllerDelegate>
@property(nonatomic, strong) UIImage *styleImage;
@property(nonatomic, strong) UIColor *styleBackgroundColor;
@property(nonatomic, strong) UIColor *styleForegroundColor;
@property(nonatomic, copy) NSString *styleTransitionKey;
@end
@implementation QMUINavigationStyleTestViewController
- (UIImage *)qmui_navigationBarBackgroundImage { return self.styleImage; }
- (UIColor *)qmui_navigationBarBarTintColor { return self.styleBackgroundColor; }
- (UIBarStyle)qmui_navigationBarStyle { return UIBarStyleDefault; }
- (UIImage *)qmui_navigationBarShadowImage { return nil; }
- (UIColor *)qmui_titleViewTintColor { return self.styleForegroundColor; }
- (UIColor *)qmui_navigationBarTintColor { return self.styleForegroundColor; }
- (NSString *)customNavigationBarTransitionKey { return self.styleTransitionKey; }
@end

@interface QMUITitleOnlyNavigationStyleTestViewController : UIViewController <QMUINavigationControllerAppearanceDelegate>
@end
@implementation QMUITitleOnlyNavigationStyleTestViewController
- (UIColor *)qmui_titleViewTintColor { return UIColor.redColor; }
@end

/// 收集真实转场中的布局结果，防止先用错误占位、结束后才纠正。
@interface QMUINavigationMaxYTestViewController : QMUICommonViewController
@property(nonatomic, assign) BOOL barHidden;
@property(nonatomic, strong) NSMutableArray<NSNumber *> *layoutPositions;
@end
@implementation QMUINavigationMaxYTestViewController
- (BOOL)shouldCustomizeNavigationBarTransitionIfHideable { return YES; }
- (BOOL)preferredNavigationBarHidden { return self.barHidden; }
- (void)viewWillAppear:(BOOL)animated { [super viewWillAppear:animated]; [self.view setNeedsLayout]; }
- (void)viewWillDisappear:(BOOL)animated { [super viewWillDisappear:animated]; [self.view setNeedsLayout]; }
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    [self.layoutPositions addObject:@(self.qmui_navigationBarMaxYInViewCoordinator)];
}
@end

@interface UIViewController (QMUINavigationStyleTesting)
- (void)renderNavigationBarStyleAnimated:(BOOL)animated;
- (void)qmuinb_updateNavigationItemAppearanceForNavigationController:(UINavigationController *)navigationController;
@end

@interface NSObjectTests : XCTestCase

@end

@implementation NSObjectTests

/// 真实 UIKit 返回需要可见的导航容器，不能把离屏控制器当作点击宿主。
- (UIWindow *)windowForPlainBackNavigationController:(UINavigationController *)nav {
    UIWindowScene *scene = (id)[UIApplication.sharedApplication.connectedScenes.allObjects qmui_filterWithBlock:^BOOL(UIScene *item) { return [item isKindOfClass:UIWindowScene.class]; }].firstObject;
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:scene];
    window.rootViewController = nav;
    window.hidden = NO;
    [nav.view layoutIfNeeded];
    return window;
}

- (void)waitForPlainBackNavigationController:(UINavigationController *)nav {
    XCTestExpectation *completed = [self expectationWithDescription:@"原生返回转场结束"];
    [nav qmui_animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) { [completed fulfill]; }];
    [self waitForExpectations:@[completed] timeout:2];
}

- (void)testPlainBackButtonKeepsBusinessVetoAndAccessibilityEscape {
    UIViewController *root = UIViewController.new;
    QMUIPlainBackTestViewController *page = QMUIPlainBackTestViewController.new;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];
    XCTAssertNil([UIBarButtonItem qmui_plainBackItemWithViewController:root]);
    [nav pushViewController:page animated:NO];
    UIWindow *window = [self windowForPlainBackNavigationController:nav];
    UIBarButtonItem *item = [UIBarButtonItem qmui_plainBackItemWithViewController:page];
    page.navigationItem.leftBarButtonItem = item;
    XCTAssertNotNil(item);
    XCTAssertTrue(item.qmui_hidesSharedBackground);
    XCTAssertNil(item.customView); // 使用系统普通 UIBarButtonItem 布局。
    [UIApplication.sharedApplication sendAction:item.action to:item.target from:item forEvent:nil];
    XCTAssertEqual(nav.topViewController, page);
    XCTAssertEqual(page.popCheckCount, 1u);
    XCTAssertFalse(page.lastByGesture);
    XCTAssertTrue([page accessibilityPerformEscape]);
    XCTAssertEqual(nav.topViewController, page);
    XCTAssertEqual(page.popCheckCount, 2u);
    page.allowsPop = YES;
    [UIApplication.sharedApplication sendAction:item.action to:item.target from:item forEvent:nil];
    [self waitForPlainBackNavigationController:nav];
    XCTAssertEqual(nav.topViewController, root);
    XCTAssertEqual(page.popCheckCount, 3u);
    window.hidden = YES;
}

- (void)testPlainBackHistoryMenuRespectsVetoAndStaleSelection {
    UIViewController *root = UIViewController.new;
    root.title = @"根页面";
    UIViewController *middle = UIViewController.new;
    middle.title = @"上一页";
    QMUIPlainBackTestViewController *page = QMUIPlainBackTestViewController.new;
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];
    [nav setViewControllers:@[root, middle, page] animated:NO];
    UIWindow *window = [self windowForPlainBackNavigationController:nav];
    UIBarButtonItem *item = [UIBarButtonItem qmui_plainBackItemWithViewController:page];
    page.navigationItem.leftBarButtonItem = item;
    XCTAssertEqual(item.menu.children.count, 2u);
    XCTAssertEqualObjects(item.menu.children.firstObject.title, @"上一页");
    UIAction *rootAction = (UIAction *)item.menu.children.lastObject;
    UIButton *sender = UIButton.new;
    [sender sendAction:rootAction];
    XCTAssertEqual(nav.topViewController, page);
    XCTAssertEqual(page.popCheckCount, 1u);
    XCTAssertFalse(page.lastByGesture);
    page.allowsPop = YES;
    [sender sendAction:rootAction];
    [self waitForPlainBackNavigationController:nav];
    XCTAssertEqual(nav.topViewController, root);
    XCTAssertEqual(page.popCheckCount, 2u);
    [sender sendAction:rootAction];
    XCTAssertEqual(page.popCheckCount, 2u); // 过期菜单不得作用于新的页面。
    window.hidden = YES;
}

- (void)testPlainBackPreservesContentGestureAndExternalEdgeVeto {
    if (@available(iOS 26.0, *)) {
        QMUIPlainBackTestViewController *page = QMUIPlainBackTestViewController.new;
        page.allowsPop = YES;
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:UIViewController.new];
        [nav pushViewController:page animated:NO];
        [nav loadViewIfNeeded];
#ifdef IOS26_SDK_ALLOWED
        id contentDelegate = nav.interactiveContentPopGestureRecognizer.delegate;
        BOOL contentEnabled = nav.interactiveContentPopGestureRecognizer.enabled;
#endif
        UIBarButtonItem *originalBackItem = nav.viewControllers.firstObject.navigationItem.backBarButtonItem;
        page.navigationItem.leftBarButtonItem = [UIBarButtonItem qmui_plainBackItemWithViewController:page];
#ifdef IOS26_SDK_ALLOWED
        XCTAssertEqual(nav.interactiveContentPopGestureRecognizer.delegate, contentDelegate);
        XCTAssertEqual(nav.interactiveContentPopGestureRecognizer.enabled, contentEnabled);
#endif
        QMUIPlainBackDenyGestureDelegate *originalDelegate = QMUIPlainBackDenyGestureDelegate.new;
        nav.interactivePopGestureRecognizer.delegate = originalDelegate;
        [nav viewDidLayoutSubviews];
        id<UIGestureRecognizerDelegate> edgeDelegate = nav.interactivePopGestureRecognizer.delegate;
        XCTAssertFalse([edgeDelegate gestureRecognizerShouldBegin:nav.interactivePopGestureRecognizer]);
        XCTAssertTrue(page.lastByGesture);
        page.navigationItem.leftBarButtonItem = nil;
        XCTAssertFalse(page.navigationItem.hidesBackButton);
        XCTAssertEqual(nav.viewControllers.firstObject.navigationItem.backBarButtonItem, originalBackItem);
        page.navigationItem.hidesBackButton = YES;
        XCTAssertNil([UIBarButtonItem qmui_plainBackItemWithViewController:page]);
        page.navigationItem.hidesBackButton = NO;
        page.navigationItem.backAction = [UIAction actionWithHandler:^(__kindof UIAction *action) {}];
        XCTAssertNil([UIBarButtonItem qmui_plainBackItemWithViewController:page]);
    }
}

- (void)withLegacyNavigationButtonConfiguration:(void (^)(QMUIConfiguration *configuration))test {
    if (@available(iOS 15.0, *)) {
        QMUIConfiguration *configuration = QMUIConfiguration.sharedInstance;
        BOOL enabled = configuration.navBarUsesLegacyButtonLayout;
        NSArray *classes = configuration.navBarContainerClasses;
        @try {
            configuration.navBarUsesLegacyButtonLayout = NO;
            configuration.navBarContainerClasses = @[QMUILegacyButtonTestNavigationController.class];
            test(configuration);
        } @finally {
            configuration.navBarUsesLegacyButtonLayout = NO;
            configuration.navBarContainerClasses = classes;
            configuration.navBarUsesLegacyButtonLayout = enabled;
        }
    }
}

/// 同一页面切换系统/QMUI 按钮，验证三类内容的颜色和几何位置不会跳动。
- (void)testLegacyNavigationButtonsUnifyBoldImagesBackAndConfiguration {
    [self withLegacyNavigationButtonConfiguration:^(QMUIConfiguration *configuration) {
        NSArray *keys = @[@"navBarButtonFontBold", @"navBarButtonImageSize", @"navBarButtonImagePadding", @"navBarButtonContentHorizontalPadding", @"navBarButtonContentEdgeDistance", @"navBarButtonItemSpacing"];
        NSMutableDictionary *saved = NSMutableDictionary.new;
        for (NSString *key in keys) saved[key] = [configuration valueForKey:key] ?: NSNull.null;
        UIWindow *window;
        @try {
            configuration.navBarButtonFontBold = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
            configuration.navBarButtonImageSize = CGSizeMake(24, 24);
            configuration.navBarButtonImagePadding = 6;
            configuration.navBarButtonContentHorizontalPadding = 11;
            configuration.navBarButtonContentEdgeDistance = 16;
            configuration.navBarButtonItemSpacing = 8;
            UIViewController *root = UIViewController.new;
            UIViewController *page = UIViewController.new;
            UINavigationController *nav = [[QMUILegacyButtonTestNavigationController alloc] initWithRootViewController:root];
            [nav pushViewController:page animated:NO];
            nav.navigationBar.tintColor = UIColor.whiteColor;
            nav.navigationBar.backIndicatorImage = [UIImage qmui_imageWithShape:QMUIImageShapeNavBack size:CGSizeMake(13, 21) lineWidth:2.5 tintColor:UIColor.blackColor];
            window = [self windowForPlainBackNavigationController:nav];
            configuration.navBarUsesLegacyButtonLayout = YES;
            CGRect (^contentRect)(UIBarButtonItem *, BOOL) = ^CGRect(UIBarButtonItem *item, BOOL title) {
                UIButton *button = (id)item.customView;
                UIView *content = title ? button.titleLabel : button.imageView;
                return [content convertRect:content.bounds toView:nav.navigationBar];
            };
            UIBarButtonItem *nativeBold = [UIBarButtonItem qmui_itemWithBoldTitle:@"加粗" target:nil action:NULL];
            page.navigationItem.rightBarButtonItem = nativeBold;
            [self layoutLegacyNavigationButtons:nav];
            CGRect nativeBoldRect = contentRect(nativeBold, YES);
            QMUINavigationButton *boldButton = [[QMUINavigationButton alloc] initWithType:QMUINavigationButtonTypeBold title:@"加粗"];
            UIBarButtonItem *qmuiBold = [UIBarButtonItem qmui_itemWithButton:boldButton target:nil action:NULL];
            page.navigationItem.rightBarButtonItem = qmuiBold;
            [self layoutLegacyNavigationButtons:nav];
            CGRect qmuiBoldRect = contentRect(qmuiBold, YES);
            XCTAssertEqualWithAccuracy(qmuiBoldRect.origin.x, nativeBoldRect.origin.x, .5);
            XCTAssertEqualWithAccuracy(qmuiBoldRect.origin.y, nativeBoldRect.origin.y, .5);
            XCTAssertEqualWithAccuracy(qmuiBoldRect.size.width, nativeBoldRect.size.width, .5);
            XCTAssertEqualObjects(boldButton.titleLabel.font, configuration.navBarButtonFontBold);
            XCTAssertEqualObjects(boldButton.configuration.baseForegroundColor, UIColor.whiteColor);

            UIImage *source = [UIImage qmui_imageWithShape:QMUIImageShapeOval size:CGSizeMake(48, 48) tintColor:UIColor.blackColor];
            UIBarButtonItem *nativeImage = [UIBarButtonItem qmui_itemWithImage:source target:nil action:NULL];
            QMUINavigationButton *imageButton = [[QMUINavigationButton alloc] initWithImage:source];
            UIBarButtonItem *qmuiImage = [UIBarButtonItem qmui_itemWithButton:imageButton target:nil action:NULL];
            page.navigationItem.rightBarButtonItems = @[nativeImage];
            [self layoutLegacyNavigationButtons:nav];
            CGRect nativeImageRect = contentRect(nativeImage, NO);
            page.navigationItem.rightBarButtonItems = @[qmuiImage];
            [self layoutLegacyNavigationButtons:nav];
            CGRect qmuiImageRect = contentRect(qmuiImage, NO);
            XCTAssertEqualWithAccuracy(qmuiImageRect.origin.x, nativeImageRect.origin.x, .5);
            XCTAssertEqualWithAccuracy(qmuiImageRect.origin.y, nativeImageRect.origin.y, .5, @"QMUI 按钮=%@ 图片=%@ 父视图=%@，系统内容=%@", imageButton, imageButton.imageView, imageButton.superview, NSStringFromCGRect(nativeImageRect));
            XCTAssertEqualWithAccuracy(qmuiImageRect.size.width, 24, .5);
            XCTAssertEqualObjects(imageButton.configuration.baseForegroundColor, UIColor.whiteColor);

            UIBarButtonItem *automaticBack = page.navigationItem.leftBarButtonItem;
            CGRect nativeBackRect = contentRect(automaticBack, NO);
            UIBarButtonItem *qmuiBack = [UIBarButtonItem qmui_backItemWithTitle:nil target:nil action:NULL];
            page.navigationItem.leftBarButtonItem = qmuiBack;
            [self layoutLegacyNavigationButtons:nav];
            CGRect qmuiBackRect = contentRect(qmuiBack, NO);
            XCTAssertEqualWithAccuracy(qmuiBackRect.origin.x, nativeBackRect.origin.x, .5);
            XCTAssertEqualWithAccuracy(qmuiBackRect.origin.y, nativeBackRect.origin.y, .5);
            XCTAssertEqualWithAccuracy(qmuiBackRect.size.width, nativeBackRect.size.width, .5);
            XCTAssertEqualWithAccuracy(qmuiBackRect.size.height, nativeBackRect.size.height, .5);
            XCTAssertEqualObjects(((UIButton *)qmuiBack.customView).configuration.baseForegroundColor, UIColor.whiteColor);

            // 动态更新配置必须同时影响原生转换按钮和 QMUINavigationButton，且保留源图片。
            page.navigationItem.rightBarButtonItems = @[nativeImage, qmuiImage];
            configuration.navBarButtonImageSize = CGSizeMake(18, 18);
            configuration.navBarButtonContentEdgeDistance = 24;
            configuration.navBarButtonItemSpacing = 12;
            configuration.navBarButtonContentHorizontalPadding = 7;
            [self layoutLegacyNavigationButtons:nav];
            CGRect first = contentRect(nativeImage, NO);
            CGRect second = contentRect(qmuiImage, NO);
            XCTAssertEqualWithAccuracy(first.size.width, 18, .5);
            XCTAssertEqualWithAccuracy(second.size.width, 18, .5);
            XCTAssertEqualWithAccuracy(CGRectGetMaxX(first), nav.navigationBar.bounds.size.width - nav.navigationBar.safeAreaInsets.right - 24, .5);
            XCTAssertEqualWithAccuracy(CGRectGetMinX(first) - CGRectGetMaxX(second), 12, .5);
            XCTAssertEqualWithAccuracy(CGRectGetMinX(contentRect(qmuiBack, NO)), nav.navigationBar.safeAreaInsets.left + 24, .5);
            nav.navigationBar.tintColor = UIColor.redColor;
            [self layoutLegacyNavigationButtons:nav];
            XCTAssertEqualObjects(((UIButton *)nativeImage.customView).configuration.baseForegroundColor, UIColor.redColor);
            XCTAssertEqualObjects(imageButton.configuration.baseForegroundColor, UIColor.redColor);
            configuration.navBarUsesLegacyButtonLayout = NO;
            [self layoutLegacyNavigationButtons:nav];
            XCTAssertNil(nativeImage.customView);
            XCTAssertEqual(nativeImage.image, source);
            XCTAssertEqual(qmuiImage.customView, imageButton);
            XCTAssertTrue(CGAffineTransformIsIdentity(imageButton.transform));
        } @finally {
            window.hidden = YES;
            configuration.navBarUsesLegacyButtonLayout = NO;
            for (NSString *key in keys) [configuration setValue:saved[key] == NSNull.null ? nil : saved[key] forKey:key];
        }
    }];
}

/// UIBarButtonItem 更换视图后，UIKit 会在下一次主队列布局更新其内部容器。
- (void)layoutLegacyNavigationButtons:(UINavigationController *)nav {
    XCTestExpectation *layout = [self expectationWithDescription:@"按钮容器完成布局"];
    dispatch_async(dispatch_get_main_queue(), ^{
        [nav.view setNeedsLayout];
        [nav.view layoutIfNeeded];
        [nav.navigationBar setNeedsLayout];
        [nav.navigationBar layoutIfNeeded];
        [layout fulfill];
    });
    [self waitForExpectations:@[layout] timeout:2];
}

- (void)testLegacyNavigationButtonSwitchControlsWholeStackAndGeometry {
    [self withLegacyNavigationButtonConfiguration:^(QMUIConfiguration *configuration) {
        QMUILegacyButtonRootTestViewController *root = QMUILegacyButtonRootTestViewController.new;
        root.navigationItem.rightBarButtonItem = [UIBarButtonItem qmui_itemWithTitle:@"根页面按钮" target:nil action:NULL];
        QMUIPlainBackTestViewController *page = QMUIPlainBackTestViewController.new;
        UIBarButtonItem *text = [UIBarButtonItem qmui_itemWithTitle:@"编辑" target:nil action:NULL];
        UIBarButtonItem *image = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:nil action:NULL];
        page.navigationItem.rightBarButtonItems = @[text, image];
        UINavigationController *nav = [[QMUILegacyButtonTestNavigationController alloc] initWithRootViewController:root];
        [nav setViewControllers:@[root, UIViewController.new, page] animated:NO];
        UIWindow *window = [self windowForPlainBackNavigationController:nav];
        configuration.navBarUsesLegacyButtonLayout = YES;
        [self layoutLegacyNavigationButtons:nav];
        XCTAssertNotNil(root.navigationItem.rightBarButtonItem.customView);
        XCTAssertEqualObjects(page.navigationItem.rightBarButtonItems, (@[text, image]));
        UIBarButtonItem *back = page.navigationItem.leftBarButtonItem;
        XCTAssertTrue([back qmui_getBoundBOOLForKey:@"qmuinb_plainBackButton"]);
        XCTAssertTrue([text.customView isKindOfClass:UIButton.class]);
        XCTAssertNotNil(((UIButton *)image.customView).configuration.image);
        UIButton *backButton = (id)back.customView;
        UIButton *textButton = (id)text.customView;
        UIButton *imageButton = (id)image.customView;
        CGRect backRect = [backButton.imageView convertRect:backButton.imageView.bounds toView:nav.navigationBar];
        CGRect textRect = [textButton.titleLabel convertRect:textButton.titleLabel.bounds toView:nav.navigationBar];
        CGRect imageRect = [imageButton.imageView convertRect:imageButton.imageView.bounds toView:nav.navigationBar];
        XCTAssertEqualWithAccuracy(CGRectGetMinX(backRect), nav.navigationBar.safeAreaInsets.left + 16, .5);
        XCTAssertEqualWithAccuracy(CGRectGetMaxX(textRect), nav.navigationBar.bounds.size.width - nav.navigationBar.safeAreaInsets.right - 16, .5);
        XCTAssertEqualWithAccuracy(CGRectGetMinX(textRect) - CGRectGetMaxX(imageRect), 8, .5);
        CGPoint point = CGPointMake(CGRectGetMidX(backRect), CGRectGetMidY(backRect));
        XCTAssertEqual([nav.navigationBar hitTest:point withEvent:nil], back.customView);
        [(UIButton *)back.customView sendActionsForControlEvents:UIControlEventTouchUpInside];
        XCTAssertEqual(nav.topViewController, page); // 普通返回按钮不能绕过业务否决。
        XCTAssertEqual(page.popCheckCount, 1u);
        page.allowsPop = YES;
        [(UIButton *)back.customView sendAction:(UIAction *)back.menu.children.lastObject];
        [self waitForPlainBackNavigationController:nav];
        XCTAssertEqual(nav.topViewController, root);
        XCTAssertFalse(root.unexpectedBackWhileAppearing); // 跨级返回的临时数组不能给根页面错误添加箭头。
        configuration.navBarUsesLegacyButtonLayout = NO;
        XCTAssertNil(page.navigationItem.leftBarButtonItem);
        XCTAssertNil(text.customView);
        XCTAssertNil(image.customView);
        XCTAssertNil(root.navigationItem.rightBarButtonItem.customView);
        XCTAssertFalse(text.qmui_hidesSharedBackground);
        window.hidden = YES;
    }];
}

- (void)testLegacyNavigationButtonsPreserveUpdatesActionsCustomViewsAndScope {
    [self withLegacyNavigationButtonConfiguration:^(QMUIConfiguration *configuration) {
        UIViewController *root = UIViewController.new;
        __block NSUInteger actionCount = 0;
        UIAction *action = [UIAction actionWithTitle:@"编辑" image:[UIImage systemImageNamed:@"pencil"] identifier:nil handler:^(__kindof UIAction *action) { actionCount++; }];
        UIBarButtonItem *item = [[UIBarButtonItem alloc] initWithPrimaryAction:action];
        UIBarButtonItem *systemItemWithAction = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd primaryAction:action];
        UIControl *custom = [[UIControl alloc] initWithFrame:CGRectMake(0, 0, 22, 30)];
        custom.transform = CGAffineTransformMakeScale(.9, .9);
        CGAffineTransform originalTransform = custom.transform;
        UIBarButtonItem *customItem = [[UIBarButtonItem alloc] initWithCustomView:custom];
        customItem.qmui_hidesSharedBackground = YES;
        root.navigationItem.rightBarButtonItems = @[item, systemItemWithAction, customItem];
        UINavigationController *nav = [[QMUILegacyButtonTestNavigationController alloc] initWithRootViewController:root];
        UIWindow *window = [self windowForPlainBackNavigationController:nav];
        configuration.navBarUsesLegacyButtonLayout = YES;
        UIButton *button = (id)item.customView;
        XCTAssertNotNil(button.configuration.image);
        XCTAssertNotNil(((UIButton *)systemItemWithAction.customView).configuration.image);
        [button sendActionsForControlEvents:UIControlEventTouchUpInside];
        XCTAssertEqual(actionCount, 1u);
        item.title = @"更新标题";
        XCTAssertEqualObjects(button.configuration.title, @"更新标题");
        item.enabled = NO;
        XCTAssertFalse(button.enabled);
        [button sendActionsForControlEvents:UIControlEventTouchUpInside];
        XCTAssertEqual(actionCount, 1u);
        UIMenu *menu = [UIMenu menuWithTitle:@"菜单" children:@[]];
        item.menu = menu;
        XCTAssertEqualObjects(button.menu, menu);
        UIViewController *systemRoot = UIViewController.new;
        UIBarButtonItem *systemItem = [UIBarButtonItem qmui_itemWithTitle:@"系统页面" target:nil action:NULL];
        systemRoot.navigationItem.rightBarButtonItem = systemItem;
        UINavigationController *systemNav = [[UINavigationController alloc] initWithRootViewController:systemRoot];
        UIWindow *systemWindow = [self windowForPlainBackNavigationController:systemNav];
        XCTAssertNil(systemItem.customView);
        XCTAssertFalse(systemItem.qmui_hidesSharedBackground);
        configuration.navBarUsesLegacyButtonLayout = NO;
        XCTAssertEqual(customItem.customView, custom);
        XCTAssertTrue(CGAffineTransformEqualToTransform(custom.transform, originalTransform));
        XCTAssertTrue(customItem.qmui_hidesSharedBackground);
        XCTAssertNil(item.customView);
        systemWindow.hidden = YES;
        window.hidden = YES;
    }];
}

- (void)testLegacyNavigationButtonsKeepCustomBackBadgeAndNeighborHitArea {
    [self withLegacyNavigationButtonConfiguration:^(QMUIConfiguration *configuration) {
        UIViewController *root = UIViewController.new;
        UIViewController *page = UIViewController.new;
        QMUINavigationButton *back = [[QMUILegacyDecoratedBackTestButton alloc] initWithType:QMUINavigationButtonTypeBack];
        back.configurationUpdateHandler = nil;
        back.configuration = nil;
        __block NSUInteger businessLayoutCount = 0;
        void (^businessLayout)(__kindof UIView *) = ^(__kindof UIView *view) { businessLayoutCount++; };
        back.qmui_layoutSubviewsBlock = businessLayout;
        __block NSUInteger businessFrameCount = 0;
        void (^businessFrame)(__kindof UIView *, CGRect) = ^(__kindof UIView *view, CGRect precedingFrame) { businessFrameCount++; };
        back.qmui_frameDidChangeBlock = businessFrame;
        UILabel *badge = [[UILabel alloc] initWithFrame:CGRectMake(18, 3, 57, 26)];
        badge.text = @"99+";
        [back addSubview:badge];
        UIBarButtonItem *backItem = [[UIBarButtonItem alloc] initWithCustomView:back];
        UIBarButtonItem *closeItem = [UIBarButtonItem qmui_closeItemWithTarget:nil action:NULL];
        page.navigationItem.leftBarButtonItems = @[backItem, closeItem];
        page.navigationItem.hidesBackButton = YES;
        UINavigationController *nav = [[QMUILegacyButtonTestNavigationController alloc] initWithRootViewController:root];
        [nav pushViewController:page animated:NO];
        UIWindow *window = [self windowForPlainBackNavigationController:nav];
        configuration.navBarUsesLegacyButtonLayout = YES;
        [self layoutLegacyNavigationButtons:nav];
        CGRect backRect = [back convertRect:back.bounds toView:nav.navigationBar];
        CGRect badgeRect = [badge convertRect:badge.bounds toView:nav.navigationBar];
        UIButton *close = (id)closeItem.customView;
        CGRect closeRect = [close.imageView convertRect:close.imageView.bounds toView:nav.navigationBar];
        XCTAssertEqualWithAccuracy(CGRectGetMinX(backRect), nav.navigationBar.safeAreaInsets.left + 16, .5);
        XCTAssertEqualWithAccuracy(CGRectGetMinX(closeRect) - CGRectGetMaxX(backRect), 8, .5);
        XCTAssertGreaterThanOrEqual(CGRectGetMinX(closeRect) - CGRectGetMaxX(badgeRect), 7.5);
        // 返回按钮扩展的点击区域不能吞掉旁边关闭按钮的事件。
        CGPoint closePoint = CGPointMake(CGRectGetMidX(closeRect), CGRectGetMidY(closeRect));
        XCTAssertEqual([nav.navigationBar hitTest:closePoint withEvent:nil], close);
        XCTAssertEqualObjects(page.navigationItem.leftBarButtonItems, (@[backItem, closeItem]));
        XCTAssertGreaterThan(businessLayoutCount, 0u);
        XCTAssertGreaterThan(businessFrameCount, 0u);
        configuration.navBarUsesLegacyButtonLayout = NO;
        XCTAssertEqual(backItem.customView, back);
        XCTAssertTrue(CGAffineTransformIsIdentity(back.transform));
        XCTAssertEqual(back.qmui_layoutSubviewsBlock, businessLayout);
        XCTAssertEqual(back.qmui_frameDidChangeBlock, businessFrame);
        window.hidden = YES;
    }];
}

- (void)testLegacyNavigationButtonsSupplementSystemBackAndRestoreBusinessState {
    [self withLegacyNavigationButtonConfiguration:^(QMUIConfiguration *configuration) {
        UIViewController *root = UIViewController.new;
        QMUIPlainBackTestViewController *page = QMUIPlainBackTestViewController.new;
        UINavigationController *nav = [[QMUILegacyButtonTestNavigationController alloc] initWithRootViewController:root];
        [nav pushViewController:page animated:NO];
        UIWindow *window = [self windowForPlainBackNavigationController:nav];
        configuration.navBarUsesLegacyButtonLayout = YES;
        UIBarButtonItem *closeItem = [UIBarButtonItem qmui_closeItemWithTarget:nil action:NULL];
        // 直接进入页面选择“同时显示”，不预先创建未读数返回按钮。
        page.navigationItem.leftItemsSupplementBackButton = YES;
        page.navigationItem.leftBarButtonItems = @[closeItem];
        [self layoutLegacyNavigationButtons:nav];
        NSArray<UIBarButtonItem *> *items = page.navigationItem.leftBarButtonItems;
        XCTAssertEqual(items.count, 2u);
        XCTAssertTrue([items.firstObject qmui_getBoundBOOLForKey:@"qmuinb_plainBackButton"]);
        XCTAssertEqual(items.lastObject, closeItem);
        XCTAssertTrue(page.navigationItem.leftItemsSupplementBackButton);
        // 系统自动箭头临时隐藏，实际显示的是参与紧凑布局的普通箭头。
        XCTAssertTrue(page.navigationItem.hidesBackButton);
        UIButton *back = (id)items.firstObject.customView;
        UIButton *close = (id)closeItem.customView;
        CGRect backRect = [back.imageView convertRect:back.imageView.bounds toView:nav.navigationBar];
        CGRect closeRect = [close.imageView convertRect:close.imageView.bounds toView:nav.navigationBar];
        XCTAssertEqualWithAccuracy(CGRectGetMinX(backRect), nav.navigationBar.safeAreaInsets.left + 16, .5);
        XCTAssertEqualWithAccuracy(CGRectGetMinX(closeRect) - CGRectGetMaxX(backRect), 8, .5);
        XCTAssertEqual([nav.navigationBar hitTest:CGPointMake(CGRectGetMidX(closeRect), CGRectGetMidY(closeRect)) withEvent:nil], close);
        [back sendActionsForControlEvents:UIControlEventTouchUpInside];
        XCTAssertEqual(nav.topViewController, page);
        XCTAssertEqual(page.popCheckCount, 1u);

        page.navigationItem.leftItemsSupplementBackButton = NO;
        XCTAssertEqualObjects(page.navigationItem.leftBarButtonItems, (@[closeItem]));
        XCTAssertFalse(page.navigationItem.hidesBackButton);
        page.navigationItem.leftItemsSupplementBackButton = YES;
        XCTAssertEqual(page.navigationItem.leftBarButtonItems.count, 2u);
        page.navigationItem.hidesBackButton = YES;
        XCTAssertEqualObjects(page.navigationItem.leftBarButtonItems, (@[closeItem]));
        page.navigationItem.hidesBackButton = NO;
        XCTAssertEqual(page.navigationItem.leftBarButtonItems.count, 2u);

        configuration.navBarUsesLegacyButtonLayout = NO;
        XCTAssertEqualObjects(page.navigationItem.leftBarButtonItems, (@[closeItem]));
        XCTAssertFalse(page.navigationItem.hidesBackButton);
        XCTAssertTrue(page.navigationItem.leftItemsSupplementBackButton);
        XCTAssertNil(closeItem.customView);
        configuration.navBarUsesLegacyButtonLayout = YES;
        XCTAssertEqual(page.navigationItem.leftBarButtonItems.count, 2u);
        page.navigationItem.hidesBackButton = YES;
        configuration.navBarUsesLegacyButtonLayout = NO;
        XCTAssertTrue(page.navigationItem.hidesBackButton); // 业务主动隐藏的状态不能被开关覆盖。
        window.hidden = YES;
    }];
}

- (void)withNativeNavigationStyles:(void (^)(void))test {
    if (@available(iOS 26.0, *)) {
        QMUIConfiguration *configuration = QMUIConfiguration.sharedInstance;
        BOOL active = configuration.active;
        BOOL standardOnly = configuration.navBarUsesStandardAppearanceOnly;
        BOOL removeEffect = configuration.navBarRemoveBackgroundEffectAutomatically;
        @try {
            [configuration setValue:@YES forKey:@"active"];
            configuration.navBarUsesStandardAppearanceOnly = YES;
            configuration.navBarRemoveBackgroundEffectAutomatically = YES;
            test();
        } @finally {
            configuration.navBarUsesStandardAppearanceOnly = standardOnly;
            configuration.navBarRemoveBackgroundEffectAutomatically = removeEffect;
            [configuration setValue:@(active) forKey:@"active"];
        }
    }
}

- (void)testNavigationMaxYUsesEachPagesVisibilityFromFirstTransitionLayout {
    [self withNativeNavigationStyles:^{
        UIWindowScene *scene = (id)[UIApplication.sharedApplication.connectedScenes.allObjects qmui_filterWithBlock:^BOOL(UIScene *item) { return [item isKindOfClass:UIWindowScene.class]; }].firstObject;
        XCTAssertNotNil(scene);
        if (!scene) return;
        UIWindow *window = [[UIWindow alloc] initWithWindowScene:scene];
        NSMutableArray<QMUINavigationMaxYTestViewController *> *pages = NSMutableArray.new;
        for (NSUInteger index = 0; index < 3; index++) {
            QMUINavigationMaxYTestViewController *page = QMUINavigationMaxYTestViewController.new;
            page.barHidden = index == 1;
            page.layoutPositions = NSMutableArray.new;
            [pages addObject:page];
        }
        QMUINavigationController *nav = [[QMUINavigationController alloc] initWithRootViewController:pages.firstObject];
        window.rootViewController = nav;
        [window makeKeyAndVisible];
        [window layoutIfNeeded];
        @try {
            // 显示→隐藏→显示，再逐级 pop，检查首帧和转场中每次布局。
            for (NSUInteger operation = 0; operation < 4; operation++) {
                for (QMUINavigationMaxYTestViewController *page in pages) [page.layoutPositions removeAllObjects];
                if (operation < 2) [nav pushViewController:pages[operation + 1] animated:YES];
                else [nav popViewControllerAnimated:YES];
                XCTestExpectation *completed = [self expectationWithDescription:@"导航栏显隐转场完成"];
                [nav qmui_animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) { [completed fulfill]; }];
                [self waitForExpectations:@[completed] timeout:2];
                QMUINavigationMaxYTestViewController *top = (id)nav.topViewController;
                XCTAssertGreaterThan(top.layoutPositions.count, 0u);
                for (QMUINavigationMaxYTestViewController *page in pages) {
                    for (NSNumber *position in page.layoutPositions) {
                        if (page.barHidden) XCTAssertEqualWithAccuracy(position.doubleValue, 0, .01);
                        else XCTAssertGreaterThan(position.doubleValue, 0);
                    }
                }
            }
            // 转场之外以实际显隐为准，兼容业务直接操作系统导航栏。
            [nav setNavigationBarHidden:YES animated:NO];
            XCTAssertEqualWithAccuracy(pages.firstObject.qmui_navigationBarMaxYInViewCoordinator, 0, .01);
            [nav setNavigationBarHidden:NO animated:NO];
            [window layoutIfNeeded];
            XCTAssertGreaterThan(pages.firstObject.qmui_navigationBarMaxYInViewCoordinator, 0);
        } @finally {
            window.hidden = YES;
        }
    }];
}

- (void)testNavigationItemsHaveDistinctStylesBeforePush {
    [self withNativeNavigationStyles:^{
        QMUINavigationStyleTestViewController *first = QMUINavigationStyleTestViewController.new;
        first.styleImage = [UIImage qmui_imageWithColor:UIColor.blueColor];
        first.styleForegroundColor = UIColor.whiteColor;
        QMUINavigationStyleTestViewController *second = QMUINavigationStyleTestViewController.new;
        second.styleForegroundColor = UIColor.blackColor;
        QMUINavigationController *nav = [[QMUINavigationController alloc] initWithRootViewController:first];
        [nav loadViewIfNeeded];
        [first renderNavigationBarStyleAnimated:NO];
        XCTAssertNil(nav.navigationBar.window);
        XCTAssertEqual(first.navigationItem.standardAppearance.backgroundImage, first.styleImage);
        __block BOOL checkedBeforePush = NO;
        [nav qmui_addNavigationActionDidChangeBlock:^(QMUINavigationAction action, BOOL animated, UINavigationController *navigationController, UIViewController *appearingViewController, NSArray<UIViewController *> *disappearingViewControllers) {
            if (action == QMUINavigationActionWillPush) {
                checkedBeforePush = YES;
                XCTAssertEqual(appearingViewController, second);
                XCTAssertNil(second.navigationController); // UIKit 尚未开始 push。
                XCTAssertNotNil(second.navigationItem.standardAppearance);
                XCTAssertNil(second.navigationItem.standardAppearance.backgroundImage);
                XCTAssertNotNil(second.navigationItem.standardAppearance.backgroundEffect);
                XCTAssertEqualObjects(second.navigationItem.standardAppearance.titleTextAttributes[NSForegroundColorAttributeName], UIColor.blackColor);
                XCTAssertEqual(first.navigationItem.standardAppearance.backgroundImage, first.styleImage);
            }
        }];
        [nav pushViewController:second animated:NO];
        XCTAssertTrue(checkedBeforePush);
        XCTAssertNotEqual(first.navigationItem.standardAppearance, second.navigationItem.standardAppearance);
        XCTAssertEqualObjects(first.navigationItem.standardAppearance.titleTextAttributes[NSForegroundColorAttributeName], UIColor.whiteColor);
        for (NSString *key in @[@"standardAppearance", @"scrollEdgeAppearance", @"compactAppearance", @"compactScrollEdgeAppearance"]) {
            UINavigationBarAppearance *appearance = [second.navigationItem valueForKey:key];
            XCTAssertNotNil(appearance);
            XCTAssertNil(appearance.backgroundImage);
            XCTAssertNotNil(appearance.backgroundEffect);
        }
    }];
}

- (void)testNavigationMaterialIsNotReassignedWhenStyleIsUnchanged {
    [self withNativeNavigationStyles:^{
        QMUINavigationStyleTestViewController *page = QMUINavigationStyleTestViewController.new;
        page.styleForegroundColor = UIColor.blackColor;
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:page];
        [page qmuinb_updateNavigationItemAppearanceForNavigationController:nav];
        UINavigationBarAppearance *appearance = page.navigationItem.standardAppearance;
        UIBlurEffect *effect = appearance.backgroundEffect;
        [page qmuinb_updateNavigationItemAppearanceForNavigationController:nav];
        XCTAssertEqual(page.navigationItem.standardAppearance, appearance);
        XCTAssertEqual(page.navigationItem.standardAppearance.backgroundEffect, effect);
        page.styleBackgroundColor = UIColor.orangeColor;
        [page qmuinb_updateNavigationItemAppearanceForNavigationController:nav];
        XCTAssertEqualObjects(page.navigationItem.standardAppearance.backgroundColor, UIColor.orangeColor);
    }];
}

- (void)testDifferentNavigationBackgroundsFollowPagesDuringTransition {
    [self withNativeNavigationStyles:^{
        UIWindowScene *scene = (id)[UIApplication.sharedApplication.connectedScenes.allObjects qmui_filterWithBlock:^BOOL(UIScene *item) { return [item isKindOfClass:UIWindowScene.class]; }].firstObject;
        XCTAssertNotNil(scene);
        if (!scene) return;
        UIWindow *window = [[UIWindow alloc] initWithWindowScene:scene];
        QMUINavigationStyleTestViewController *first = QMUINavigationStyleTestViewController.new;
        first.styleImage = [UIImage qmui_imageWithColor:UIColor.blueColor];
        first.styleForegroundColor = UIColor.whiteColor;
        first.styleTransitionKey = @"blue";
        QMUINavigationStyleTestViewController *second = QMUINavigationStyleTestViewController.new;
        second.styleForegroundColor = UIColor.blackColor;
        second.styleTransitionKey = @"blur";
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:first];
        window.rootViewController = nav;
        window.hidden = NO;
        [nav.view layoutIfNeeded];
        UIView *systemBackground = nav.navigationBar.qmui_backgroundView;
        CALayer *originalMask = systemBackground.layer.mask;
        XCTestExpectation *completed = [self expectationWithDescription:@"不同背景随页面移动后清理临时视图"];
        __block NSUInteger preparedCount = 0;
        [nav qmui_addNavigationActionDidChangeBlock:^(QMUINavigationAction action, BOOL animated, UINavigationController *navigationController, UIViewController *appearing, NSArray<UIViewController *> *disappearing) {
            if (action == QMUINavigationActionWillPush || action == QMUINavigationActionWillPop) {
                preparedCount++;
                id transition = [navigationController.navigationBar qmui_getBoundObjectForKey:@"qmuinb_backgroundTransition"];
                XCTAssertNotNil(transition);
                UIView *fromBackground = [transition valueForKey:@"fromBackground"];
                UIView *toBackground = [transition valueForKey:@"toBackground"];
                XCTAssertEqual(fromBackground.superview, navigationController.topViewController.view);
                XCTAssertEqual(toBackground.superview, appearing.view);
                XCTAssertFalse([fromBackground isKindOfClass:UINavigationBar.class]);
                XCTAssertNotNil(systemBackground.layer.mask);
                UIImage *fromImage = [[fromBackground valueForKey:@"appearance"] backgroundImage];
                UIImage *toImage = [[toBackground valueForKey:@"appearance"] backgroundImage];
                XCTAssertEqual(action == QMUINavigationActionWillPush ? fromImage : toImage, first.styleImage);
                XCTAssertNil(action == QMUINavigationActionWillPush ? toImage : fromImage);
            } else if (action == QMUINavigationActionPopCompleted) {
                XCTAssertNil([navigationController.navigationBar qmui_getBoundObjectForKey:@"qmuinb_backgroundTransition"]);
                XCTAssertEqual(systemBackground.layer.mask, originalMask);
                XCTAssertEqual(navigationController.topViewController, first);
                [completed fulfill];
            }
        }];
        [nav pushViewController:second animated:YES];
        [nav qmui_animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            // completion 内仍在清理 push 状态，等下一次主队列再返回。
            dispatch_async(dispatch_get_main_queue(), ^{ [nav popViewControllerAnimated:YES]; });
        }];
        [self waitForExpectations:@[completed] timeout:3];
        XCTAssertEqual(preparedCount, 2u);
        window.hidden = YES;
    }];
}

- (void)testNavigationStyleChangesAndPopPreservePreviousPage {
    [self withNativeNavigationStyles:^{
        QMUINavigationStyleTestViewController *first = QMUINavigationStyleTestViewController.new;
        first.styleImage = [UIImage qmui_imageWithColor:UIColor.blueColor];
        first.styleForegroundColor = UIColor.whiteColor;
        QMUINavigationStyleTestViewController *second = QMUINavigationStyleTestViewController.new;
        second.styleForegroundColor = UIColor.blackColor;
        QMUINavigationController *nav = [[QMUINavigationController alloc] initWithRootViewController:first];
        [nav pushViewController:second animated:NO];
        second.styleBackgroundColor = UIColor.purpleColor;
        second.styleForegroundColor = UIColor.yellowColor;
        [second renderNavigationBarStyleAnimated:NO];
        XCTAssertEqualObjects(second.navigationItem.standardAppearance.backgroundColor, UIColor.purpleColor);
        XCTAssertEqualObjects(second.navigationItem.standardAppearance.titleTextAttributes[NSForegroundColorAttributeName], UIColor.yellowColor);
        XCTAssertEqual(first.navigationItem.standardAppearance.backgroundImage, first.styleImage);
        XCTAssertEqualObjects(first.navigationItem.standardAppearance.titleTextAttributes[NSForegroundColorAttributeName], UIColor.whiteColor);
        [nav popViewControllerAnimated:NO];
        XCTAssertEqual(nav.topViewController, first);
        XCTAssertEqual(first.navigationItem.standardAppearance.backgroundImage, first.styleImage);
        XCTAssertEqualObjects(second.navigationItem.standardAppearance.backgroundColor, UIColor.purpleColor);
    }];
}

- (void)testLegacyNavigationStyleSettersAndEffectUpdateOnlyCurrentItem {
    [self withNativeNavigationStyles:^{
        QMUINavigationStyleTestViewController *first = QMUINavigationStyleTestViewController.new;
        first.styleImage = [UIImage qmui_imageWithColor:UIColor.blueColor];
        first.styleForegroundColor = UIColor.whiteColor;
        QMUINavigationStyleTestViewController *second = QMUINavigationStyleTestViewController.new;
        second.styleForegroundColor = UIColor.blackColor;
        QMUINavigationController *nav = [[QMUINavigationController alloc] initWithRootViewController:first];
        [nav pushViewController:second animated:NO];
        [nav loadViewIfNeeded];
        XCTAssertEqual(nav.navigationBar.topItem, second.navigationItem);
        nav.navigationBar.barTintColor = UIColor.greenColor;
        XCTAssertEqualObjects(second.navigationItem.standardAppearance.backgroundColor, UIColor.greenColor);
        XCTAssertEqualObjects(nav.navigationBar.barTintColor, UIColor.greenColor);
        UIImage *image = [UIImage qmui_imageWithColor:UIColor.redColor];
        [nav.navigationBar setBackgroundImage:image forBarMetrics:UIBarMetricsDefault];
        XCTAssertEqual(second.navigationItem.standardAppearance.backgroundImage, image);
        XCTAssertNil(second.navigationItem.standardAppearance.backgroundEffect);
        [nav.navigationBar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
        nav.navigationBar.barStyle = UIBarStyleDefault;
        XCTAssertNotNil(second.navigationItem.standardAppearance.backgroundEffect);
        nav.navigationBar.qmui_effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleLight];
        nav.navigationBar.qmui_effect = nil;
        nav.navigationBar.qmui_effectForegroundColor = UIColor.orangeColor;
        XCTAssertNil(second.navigationItem.standardAppearance.backgroundEffect);
        XCTAssertEqualObjects(second.navigationItem.standardAppearance.backgroundColor, UIColor.orangeColor);
        XCTAssertEqual(first.navigationItem.standardAppearance.backgroundImage, first.styleImage);
        XCTAssertNil(first.navigationItem.standardAppearance.backgroundEffect);
    }];
}

- (void)testNavigationStylePreservesIndependentAppearancesAndSystemPages {
    if (@available(iOS 26.0, *)) {
        QMUIConfiguration *configuration = QMUIConfiguration.sharedInstance;
        BOOL active = configuration.active;
        BOOL standardOnly = configuration.navBarUsesStandardAppearanceOnly;
        @try {
            [configuration setValue:@NO forKey:@"active"];
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:UIViewController.new];
            [nav.topViewController qmuinb_updateNavigationItemAppearanceForNavigationController:nav];
            XCTAssertNil(nav.topViewController.navigationItem.standardAppearance);
            QMUITitleOnlyNavigationStyleTestViewController *page = QMUITitleOnlyNavigationStyleTestViewController.new;
            UINavigationBarAppearance *standard = UINavigationBarAppearance.new;
            standard.backgroundColor = UIColor.blueColor;
            UINavigationBarAppearance *edge = UINavigationBarAppearance.new;
            [edge configureWithTransparentBackground];
            edge.backgroundColor = UIColor.greenColor;
            page.navigationItem.standardAppearance = standard;
            page.navigationItem.scrollEdgeAppearance = edge;
            [page qmuinb_updateNavigationItemAppearanceForNavigationController:nav];
            XCTAssertEqualObjects(page.navigationItem.standardAppearance.backgroundColor, UIColor.blueColor);
            XCTAssertEqualObjects(page.navigationItem.scrollEdgeAppearance.backgroundColor, UIColor.greenColor);
            XCTAssertNil(page.navigationItem.scrollEdgeAppearance.backgroundEffect);
            XCTAssertEqualObjects(page.navigationItem.standardAppearance.titleTextAttributes[NSForegroundColorAttributeName], UIColor.redColor);
            XCTAssertEqualObjects(page.navigationItem.scrollEdgeAppearance.titleTextAttributes[NSForegroundColorAttributeName], UIColor.redColor);
            XCTAssertEqualObjects(standard.backgroundColor, UIColor.blueColor);
            XCTAssertEqualObjects(edge.backgroundColor, UIColor.greenColor);
            // 启用配置表但未统一四种状态，也不能把独立的透明边缘材料改成磨砂。
            [configuration setValue:@YES forKey:@"active"];
            configuration.navBarUsesStandardAppearanceOnly = NO;
            [page qmuinb_updateNavigationItemAppearanceForNavigationController:nav];
            XCTAssertEqualObjects(page.navigationItem.scrollEdgeAppearance.backgroundColor, UIColor.greenColor);
            XCTAssertNil(page.navigationItem.scrollEdgeAppearance.backgroundEffect);
        } @finally {
            configuration.navBarUsesStandardAppearanceOnly = standardOnly;
            [configuration setValue:@(active) forKey:@"active"];
        }
    }
}

- (void)testMissingRuntimeMethodIsSkipped {
    SEL missingSelector = NSSelectorFromString(@"qmui_missingRuntimeMethodForRegression");
    XCTAssertFalse(OverrideImplementation(NSObject.class, missingSelector, ^id(__unsafe_unretained Class cls, SEL selector, IMP (^provider)(void)) {
        XCTFail(@"不存在的方法不应进入替换回调");
        return ^(NSObject *object) {};
    }));
    XCTAssertFalse([NSObject instancesRespondToSelector:missingSelector]);
}

- (void)testNavigationContentViewDoesNotRequirePrivateProvider {
    UINavigationBar *bar = QMUINoPrivateProviderNavigationBar.new;
    XCTAssertNoThrow((void)bar.qmui_contentView);
}

- (void)testTabBarSelectionCanBeCleared {
    UITabBar *bar = UITabBar.new;
    UITabBarItem *item = [[UITabBarItem alloc] initWithTitle:@"测试" image:nil tag:0];
    bar.items = @[item];
    bar.selectedItem = item;
    XCTAssertNoThrow(bar.selectedItem = nil);
    XCTAssertNil(bar.selectedItem);
}

- (void)testTabBarImageLookupSkipsHiddenSubtreesAndEmptyImages {
    UIView *button = UIView.new;
    UIView *hiddenContainer = UIView.new;
    hiddenContainer.hidden = YES;
    UIImage *image = [UIImage qmui_imageWithColor:UIColor.redColor];
    [hiddenContainer addSubview:[[UIImageView alloc] initWithImage:image]];
    [button addSubview:hiddenContainer];
    UIImageView *transparent = [[UIImageView alloc] initWithImage:image];
    transparent.alpha = 0;
    [button addSubview:transparent];
    [button addSubview:UIImageView.new];
    UIView *content = UIView.new;
    UIImageView *icon = UIImageView.new;
    icon.highlightedImage = image;
    icon.highlighted = YES;
    [content addSubview:icon];
    [button addSubview:content];
    XCTAssertEqual([UITabBarItem qmui_imageViewInTabBarButton:button], icon);
    icon.hidden = YES;
    XCTAssertNil([UITabBarItem qmui_imageViewInTabBarButton:button]);
    XCTAssertNil([UITabBarItem qmui_imageViewInTabBarButton:nil]);
}

/// 等待系统完成两套图标的同步，不缓存 item.view 或 imageView。
- (void)waitForTabBarImageLayout:(UITabBar *)bar {
    [bar setNeedsLayout];
    [bar layoutIfNeeded];
    XCTestExpectation *layout = [self expectationWithDescription:@"TabBar 图标更新"];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.05 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
        [bar layoutIfNeeded];
        [layout fulfill];
    });
    [self waitForExpectations:@[layout] timeout:2];
}

- (void)checkTabBarImageStatesWithController:(BOOL)usesController {
    UIWindowScene *scene = (id)[UIApplication.sharedApplication.connectedScenes.allObjects qmui_filterWithBlock:^BOOL(UIScene *item) { return [item isKindOfClass:UIWindowScene.class]; }].firstObject;
    XCTAssertNotNil(scene);
    if (!scene) return;
    UIImage *normal = [UIImage qmui_imageWithColor:UIColor.redColor size:CGSizeMake(23, 21) cornerRadius:0];
    UIImage *selected = [UIImage qmui_imageWithColor:UIColor.blueColor size:CGSizeMake(25, 23) cornerRadius:0];
    UITabBarItem *first = [[UITabBarItem alloc] initWithTitle:@"图片" image:normal selectedImage:selected];
    // 邻居使用相同图片，确保不会把另一个 item 的图标当成选中副本。
    UITabBarItem *second = [[UITabBarItem alloc] initWithTitle:@"相同图片" image:normal selectedImage:selected];
    UITabBarItem *symbol = [[UITabBarItem alloc] initWithTitle:@"系统图标" image:[UIImage systemImageNamed:@"house"] selectedImage:[UIImage systemImageNamed:@"house.fill"]];
    NSArray<UITabBarItem *> *items = @[first, second, symbol];
    UIWindow *window = [[UIWindow alloc] initWithWindowScene:scene];
    UITabBarController *controller = usesController ? UITabBarController.new : nil;
    UIViewController *root = controller ?: UIViewController.new;
    UITabBar *bar;
    if (controller) {
        NSMutableArray<UIViewController *> *pages = NSMutableArray.new;
        for (UITabBarItem *item in items) {
            UIViewController *page = UIViewController.new;
            page.tabBarItem = item;
            [pages addObject:page];
        }
        controller.viewControllers = pages;
        bar = controller.tabBar;
    } else {
        bar = [[UITabBar alloc] initWithFrame:CGRectMake(0, 200, CGRectGetWidth(window.bounds), 83)];
        bar.items = items;
        [root.view addSubview:bar];
    }
    window.rootViewController = root;
    window.hidden = NO;
    @try {
        for (NSUInteger index = 0; index < items.count; index++) {
            if (controller) controller.selectedIndex = index;
            else bar.selectedItem = items[index];
            [self waitForTabBarImageLayout:bar];
            for (UITabBarItem *item in items) {
                UIImageView *icon = item.qmui_imageView;
                XCTAssertNotNil(icon);
                UIImage *displayedImage = icon.highlighted && icon.highlightedImage ? icon.highlightedImage : icon.image;
                XCTAssertEqualObjects(displayedImage, bar.selectedItem == item ? item.selectedImage : item.image);
                CGPoint center = [icon convertPoint:CGPointMake(CGRectGetMidX(icon.bounds), CGRectGetMidY(icon.bounds)) toView:bar];
                XCTAssertTrue(CGRectContainsPoint([item.qmui_view convertRect:item.qmui_view.bounds toView:bar], center));
            }
        }
        if (controller) controller.selectedIndex = 0;
        else bar.selectedItem = first;
        first.title = @"更新图片";
        first.selectedImage = [UIImage qmui_imageWithColor:UIColor.greenColor size:CGSizeMake(24, 24) cornerRadius:0];
        [self waitForTabBarImageLayout:bar];
        UIImageView *updated = first.qmui_imageView;
        XCTAssertEqualObjects(updated.highlighted && updated.highlightedImage ? updated.highlightedImage : updated.image, first.selectedImage);
        first.selectedImage = normal;
        [self waitForTabBarImageLayout:bar];
        XCTAssertNotNil(first.qmui_imageView);
        if (@available(iOS 26.0, *)) {
            // 同图时仍应取得液态选中层，动画才能作用于实际显示的图标。
            XCTAssertNotEqual(first.qmui_imageView, [UITabBarItem qmui_imageViewInTabBarButton:first.qmui_view]);
        }
    } @finally {
        window.hidden = YES;
    }
}

- (void)testStandaloneTabBarImageFollowsSelectedState {
    [self checkTabBarImageStatesWithController:NO];
}

- (void)testControllerTabBarImageFollowsSelectedState {
    [self checkTabBarImageStatesWithController:YES];
}

- (void)testToastBlurDoesNotAccumulateEffectViews {
    QMUIToastBackgroundView *background = QMUIToastBackgroundView.new;
    background.shouldBlurBackgroundView = YES;
    UIVisualEffectView *effectView = background.effectView;
    background.shouldBlurBackgroundView = YES;
    XCTAssertEqual(background.effectView, effectView);
    XCTAssertEqual(background.subviews.count, 1);
    background.shouldBlurBackgroundView = NO;
    XCTAssertNil(background.effectView);
    XCTAssertEqual(background.subviews.count, 0);
}

- (void)testNavigationBackgroundImageCanRestoreBlurWithoutForwarding {
    QMUIConfiguration *configuration = QMUIConfiguration.sharedInstance;
    BOOL active = configuration.active;
    BOOL standardOnly = configuration.navBarUsesStandardAppearanceOnly;
    BOOL removeEffect = configuration.navBarRemoveBackgroundEffectAutomatically;
    @try {
        // 仅临时激活框架自有配置，结束后恢复，不依赖 Demo 的全局主题。
        [configuration setValue:@YES forKey:@"active"];
        configuration.navBarUsesStandardAppearanceOnly = YES;
        configuration.navBarRemoveBackgroundEffectAutomatically = YES;
        UINavigationBar *bar = QMUINoBackgroundImageForwardingNavigationBar.new;
        UINavigationBarAppearance *appearance = UINavigationBarAppearance.new;
        [appearance configureWithOpaqueBackground];
        appearance.backgroundImage = [UIImage qmui_imageWithColor:UIColor.redColor];
        bar.standardAppearance = appearance;
        [bar setBackgroundImage:nil forBarMetrics:UIBarMetricsDefault];
        bar.barStyle = UIBarStyleDefault;
        XCTAssertNil(bar.standardAppearance.backgroundImage);
        XCTAssertNotNil(bar.standardAppearance.backgroundEffect);
        for (NSString *key in @[@"scrollEdgeAppearance", @"compactAppearance", @"compactScrollEdgeAppearance"]) {
            UINavigationBarAppearance *item = [bar valueForKey:key];
            XCTAssertNotNil(item);
            XCTAssertNil(item.backgroundImage);
            XCTAssertNotNil(item.backgroundEffect);
        }
        UIImage *image = [UIImage qmui_imageWithColor:UIColor.blueColor];
        [bar setBackgroundImage:image forBarMetrics:UIBarMetricsDefault];
        XCTAssertEqual(bar.standardAppearance.backgroundImage, image);
        XCTAssertNil(bar.standardAppearance.backgroundEffect);
    } @finally {
        configuration.navBarUsesStandardAppearanceOnly = standardOnly;
        configuration.navBarRemoveBackgroundEffectAutomatically = removeEffect;
        [configuration setValue:@(active) forKey:@"active"];
    }
}

- (void)testInteractivePopObservesBothSystemRecognizers {
    QMUINavigationController *nav = [[QMUINavigationController alloc] initWithRootViewController:UIViewController.new];
    [nav loadViewIfNeeded];
    [nav viewDidLayoutSubviews];
    XCTAssertEqual([nav valueForKey:@"observedEdgePopGestureRecognizer"], nav.interactivePopGestureRecognizer);
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) {
        XCTAssertNotNil(nav.interactiveContentPopGestureRecognizer);
        XCTAssertEqual([nav valueForKey:@"observedContentPopGestureRecognizer"], nav.interactiveContentPopGestureRecognizer);
    }
#endif
}

- (void)testInteractivePopWaitsForCancellationAfterCoordinatorIsRemoved {
    QMUIInteractivePopTestNavigationController *nav = QMUIInteractivePopTestNavigationController.new;
    QMUIInteractivePopTestViewController *from = QMUIInteractivePopTestViewController.new;
    QMUIInteractivePopTestViewController *to = QMUIInteractivePopTestViewController.new;
    QMUIInteractivePopTestCoordinator *coordinator = QMUIInteractivePopTestCoordinator.new;
    coordinator.initiallyInteractive = YES;
    coordinator.interactive = YES;
    coordinator.from = from;
    coordinator.to = to;
    nav.testCoordinator = coordinator;
    QMUIInteractivePopTestGestureRecognizer *gesture = QMUIInteractivePopTestGestureRecognizer.new;
    gesture.testState = UIGestureRecognizerStateBegan;
    [nav handleInteractivePopGestureRecognizer:gesture];
    XCTAssertEqual(from.callbackCount, 1);
    XCTAssertEqual(to.callbackCount, 1);
    XCTAssertNotNil(coordinator.interactionChange);
    gesture.testState = UIGestureRecognizerStateChanged;
    [nav handleInteractivePopGestureRecognizer:gesture];
    XCTAssertTrue(from.qmui_navigationControllerPopGestureRecognizerChanging);
    nav.testCoordinator = nil;
    gesture.testState = UIGestureRecognizerStateEnded;
    [nav handleInteractivePopGestureRecognizer:gesture];
    XCTAssertEqual(from.callbackCount, 2); // 结果未确定时，不提前报告成功。
    coordinator.cancelled = YES;
    coordinator.interactive = NO;
    coordinator.interactionChange((id)coordinator);
    XCTAssertEqual(from.callbackCount, 3);
    XCTAssertEqual(to.callbackCount, 3);
    XCTAssertTrue(from.lastCancelled);
    XCTAssertEqual(from.lastFrom, to);
    XCTAssertEqual(from.lastTo, from);
    XCTAssertFalse(from.qmui_navigationControllerPopGestureRecognizerChanging);
    XCTAssertFalse(to.qmui_navigationControllerPopGestureRecognizerChanging);
    coordinator.interactionChange((id)coordinator);
    XCTAssertEqual(from.callbackCount, 3); // 过期的系统回调不能重复通知。

    XCTestExpectation *deferredFlag = [self expectationWithDescription:@"快速松手后不重新进入 changing"];
    dispatch_async(dispatch_get_main_queue(), ^{
        XCTAssertFalse(from.qmui_navigationControllerPopGestureRecognizerChanging);
        XCTAssertFalse(to.qmui_navigationControllerPopGestureRecognizerChanging);
        [deferredFlag fulfill];
    });
    [self waitForExpectations:@[deferredFlag] timeout:1];
}

- (void)testInteractivePopPreservesSuccessAndSystemCancellation {
    for (NSNumber *cancelled in @[@NO, @YES]) {
        QMUIInteractivePopTestNavigationController *nav = QMUIInteractivePopTestNavigationController.new;
        QMUIInteractivePopTestViewController *from = QMUIInteractivePopTestViewController.new;
        QMUIInteractivePopTestViewController *to = QMUIInteractivePopTestViewController.new;
        QMUIInteractivePopTestCoordinator *coordinator = QMUIInteractivePopTestCoordinator.new;
        coordinator.initiallyInteractive = YES;
        coordinator.interactive = YES;
        coordinator.from = from;
        coordinator.to = to;
        nav.testCoordinator = coordinator;
        QMUIInteractivePopTestGestureRecognizer *gesture = QMUIInteractivePopTestGestureRecognizer.new;
        gesture.testState = UIGestureRecognizerStateBegan;
        [nav handleInteractivePopGestureRecognizer:gesture];
        coordinator.interactive = NO;
        coordinator.cancelled = cancelled.boolValue;
        coordinator.interactionChange((id)coordinator);
        nav.testCoordinator = nil;
        gesture.testState = cancelled.boolValue ? UIGestureRecognizerStateCancelled : UIGestureRecognizerStateEnded;
        [nav handleInteractivePopGestureRecognizer:gesture];
        XCTAssertEqual(from.callbackCount, 2);
        XCTAssertEqual(to.callbackCount, 2);
        XCTAssertEqual(from.lastCancelled, cancelled.boolValue);
        XCTAssertEqual(from.lastFrom, cancelled.boolValue ? to : from);
        XCTAssertEqual(from.lastTo, cancelled.boolValue ? from : to);
        XCTAssertNil([nav valueForKey:@"activePopGestureRecognizer"]);
    }
}

- (UIPanGestureRecognizer<QMUIContentPopProtectionTesting> *)contentPopProtectionInView:(UIView *)view {
    Class protectionClass = NSClassFromString(@"_QMUINavigationContentPopGestureRecognizer");
    XCTAssertNotNil(protectionClass);
    UIPanGestureRecognizer<QMUIContentPopProtectionTesting> *protection = [[protectionClass alloc] initWithTarget:nil action:NULL];
    [view addGestureRecognizer:protection];
    return protection;
}

- (void)testContentPopProtectionTracksHorizontalScrollChanges {
    UIView *host = UIView.new;
    UIScrollView *scrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 320, 160)];
    UIView *content = UIView.new;
    [host addSubview:scrollView];
    [scrollView addSubview:content];
    UIPanGestureRecognizer<QMUIContentPopProtectionTesting> *protection = [self contentPopProtectionInView:host];

    // 纯纵向列表不限制内容返回；横向内容及其子视图优先响应拖动。
    scrollView.contentSize = CGSizeMake(320, 1000);
    XCTAssertFalse([protection qmuinc_shouldProtectTouchInView:content]);
    scrollView.contentSize = CGSizeMake(640, 160);
    XCTAssertTrue([protection qmuinc_shouldProtectTouchInView:content]);
    scrollView.contentOffset = CGPointMake(320, 0);
    XCTAssertTrue([protection qmuinc_shouldProtectTouchInView:content]);
    scrollView.scrollEnabled = NO;
    XCTAssertFalse([protection qmuinc_shouldProtectTouchInView:content]);
    scrollView.scrollEnabled = YES;
    scrollView.panGestureRecognizer.enabled = NO;
    XCTAssertFalse([protection qmuinc_shouldProtectTouchInView:content]);
    scrollView.panGestureRecognizer.enabled = YES;
    scrollView.contentSize = CGSizeMake(320, 160);
    scrollView.alwaysBounceHorizontal = YES;
    XCTAssertTrue([protection qmuinc_shouldProtectTouchInView:content]);
    scrollView.bounces = NO;
    XCTAssertFalse([protection qmuinc_shouldProtectTouchInView:content]);
    scrollView.bounces = YES;
    scrollView.alwaysBounceHorizontal = NO;
    scrollView.contentInset = UIEdgeInsetsMake(0, 8, 0, 8);
    XCTAssertTrue([protection qmuinc_shouldProtectTouchInView:content]);
    scrollView.contentInset = UIEdgeInsetsZero;
    XCTAssertFalse([protection qmuinc_shouldProtectTouchInView:content]);
}

- (void)testContentPopProtectionPreservesSliderAndOtherGestures {
    UIView *host = UIView.new;
    UISlider *slider = UISlider.new;
    UIView *thumbContent = UIView.new;
    [host addSubview:slider];
    [slider addSubview:thumbContent];
    UIPanGestureRecognizer<QMUIContentPopProtectionTesting> *protection = [self contentPopProtectionInView:host];
    XCTAssertTrue([protection qmuinc_shouldProtectTouchInView:thumbContent]);
    slider.enabled = NO;
    XCTAssertFalse([protection qmuinc_shouldProtectTouchInView:thumbContent]);
    XCTAssertFalse(protection.cancelsTouchesInView);
    XCTAssertFalse(protection.delaysTouchesBegan);
    XCTAssertFalse(protection.delaysTouchesEnded);

    // 旁路手势不抢占滑块内部手势或边缘返回，也不会被其先识别而破坏保护。
    UIGestureRecognizer *controlPan = UIPanGestureRecognizer.new;
    UIGestureRecognizer *edgePan = UIScreenEdgePanGestureRecognizer.new;
    XCTAssertFalse([protection canPreventGestureRecognizer:controlPan]);
    XCTAssertFalse([protection canPreventGestureRecognizer:edgePan]);
    XCTAssertFalse([protection canBePreventedByGestureRecognizer:controlPan]);
}

- (void)testContentPopProtectionUsesMarkedRegionAndNavigationBoundary {
    UIView *outer = UIView.new;
    UIView *host = UIView.new;
    UIView *region = UIView.new;
    UIView *content = UIView.new;
    [outer addSubview:host];
    [host addSubview:region];
    [region addSubview:content];
    UIPanGestureRecognizer<QMUIContentPopProtectionTesting> *protection = [self contentPopProtectionInView:host];
    XCTAssertFalse(region.qmui_preventsInteractiveContentPopGestureRecognizer);
    XCTAssertFalse([protection qmuinc_shouldProtectTouchInView:content]);
    region.qmui_preventsInteractiveContentPopGestureRecognizer = YES;
    XCTAssertTrue([protection qmuinc_shouldProtectTouchInView:content]);
    region.qmui_preventsInteractiveContentPopGestureRecognizer = NO;
    outer.qmui_preventsInteractiveContentPopGestureRecognizer = YES;
    XCTAssertFalse([protection qmuinc_shouldProtectTouchInView:content]);
}

- (void)testBackGestureVetoIsSharedByEdgeAndContent {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) {
        QMUIBackGestureTestViewController *page = QMUIBackGestureTestViewController.new;
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:UIViewController.new];
        [nav pushViewController:page animated:NO];
        [nav loadViewIfNeeded];
        id<QMUIBackGestureTesting> delegator = nav.qmuinc_backGestureDelegator;
        XCTAssertNotNil(delegator);
        XCTAssertEqual(delegator.protectedEdgeGestureRecognizer, nav.interactivePopGestureRecognizer);
        XCTAssertEqual(delegator.protectedContentGestureRecognizer, nav.interactiveContentPopGestureRecognizer);
        __attribute__((objc_precise_lifetime)) UITouch *touch = UITouch.new;
        delegator.edgeTouch = touch;
        delegator.contentTouch = touch;
        // 尚未识别的 UIPan 不接受 setTranslation，以明确位移验证许可规则。
        XCTAssertTrue([delegator qmuinc_shouldBlockPopForTranslation:CGPointMake(30, 1) touch:delegator.edgeTouch]);
        XCTAssertTrue([delegator qmuinc_shouldBlockPopForTranslation:CGPointMake(30, 1) touch:delegator.contentTouch]);
        XCTAssertEqual(page.popCheckCount, 1);
        // 旧边缘代理不得重复询问业务，也不得给许可手势创建反向失败依赖。
        id<UIGestureRecognizerDelegate> edgeDelegate = nav.interactivePopGestureRecognizer.delegate;
        XCTAssertFalse([edgeDelegate gestureRecognizerShouldBegin:nav.interactivePopGestureRecognizer]);
        XCTAssertEqual(page.popCheckCount, 1);
        XCTAssertFalse([edgeDelegate gestureRecognizer:nav.interactivePopGestureRecognizer shouldBeRequiredToFailByGestureRecognizer:delegator.edgeGestureRecognizer]);
        XCTAssertFalse([edgeDelegate gestureRecognizer:nav.interactivePopGestureRecognizer shouldBeRequiredToFailByGestureRecognizer:delegator.contentGestureRecognizer]);
    }
#endif
}

- (void)testEdgeDelegateVetoPrecedesPermissionGateAndSurvivesDelegateReplacement {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) {
        QMUIBackGestureTestViewController *page = QMUIBackGestureTestViewController.new;
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:UIViewController.new];
        [nav pushViewController:page animated:NO];
        [nav loadViewIfNeeded];
        QMUIBackGestureOriginalDelegate *originalDelegate = QMUIBackGestureOriginalDelegate.new;
        nav.interactivePopGestureRecognizer.delegate = originalDelegate;
        [nav viewDidLayoutSubviews];
        XCTAssertEqual(nav.qmui_interactivePopGestureRecognizerDelegate, originalDelegate);
        XCTAssertNotEqual(nav.interactivePopGestureRecognizer.delegate, originalDelegate);

        id<UIGestureRecognizerDelegate> edgeDelegate = nav.interactivePopGestureRecognizer.delegate;
        id<QMUIBackGestureTesting> delegator = nav.qmuinc_backGestureDelegator;
        QMUIBackGestureTestTouch *touch = QMUIBackGestureTestTouch.new;
        touch.touchedView = page.view;
        [edgeDelegate gestureRecognizer:nav.interactivePopGestureRecognizer shouldReceiveTouch:touch];
        // 系统先询问边缘代理时，必须直接得到 NO，不能等待许可手势事后阻止转场。
        XCTAssertFalse([edgeDelegate gestureRecognizerShouldBegin:nav.interactivePopGestureRecognizer]);
        XCTAssertEqual(page.popCheckCount, 1);
        XCTAssertEqual(originalDelegate.beginCount, 0);

        // 同一触摸继续进入其他代理或许可手势，缓存不能被再次清空。
        [edgeDelegate gestureRecognizer:nav.interactivePopGestureRecognizer shouldReceiveTouch:touch];
        XCTAssertTrue([delegator qmuinc_shouldBlockPopForTranslation:CGPointMake(30, 1) touch:delegator.edgeTouch]);
        delegator.contentTouch = touch;
        XCTAssertTrue([delegator qmuinc_shouldBlockPopForTranslation:CGPointMake(30, 1) touch:delegator.contentTouch]);
        XCTAssertEqual(page.popCheckCount, 1);

        QMUIBackGestureTestTouch *nextTouch = QMUIBackGestureTestTouch.new;
        nextTouch.touchedView = page.view;
        page.allowsPop = YES;
        [edgeDelegate gestureRecognizer:nav.interactivePopGestureRecognizer shouldReceiveTouch:nextTouch];
        XCTAssertTrue([edgeDelegate gestureRecognizerShouldBegin:nav.interactivePopGestureRecognizer]);
        XCTAssertEqual(page.popCheckCount, 2);
        XCTAssertEqual(originalDelegate.beginCount, 1);
    }
#endif
}

- (void)testBackGestureAllowsPopAndChecksEachNewTouch {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) {
        QMUIBackGestureTestViewController *page = QMUIBackGestureTestViewController.new;
        page.allowsPop = YES;
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:UIViewController.new];
        [nav pushViewController:page animated:NO];
        [nav loadViewIfNeeded];
        id<QMUIBackGestureTesting> delegator = nav.qmuinc_backGestureDelegator;
        __attribute__((objc_precise_lifetime)) UITouch *touch = UITouch.new;
        delegator.contentTouch = touch;
        XCTAssertFalse([delegator qmuinc_shouldBlockPopForTranslation:CGPointMake(30, 1) touch:delegator.contentTouch]);
        XCTAssertEqual(page.popCheckCount, 1);

        // 反方向及纵向拖动不应调用返回确认；从右向左布局时反转返回方向。
        XCTAssertFalse([delegator qmuinc_shouldBlockPopForTranslation:CGPointMake(-30, 1) touch:delegator.contentTouch]);
        XCTAssertFalse([delegator qmuinc_shouldBlockPopForTranslation:CGPointMake(1, 30) touch:delegator.contentTouch]);
        XCTAssertEqual(page.popCheckCount, 1);
        __attribute__((objc_precise_lifetime)) UITouch *nextTouch = UITouch.new;
        delegator.contentTouch = nextTouch;
        page.allowsPop = NO;
        nav.view.semanticContentAttribute = UISemanticContentAttributeForceRightToLeft;
        XCTAssertTrue([delegator qmuinc_shouldBlockPopForTranslation:CGPointMake(-30, 1) touch:delegator.contentTouch]);
        XCTAssertEqual(page.popCheckCount, 2);
    }
#endif
}

- (void)testBackGesturePreservesProtectedControlTouches {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) {
        QMUIBackGestureTestViewController *page = QMUIBackGestureTestViewController.new;
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:UIViewController.new];
        [nav pushViewController:page animated:NO];
        [nav loadViewIfNeeded];
        id<QMUIBackGestureTesting> delegator = nav.qmuinc_backGestureDelegator;
        // 独立验证触摸过滤，不依赖系统对当前页面 enabled 的动态设置。
        UIGestureRecognizer *edge = UIPanGestureRecognizer.new;
        UIGestureRecognizer *content = UIPanGestureRecognizer.new;
        delegator.protectedEdgeGestureRecognizer = edge;
        delegator.protectedContentGestureRecognizer = content;
        QMUIBackGestureTestTouch *touch = QMUIBackGestureTestTouch.new;
        UISlider *slider = UISlider.new;
        [page.view addSubview:slider];
        touch.touchedView = slider;
        XCTAssertFalse([delegator gestureRecognizer:delegator.contentGestureRecognizer shouldReceiveTouch:touch]);
        XCTAssertTrue([delegator gestureRecognizer:delegator.edgeGestureRecognizer shouldReceiveTouch:touch]);
        slider.enabled = NO;
        XCTAssertTrue([delegator gestureRecognizer:delegator.contentGestureRecognizer shouldReceiveTouch:touch]);
        XCTAssertEqual(page.popCheckCount, 0);
        for (UIGestureRecognizer *gate in @[delegator.edgeGestureRecognizer, delegator.contentGestureRecognizer]) {
            XCTAssertFalse(gate.cancelsTouchesInView);
            XCTAssertFalse(gate.delaysTouchesBegan);
            XCTAssertFalse(gate.delaysTouchesEnded);
            XCTAssertFalse([gate canPreventGestureRecognizer:slider.gestureRecognizers.firstObject]);
            XCTAssertFalse([gate canBePreventedByGestureRecognizer:edge]);
        }
    }
#endif
}

- (void)testBackGestureInstallationIsStableAndManualPopIsAllowed {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 260000
    if (@available(iOS 26.0, *)) {
        QMUIBackGestureTestViewController *root = QMUIBackGestureTestViewController.new;
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:root];
        [nav loadViewIfNeeded];
        id<QMUIBackGestureTesting> delegator = nav.qmuinc_backGestureDelegator;
        NSUInteger gestureCount = nav.view.gestureRecognizers.count;
        id<UIGestureRecognizerDelegate> contentDelegate = nav.interactiveContentPopGestureRecognizer.delegate;
        [nav viewDidLayoutSubviews];
        [nav viewDidLayoutSubviews];
        XCTAssertEqual(nav.qmuinc_backGestureDelegator, delegator);
        XCTAssertEqual(nav.view.gestureRecognizers.count, gestureCount);
        XCTAssertEqual(nav.interactiveContentPopGestureRecognizer.delegate, contentDelegate);
        __attribute__((objc_precise_lifetime)) UITouch *touch = UITouch.new;
        delegator.edgeTouch = touch;
        XCTAssertFalse([delegator qmuinc_shouldBlockPopForTranslation:CGPointMake(30, 1) touch:delegator.edgeTouch]);
        XCTAssertEqual(root.popCheckCount, 0);
        QMUIBackGestureTestViewController *page = QMUIBackGestureTestViewController.new;
        [nav pushViewController:page animated:NO];
        XCTAssertEqual([nav popViewControllerAnimated:NO], page);
        XCTAssertEqual(page.popCheckCount, 0);
    }
#endif
}

- (void)testValueForKey {
    UINavigationBar *navigationBar = [UINavigationBar new];
    [navigationBar sizeToFit];
    // 新系统的内部容器允许为空，验证查询安全性，不限定 UIKit 私有层级。
    XCTAssertNoThrow((void)navigationBar.qmui_backgroundView);
    XCTAssertNoThrow((void)navigationBar.qmui_shadowImageView);
    
    UITabBar *tabBar = [UITabBar new];
    [tabBar sizeToFit];
    XCTAssertNoThrow((void)tabBar.qmui_backgroundView);
    XCTAssertNoThrow((void)tabBar.qmui_shadowImageView);
    
    UISearchBar *searchBar = [UISearchBar new];
    searchBar.scopeButtonTitles = @[@"A", @"B"];
    searchBar.showsCancelButton = YES;
    [searchBar sizeToFit];
    XCTAssertEqual([searchBar qmui_valueForKey:@"searchTextField"], searchBar.searchTextField);
    XCTAssertNoThrow((void)searchBar.qmui_backgroundView);
    XCTAssertNoThrow((void)searchBar.qmui_cancelButton);
    XCTAssertNoThrow((void)searchBar.qmui_segmentedControl);
    XCTAssertNil(searchBar.qmui_searchController);
}

@end
