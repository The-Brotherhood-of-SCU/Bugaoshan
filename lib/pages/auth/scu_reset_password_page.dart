import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/widgets/webview/webview_notice_page.dart';
import 'package:flutter/material.dart';

/// 统一身份认证「重置密码」页。
///
/// 官方流程为三步：确认账户（学/工号 + 验证码）→ 短信/邮件安全验证 →
/// 设置新密码。该流程不依赖登录态（忘记密码时使用），验证方式与服务端
/// 强绑定，因此直接以 WebView 打开官方页面，不在应用内复刻表单。
class ScuResetPasswordPage extends StatelessWidget {
  const ScuResetPasswordPage({super.key});

  @override
  Widget build(BuildContext context) {
    return WebViewNoticePage(
      url: scuResetPasswordUrl,
      beautifyAsset: null,
      title: AppLocalizations.of(context)!.resetPassword,
      heroTag: 'scu_reset_password',
      debugLabel: 'ScuResetPassword',
    );
  }
}
