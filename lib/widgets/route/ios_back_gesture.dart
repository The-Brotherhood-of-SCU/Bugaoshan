import 'dart:math' as math;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';

/// 手势结束后补齐动画的时长。
///
/// 固定 350ms，取自官方 Cupertino 返回手势（`_kDroppedSwipePageAnimationDuration`），
/// **刻意不跟随「设置 → 动画时长」**：该设置管的是进页/退出的转场，而返回
/// 手势松手后的补齐动画以系统手感为基准，跟着设置变只会比原生快或慢半拍。
const Duration _kSwipeSettleDuration = Duration(milliseconds: 350);

/// 页面前缘的宽度：起手点落在这条带子里时按「边缘返回」处理。
///
/// iOS 26 的系统实现是两个识别器并存：左缘的 `interactivePopGestureRecognizer`
/// 与内容区的 `interactiveContentPopGestureRecognizer`。这里同样保留两层，
/// 否则内容自带横向手势的页面（`PhotoView`、横向列表）连边缘都滑不动——
/// 那是改动前可以返回的地方。
const double _kEdgeGestureWidth = 20.0;

/// 边缘起手时的接受阈值，低于 `kTouchSlop`（18）。
///
/// 边缘识别器要抢在内容自带的横向手势之前接受：普通横向滚动/拖动识别器的
/// 阈值是 18，`HorizontalDragGestureRecognizer` 的兄弟识别器在命中路径上更深，
/// 同阈值时会因先派发而胜出，所以这里必须更小才抢得到。
const double _kEdgeAcceptSlop = 12.0;

/// 触发「甩出」的最小速度，单位为「屏宽/秒」（与 Cupertino 返回手势一致）。
const double _kMinFlingVelocity = 1.0;

/// iOS 版页面转场：保留 Cupertino 的滑动 + 视差转场，把返回手势从「左缘 20
/// 点」扩大到整个内容区，对齐 iOS 26 起系统自带的全局侧滑返回。
///
/// iOS 26 给 `UINavigationController` 新增了
/// `interactiveContentPopGestureRecognizer`：在人造的任何位置做一次「从前往
/// 后」的横向平移即可交互式返回，不再要求从屏幕左缘起手。Flutter 的页面栈
/// 不经过 UIKit 的 `UINavigationController`（根视图是 `FlutterViewController`，
/// 路由由 Dart 侧 `Navigator` 管理），系统手势完全作用不到 Flutter 路由上；
/// 而 Flutter 自带的 [CupertinoPageTransitionsBuilder] 走的是框架私有的
/// `_CupertinoBackGestureDetector`，手势区被写死为 20 点。因此这里在 Flutter
/// 侧重放同一套交互，把转场、跟手、松手判定都对齐官方实现：
///
/// 1. 手势区覆盖整页内容（[Listener] 覆盖 child，命中任意位置都能起手），
///    同时保留左缘 20 点的「边缘优先」通道，见 [_kEdgeGestureWidth]；
/// 2. 只接受「从前往后」的横向平移（LTR 向右、RTL 向左），反向拖动不接受，
///    因此不会把内层的左滑误吞成「返回后又弹回」；
/// 3. 手势竞争交给 Flutter 手势竞技场：识别器的启动阈值抬到内层 pan / scale
///    识别器的阈值之上，`SwipePageView`、`PageView`、`InteractiveViewer` 这类
///    位于更深命中路径的横向手势会先跨过阈值、先声明接受并胜出，横向拖动仍归
///    它们，与系统「内容自带的横向平移优先」一致；`SwipePageView` 另外在滑动
///    边界（第一页向右 / 最后一页向左）不认领手势，右滑才能交还到这里；
/// 4. 松手后的判定、补齐动画和曲线（超过半屏或甩出即 pop，否则回弹）直接
///    复刻 [CupertinoPageTransitionsBuilder] 的实现，视觉与原生一致。
///
/// 因为实现完全在 Flutter 层，它不依赖 UIKit 的可用性：iOS 26 以下的系统也
/// 会获得同一套全局返回手势（旧系统只会提供左缘返回，这里统一为全局返回，
/// 避免同一份代码在不同系统版本上手势范围不同）。
///
/// 返回手势的放行条件由 [ModalRoute.popGestureEnabled] 决定：栈底、`PopScope`
/// 拒绝 pop、转场进行中以及 `willHandlePopInternally` 的路由都不会进入手势；
/// `fullscreenDialog` 路由没有任何「回上一页」语义，直接不安装手势。
class AppCupertinoPageTransitionsBuilder extends PageTransitionsBuilder {
  /// 创建 iOS 版转场构建器。
  const AppCupertinoPageTransitionsBuilder({required this.duration});

