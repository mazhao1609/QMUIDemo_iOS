/**
 * Tencent is pleased to support the open source community by making QMUI_iOS available.
 * Copyright (C) 2016-2021 THL A29 Limited, a Tencent company. All rights reserved.
 * Licensed under the MIT License (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 * http://opensource.org/licenses/MIT
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
 */

//
//  QMUICommonDefinesTests.m
//  QMUIKitTests
//
//  Created by MoLice on 2020/5/12.
//

#import <XCTest/XCTest.h>
#import <QMUIKit/QMUIKit.h>

/// 使用独立子类模拟硬件标识，不修改 QMUIHelper 的实际设备缓存。
static NSString *qmui_testDeviceModel;
@interface QMUIDeviceModelTestHelper : QMUIHelper
@end
@implementation QMUIDeviceModelTestHelper
+ (NSString *)deviceModel {
    return qmui_testDeviceModel ?: @"Unknown Device";
}
+ (BOOL)isIPhone {
    return [self.deviceModel hasPrefix:@"iPhone"];
}
@end

/// 为多窗口布局测试提供可控的安全区。
@interface QMUITestSafeAreaView : UIView
@property(nonatomic, assign) UIEdgeInsets qmui_testSafeAreaInsets;
@end

@implementation QMUITestSafeAreaView
- (UIEdgeInsets)safeAreaInsets {
    return self.qmui_testSafeAreaInsets;
}
@end

@interface QMUICommonDefinesTests : XCTestCase

@end

@implementation QMUICommonDefinesTests

- (void)testOrientationMaskSupportsCombinedInterfaceOrientations {
    // 竖屏与单侧横屏组合时，每个支持的方向都应正确匹配。
    UIInterfaceOrientationMask mask = UIInterfaceOrientationMaskPortrait | UIInterfaceOrientationMaskLandscapeRight;
    XCTAssertTrue([QMUIHelper interfaceOrientationMask:mask containsInterfaceOrientation:UIInterfaceOrientationPortrait]);
    XCTAssertTrue([QMUIHelper interfaceOrientationMask:mask containsInterfaceOrientation:UIInterfaceOrientationLandscapeRight]);
    XCTAssertFalse([QMUIHelper interfaceOrientationMask:mask containsInterfaceOrientation:UIInterfaceOrientationLandscapeLeft]);
    XCTAssertFalse([QMUIHelper interfaceOrientationMask:mask containsInterfaceOrientation:UIInterfaceOrientationPortraitUpsideDown]);
    XCTAssertFalse([QMUIHelper interfaceOrientationMask:0 containsInterfaceOrientation:UIInterfaceOrientationPortrait]);
}

- (void)testOrientationMaskConvertsPhysicalLandscapeDirections {
    // 物理左横屏对应界面右横屏，反向亦然。
    XCTAssertTrue([QMUIHelper interfaceOrientationMask:UIInterfaceOrientationMaskLandscapeRight containsDeviceOrientation:UIDeviceOrientationLandscapeLeft]);
    XCTAssertFalse([QMUIHelper interfaceOrientationMask:UIInterfaceOrientationMaskLandscapeLeft containsDeviceOrientation:UIDeviceOrientationLandscapeLeft]);
    XCTAssertTrue([QMUIHelper interfaceOrientationMask:UIInterfaceOrientationMaskLandscapeLeft containsDeviceOrientation:UIDeviceOrientationLandscapeRight]);
    XCTAssertFalse([QMUIHelper interfaceOrientationMask:UIInterfaceOrientationMaskLandscapeRight containsDeviceOrientation:UIDeviceOrientationLandscapeRight]);
    XCTAssertTrue([QMUIHelper interfaceOrientationMask:UIInterfaceOrientationMaskPortrait containsDeviceOrientation:UIDeviceOrientationPortrait]);
    XCTAssertTrue([QMUIHelper interfaceOrientationMask:UIInterfaceOrientationMaskPortraitUpsideDown containsDeviceOrientation:UIDeviceOrientationPortraitUpsideDown]);
    // 无有效界面方向时无需强制旋转。
    for (NSNumber *orientation in @[@(UIDeviceOrientationUnknown), @(UIDeviceOrientationFaceUp), @(UIDeviceOrientationFaceDown)]) {
        XCTAssertTrue([QMUIHelper interfaceOrientationMask:UIInterfaceOrientationMaskPortrait containsDeviceOrientation:(UIDeviceOrientation)orientation.integerValue]);
    }
}

- (void)testDynamicIslandDistinguishesNotchedAndNewDevices {
    @try {
        // e 系列有刘海但没有灵动岛；普通 iPhone 14 和未知设备也不能误判。
        for (NSString *model in @[@"iPhone17,5", @"iPhone18,5", @"iPhone14,7", @"iPad17,1", @"iPhone99,1"]) {
            qmui_testDeviceModel = model;
            XCTAssertFalse(QMUIDeviceModelTestHelper.isDynamicIslandDevice, @"%@", model);
        }
        // 覆盖旧 Pro、最新普通版、Air、Duo，以及 Pro Max 的不同地区标识。
        for (NSString *model in @[@"iPhone15,2", @"iPhone17,3", @"iPhone18,3", @"iPhone18,4", @"iPhone19,2", @"iPhone19,3", @"iPhone19,4", @"iPhone19,7"]) {
            qmui_testDeviceModel = model;
            XCTAssertTrue(QMUIDeviceModelTestHelper.isDynamicIslandDevice, @"%@", model);
        }
    } @finally {
        qmui_testDeviceModel = nil;
    }
}

