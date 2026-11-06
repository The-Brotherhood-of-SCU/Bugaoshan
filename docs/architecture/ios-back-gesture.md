# iOS 全局侧滑返回

本文记录 iOS 内容区全局侧滑返回的实现位置、手势竞争规则，以及与 iOS 26 系统手势、Flutter 内置 Cupertino 返回手势的差异。

## 手势来源

iOS 26 给 `UINavigationController` 新增了 `interactiveContentPopGestureRecognizer`（见 `UINavigationController.h`，`iOS 26.0` 起可用）：系统在导航控制器上安装该识别器，只要在**内容区任意位置**做一次「从前往后」的横向平移，就能交互式返回上一页；它只覆盖 `interactivePopGestureRecognizer`（左缘手势）没有覆盖到的区域，两者并存。

Flutter 的页面栈不经过 UIKit 的 `UINavigationController`：根视图是 `FlutterViewController`，路由由 Dart 侧的 `Navigator` 管理，系统识别器不会作用到 Flutter 路由上。Flutter 自带的 Cupertino 返回手势由框架私有的 `_CupertinoBackGestureDetector` 实现，手势区被写死为左缘 20 点（`_kBackGestureWidth`），`CupertinoPageTransitionsBuilder` 也没有把手势区宽度开放成参数。

因此本项目的全局返回手势在 Flutter 层重放，见 [`ios_back_gesture.dart`](../../lib/widgets/route/ios_back_gesture.dart)。

## 实现

[`AppCupertinoPageTransitionsBuilder`](../../lib/widgets/route/ios_back_gesture.dart) 通过 [`theme.dart`](../../lib/theme.dart) 的 `PageTransitionsTheme` 接入 `TargetPlatform.iOS`，因此**所有 `MaterialPageRoute` 自动生效**，业务页面无需改动：转场、跟手、松手判定都沿用官方 Cupertino 实现，只把手势区从 20 点扩到整页。

| 组成 | 做法 |
|---|---|
| 转场动画 | 直接用公开的 `CupertinoPageTransition`，手势进行中 `linearTransition: true` 保证跟手 |
| 上一页视差 | 转发 `CupertinoPageTransition.delegatedTransition`，否则侧滑时上一页停在原地 |
| 手势区 | `Listener(behavior: HitTestBehavior.translucent)` 包裹整页内容，任意位置按下都会参与竞争 |
| 方向门控 | 继承 `HorizontalDragGestureRecognizer`，`hasSufficientGlobalDistanceToAccept` 阶段就拒绝反向拖动；启动阈值抬到 `computePanSlop`（36）之上 |
| 跟手/松手 | 复刻 `_CupertinoBackGestureController`：扣减路由动画进度，过半屏或速度 ≥ 1 屏宽/秒则 pop，否则 350ms 回弹 |
| 放行条件 | 复用 `ModalRoute.popGestureEnabled`：栈底、`PopScope(canPop: false)`、转场进行中、`willHandlePopInternally` 都不起手；`fullscreenDialog` 在 `buildTransitions` 里直接不装手势 |

`TransitionRoute.controller` 是 `@protected` 成员，Flutter 没有公开「在 `PageTransitionsBuilder` 里驱动路由动画」的 API。实现里对它做了一次带注释的 `// ignore: invalid_use_of_protected_member`：不驱动控制器就只能拿到只读的 `Animation<double>`，无法做到跟手，而官方手势同样是在路由内部直接使用该控制器。

## 手势竞争

Flutter 的手势竞技场是**先声明 accepted 者胜**，命中路径更深的识别器会先拿到指针事件。这里有两层因素：

1. **命中深度**：返回手势是包住整页内容的祖先 `Listener`，页面内的滚动组件、翻页容器都在更深的层级；
2. **接受阈值**：`SwipePageView`、`InteractiveViewer` 这类内层组件用的是 pan / scale 识别器，阈值是 `computePanSlop`（36），而普通横向拖动识别器是 `computeHitSlop`（18）。若返回手势沿用 18 的阈值，它会在内层 pan 还没达到阈值前就先接受，把「右滑回上一个 Tab」变成「退出页面」。

因此返回手势的启动阈值取 `max(computeHitSlop, computePanSlop)`：内层 pan 与本识别器累积的是同一个横向位移，抬高阈值后两者会在同一次移动事件里同时跨过阈值，内层因命中更深先接受并胜出。