  /// 转场（进页 / 退出）时长，由「设置 → 动画时长」决定。
  final Duration duration;

  @override
  Duration get transitionDuration => duration;

  @override
  Duration get reverseTransitionDuration => duration;

  /// 上一页的视差由 Cupertino 转场自带的委托转场完成，必须一并转发，
  /// 否则侧滑时上一页停在原地，只剩当前页右移。
  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      CupertinoPageTransition.delegatedTransition;

  @override
  bool operator ==(Object other) =>
      other is AppCupertinoPageTransitionsBuilder && other.duration == duration;

  @override
  int get hashCode => duration.hashCode;

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // 返回手势进行中改用线性转场，页面才能精确跟手（与官方实现一致）。
    final bool linearTransition = route.popGestureInProgress;
    if (route.fullscreenDialog) {
      // 全屏对话框没有「回上一页」语义，保持原有转场，不装手势。
      return CupertinoFullscreenDialogTransition(
        primaryRouteAnimation: animation,
        secondaryRouteAnimation: secondaryAnimation,
        linearTransition: linearTransition,
        child: child,
      );
    }
    return CupertinoPageTransition(
      primaryRouteAnimation: animation,
      secondaryRouteAnimation: secondaryAnimation,
      linearTransition: linearTransition,
      child: _ContentAreaBackGestureDetector<T>(route: route, child: child),
    );
  }
}

/// 把返回手势的识别区从屏幕左缘扩大到整个页面内容。
class _ContentAreaBackGestureDetector<T> extends StatefulWidget {
  const _ContentAreaBackGestureDetector({
    required this.route,
    required this.child,
  });

  final PageRoute<T> route;
  final Widget child;

  @override
  State<_ContentAreaBackGestureDetector<T>> createState() =>
      _ContentAreaBackGestureDetectorState<T>();
}

