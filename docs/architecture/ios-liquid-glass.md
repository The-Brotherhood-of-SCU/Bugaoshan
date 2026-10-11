# iOS 液态玻璃适配

本文记录 iOS 原生 Liquid Glass 的呈现范围、Flutter 与 UIKit 的桥接边界，以及合入 `preview` 时的兼容要求。

## 呈现范围

| 区域 | iOS 26+ | 旧 iOS / 其他平台 |
|---|---|---|
| 窄屏 Home 底部 Dock（宽度小于 600） | 系统 `UITabBarController`，由 UIKit 提供玻璃材质、选中透镜和交互反馈 | 原有 Material `NavigationBar` |
| 宽屏 Home 侧栏 | 原有 `NavigationRail` | 原有 `NavigationRail` |
| 设置及业务页的开关 | 系统 `UISwitch`，值和业务回调由 Flutter 管理 | 原有 `Switch` / `SwitchListTile` |
| 设置滑块（动画时长、课程透明度/字号/行高、背景透明度） | 系统 `UISlider`，玻璃拇指、刻度吸附及拖动回弹由系统提供 | 原有 Material `Slider` |
| 登录/登出、重试、确认/重置及背景操作按钮、顶部工具栏、课程卡片、列表内容 | 保持 Flutter 绘制 | 保持 Flutter 绘制 |

Dock 使用系统标签栏，而非自绘胶囊容器：给自定义视图应用玻璃材质不会自动获得系统标签栏的选中透镜。课表、校园、个人主页的滚动内容延伸到 Dock 后方，末尾留出可操作空间。桥接失败时恢复 Material 控件及原有安全区布局。

## 当前分层

Home 页继续持有选中索引和页面状态，`AdaptiveHomeDock` 只把 Dock 展示所需的数据传给原生侧：稳定的 destination id、文案、SF Symbols、角标、主题色、深浅色、动效设置、对比度、文字缩放和 RTL 方向。原生侧只回传 destination id，Flutter 再按当前列表解析索引；因此 Dock 重排或增删后，过期事件不会跳转到错误页面。

iOS 侧的 [`LiquidGlassDock.swift`](../../ios/Runner/LiquidGlassDock.swift) 注册一个平台视图工厂，由 `LiquidGlassDockController: UITabBarController` 承载系统 `UITabBarItem`。每个 destination 的子控制器都是透明占位视图，不承载业务内容；页面内容仍由 Flutter 管理。容器沿实际 responder chain 寻找父控制器，维护添加、移除和销毁时的 containment，不使用全局窗口 overlay。

原生层保留系统背景、材质和 selection lens，不设置自定义 `UITabBarAppearance`、模糊层、背景或 `selectionIndicatorImage`；入口的选中图标仍通过 `UITabBarItem.selectedImage` 设置。Dock 的平台视图横向铺满可用宽度，高度为 `88 + MediaQuery.viewPadding.bottom`，一直延伸到底边；UIKit 计算实际标签栏的边距与安全区，Flutter 不再用外层 `SafeArea` 或圆角裁剪收紧原生视图。

最多五个入口直接显示。超过五个时，原生栏显示前三个入口、当前额外入口和“更多”；“更多”通过原生 action sheet 列出其余入口，避免系统内置 More 页面被限制在短平台视图中。入口排序仍由 Flutter 设置页管理。

## 内容延伸与底部避让

[`home_page.dart`](../../lib/pages/home_page.dart) 仅在底栏可见且原生模式可用时设置 `Scaffold.extendBody: true`。键盘出现、宽屏切为 Rail 或原生更新失败回退时，关闭延伸布局。`AdaptiveHomeDock.onNativeModeChanged` 将原生模式的启用与失败回退同步给 Home。

[`HomeDockBody` / `HomeDockInsets`](../../lib/widgets/navigation/home_dock_insets.dart) 在 Scaffold 的 body 内读取其注入的底部 padding。原生模式下，`HomeDockBody` 保留顶部和侧边安全区，让滚动 viewport 一直铺到底边，并通过 `HomeDockInsets` 传递 Dock 避让距离。**避让加在滚动内容末尾，而不是裁短 viewport**，使内容能从标签栏后方经过，且最后一项仍能滚动至可操作区域。