| 场景 | 结果 |
|---|---|
| [`SwipePageView`](../../lib/widgets/common/swipe_page_view.dart)（pan 识别器）中间页 | 内层横滑优先，返回手势不介入 |
| `SwipePageView` 第一页右滑 / 最后一页左滑 | 组件在竞技场判定阶段不认领：第一页右滑交还返回手势，最后一页左滑两边都不翻 |
| 可横向滚动的 `ListView` / `PageView`（18 阈值、命中更深） | 内层横滑优先 |
| 横向内容不足以滚动（`minScrollExtent == maxScrollExtent`） | 内层不注册拖动识别器，返回手势生效 |
| 普通横向滚动容器停在最左端再向右拖 | 内层仍先接受手势（只是滚不动），返回手势不接管；`SwipePageView` 已在边界显式让位，普通容器未做 |
| 纵向列表 / `CustomScrollView` | 纵向位移不满足横向阈值，列表正常滚动，返回手势不介入 |
| 向左拖动（LTR）/ 向右拖动（RTL） | 在竞技场胜出前就被拒绝，不会「先吞手势再回弹」 |
| 平台视图（原生 Dock、WebView 正文） | 原生视图自带的手势识别器参与同一竞技场，横滑通常归原生侧；从平台视图起手一般不会触发返回 |
| 通知 WebView 页（[`webview_notice_page.dart`](../../lib/widgets/webview/webview_notice_page.dart)） | 该页声明了 `PopScope(canPop: false)`（内部自己处理网页历史回退），`popGestureEnabled` 恒为 false，整页都不参与全局返回手势，与本次改动前一致 |

桌面端的 `MouseBackHandler`（鼠标侧键）与 `TargetPlatform.macOS` 的 FadeForwards 转场不受影响：本构建器只挂在 `TargetPlatform.iOS` 上。嵌套 Navigator（如 `popupOrNavigate` 宽屏 dialog 里的 `Fragment`）里，返回手势按该页自身宽度归一化，只 pop 内层路由。

## 与官方实现的关系

| 行为 | Flutter 内置 `CupertinoPageTransitionsBuilder` | 本项目构建器 |
|---|---|---|
| 手势起点 | 左缘 20 点 | 整页内容区 |
| 方向 | 由区域决定，横滑即判定 | 显式要求「从前往后」 |
| 转场、曲线、阈值、速度判定 | 官方实现 | 同官方实现（复刻） |
| 上一页视差 | `delegatedTransition` | 转发同一实现 |
| `PopScope` / `PopScope(canPop: false)` | 由 `popGestureEnabled` 判 `popDisposition` | 同 |
| `fullscreenDialog` | 不安装手势（`buildPageTransitions` 分支） | 同（`buildTransitions` 分支） |

## 维护注意

- 代码里对 `TransitionRoute.controller`（`@protected`）的访问带 `// ignore: invalid_use_of_protected_member`，与 Flutter 3.44 的 `cupertino/route.dart` 对齐。升级 Flutter 时要复查：`TransitionRoute.controller` 是否仍在、`CupertinoPageTransition` 的 `linearTransition` 语义是否变化、框架是否新增了可直接使用的公开 API（例如 `PredictiveBackRoute` 的 `handleStartBackGesture` 一族，代价是失去 Cupertino 的 350ms + `fastEaseInToSlowEaseOut` 补齐动画）。
- 手势结束时必须保证 `NavigatorState.userGestureInProgress` 复位；测试里统一断言这一点。

## 系统版本边界

实现完全在 Flutter 层，不依赖 UIKit 的新 API 是否可用：iOS 26 以下的系统也会获得同一套全局返回手势。这是有意为之——同一份 Flutter 代码在不同系统版本上保持同一种返回手势，比「26 以下只允许左缘、26 以上全屏」更稳定，也避免为一个纯 Dart 能力增加平台通道探测。若将来要严格对齐系统版本，只需在 `theme.dart` 里按运行时系统版本在两套构建器之间切换。

## 验证状态

[`ios_back_gesture_test.dart`](../../test/ios_back_gesture_test.dart) 覆盖：中央起手过半屏返回、不足半屏回弹、反向拖动不返回、纵向拖动交给页内列表、RTL 双向、内层横向滚动内容优先、内层 pan 翻页容器（`SwipePageView`）优先、转场未结束时不起手、`PopScope(canPop: false)` 拦截、`fullscreenDialog` 不装手势、栈底无副作用、Android 平台不受影响、拖动中被程序化 pop、连续两次返回、`userGestureInProgress` 复位，以及 `buildTheme` 的 iOS 挂载（该接线断言在 [`theme_page_transitions_test.dart`](../../test/theme_page_transitions_test.dart)）。

Widget 测试不能替代真机验收。合入前仍应在 iOS 26+ 真机/模拟器确认：从列表、表单、地图/图片等区域起手的手感，与 `SwipePageView` 翻页、`InteractiveViewer`、横向轮播的手势竞争，通知 WebView 页（当前整页不参与手势）与产品预期是否一致，以及系统「减少动态效果」下的表现。