class _ContentAreaBackGestureDetectorState<T>
    extends State<_ContentAreaBackGestureDetector<T>> {
  late final _BackGestureRecognizer _recognizer;
  _ContentAreaBackGestureController? _backGestureController;

  @override
  void initState() {
    super.initState();
    _recognizer = _BackGestureRecognizer(debugOwner: this)
      ..onStart = _handleDragStart
      ..onUpdate = _handleDragUpdate
      ..onEnd = _handleDragEnd
      ..onCancel = _handleDragCancel;
  }

  @override
  void dispose() {
    _recognizer.dispose();
    // 手势进行中被销毁时，必须让 Navigator 退出 userGesture 状态，
    // 否则整个 Navigator 的 `userGestureInProgress` 会一直为 true。
    final _ContentAreaBackGestureController? controller =
        _backGestureController;
    _backGestureController = null;
    if (controller != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (controller.navigator.mounted) {
          controller.navigator.didStopUserGesture();
        }
      });
    }
    super.dispose();
  }

  void _handlePointerDown(PointerDownEvent event) {
    if (!_prepareGesture(event.localPosition)) return;
    _recognizer.addPointer(event);
  }

  /// iPad 触控板的两指横滑走 `PointerPanZoom`，与手指拖动分开派发。
  /// 这里同样喂给识别器，让「两指左滑返回」与手指侧滑行为一致。
  void _handlePointerPanZoomStart(PointerPanZoomStartEvent event) {
    if (!_prepareGesture(event.localPosition)) return;
    _recognizer.addPointerPanZoom(event);
  }

  /// 起手前的一次性判定，返回 false 表示本次手势不参与。
  bool _prepareGesture(Offset localPosition) {
    // 已经有一根手指在手势中：不再接管新的指针，避免识别器把活动指针切到
    // 第二根手指后，第一根抬起不触发 onEnd、页面卡在跟手状态。
    if (_backGestureController != null) return false;
    // 与官方实现一致：按下时判定一次，转场进行中 / 栈底 / 被 PopScope 拦截的
    // 路由不参与手势竞争，点击直接透传给页面内容。
    if (!widget.route.popGestureEnabled) return false;
    final bool rtl = Directionality.of(context) == TextDirection.rtl;
    final MediaQueryData mediaQuery = MediaQuery.of(context);
    final double width = context.size?.width ?? 0.0;
    // 起手点距离「前缘」多远：LTR 看左边、RTL 看右边，刘海侧还要更宽。
    final double edgeWidth = math.max(
      rtl ? mediaQuery.padding.right : mediaQuery.padding.left,
      _kEdgeGestureWidth,
    );
    final double leadingDistance = rtl
        ? width - localPosition.dx
        : localPosition.dx;
    _recognizer
      ..reverse = rtl
      ..acceptsFromEdge = leadingDistance <= edgeWidth;
    return true;
  }

  void _handleDragStart(DragStartDetails details) {
    assert(mounted);
    // 按下与真正胜出之间可能隔了若干帧（例如中间被新的 push 顶掉，或页面被
    // PopScope 改成不可 pop），启动前复查一次，避免为不可返回的路由开手势。
    if (!widget.route.popGestureEnabled) return;
    assert(_backGestureController == null);
    final NavigatorState? navigator = widget.route.navigator;
    // 转场动画控制器是 TransitionRoute 的受保护成员，Flutter 没有对外暴露
    // 「在 PageTransitionsBuilder 里驱动路由动画」的公开 API；官方的 Cupertino
    // 返回手势同样是在路由内部直接使用它。不这样做就只能拿到 `Animation<double>`
    // 的只读视图，无法让页面跟手。
    // ignore: invalid_use_of_protected_member
    final AnimationController? controller = widget.route.controller;
    if (navigator == null || controller == null) return;
    _backGestureController = _ContentAreaBackGestureController(
      navigator: navigator,
      controller: controller,
      getIsCurrent: () => widget.route.isCurrent,
      getIsActive: () => widget.route.isActive,
    );
  }

  void _handleDragUpdate(DragUpdateDetails details) {
    assert(mounted);
    final _ContentAreaBackGestureController? controller =
        _backGestureController;
    final double? primaryDelta = details.primaryDelta;
    final double width = context.size?.width ?? 0.0;
    if (controller == null || primaryDelta == null || width <= 0.0) return;
    controller.dragUpdate(_toLogical(primaryDelta / width));
  }

  void _handleDragEnd(DragEndDetails details) {
    assert(mounted);
    final _ContentAreaBackGestureController? controller =
        _backGestureController;
    _backGestureController = null;
    if (controller == null) return;
    final double width = context.size?.width ?? 0.0;
    final double velocity = width <= 0.0
        ? 0.0
        : _toLogical(details.velocity.pixelsPerSecond.dx / width);
    controller.dragEnd(velocity);
  }

  void _handleDragCancel() {
    final _ContentAreaBackGestureController? controller =
        _backGestureController;
    _backGestureController = null;
    // 手势在开始判定前就被取消也会走到这里，此时没有控制器，直接忽略。
    controller?.dragEnd(0.0);
  }

  double _toLogical(double value) =>
      Directionality.of(context) == TextDirection.rtl ? -value : value;

  @override
  Widget build(BuildContext context) {
    assert(debugCheckHasDirectionality(context));
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _handlePointerDown,
      onPointerPanZoomStart: _handlePointerPanZoomStart,
      child: widget.child,
    );
  }
}

/// 只在「从前往后」方向上接受手势的横向拖动识别器。
///
/// 官方实现把手势区限制在左缘 20 点，方向由区域本身保证；手势区扩大到全屏
/// 后必须显式判方向：否则在内容区左滑也会被识别成返回手势，把本该交给内层
/// 或本就无意义的横滑吞掉。判定发生在竞技场胜出之前（[hasSufficientGlobalDistanceToAccept]），
/// 反向拖动根本不会接受手势，内层组件拿到的输入不受影响。
class _BackGestureRecognizer extends HorizontalDragGestureRecognizer {
  _BackGestureRecognizer({super.debugOwner});

  /// 当前文本方向是否为 RTL：RTL 下「从前往后」对应向左滑。
  bool reverse = false;

