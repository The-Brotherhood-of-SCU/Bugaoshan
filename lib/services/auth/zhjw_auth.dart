import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';

/// 教务系统认证（第2层）
///
/// zhjw.scu.edu.cn 的 SSO 预热已在 [ScuAuth.bindSession] 中完成，
/// 共享同一个 CookieClient，因此只需代理 [ScuAuth.getClient]。
class ZhjwAuth {
  final ScuAuth _scuAuth;
  ZhjwAuth(this._scuAuth);

  /// 获取已认证的教务系统 CookieClient。
  ///
  /// 如果 SCU 认证失败，[UnauthenticatedException] 自动穿透。
  Future<CookieClient> getClient() => _scuAuth.getClient();
}
