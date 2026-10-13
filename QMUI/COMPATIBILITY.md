# iOS 15 及现代系统兼容说明

Created by Ma on 2026/10/09.

最低部署版本已统一为 iOS 15。框架目录与 Demo 内嵌的 QMUI 使用相同修改。

## 导航栏磨砂与显隐占位（2026/10/12）

Demo 的“浅色（磨砂）”显式使用半透明主题色和浅色系统磨砂，背景图保持为空，避免旧版本的残留背景与 iOS 26 的白色背景呈现两种效果。默认、深色及其他页面的背景配置保留，系统按钮仍使用现有独立配置。

iOS 26 的导航栏横向 frame 在首次页面布局后才更新，旧版 `qmui_navigationBarMaxYInViewCoordinator` 据此推断显隐会产生错误首帧。新路径在导航转场中读取各页面已开启接管的 `preferredNavigationBarHidden`，仅按纵向坐标计算显示页占位；隐藏页立即返回 0。离栈页面通过公开导航转场上下文及祖先视图获取导航控制器，不假定容器层数；转场之外仍以系统实际显隐为准，iOS 15–25 保留原计算路径。

坐标 Demo 移除固定一秒的延迟刷新，改为随系统转场和完成回调布局，交互取消也会触发结束校正。iOS 16.0、26.3 临时宿主采样真实程序化 push/pop 的四种显隐组合并对比磨砂截图；iOS 26 新增首帧坐标回归及既有背景转场、磨砂恢复回归共 3 项通过。局部语法检查和框架增量编译通过，未进行 Demo 全量构建或实机手势复测。

## 已处理的问题

- 导航栏内容、背景、搜索栏及滑块等视图查询不再依赖易失效的私有 KVC 路径；找不到内部容器时返回 `nil`，调用方需允许为空。
- 运行时替换函数跳过不存在的类或方法；iOS 26+ 不应用旧导航栏间距、标题锁定及假导航栏转场补丁。
- 导航栏、TabBar 的效果通过公开 appearance 更新，移除系统私有背景效果注入；修复滚动边缘 appearance 的转场复制目标错误，补齐导航栏与工具栏紧凑状态。
- 窗口、状态栏、方向和屏幕查询优先使用 Scene 上下文；浮层绑定宿主场景，键盘坐标优先使用目标视图窗口，修复无主窗口时坐标转换结果遗漏。
- 图片资源改用 `UniformTypeIdentifiers`、`PHAssetResource` 与 `requestImageDataAndOrientationForAsset:`；转换 EXIF 方向以保持原接口返回约定。
- 导航按钮使用 `UIButtonConfiguration`。`QMUIButton` 增加 `qmui_contentInsets`、`qmui_titleInsets`、`qmui_imageInsets`；旧接口保留转发，配置按钮的布局交由 UIKit。
- 活动指示器改用 Medium / Large，Toast 改用设备方向通知，内部边框改用 `CALayer.maskedCorners`。

旧系统接口仅在必要兼容边界保留：Scene 连接前的 `UIScreen.mainScreen` 兜底，以及手工布局 `QMUIButton` 初始化时的图片高亮/禁用渲染标志。

## 设备与判断宏

- 补齐 iPhone SE 第三代、16e、17 / 17 Pro / 17 Pro Max / Air / 17e、18 Pro / 18 Pro Max；未知型号保留原始硬件标识。
- 补齐 iPad 第九、十代、Air M3 / M4、iPad A16、mini A17 Pro 和 Pro M5；修正 Air M2 的尺寸及 Pro M4 的名称。
- 增加 `IS_69INCH_SCREEN`、`IS_63INCH_SCREEN`、`IS_65INCH_SCREEN_AND_IPHONEAIR`；Air 的 420×912 与旧款 6.5 英寸的 414×896 分别判断，旧宏保留原意。尺寸宏按当前逻辑尺寸判断，放大显示可能不匹配标准尺寸。
- 增加 `IOS26_SDK_ALLOWED`、`IOS27_SDK_ALLOWED`，保持旧 SDK 宏的条件定义方式；这些宏判断编译 SDK，运行系统仍需 `@available`。
- 灵动岛改用确认的硬件标识，排除 16e、17e 和未知设备；普通 / 紧凑屏幕按实际宽度及放大显示判断。安全区优先使用窗口真实值，缺少静态数据且窗口未就绪时返回零，需在布局阶段重新读取。