| 页面 | 当前避让方式 |
|---|---|
| 课表主页 | 纵向 `SingleChildScrollView` 增加底部内容 padding |
| 校园主页 | `CustomScrollView` 末尾增加相应高度的 sliver；底部提示也避让 Dock |
| 个人主页 | `SingleChildScrollView` 增加底部内容 padding，并修正内容最小高度 |
| 其他自定义业务入口 | Home 外层增加底部安全留白，保留表单、FAB 和嵌套 Scaffold 的可操作区域；尚未逐页适配内容延伸 |

非延伸模式使用原有 `SafeArea`，scope 的底部 inset 为 0；Home 以外的详情页没有此 scope 时也默认返回 0，避免改变共用组件的布局。

## Flutter 桥接契约

能力通道为 `bugaoshan/liquid_glass`：

| 调用 | 参数 | 返回值 |
|---|---|---|
| `isSupported` | 无 | `bool`。只有编译器支持 iOS 26 API 且运行系统为 iOS 26+ 时为 `true` |

能力不可用、能力调用超时或原生状态更新失败时，Flutter 使用 `NavigationBar`。状态更新失败同时通知 Home 关闭内容延伸。

原生视图类型为 `bugaoshan/liquid_glass_dock`，创建参数和后续 `update` 参数使用同一份 Map：

| 字段 | 类型 | 用途 |
|---|---|---|
| `items` | `List<Map>` | `id`、`label`、`symbol`、`selectedSymbol`、`badge`、`badgeLabel` |
| `selectedId` | `String` | 当前选中的稳定 destination id |
| `tint` | ARGB `int` | 选中项颜色 |
| `brightness` | `String` | `light` 或 `dark` |
| `reduceMotion` | `bool` | Flutter 设置或系统禁用动画 |
| `highContrast` | `bool` | Flutter 高对比度设置 |
| `textScale` | `double` | 1 到 2 之间的文字缩放 |
| `direction` | `String` | `ltr` 或 `rtl` |
| `moreLabel` | 可选 `String` | “更多”入口和原生 action sheet 标题 |
| `cancelLabel` | 可选 `String` | 原生 action sheet 的取消文案 |

每个已创建的平台视图有独立通道 `bugaoshan/liquid_glass_dock/<viewId>`。原生按钮点击通过 `select` 回传 destination id；Flutter 只接受当前列表中仍存在的 id。

## 原生开关与滑块

[`adaptive_glass_controls.dart`](../../lib/widgets/adaptive/adaptive_glass_controls.dart) 提供 `AdaptiveGlassSwitch`、`AdaptiveGlassSwitchListTile` 和 `AdaptiveGlassSlider`，复用能力探测。液态玻璃只用于底部导航、开关和滑块；登录/登出、重试、确认/重置、背景操作等普通按钮保留原有 Material 样式。iOS 26+ 由 [`LiquidGlassControls.swift`](../../ios/Runner/LiquidGlassControls.swift) 创建真实 `UISwitch` / `UISlider`，不再注册玻璃操作按钮。

开关覆盖课程与字体设置、Dock 设置、桌面小组件、校园展示、电费、报修、开发选项，以及提醒总开关与免打扰开关。滑块覆盖动画时长、课程透明度、字号、行高和背景透明度。iOS 26 以下、能力探测失败或更新超时时，恢复 `Switch` / `SwitchListTile` / `Slider`；业务校验和持久化仍由 Flutter 管理。

控件平台视图类型为 `bugaoshan/liquid_glass_control`，每个实例的通道为 `bugaoshan/liquid_glass_control/<viewId>`。创建与 `update` 传入完整配置：`kind`（`switch` / `slider`）、可访问性 `label`、受控 `value`、`enabled`，以及主题、方向、动效和对比度参数。滑块额外接收 `min`、`max`、可选 `divisions`、`valueLabel` 和 `inactiveTint`。开关回传 `change(bool)`；滑块回传 `changeStart(double)`、`change(double)`、`changeEnd(double)`。释放时解除通道 handler 与原生 target。