  /// 本次手势是否从页面前缘起手：边缘通道用更低阈值，优先于内容自带的
  /// 横向手势（`PhotoView` 缩放、横向滚动列表等）。
  bool acceptsFromEdge = false;

  @override
  bool hasSufficientGlobalDistanceToAccept(
    PointerDeviceKind pointerDeviceKind,
    double? deviceTouchSlop,
  ) {
    final double leadingToTrailing = reverse
        ? -globalDistanceMoved
        : globalDistanceMoved;
    if (leadingToTrailing <= 0.0) return false;
    // 启动阈值必须高过内层 pan / scale 识别器的阈值（`kPanSlop` 36 > `kTouchSlop`
    // 18）。竞技场是先声明 accepted 者胜，而 `SwipePageView`、`InteractiveViewer`
    // 这类内层组件用的正是 pan/scale 识别器：若仍用 18 的 hit slop，返回手势会
    // 抢在它们之前接受，把「右滑回上一个 Tab」变成「退出页面」。抬到此阈值后，
    // 两者会在同一次移动事件里同时跨过阈值，内层因命中路径更深先接受并胜出。
    if (acceptsFromEdge) {
      // 边缘通道：比内容识别器（18）更早接受，抢下内容自带的横向手势。
      return leadingToTrailing > _kEdgeAcceptSlop;
    }
    final double slop = math.max(
      computeHitSlop(pointerDeviceKind, gestureSettings),
      computePanSlop(pointerDeviceKind, gestureSettings),
    );
    return leadingToTrailing > slop;
  }
}

/// 驱动路由动画的返回手势控制器（复刻 Cupertino 的私有实现）。
///
/// 全部使用逻辑坐标：0.0 表示新页面已被返回，1.0 表示新页面完全覆盖。
class _ContentAreaBackGestureController {
  _ContentAreaBackGestureController({
    required this.navigator,
    required this.controller,
    required this.getIsCurrent,
    required this.getIsActive,
  }) {
    navigator.didStartUserGesture();
  }

  final NavigatorState navigator;
  final AnimationController controller;
  final ValueGetter<bool> getIsCurrent;
  final ValueGetter<bool> getIsActive;

  /// 拖动量为正表示向「后」滑（页面右移），直接扣减路由动画进度。
  void dragUpdate(double delta) {
    // 拖动期间路由可能已被别处 pop 掉：此时写 `value` 会 stop 掉那条退出动画，
    // 页面会停在半路。框架的预测返回实现同样先判 `isCurrent`。
    if (!getIsCurrent()) return;
    controller.value -= delta;
  }

  /// 手势结束。[velocity] 单位是「屏宽/秒」，正负与拖拽方向一致。
  void dragEnd(double velocity) {
    // 这条曲线是官方按原生 iOS 动画反复对齐后得出的，保持一致。
    const Curve animationCurve = Curves.fastEaseInToSlowEaseOut;
    final bool isCurrent = getIsCurrent();
    final bool animateForward;

    if (!isCurrent) {
      // 页面已经被导航走了：方向只取决于它是否还在栈里，与手势无关。
      // 对应 flutter/flutter#141268。
      animateForward = getIsActive();
    } else if (velocity.abs() >= _kMinFlingVelocity) {
      animateForward = velocity <= 0;
    } else {
      animateForward = controller.value > 0.5;
    }

    if (animateForward) {
      controller.animateTo(
        1.0,
        duration: _kSwipeSettleDuration,
        curve: animationCurve,
      );
    } else {
      if (isCurrent) {
        navigator.pop();
      }
      // 如果 pop 已经让动画走到终点，这里就不用再补动画。
      if (controller.isAnimating) {
        controller.animateBack(
          0.0,
          duration: _kSwipeSettleDuration,
          curve: animationCurve,
        );
      }
    }

    if (controller.isAnimating) {
      // 补齐动画期间保持 userGestureInProgress 为 true，避免转场在飞行途中
      // 从线性切回曲线（CupertinoPageTransition 依赖这个标志）。
      late AnimationStatusListener animationStatusCallback;
      animationStatusCallback = (AnimationStatus status) {
        navigator.didStopUserGesture();
        controller.removeStatusListener(animationStatusCallback);
      };
      controller.addStatusListener(animationStatusCallback);
    } else {
      navigator.didStopUserGesture();
    }
  }
}
