/**
 * Tencent is pleased to support the open source community by making QMUI_iOS available.
 * Copyright (C) 2016-2021 THL A29 Limited, a Tencent company. All rights reserved.
 * Licensed under the MIT License (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at
 * http://opensource.org/licenses/MIT
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.
 */

//
//  UIInterface+QMUI.m
//  QMUIKit
//
//  Created by QMUI Team on 2018/12/20.
//

#import "UIInterface+QMUI.h"
#import "QMUICore.h"

// 物理方向与界面方向的左右横屏枚举相反，不能直接比较或强制转换。
static UIInterfaceOrientation QMUIInterfaceOrientationFromDeviceOrientation(UIDeviceOrientation deviceOrientation) {
    switch (deviceOrientation) {
        case UIDeviceOrientationPortrait:
            return UIInterfaceOrientationPortrait;
        case UIDeviceOrientationPortraitUpsideDown:
            return UIInterfaceOrientationPortraitUpsideDown;
        case UIDeviceOrientationLandscapeLeft:
            return UIInterfaceOrientationLandscapeRight;
        case UIDeviceOrientationLandscapeRight:
            return UIInterfaceOrientationLandscapeLeft;
        default:
            return UIInterfaceOrientationUnknown;
    }
}

@implementation QMUIHelper (QMUI_Interface)

QMUISynthesizeNSIntegerProperty(lastOrientationChangedByHelper, setLastOrientationChangedByHelper)

- (void)handleDeviceOrientationNotification:(NSNotification *)notification {
    QMUILogInfo(@"Interface (QMUI)", @"device orientation did change to %@", @(((UIDevice *)([notification.object isKindOfClass:UIDevice.class] ? notification.object : UIDevice.currentDevice)).orientation));
    
    // 如果是由 setValue:forKey: 方式修改方向而走到这个 notification 的话，理论上是不需要重置为 Unknown 的，但因为在 UIViewController (QMUI) 那边会再次记录旋转前的值，所以这里就算重置也无所谓
    [QMUIHelper sharedInstance].lastOrientationChangedByHelper = UIDeviceOrientationUnknown;
}

+ (UIDeviceOrientation)deviceOrientationWithInterfaceOrientationMask:(UIInterfaceOrientationMask)mask {
    if (UIDevice.currentDevice.orientation == UIDeviceOrientationUnknown) return UIDeviceOrientationUnknown;
    
    // mask 包含多个方向值，如果要转换的 mask 方向已经包含当前设备方向，则直接返回当前设备方向，以免外面要用这个返回值去做方向旋转时出现不必要的旋转。
    UIInterfaceOrientation orientation = QMUIInterfaceOrientationFromDeviceOrientation(UIDevice.currentDevice.orientation);
    if (orientation != UIInterfaceOrientationUnknown && [self interfaceOrientationMask:mask containsInterfaceOrientation:orientation]) {
        return UIDevice.currentDevice.orientation;
    }
    
    if ((mask & UIInterfaceOrientationMaskPortrait) == UIInterfaceOrientationMaskPortrait) {
        return UIDeviceOrientationPortrait;
    }
    if ((mask & UIInterfaceOrientationMaskLandscape) == UIInterfaceOrientationMaskLandscape) {
        return [UIDevice currentDevice].orientation == UIDeviceOrientationLandscapeLeft ? UIDeviceOrientationLandscapeLeft : UIDeviceOrientationLandscapeRight;
    }
    if ((mask & UIInterfaceOrientationMaskLandscapeLeft) == UIInterfaceOrientationMaskLandscapeLeft) {
        return UIDeviceOrientationLandscapeRight;
    }
    if ((mask & UIInterfaceOrientationMaskLandscapeRight) == UIInterfaceOrientationMaskLandscapeRight) {
        return UIDeviceOrientationLandscapeLeft;
    }
    if ((mask & UIInterfaceOrientationMaskPortraitUpsideDown) == UIInterfaceOrientationMaskPortraitUpsideDown) {
        return UIDeviceOrientationPortraitUpsideDown;
    }
    return [UIDevice currentDevice].orientation;
}

