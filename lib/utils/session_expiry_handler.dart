import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/scu_login_page.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

/// 统一的 session 过期处理中间件
///
/// 当 API 调用检测到 session 过期时，调用此 handler：
/// 1. 执行 logout() 清除本地 token
/// 2. 弹出提示 Dialog，说明会话已过期
/// 3. 提供「重新登录」按钮引导用户重新认证
class SessionExpiryHandler {
  /// 处理 session 过期
  ///
  /// [authProvider] - SCU 认证 Provider
  /// [context] - 可选的 BuildContext，如果不提供则使用 logicRootContext
  ///
  /// 返回是否重新登录成功
  static Future<bool> handle(
    ScuAuthProvider authProvider, {
    BuildContext? context,
  }) async {
    // 1. 先获取 context（避免 async gap 后使用 BuildContext）
    final effectiveContext = context ?? logicRootContext;
    final l10n = AppLocalizations.of(effectiveContext)!;

    // 2. 执行 logout，清除本地 token
    await authProvider.logout();

    if (!effectiveContext.mounted) return false;

    // 3. 弹出会话过期提示 Dialog
    final result = await showDialog<bool>(
      context: effectiveContext,
      barrierDismissible: false, // 防止用户点击外部关闭
      builder: (ctx) => AlertDialog(
        title: Text(l10n.sessionExpiredTitle),
        content: Text(l10n.sessionExpiredMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.relogin),
          ),
        ],
      ),
    );

    // 4. 如果用户选择重新登录，打开登录页面
    if (result == true) {
      if (effectiveContext.mounted) {
        final loginResult = await Navigator.of(
          effectiveContext,
        ).push<bool>(MaterialPageRoute(builder: (_) => const ScuLoginPage()));
        return loginResult == true;
      }
    }

    return false;
  }
}
