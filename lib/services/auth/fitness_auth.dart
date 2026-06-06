import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/sso_relay_auth.dart';

/// 体测系统认证（第2层）
///
/// pead.scu.edu.cn 通过 SCU SSO 跳转获取已认证的 CookieClient。
class FitnessAuth extends SsoRelayAuth {
  FitnessAuth(ScuAuth scuAuth)
    : super(
        scuAuth,
        'https://pead.scu.edu.cn/bdlp_h5_fitness_test/public/index.php/index/login/scuMsLogin',
      );

  @override
  String get moduleId => 'fitness';
}