型号标识核对来源：[IPSW.me](https://api.ipsw.me/v4/devices)、[DeviceKit](https://github.com/devicekit/DeviceKit/blob/master/Source/Device.generated.swift)。屏幕参数来源：[iPhone Air](https://www.apple.com/iphone-air/specs/)、[iPhone 17](https://www.apple.com/iphone-17/specs/)、[iPhone 17e](https://www.apple.com/iphone-17e/specs/)、[iPhone 18 Pro](https://www.apple.com/iphone-18-pro/specs/)。

## 多窗口与折叠屏布局建议（2026/10/13）

设备宏只适合作为没有 view 上下文时的兼容回退。导航栏、TabBar、状态栏和底部工具栏的实际高度应在页面布局阶段读取 `view.safeAreaInsets`、`navigationBar.bounds`、`tabBar.bounds` 及 `layoutMargins`，不能再用屏幕型号推导业务布局。QMUI 新增 `QMUIHelper.windowForView:`、`safeAreaInsetsForView:`、`interfaceOrientationForView:`、`navigationBarHeightForViewController:` 与 `tabBarHeightForViewController:`，并提供 `SafeAreaInsetsForView(view)`、`IS_LANDSCAPE_FOR_VIEW(view)`、`NavigationBarHeightForViewController(vc)`、`TabBarHeightForViewController(vc)`、`NavigationContentTopForViewController(vc)` 宏，弹窗、图片选择器等组件已改为使用所属窗口的安全区。

Scene 连接、分屏、旋转和折叠状态变化都会触发布局；不要缓存全局 `keyWindow`、`UIScreen.mainScreen`、状态栏高度或设备尺寸分类。需要跨窗口刷新主题时使用 `QMUIHelper.applicationWindows`，需要在当前页面布局时传入具体 view。`NavigationContentTopConstant`、`TabBarHeight` 等旧宏仍保留给历史代码，但不应作为新页面的主布局依据。

回归用例覆盖两个独立窗口的安全区与窗口归属、动态导航栏 / TabBar 实际高度、导航栏隐藏状态，以及每个 Scene 的尺寸变化通知和源窗口标识；尺寸样例覆盖窄屏、宽屏和横向展开状态。测试源码位于 `QMUI/QMUIKitTests/Core/QMUICommonDefinesTests.m`。

## 弃用 API 警告清理（2026/10/10）

Demo 的 `QMUIButton` 内边距统一改用 `qmui_contentInsets` / `qmui_imageInsets`；系统按钮内边距示例改用 `UIButtonConfiguration.contentInsets` 与 `imagePadding`，标题、图片的交互通过配置对象更新。视频拍摄类型改用 `UTTypeMovie.identifier`，Aspects 的 `OSSpinLock` 改为 `os_unfair_lock`。未新增全局警告屏蔽。

使用 iOS 26.5 SDK 对 297 个框架、Demo 与测试实现文件进行语法扫描，该轮发现的 37 处弃用警告已迁移；修改文件额外以 `-Werror=deprecated-declarations` 检查。此前必要的局部兼容屏蔽仍保留。该轮仅进行了语法扫描，后续工程编译结果见下节。

## 工程剩余警告清理（2026/10/10）

按 Xcode 工程实际警告设置编译 Demo，定位并清理 18 处警告：

- 设备方向明确转换为界面方向后再判断掩码，修正左右横屏混用与竖屏、单侧横屏组合判断不完整的问题。
- 图片处理的 alpha 信息显式转换为 `CGBitmapInfo`；动态图片私有方法改为分类声明。
- Demo 选色回调迁移到 iOS 15 的 `colorPickerViewController:didSelectColor:continuously:`。
- `QMUIButton` 的 6 个旧内边距转发方法保留业务兼容，仅在这组方法内屏蔽 `-Wdeprecated-implementations`，未修改工程全局警告设置。

另外修正 Aspects 源码的 2 处 block 捕获 `NSError **` 警告：锁内使用本地错误变量，同步执行后写回调用方，保留成功时不改写错误与传入 `NULL` 的行为。该文件未纳入当前 Demo target，已单独通过 `-Werror=block-capture-autoreleasing` 语法检查。

使用 iOS 26.5 SDK、最低 iOS 15，完成 Demo Debug 无签名工程编译及修复后的增量复查：`BUILD SUCCEEDED`，0 条 warning、0 条 error。方向回归用例已添加并通过语法检查，未执行模拟器或真机测试。

## iOS 26 内容区域返回手势

导航控制器自动为 `interactiveContentPopGestureRecognizer` 配置失败依赖：触摸从横向可滚动的 `UIScrollView`（包含横向 `UICollectionView`）、启用的 `UISlider` 内开始时，优先响应控件拖动，滑到内容两端仍保持保护。纯纵向列表、禁用滚动或禁用的滑块、未标记的空白区域沿用系统内容返回行为。滚动内容、内边距和开关在每次触摸时重新判断。

自定义横向拖动控件可标记其交互区域，子视图也会继承保护：

```objc
// 仅保护指定区域；不要给整个页面设置，除非确实希望整页禁止内容返回。
customDragView.qmui_preventsInteractiveContentPopGestureRecognizer = YES;
```

保护手势不取消、延迟控件触摸，不抢占控件内部手势；保留系统内容返回的 delegate 与 enabled，不修改边缘返回，也不访问私有 target。SDK 和运行系统均为 iOS 26+ 时自动启用，较早系统无变化。

新增回归用例覆盖嵌套触摸区域、横向/纵向滚动切换、滚动禁用、横向弹性与内边距、滑块及自定义区域。修改源码使用本机 SDK 进行语法检查；尚未执行这些测试或真机手势验证。

## iOS 26 返回手势拦截（2026/10/10）

`shouldPopViewControllerByBackButtonOrPopGesture:` 的手势拦截同时接入边缘返回和内容区域全屏返回，参数均为 `YES`。边缘代理直接应用业务返回的 `NO`，同时保留两种手势的公开失败依赖；不能仅靠旁路手势事后阻止边缘转场。同一次触摸共用判断结果，避免系统代理与许可手势重复弹窗，也不会形成循环失败依赖。系统延后创建或替换手势、重设边缘代理时，在布局阶段补齐绑定并继续转发原代理的系统判断。

边缘许可使用独立的 `UIScreenEdgePanGestureRecognizer`，内容许可继续避让横向列表、滑块和已标记的交互区域。只判断向返回方向的拖动，支持从右向左布局；根页面、转场中、模态页面覆盖时不触发确认，手动代码 pop 不受拦截。内容返回的系统 delegate、enabled 与私有 target 保持原有配置，早于 iOS 26 的实现保持原样。

新增回归源码覆盖拒绝与放行、同次触摸去重、方向与布局方向、横向控件避让、根页面、手动 pop、重复布局及反向失败依赖。使用 iOS 26.5 SDK、最低 iOS 15 完成修改源码与测试源码的语法检查，0 条诊断；本轮未执行 Xcode Build、回归测试或真实手势验证。

后续根据实机“边缘返回弹窗后仍退出”的反馈，修正边缘代理跳过业务否决的问题，并改为同一触摸首次进入时才清理判断缓存。补充系统代理先被询问、许可手势先被询问、原系统代理允许而业务拒绝、代理被重设及下一次触摸重新放行的用例。此前对尚未开始识别的 `UIPanGestureRecognizer` 使用 `setTranslation:` 无法提供测试位移，已改为向内部许可判定传入明确位移；这些用例验证代理返回值和许可规则，不冒充真实触摸识别。

使用 iOS 26.5 SDK 完成框架增量编译，0 条 warning、0 条 error；在 iOS 26.3 模拟器的临时宿主中执行 5 个返回拦截回归用例，0 失败。未进行 Demo 全量编译或实机手势复测；模拟器 UI 拖动工具未能稳定派发有效手势，不将其视为手势验证通过。

## UISlider Steps 拖动归档（2026/10/10）

修复新版系统中圆点已停靠档位、进度条仍保留连续值的问题。Steps 开启时，在业务收到控制事件前通过公开 setter 同步实际 `value`、圆点与进度条；补齐松手、滑出控件松手及取消事件的归档处理，不额外发送 `valueChanged`。关闭 Steps 后移除相关监听。

档位标记改用实际 `qmui_step` 判断显隐，避免内部圆点视图层级变化影响坐标判断；修正减少档位时多删除一个控件的问题，数值换算支持实际最小值与最大值。

新增回归源码覆盖业务监听先注册、同档位重复拖动、非连续事件、松手及取消、关闭和调整 Steps、自定义数值范围。本轮仅对修改源码及回归源码进行编译器语法检查，并校验工程引用和两份副本同步，未执行 Xcode Build、模拟器或真机测试。

## UISlider 导轨贴合与高度（2026/10/10）

Steps 不再手动覆盖圆点的横坐标，将归档后的值交给系统计算圆点位置；每个刻度跟随对应档位的系统圆点中心，移除仅按导轨宽度分配刻度及不完整的布局缓存，适应尺寸、圆点图片和布局方向的变化。

设置 `qmui_trackHeight > 0` 时，通过公开的最小、最大导轨图片 API 固定高度，高亮与普通状态使用同一图片，避免 iOS 26 玻璃导轨在状态变化后产生不同厚度。保留业务自定义的导轨图片，颜色和显示倍数变化时刷新 QMUI 图片；设置回 0 时仅移除 QMUI 生成的图片。未设置自定义高度的系统滑块保持默认外观。

使用 iOS 26.5 SDK 编译框架，0 条 warning、0 条 error；在已启动的 iOS 26.3 模拟器中使用临时验证 App 核对导轨和圆点几何，执行 7 个滑块回归用例，0 失败。用例覆盖固定高度、图片恢复及业务图片保留、档位坐标、数值归档、取消和动态调整。Xcode 无宿主测试首次发现无法派发业务 action，已调整相关用例的初始事件处理，并在具有 UIApplication 的临时宿主中确认通过。未运行 Demo 全量构建或其他测试，真实触摸拖动及更早系统仍需真机复查。

## 手势返回感知、浅色磨砂与 NSObject Demo 崩溃（2026/10/10）

`QMUINavigationController` 同时监听边缘返回及 iOS 26 内容区域返回，在布局时补齐系统延后创建或替换的手势，避免重复绑定。保存本次交互转场的双方，通过公开的 `notifyWhenInteractionChangesUsingBlock:` 获取完成或取消结果，防止松手时协调器已移除、或 QMUI target 先于系统 target 而丢失回调、误报成功；取消、失败与快速松手时清理 changing 标记。

带 `isCancelled:` 的协议回调参数改为通用 `UIGestureRecognizer *`，业务实现应同步调整参数类型；边缘与内容返回均可通过 `state` 感知阶段。已弃用的旧接口继续仅回调真实的 `UIScreenEdgePanGestureRecognizer`。Demo 补齐取消及失败的结束处理，原有返回拦截和横向控件保护继续保留。

导航栏补齐 `setBackgroundImage:forBarMetrics:` 到 `UINavigationBarAppearance` 的同步，避免 UIKit 不再转发到三参数重载时，清空背景图仍保留旧图并移除磨砂。浅色磨砂 Demo 显式使用浅色材料并清空背景色，避免继承深色主题或上一页的背景配置；未启用 QMUI 配置表时仍沿用 iOS 26 原生外观行为。

`NSObject+QMUI` Demo 使用 `objc_copyClassList` 一次读取运行时类列表快照，替换先计数再读取的代码。旧实现第二次返回的类总数可能超过已分配容量，造成越界读和向数组插入 nil；新实现检查类名后发布不可变列表，在主线程刷新已输入的搜索结果。

使用 iOS 26.5 SDK 完成框架增量编译，0 条 warning、0 条 error；6 个修改实现文件（含 Demo、测试）通过局部语法检查。在已启动的 iOS 26.3 模拟器临时宿主中执行 4 个新增定向用例及 5 个原有返回拦截用例，共 9 个、0 失败。临时宿主首次从主队列任务执行套件导致异步等待超时，改为 RunLoop 调度入口后复查通过。这些用例验证手势监听绑定、回调结果与样式同步，不等同于实机触摸及视觉效果验证；未执行 Demo 全量构建。

## iOS 26 导航栏独立外观与转场（2026/10/10）

每个页面保存独立的 `UINavigationItem` appearance，在 `WillPush`、`WillPop`、`WillSet` 时提前准备前后页样式。首次显示可在加入 window 前配置，避免等待 UIAppearance 应用后才补写新页样式。iOS 15–25 保留原有的转场导航栏实现。上一轮只隔离页面 appearance，端点数据正确，但实机仍出现交互返回时整条导航栏提前变蓝、进入磨砂页先白闪的问题，不能把端点测试视为动画修复成功。

背景图、颜色、材料、分隔线、标题与按钮文字样式通过复制的 appearance 一次提交，不改写前一页的外观。启用 `NavBarUsesStandardAppearanceOnly` 时同步标准、滚动边缘、紧凑及紧凑滚动四种状态；未启用时保留独立边缘/紧凑样式与 nil 回退，配置表默认值只覆盖标准状态，其余状态仅应用页面显式声明的样式。样式 getter 可能在 push 前读取，应返回控制器已配置的属性。

旧 `barTintColor`、`barStyle`、背景图、分隔线及标题 setter 继续同步 QMUI 管理的当前页面；`qmui_effect`、`qmui_effectForegroundColor` 也更新当前页面的公开 appearance。业务通过这些接口修改新页面时，不污染前一页。未声明 QMUI 外观的系统页面保留 UIKit 行为。

使用 iOS 26.5 SDK 完成框架增量编译，0 条 warning、0 条 error；修改实现及测试通过局部语法检查。在已启动的 iOS 26.3 模拟器临时宿主执行 4 个新增页面样式用例、4 个已有导航观察/背景同步用例、5 个返回拦截用例，共 13 个、0 失败。新增用例覆盖 push 前已准备目标样式、首帧前的配置、前后页外观隔离、刷新及 pop、旧 setter 和磨砂接口、独立滚动外观及未接管的系统页面。

另用临时窗口自动执行原生动画 push/pop，确认前页背景图保留、新页背景图清空且材料有效、返回后恢复原页面；窗口绘制截图只作为局部显示参考，未验证实机动画全过程或真实返回手势。本轮未构建 Demo 全量工程。

根据后续实机截图，iOS 26 需要自定义转场时只创建前后页的背景视图，分别绘制各页背景图、颜色、磨砂及分隔线，随页面移动；转场期间遮住共享背景容器，保留系统标题、按钮、玻璃控件和手势。仍使用原有的自定义转场 key、自动判断与自定义 animator 许可规则，同样式和未接管的系统页面沿用原生行为。完成、取消及无动画操作后清理临时背景，恢复原有背景 mask 和当前页按钮颜色；导航栏显隐按各页判断，支持标准、紧凑与滚动边缘外观。

复用相同的磨砂材料，仅在 appearance 有变化时提交，并关闭材料赋值的隐式动画，避免在 WillPush、viewWillAppear 等连续回调中重建材料。新增回归覆盖不重复赋值材料、不同背景的真实动画 push/pop、背景归属和结束清理；本轮共执行 15 个定向回归，0 失败。框架增量编译及局部语法检查通过，0 条 warning、0 条 error。

使用与 Demo 相同的默认蓝色背景、导航栏容器配置，在 iOS 26.3 模拟器录制真实系统屏幕的默认→深色→磨砂→深色→默认动画，并核对动画帧：前后页背景各自保留，未见整条背景提前变蓝或先全白再显示材料。此验证使用原生程序化 push/pop，未复测实机边缘、全屏返回及取消手势，也未构建 Demo 全量工程。

## 导航栏普通按钮保留液态玻璃导航栏（2026/10/10）

新增 `UIBarButtonItem.qmui_hidesSharedBackground`，iOS 26 通过公开的 `hidesSharedBackground` 隐藏普通左右按钮的共享玻璃背景，iOS 15–25 保存设置并保持原样。接口按按钮生效，默认关闭，不修改导航栏 appearance、按钮内容、target/action、布局或系统手势，也不恢复之前删除的全局液态玻璃效果开关。

```objc
UIBarButtonItem *item = [UIBarButtonItem qmui_itemWithTitle:@"编辑" target:self action:@selector(handleEdit)];
item.qmui_hidesSharedBackground = YES;
self.navigationItem.rightBarButtonItem = item;
```

普通 `leftBarButtonItems` / `rightBarButtonItems` 数组可逐个设置；多按钮 `UIBarButtonItemGroup` 会忽略此属性，这是系统 API 的限制，不自动拆组。接口不移除 `customView` 自身的背景或 prominent 按钮自己的突出样式，纯文字或图标建议使用 `UIBarButtonItemStylePlain`。

系统自动返回按钮有单独的限制：在 iOS 26.3 临时宿主中将上一页 `backBarButtonItem.hidesSharedBackground` 设置为 YES 后，实际屏幕仍显示玻璃返回按钮。因此新增 `qmui_plainBackItemWithViewController:`，通过公开的普通 `UIBarButtonItem` 显示无玻璃返回箭头。建议在当前页 `viewWillAppear:` 中创建并赋给 `leftBarButtonItem`，导航栏背景及系统转场保持原有实现。

```objc
self.navigationItem.leftBarButtonItem = [UIBarButtonItem qmui_plainBackItemWithViewController:self];
```

普通返回箭头的点击、VoiceOver 退出及历史菜单都调用 `shouldPopViewControllerByBackButtonOrPopGesture:NO`，业务拒绝时不会执行 pop。长按历史菜单按导航栈用标准 `UIMenu` 重建，并检查过期目标，不能视为系统自动返回按钮的私有菜单。根页面、隐藏返回按钮或声明 `backAction` 时工厂返回 nil，已有业务左按钮由调用方决定是否替换。

边缘手势沿用 QMUI 的代理兼容逻辑，仅为本工厂按钮补齐 UIKit 因自定义左按钮产生的拒绝，并保留业务返回判断和外部代理的否决。内容全屏返回手势不接管 delegate、enabled 或 target；既有的返回拦截与横向控件保护继续沿用。

Demo 的导航栏样式页面在 iOS 26 增加文字、图标按钮，并提供“全局旧版导航栏按钮”开关；切换通过配置表统一控制项目导航栏，具体行为见下节。更早系统不增加切换入口。

修改框架和 Demo 源码通过 iOS 26.5 SDK、最低 iOS 15 的局部语法检查，0 条诊断；完成框架增量编译，0 条 warning、0 条 error。在 iOS 26.3 模拟器执行 3 个普通返回按钮用例及 5 个已有返回拦截用例，共 8 个、0 失败，覆盖按钮/无障碍业务否决、历史菜单及过期目标、外部边缘代理否决和内容手势设置保留。临时 UIKit 宿主的实际屏幕确认返回箭头与普通左右按钮均无玻璃背景，真实点击和长按菜单选择均正常返回。工具拖动未派发有效返回手势，因此边缘、全屏及取消手势没有完成触摸复测；未进行 Demo 全量构建或实机验证。

## 全局普通导航按钮与紧凑布局（2026/10/10）

新增配置表开关，统一管理项目导航栏，无需逐页创建返回按钮：

```objc
QMUICMI.navBarUsesLegacyButtonLayout = YES; // 普通按钮、旧版返回箭头与紧凑间距
// QMUICMI.navBarUsesLegacyButtonLayout = NO; // 恢复原有系统按钮配置
```

框架默认 NO，Demo 配置表默认 YES。当前实现从 iOS 15 起使用同一套普通按钮和内容布局（2026/10/12 更新），不再只针对 iOS 26。开关沿用 `navBarContainerClasses` 指定的导航控制器范围，未指定时仅处理 `QMUINavigationController`；Demo 使用 QMUI 导航控制器范围，不修改系统选择器等其他导航控制器。请在主线程设置。

当前栈与后续页面自动应用。文字、图标及常用系统按钮通过公开的普通 UIButton 配置呈现，并按实际内容边缘布局：距导航栏安全区域 16pt，相邻内容间距 8pt。UIKit 对按钮视图保留的最小宽度不再撑开视觉间距，图片/文字完成布局后也会重新核对位置，避免动态切换后回弹。仅调整框架创建的视图或业务提供的 customView，不修改 UIKit 的内部按钮容器、约束、导航栏高度、标题或背景材料。

保留原 UIBarButtonItem 对象、左右按钮数组顺序、target/action、primaryAction、菜单、禁用和选中状态；文字、图片、菜单等动态设置会同步到展示按钮。业务自定义视图保留自己的内容和动作，只调整水平位置。关闭开关时恢复原 customView、变换及开启前保存的共享背景设置；框架生成的返回箭头会清理，恢复系统自动返回按钮。业务提供的左按钮、隐藏返回按钮与 backAction 继续由业务控制。普通返回箭头的点击、历史菜单及无障碍退出沿用原业务拦截。跨多级返回时按真实根页面整理 UIKit 的临时导航数组，避免给根页面短暂添加错误箭头；离栈但仍被业务保留的页面也会清理自动箭头。

业务 QMUINavigationButton 子类按完整视图宽度预留空间，避免未读数或徽标与相邻按钮重叠；普通配置按钮的图片/标题先转换到按钮坐标，再计算内容边缘。先完成全部按钮布局，再统一调整位置。业务 customView 的布局和 frame 回调保留并串接，关闭开关或更换视图时恢复；扩展点击区域不会覆盖相邻按钮。Demo 的 QMUIBackBarButton 会把全局自动箭头视为返回占位项，自定义未读数按钮自行布局并提供完整 intrinsicContentSize，支持动态替换、附加关闭按钮和恢复系统返回。

`leftItemsSupplementBackButton = YES` 且没有业务自定义返回按钮时，自动普通返回箭头与业务左按钮一起布局，避免系统玻璃返回按钮与移动后的左按钮重叠。保留 supplement 的业务设置，通过原公开 setter 临时隐藏系统自动箭头，不经过业务 hook；因此此时 `hidesBackButton` 为 YES，但普通箭头正常显示。业务重新设置显隐、改为仅左按钮、替换自定义返回视图或关闭开关时按业务最新状态恢复。Demo 的任意自定义返回视图均显式标记，避免被再次添加普通箭头。

框架通过公开初始化参数识别常用系统按钮，空间项保留业务宽度；没有公开文字/图片且无法识别的归档系统项保留原按钮，不使用私有 KVC 读取类型。此开关仅用于导航按钮，不恢复此前删除的全局液态玻璃开关。

Demo 在“导航栏样式”第一行展示 UISwitch，切换后作用于项目内全部 QMUI 导航栈；右侧文字/图标按钮同样操作这个全局值，页面返回或继续 push 不会重新设置局部开关。

使用 iOS 26.5 SDK、最低 iOS 15 完成修改源文件的局部语法检查与框架增量编译。iOS 26.3 模拟器执行 3 个全局按钮用例、3 个普通返回按钮用例和 5 个原有返回拦截用例，共 11 个、0 失败，验证内容边距、间距、真实命中区域、全栈恢复、业务否决、属性更新、primaryAction、自定义视图及业务回调恢复、范围隔离。临时 UIKit 宿主另核对实际开关反复切换、普通/玻璃屏幕显示、新页面自动继承、长按历史菜单及跨级返回；链接真实 QMUIBackBarButton 组件及 Demo 未读数按钮实现，核对 8/99+、附加关闭按钮、隐藏/恢复返回按钮、仅左按钮和恢复系统返回。未构建 Demo 全量工程，实机手势及 iOS 27 尚未复测。

2026/10/12 补充“未设置未读数、直接同时显示左按钮与系统返回”的回归，共 12 个、0 失败。真实 Demo 返回组件另核对 15 个动态状态，覆盖 supplement 开关、系统/未读数/普通自定义返回视图替换、独立点击、仅左按钮、业务显隐和全局开关恢复；局部语法检查与框架增量编译通过，未构建 Demo 全量工程。

## iOS 26 旧版导航按钮颜色与 InsetGrouped 布局（2026/10/12）

旧版导航按钮开关下，自动生成的返回箭头和普通按钮会沿用导航栏实际 tintColor；未单独设置按钮颜色时回退到 QMUI 配置的 NavBarTintColor，避免 iOS 26 UIButtonConfiguration 使用黑色默认颜色。返回箭头继续使用 13×21 的旧版线稿尺寸，业务已配置的返回图片优先保留。

InsetGrouped 在 iOS 26 的布局路径增加了 directionalLayoutMargins，并可能在 cell 布局末尾重新写入圆角。QMUI 同步覆盖公开的 layoutMargins 与 directionalLayoutMargins，在 cell/tableView 的公开布局阶段重新应用 qmui_insetGroupedHorizontalInset 和 qmui_insetGroupedCornerRadius，并同步 iOS 26 的公开 cornerConfiguration，避免 layer.cornerRadius 数值正确但屏幕仍显示系统大圆角；动态修改属性后立即请求布局。iOS 15–25 的原有路径保持不变。

使用 iOS 26.5 SDK 完成框架增量编译；iOS 26.3 模拟器临时宿主核对横向缩进 10→40、圆角 10→3 的动态更新，以及普通导航按钮布局回归，均通过。未构建 Demo 全量工程或进行 iOS 27 真机验证。

## 跨版本统一导航按钮指标（2026/10/12）

开启 `navBarUsesLegacyButtonLayout` 后，iOS 15–25 与 iOS 26 的系统文字/图片按钮及 `QMUINavigationButton` 使用相同字体、图片尺寸和内容边距。Demo 采用 17pt 常规文字、17pt Semibold 加粗文字、24×24pt 普通图标、13×21pt 返回箭头、16pt 安全区域边距和 8pt 相邻内容间距。这是项目统一的视觉规格；不同机型按 pt 和安全区域对齐。

在配置表统一修改：

```objc
QMUICMI.navBarUsesLegacyButtonLayout = YES;
QMUICMI.navBarButtonFont = [UIFont systemFontOfSize:17];
QMUICMI.navBarButtonFontBold = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
QMUICMI.navBarButtonImageSize = CGSizeMake(24, 24);
QMUICMI.navBarButtonImagePadding = 6;
QMUICMI.navBarButtonContentEdgeDistance = 16;
QMUICMI.navBarButtonItemSpacing = 8;
QMUICMI.navBarButtonContentHorizontalPadding = 11;
QMUICMI.navBarBackIndicatorImage = [UIImage qmui_imageWithShape:QMUIImageShapeNavBack size:CGSizeMake(13, 21) lineWidth:2.5 tintColor:NavBarTintColor];
```

普通图标按比例缩放到 `navBarButtonImageSize` 指定范围；CGSizeZero 保留源尺寸。返回与关闭图标使用各自的配置图片，不受普通图标尺寸影响。普通布局保存源图，运行时更改尺寸及关闭开关均不会在缩小后的图片上重复缩放。字体、图标尺寸、边距和间距变更会刷新已创建的按钮。普通返回箭头与 QMUI 返回按钮共用图片来源；模板图标和粗体文字显式采用导航栏颜色，解决 iOS 26 黑色继承问题；业务 AlwaysOriginal 图标继续保留原色。

普通布局同步状态图片与 configuration 的图片尺寸，并对自己的纯图片按钮显式居中，修复 iOS 15/16 旧布局把图片置顶的问题。框架仍仅定位自己的普通按钮或业务 customView，导航栏高度、背景及标题由系统布局。业务按钮子类和额外内容保留原样。

使用 iOS 26.5 SDK、最低 iOS 15 完成 5 个修改源文件的局部语法检查及框架增量编译，0 编译诊断。iOS 16.0 模拟器的 5 项导航按钮回归、iOS 26.3 模拟器的 13 项导航按钮/返回回归均通过；新用例核对三类系统/QMUI 按钮切换前后的 pt 坐标、字体和图片尺寸、颜色继承、配置动态刷新及关闭恢复。未全量构建 Demo 或复测实机转场。

## iOS 26 TabBar 图标获取（2026/10/12）

液态 TabBar 同时保留普通、选中两套按钮，而 `UITabBarItem.qmui_view` 在 iOS 26.3 中仍指向普通按钮；只遍历该按钮会在选中后拿到普通图标，缩放等动画无法正确作用于选中图标。

`qmui_imageView` 在 iOS 26+ 按当前选中项、按钮类型及 TabBar 内的位置查找对应副本，优先匹配选中图片；没有副本时保留原获取路径。查找通过公开视图层级与坐标转换完成，不增加固定私有类名或 KVC。忽略隐藏、透明及无图片的子视图，并支持仅设置 highlightedImage 的图标。

请在 TabBar 布局完成后获取，切换状态或修改 items 后重新查询，不缓存图标视图。获取业务原图仍使用 `item.image` / `item.selectedImage`；`qmui_imageViewInTabBarButton:` 仅查询传入按钮内部，不自动跨到液态选中副本。未修改系统 TabBar 的布局、背景材料或按钮动作。

框架与 Demo 副本已同步。使用 iOS 26.5 SDK 完成框架增量编译及修改实现、测试文件的局部语法检查，0 编译诊断。iOS 16.0 与 iOS 26.3 模拟器分别执行 4 项定向回归，均 0 失败，覆盖独立 UITabBar、UITabBarController、普通/选中及同图状态、相同图片的相邻项、SF Symbols、动态换图、隐藏子树及清空选中项；临时宿主另核对替换 items。未进行 Demo 全量构建、实机或 iOS 27 运行验证。

## iOS 26 Steps 导轨端点与圆点阴影（2026/10/12）

修复 Demo 中 `trackHeight = 1`、`thumbSize = 14` 的两处显示问题：系统导轨两端比首尾圆点中心各多出约 4pt；自定义圆点改用名称不含 Thumb 的图片视图，原查找逻辑漏掉视图，阴影颜色无法呈现。

`qmui_thumbView` 增加当前圆点图片与实际坐标匹配；阴影在公开的布局阶段重新应用，移除旧私有 visualElement 的 didAddSubview: hook，支持修改圆点图片、尺寸、阴影颜色及清除阴影。iOS 26+ 同时启用 Steps 与自定义轨道高度时，根据首尾圆点中心裁剪导轨图片的可见范围，保留原 mask，并在关闭 Steps 或重置高度时恢复。不改变系统圆点坐标、数值范围或事件逻辑，也不清空业务配置的导轨颜色。

系统玻璃滑块的绘制路径会忽略单独设置的自定义圆点图片；需要这类圆点及阴影时，沿用 Demo 的 `qmui_trackHeight > 0` 或业务自定义导轨图片。未配置 QMUI 自定义样式的系统滑块保持原有绘制路径。

框架与 Demo 副本已同步。使用 iOS 26.5 SDK 完成框架增量编译及修改实现、测试文件的局部语法检查，0 编译诊断。iOS 16.0、iOS 26.3 各执行 9 项滑块定向用例，均 0 失败；新增裁剪用例仅在 iOS 26 执行，覆盖普通/高亮、LTR/RTL、宽度变化及原 mask 恢复，阴影用例覆盖尺寸、图片、颜色动态更新和清除。实际屏幕核对 1pt / 3pt 导轨、14pt / 20pt 圆点及蓝色 / 红色阴影。未全量构建 Demo 或执行实机拖动测试。

## 验证范围

已使用本机 iOS 26.5 SDK、arm64、最低 iOS 15 对框架、修改的 Demo 源码与回归测试源码进行编译器语法检查。回归覆盖缺失运行时方法、导航栏私有路径移除、磨砂重复设置、清空 TabBar 选中项。

本次移除效果开关并更新设备后，对涉及的框架、Demo 和测试源码进行语法检查，并校验工程引用及两份框架副本同步。新增灵动岛回归用例覆盖 e 系列、新型号和未知设备。

已完成 Demo Debug 无签名 Xcode 工程编译；滑块的 7 个回归用例、返回拦截的 5 个回归用例及导航观察/样式同步的 4 个定向用例、页面外观/转场的 4 个定向用例已在 iOS 26.3 模拟器执行，其余回归用例及真机测试尚未执行。本机没有 iOS 27 SDK，不能将前向兼容代码视为 iOS 27 的运行验证；导航转场、深色模式及辅助功能仍需对应系统实机确认。
