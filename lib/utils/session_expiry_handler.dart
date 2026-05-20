import 'package:flutter/material.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/auth/scu_login_page.dart';
import 'package:bugaoshan/providers/ccyl_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

/// 统一的 session 过期处理中间件
///
/// 当 API 调用检测到 session 过期时，调用此 handler：
/// 1. 如果用户启用了自动登录，尝试静默重新登录
/// 2. 自动登录失败或未启用时，弹出提示 Dialog
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

    // 2. 在 logout 前读取自动登录状态（logout 会清除该标志）
    final wasAutoLoginEnabled = await authProvider.isAutoLoginEnabled();

    // 3. 执行 logout，清除本地 token
    await authProvider.logout();

    if (!effectiveContext.mounted) return false;

    // 4. 如果用户启用了自动登录，尝试静默重新登录
    if (wasAutoLoginEnabled) {
      await authProvider.setAutoLogin(true);
      final autoLoginSuccess = await authProvider.autoLogin();
      if (autoLoginSuccess) {
        // 统一认证恢复后，自动恢复二课等子系统登录状态
        getIt<CcylProvider>().reLogin();
        return true;
      }
    }

    // 5. 自动登录未启用或失败，弹出会话过期提示 Dialog
    if (!effectiveContext.mounted) return false;
    final result = await GlassDialog.show<bool>(
      context: effectiveContext,
      title: l10n.sessionExpiredTitle,
      message: l10n.sessionExpiredMessage,
      actions: [
        GlassDialogAction(
          label: l10n.cancel,
          onPressed: () => Navigator.pop(effectiveContext, false),
        ),
        GlassDialogAction(
          label: l10n.relogin,
          isPrimary: true,
          onPressed: () => Navigator.pop(effectiveContext, true),
        ),
      ],
    );

    // 6. 如果用户选择重新登录，打开登录页面
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
