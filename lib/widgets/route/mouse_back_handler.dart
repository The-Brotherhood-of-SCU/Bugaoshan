import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/gestures.dart' show kBackMouseButton;
import 'package:flutter/material.dart';

import 'router_utils.dart' show navigatorKey;

/// 全局拦截鼠标侧键 X1（[kBackMouseButton]），按下时调用
/// [NavigatorState.maybePop]，使后退行为与 Android 系统返回键一致：
/// - 子页：被 `Navigator.push` 推入的 route 被 pop；
/// - 栈底（首页 / EULA / 引导）：[NavigatorState.maybePop] 返回 `false`，无操作；
/// - `PopScope(canPop: false)` 的页面静默拦截；
/// - 自带 `onPopInvokedWithResult` 的页面（如 `classroom_page`、`webview_notice_page`）
///   走页面自身的"后退"逻辑；
/// - 嵌套 Navigator（如 `popupOrNavigate` 在宽屏 dialog 内的 `Fragment`
///   子导航）会先 pop 最深一层的 route，到 Fragment 初始页后再退回
///   root 关闭 dialog。
///
/// 故意不处理 X2（`kForwardMouseButton`）——应用内多数页面没有对称的
/// "前进"路径，盲目实现会破坏 [PopScope] 拦截语义与用户预期。
///
/// 仅在桌面端（Windows / Linux / macOS）与 Web 上激活；移动端为
/// `child` 透传，零行为变化。
class MouseBackHandler extends StatelessWidget {
  const MouseBackHandler({super.key, required this.child});

  final Widget child;

  static bool get _isSupported {
    if (kIsWeb) return true;
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  @override
  Widget build(BuildContext context) {
    if (!_isSupported) return child;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (event) {
        if ((event.buttons & kBackMouseButton) == 0) return;
        _handleBack();
      },
      child: child,
    );
  }

  void _handleBack() {
    final rootState = navigatorKey.currentState;
    if (rootState == null) return;
    final target = _topmostNavigator() ?? rootState;

    if (!identical(target, rootState) && !target.canPop()) {
      // 嵌套 Navigator（典型：宽屏 dialog 内 `Fragment` 的初始页）已经
      // 没有可 pop 的 route；退回 root 把 dialog 关掉，与 Android
      // 系统返回键的语义一致。
      rootState.maybePop();
    } else {
      // 交给 maybePop：会尊重 PopScope（`canPop: false` 静默拦截、
      // `onPopInvokedWithResult` 走页面自身逻辑），并在栈底时无副作用。
      target.maybePop();
    }
  }

  /// 通过当前焦点定位最顶层的 [NavigatorState]。
  ///
  /// Flutter 在 `showDialog` / `Navigator.push` 时会默认把焦点移动到
  /// 新 route 的第一个可 focus widget，所以 `primaryFocus` 通常就在
  /// 用户当前正在交互的最深 Navigator 内。找不到焦点上下文时返回
  /// `null`，由调用方退回 root。
  NavigatorState? _topmostNavigator() {
    final focusContext = FocusManager.instance.primaryFocus?.context;
    if (focusContext == null) return null;
    return Navigator.maybeOf(focusContext);
  }
}