+ (BOOL)interfaceOrientationMask:(UIInterfaceOrientationMask)mask containsDeviceOrientation:(UIDeviceOrientation)deviceOrientation {
    return [self interfaceOrientationMask:mask containsInterfaceOrientation:QMUIInterfaceOrientationFromDeviceOrientation(deviceOrientation)];
}

+ (BOOL)interfaceOrientationMask:(UIInterfaceOrientationMask)mask containsInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    switch (interfaceOrientation) {
        case UIInterfaceOrientationPortrait:
        case UIInterfaceOrientationPortraitUpsideDown:
        case UIInterfaceOrientationLandscapeLeft:
        case UIInterfaceOrientationLandscapeRight:
            // 直接检查对应位，支持竖屏与任一横屏组合，避免只匹配第一个方向。
            return (mask & ((UIInterfaceOrientationMask)1 << interfaceOrientation)) != 0;
        default:
            // 未知、平放等方向不触发额外旋转。
            return YES;
    }
}

+ (CGFloat)angleForTransformWithInterfaceOrientation:(UIInterfaceOrientation)orientation {
    CGFloat angle;
    switch (orientation)
    {
        case UIInterfaceOrientationPortraitUpsideDown:
            angle = M_PI;
            break;
        case UIInterfaceOrientationLandscapeLeft:
            angle = -M_PI_2;
            break;
        case UIInterfaceOrientationLandscapeRight:
            angle = M_PI_2;
            break;
        default:
            angle = 0.0;
            break;
    }
    return angle;
}

+ (CGAffineTransform)transformForCurrentInterfaceOrientation {
    return [QMUIHelper transformWithInterfaceOrientation:QMUIHelper.interfaceOrientation];
}

+ (CGAffineTransform)transformWithInterfaceOrientation:(UIInterfaceOrientation)orientation {
    CGFloat angle = [QMUIHelper angleForTransformWithInterfaceOrientation:orientation];
    return CGAffineTransformMakeRotation(angle);
}
@end

@implementation UIViewController (QMUI_Interface)

+ (void)load {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        
        // iOS 16 及以后，系统会在界面切换时自动旋转设备方向，所以不需要以下逻辑。
        if (@available(iOS 16.0, *)) return;

        // 实现 AutomaticallyRotateDeviceOrientation 开关的功能
        OverrideImplementation([UIViewController class], @selector(viewWillAppear:), ^id(__unsafe_unretained Class originClass, SEL originCMD, IMP (^originalIMPProvider)(void)) {
            return ^(UIViewController *selfObject, BOOL animated) {
                
                // call super
                void (*originSelectorIMP)(id, SEL, BOOL);
                originSelectorIMP = (void (*)(id, SEL, BOOL))originalIMPProvider();
                originSelectorIMP(selfObject, originCMD, animated);
                
                if (!AutomaticallyRotateDeviceOrientation) {
                    return;
                }
                
                // 某些情况下的 UIViewController 不具备决定设备方向的权利，具体请看 https://github.com/Tencent/QMUI_iOS/issues/291
                if (![selfObject qmui_shouldForceRotateDeviceOrientation]) {
                    BOOL isRootViewController = [selfObject isViewLoaded] && selfObject.view.window.rootViewController == selfObject;
                    BOOL isChildViewController = [selfObject.tabBarController.viewControllers containsObject:selfObject] || [selfObject.navigationController.viewControllers containsObject:selfObject] || [selfObject.splitViewController.viewControllers containsObject:selfObject];
                    BOOL hasRightsOfRotateDeviceOrientaion = isRootViewController || isChildViewController;
                    if (!hasRightsOfRotateDeviceOrientaion) {
                        return;
                    }
                }
                
                
                UIInterfaceOrientation statusBarOrientation = QMUIHelper.interfaceOrientation;
                UIDeviceOrientation lastOrientationChangedByHelper = [QMUIHelper sharedInstance].lastOrientationChangedByHelper;
                BOOL shouldConsiderLastChanged = lastOrientationChangedByHelper != UIDeviceOrientationUnknown;
                UIDeviceOrientation deviceOrientation = [UIDevice currentDevice].orientation;
                
                // 虽然这两者的 unknow 值是相同的，但在启动 App 时可能只有其中一个是 unknown
                if (statusBarOrientation == UIInterfaceOrientationUnknown || deviceOrientation == UIDeviceOrientationUnknown) return;
                
                // 之前没用私有接口修改过，那就按最标准的方式去旋转
                if (!shouldConsiderLastChanged) {
                    // 如果当前设备方向和界面支持的方向不一致，则主动进行旋转
                    UIDeviceOrientation deviceOrientationToRotate = [QMUIHelper interfaceOrientationMask:selfObject.supportedInterfaceOrientations containsDeviceOrientation:deviceOrientation] ? deviceOrientation : [QMUIHelper deviceOrientationWithInterfaceOrientationMask:selfObject.supportedInterfaceOrientations];
                    if ([selfObject qmui_rotateToInterfaceOrientation:(UIInterfaceOrientation)deviceOrientationToRotate]) {
                        [QMUIHelper sharedInstance].lastOrientationChangedByHelper = deviceOrientation;
                    } else {
                        [QMUIHelper sharedInstance].lastOrientationChangedByHelper = UIDeviceOrientationUnknown;
                    }
                    return;
                }
                
                // 用私有接口修改过方向，但下一个界面和当前界面方向不相同，则要把修改前记录下来的那个设备方向考虑进来
                UIDeviceOrientation deviceOrientationToRotate = [QMUIHelper interfaceOrientationMask:selfObject.supportedInterfaceOrientations containsDeviceOrientation:lastOrientationChangedByHelper] ? lastOrientationChangedByHelper : [QMUIHelper deviceOrientationWithInterfaceOrientationMask:selfObject.supportedInterfaceOrientations];
                [selfObject qmui_rotateToInterfaceOrientation:(UIInterfaceOrientation)deviceOrientationToRotate];
            };
        });
    });
}