- (void)testCGFloatCalcOperator {
    CGFloat a = 0.999;
    CGFloat b = 1.011;
    CGFloat c = 1.033;
    CGFloat d = 1.099;
    
    XCTAssertTrue(CGFloatEqualToFloat(a, b));
    XCTAssertTrue(CGFloatEqualToFloat(b, c));
    XCTAssertTrue(CGFloatEqualToFloat(c, d));
    
    XCTAssertTrue(CGFloatEqualToFloatWithPrecision(a, b, 1));
    XCTAssertTrue(CGFloatEqualToFloatWithPrecision(b, c, 1));
    XCTAssertFalse(CGFloatEqualToFloatWithPrecision(c, d, 1));
    
    XCTAssertFalse(CGFloatEqualToFloatWithPrecision(a, b, 2));
    XCTAssertFalse(CGFloatEqualToFloatWithPrecision(b, c, 2));
    XCTAssertFalse(CGFloatEqualToFloatWithPrecision(c, d, 2));
}

- (void)testLayoutMetricsUseTheViewWindowContext {
    UIWindow *firstWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 390, 844)];
    UIWindow *secondWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 820, 600)];
    QMUITestSafeAreaView *firstView = [[QMUITestSafeAreaView alloc] initWithFrame:firstWindow.bounds];
    QMUITestSafeAreaView *secondView = [[QMUITestSafeAreaView alloc] initWithFrame:secondWindow.bounds];
    firstView.qmui_testSafeAreaInsets = UIEdgeInsetsMake(59, 0, 34, 0);
    secondView.qmui_testSafeAreaInsets = UIEdgeInsetsMake(24, 0, 20, 0);
    [firstWindow addSubview:firstView];
    [secondWindow addSubview:secondView];

    XCTAssertEqualObjects([QMUIHelper windowForView:firstView], firstWindow);
    XCTAssertEqualObjects([QMUIHelper windowForView:secondView], secondWindow);
    XCTAssertEqual([QMUIHelper safeAreaInsetsForView:firstView].top, 59);
    XCTAssertEqual([QMUIHelper safeAreaInsetsForView:secondView].bottom, 20);
    XCTAssertFalse(IS_LANDSCAPE_FOR_VIEW(firstView));
}

- (void)testBarMetricsFollowActualBarBounds {
    UINavigationController *navigationController = [[UINavigationController alloc] initWithRootViewController:[UIViewController new]];
    navigationController.navigationBar.frame = CGRectMake(0, 0, 390, 57);
    XCTAssertEqualWithAccuracy([QMUIHelper navigationBarHeightForViewController:navigationController], 57, 0.01);

    UITabBarController *tabBarController = [UITabBarController new];
    tabBarController.viewControllers = @[[UIViewController new]];
    tabBarController.tabBar.frame = CGRectMake(0, 0, 390, 83);
    XCTAssertEqualWithAccuracy([QMUIHelper tabBarHeightForViewController:tabBarController], 83, 0.01);

    navigationController.navigationBar.hidden = YES;
    tabBarController.tabBar.hidden = YES;
    XCTAssertEqual([QMUIHelper navigationBarHeightForViewController:navigationController], 0);
    XCTAssertEqual([QMUIHelper tabBarHeightForViewController:tabBarController], 0);
}

- (void)testSplitAndFoldedWindowSizeNotificationsIdentifyEachScene {
    UIWindow *firstWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 390, 844)];
    UIWindow *secondWindow = [[UIWindow alloc] initWithFrame:CGRectMake(0, 0, 820, 600)];
    UIViewController *firstRootViewController = [UIViewController new];
    UIViewController *secondRootViewController = [UIViewController new];
    firstWindow.rootViewController = firstRootViewController;
    secondWindow.rootViewController = secondRootViewController;
    firstWindow.hidden = NO;
    secondWindow.hidden = NO;
    [firstWindow layoutIfNeeded];
    [secondWindow layoutIfNeeded];

    XCTestExpectation *expectation = [self expectationWithDescription:@"每个 Scene 的尺寸通知均包含源窗口"];
    __block NSUInteger notificationCount = 0;
    id observer = [[NSNotificationCenter defaultCenter] addObserverForName:QMUIAppSizeWillChangeNotification object:nil queue:nil usingBlock:^(NSNotification * _Nonnull note) {
        UIWindow *sourceWindow = note.userInfo[QMUISourceWindowUserInfoKey];
        if (sourceWindow == firstWindow || sourceWindow == secondWindow) {
            CGSize precedingSize = [note.userInfo[QMUIPrecedingAppSizeUserInfoKey] CGSizeValue];
            CGSize followingSize = [note.userInfo[QMUIFollowingAppSizeUserInfoKey] CGSizeValue];
            if (sourceWindow == firstWindow) {
                XCTAssertEqualWithAccuracy(precedingSize.width, 390, 0.01);
                XCTAssertEqualWithAccuracy(followingSize.width, 500, 0.01);
            } else {
                XCTAssertEqualWithAccuracy(precedingSize.width, 820, 0.01);
                XCTAssertEqualWithAccuracy(followingSize.height, 820, 0.01);
            }
            notificationCount += 1;
            if (notificationCount == 2) [expectation fulfill];
        }
    }];

    // 手动触发系统回调以覆盖两个独立窗口的尺寸通知；UIKit 正常流程会提供非空 coordinator。
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wnonnull"
    [firstRootViewController viewWillTransitionToSize:CGSizeMake(500, 844) withTransitionCoordinator:nil];
    [secondRootViewController viewWillTransitionToSize:CGSizeMake(600, 820) withTransitionCoordinator:nil];
#pragma clang diagnostic pop
    [self waitForExpectationsWithTimeout:0.5 handler:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:observer];
    XCTAssertEqual(notificationCount, 2);
}

@end
