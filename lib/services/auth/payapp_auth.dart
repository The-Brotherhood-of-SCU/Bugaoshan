import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/sso_relay_auth.dart';
import 'package:bugaoshan/services/auth/wfw_auth.dart';

/// 缴费平台认证（第2层）
///
/// payapp.scu.edu.cn 通过 SCU SSO 跳转获取 airWarrant cookie。
class PayAppAuth extends SsoRelayAuth {
  PayAppAuth(ScuAuth scuAuth, WfwAuth wfwAuth)
    : super(
        scuAuth,
        'https://payapp.scu.edu.cn/eleFees/oauth/airWarrant',
        dependencies: [wfwAuth],
      );

  @override
  String get moduleId => 'payapp';
}
