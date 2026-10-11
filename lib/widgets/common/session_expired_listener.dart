import 'dart:async';

import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/auth/scu_login_page.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';

/// 全局 session 过期监听器。
///
/// 包裹在 [MaterialApp] 内层，监听 [ScuAuth.onSessionExpired] 回调，
/// 统一显示带「前往登录」action 的 [SnackBar]。
class SessionExpiredListener extends StatefulWidget {
  final Widget child;
  const SessionExpiredListener({super.key, required this.child});

  @override
  State<SessionExpiredListener> createState() => _SessionExpiredListenerState();
}

class _SessionExpiredListenerState extends State<SessionExpiredListener> {
  late final ScuAuth _auth;
  bool _handling = false;
  Timer? _cooldownTimer;
  Locale? _locale;
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _snackBar;

  @override
  void initState() {
    super.initState();
    _auth = getIt<ScuAuth>();
    _auth.onSessionExpired = _onSessionExpired;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final locale = Localizations.localeOf(context);
    final snackBar = _snackBar;
    if (_locale != null && _locale != locale && snackBar != null) {
      // 在本帧结束后替换仍有效的过期提示，同时更新正文和登录按钮。
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _snackBar != snackBar) return;
        final rootContext = navigatorKey.currentContext;
        if (rootContext == null || !rootContext.mounted) return;
        ScaffoldMessenger.of(rootContext)
          ..clearSnackBars()
          ..removeCurrentSnackBar();
        _showSnackBar(rootContext);
      });
    }
    _locale = locale;
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    if (_auth.onSessionExpired == _onSessionExpired) {
      _auth.onSessionExpired = null;
    }
    super.dispose();
  }

  void _onSessionExpired() {
    if (!mounted || _handling) return;
    _handling = true;

    // 导航树不可用（currentContext 为 null 或已卸载）时复位标志，
    // 避免空断言异常使 _handling 永久卡死、过期提示再也不弹出。
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      _handling = false;
      return;
    }
    ScaffoldMessenger.of(context).clearSnackBars();
    _showSnackBar(context);

    // 冷却期 5s，防止短时间内重复弹出
    _cooldownTimer = Timer(const Duration(seconds: 5), () => _handling = false);
  }

  void _showSnackBar(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    final controller = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.sessionExpired),
        action: SnackBarAction(
          label: l10n.goToLogin,
          onPressed: () async {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            await Navigator.of(context).push<bool>(
              MaterialPageRoute(builder: (_) => const ScuLoginPage()),
            );
            // 登录成功后 ScuLoginPage pop(true)，自动回到当前页
          },
        ),
      ),
    );
    _snackBar = controller;
    controller.closed.then((_) {
      if (_snackBar == controller) _snackBar = null;
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