- (BOOL)qmui_rotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    QMUILogInfo(@"Interface (QMUI)", @"try rotating to %@", @(interfaceOrientation));
    
#ifdef IOS16_SDK_ALLOWED
    if (@available(iOS 16.0, *)) {
        
        [self setNeedsUpdateOfSupportedInterfaceOrientations];
        
        if (interfaceOrientation == UIInterfaceOrientationUnknown) return NO;
        UIInterfaceOrientationMask mask = 1 << interfaceOrientation;
        UIWindowScene *scene = (self.isViewLoaded ? self.view.window : nil).windowScene ?: QMUIHelper.keyWindow.windowScene;
        if (!scene) return NO;
        [scene requestGeometryUpdateWithPreferences:[[UIWindowSceneGeometryPreferencesIOS alloc] initWithInterfaceOrientations:mask] errorHandler:^(NSError * _Nonnull error) {
            QMUILogWarn(@"Interface (QMUI)", @"场景旋转请求失败：%@", error);
        }];
        // 系统异步处理；YES 表示已发出请求，不代表旋转已完成。
        return YES;
    }
#endif
    
    if ([UIDevice currentDevice].orientation == (UIDeviceOrientation)interfaceOrientation) {
        [UIViewController attemptRotationToDeviceOrientation];
        return NO;
    }
    [[UIDevice currentDevice] setValue:@(interfaceOrientation) forKey:@"orientation"];
    return YES;
}

- (void)qmui_setNeedsUpdateOfSupportedInterfaceOrientations {
#ifdef IOS16_SDK_ALLOWED
    if (@available(iOS 16.0, *)) {
        [self setNeedsUpdateOfSupportedInterfaceOrientations];
    } else
#endif
    {
        UIDeviceOrientation orientation = [QMUIHelper deviceOrientationWithInterfaceOrientationMask:self.supportedInterfaceOrientations];
        [[UIDevice currentDevice] setValue:@(orientation) forKey:@"orientation"];
    }
}

- (BOOL)qmui_shouldForceRotateDeviceOrientation {
    return NO;
}

@end