**原生控件独占交互动效。** 开关点击/拖动后，Flutter 接受的值与 `UISwitch.isOn` 相同时不再调用 `setOn`；主题更新与被拒绝的值回退也不另启切换动画。只有外部主动改变开关值时才允许原生动画，并遵守减少动态效果设置。`ListTile` 文字区域仍可点击切换，控件自身的点击交给 UIKit，防止一击触发两次翻转。

滑块使用系统 `TrackConfiguration` 配置 `divisions + 1` 个刻度，由 UIKit 处理吸附、惯性和玻璃拇指回弹。拖动期间不让延迟的 Flutter 配置拉回拇指；松手后同步受控值。相同值不重复设置，程序更新不附加位移动画，Flutter 将原生 Float 值归一到业务离散刻度，过滤非法、禁用和重复值。VoiceOver/键盘的无触摸变化也回传开始/变化/结束。系统控件行为参见 [Apple《Build a UIKit app with the new design》](https://developer.apple.com/videos/play/wwdc2025/284/)。

开关使用 `64 × 44` 平台区，按系统尺寸居中，触摸区至少 44 点；滑块高度为 48 点，左右保留与原设置页一致的空间。点击和横向拖动交给原生控件，纵向拖动参与 Flutter 列表的手势竞争。控件外不叠加玻璃容器、Flutter 拇指、缩放或切换动画。

## 原生与 Flutter 方案比较

| 方案 | 当前用途 | 优点 | 边界 |
|---|---|---|---|
| UIKit `UITabBarController` | 当前 iOS 26+ Dock | 系统标签栏管理材质、selection lens 和原生导航交互 | 需要平台视图及控制器 containment；与 Flutter 内容的材质合成仍须视觉验证 |
| UIKit `UISwitch` / `UISlider` | 开关与设置滑块 | 系统提供玻璃拇指、交互与辅助功能 | Flutter 维护受控状态与列表滚动手势 |
| SwiftUI `glassEffect` | 早期自定义 Dock 方案，已替换 | 可给自定义 SwiftUI 视图应用玻璃材质 | 材质 API 不等于系统 TabBar；自绘按钮不会因此获得系统 selection lens |
| Flutter `NavigationBar` | 旧 iOS、非 iOS 和桥接失败时的回退 | 保留现有导航行为和页面状态 | 不声明为原生 Liquid Glass 效果 |

参考：[Apple《Adopting Liquid Glass》](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)、[SwiftUI 自定义 Liquid Glass](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)、[Flutter iOS platform views](https://docs.flutter.dev/platform-integration/ios/platform-views)、[Flutter platform-view backdrop filter 设计文档](https://flutter.dev/go/ios-platformview-backdrop-filter-blur)。

## 平台与可访问性边界

Podfile 的最低版本继续为 iOS 15。原生能力探测使用 `#if compiler(>=6.2)` 和 `#available(iOS 26.0, *)`；旧 SDK 或旧系统使用 Flutter `NavigationBar` 和各控件的 Material 回退，宽屏 Home 使用 `NavigationRail`。

Flutter 把 `disableAnimations`、高对比度、文字缩放、深浅色和方向传入原生层。UIKit 侧映射为配置与 traits，更新时同时检查 `UIAccessibility.isReduceMotionEnabled`。减少透明度交由系统控件响应原生辅助功能设置，不用高对比度替代这一设置。原生 tab item 提供可访问性标签和角标值，选中状态由系统标签栏管理。

Flutter 的滚动组件不是 `UIScrollView`，当前也没有把 Flutter 滚动状态桥接成原生滚动容器。**不承诺原生自动缩栏或 scroll-edge 效果联动**；iOS 26 下明确设置 `tabBarMinimizeBehavior = .never`。内容延伸与末尾 padding 只处理叠放和可操作区域，不能替代原生滚动联动。

平台视图采用 iOS hybrid composition。不要在 Flutter 祖先上用 `Opacity`、`FadeTransition` 或 `ClipRRect` 包裹原生 Dock；平台视图的合成、遮罩和透明度会影响原生材质。Flutter 官方也列出平台视图与 `ShaderMask`、`ColorFiltered` 及跨层 `BackdropFilter` 的限制。原生层注册遵循当前 `UIScene` 生命周期，在 `didInitializeImplicitFlutterEngine` 中完成。

## 验证状态

[`adaptive_home_dock_test.dart`](../../test/adaptive_home_dock_test.dart) 覆盖桥接回退、稳定 ID 选择、参数更新与释放、原生模式切换，以及全宽平台视图、延伸 viewport、末尾内容避让和旧模式安全区。Widget 测试使用模拟平台通道，不渲染 UIKit 材质；源码中的系统控件和这些通过的测试都不能证明玻璃已正确采样 Flutter 内容。

[`adaptive_glass_controls_test.dart`](../../test/adaptive_glass_controls_test.dart) 覆盖控件回退、离散滑块事件与开始/结束回调、受控值同步、禁用、非法事件、配置失败回退、释放、列表手势，以及登录按钮保持常规样式。Widget 测试使用模拟平台通道，不渲染 UIKit 材质。

[`RunnerTests.swift`](../../ios/RunnerTests/RunnerTests.swift) 在真实 UIKit 控件上记录 `setOn` / `setValue` 调用，确认同值回传不会再次设置或重启动画、外部更新和减少动态效果的行为，以及滑块刻度、连续模式、辅助功能事件、禁用与释放。四项原生测试已在 iOS 26.0 模拟器通过。连续滑块显式设置 `allowsTickValuesOnly: false` 和空刻度，避免 iOS 26 将清空配置后的值吸附至零。

可在 Xcode 的 Runner scheme 执行 Test，或运行 `xcodebuild test -workspace ios/Runner.xcworkspace -scheme Runner -destination 'platform=iOS Simulator,id=<模拟器 UUID>' -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO`。测试在各用例结束时恢复 UIKit 方法探针，不修改生产控件行为；原生单测仍不能替代实际触摸拖动和真机材质验收。

合入最新 `preview` 时保留了学生类型对 Dock 入口的筛选、按稳定 ID 保存/重排的设置、`enableDockSwitchAnimation` 动效设置，以及 `undergradOnly` 错误态的登录指引。iOS 包名、开发团队、App Group、商店分发、隐私政策和版本号不属于本次适配范围。

已在 Xcode 27 / iOS 26.0 的 iPhone 17 Pro 模拟器构建并运行，检查浅色/深色 Dock、标签切换、设置开关值同步、禁用开关，以及六个入口时的原生“更多”菜单和选择后的页面跳转。截图中的课程、教师和教室均为本地虚构数据；截图只记录静态呈现。

| 浅色课表 Dock | 深色校园 Dock |
|---|---|
| <img src="../../screenshot/ios-liquid-glass/dock-light.png" width="220" alt="浅色课表 Dock"> | <img src="../../screenshot/ios-liquid-glass/dock-dark.png" width="220" alt="深色校园 Dock"> |

更多截图：[浅色校园](../../screenshot/ios-liquid-glass/campus-light.png)、[更多入口菜单](../../screenshot/ios-liquid-glass/more-light.png)。

正式验收还应在 iOS 26+ 真机确认内容经过标签栏后方时的材质变化、系统选中透镜、开关切换与滑块拖动、从控件区域开始的列表滚动、禁用状态、浅色/深色、减少透明度、增加对比度、减少动态效果、动态字体、RTL、路由切换、弹窗、WebView、不同安全区和超过五个入口的“更多”行为。性能应在 release 构建和真实设备上测量平台视图合成开销。编译成功、Widget 测试或静态截图均不代表全部真机视觉与性能验收完成。
