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
  bool _handling = false;

  @override
  void initState() {
    super.initState();
    getIt<ScuAuth>().onSessionExpired = _onSessionExpired;
  }

  void _onSessionExpired() {
    if (_handling) return;
    _handling = true;

    // 导航树不可用（currentContext 为 null 或已卸载）时复位标志，
    // 避免空断言异常使 _handling 永久卡死、过期提示再也不弹出。
    final context = navigatorKey.currentContext;
    if (context == null || !context.mounted) {
      _handling = false;
      return;
    }
    final l10n = AppLocalizations.of(context)!;

    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
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

    // 冷却期 5s，防止短时间内重复弹出
    Future.delayed(const Duration(seconds: 5), () => _handling = false);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
