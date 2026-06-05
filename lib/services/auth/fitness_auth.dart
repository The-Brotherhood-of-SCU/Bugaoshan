import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/utils/constants.dart';

/// 体测系统认证（第2层）
///
/// pead.scu.edu.cn 通过 SCU SSO 跳转获取已认证的 CookieClient。
class FitnessAuth {
  final ScuAuth _scuAuth;

  static const _baseUrl =
      'https://pead.scu.edu.cn/bdlp_h5_fitness_test/public/index.php';

  CookieClient? _ssoedClient;
  CookieClient? _lastScuClient;

  FitnessAuth(this._scuAuth);

  /// 获取已认证的体测系统 CookieClient。
  ///
  /// 内部先获取 SCU CookieClient，再执行 SSO 跳转。
  /// 如果 SCU 认证失败，[UnauthenticatedException] 自动穿透。
  Future<CookieClient> getClient() async {
    final scuClient = await _scuAuth.getClient();

    // 当底层 client 与上次 SSO 过的 client 不是同一实例时，重新执行 SSO
    if (!identical(scuClient, _lastScuClient)) {
      _lastScuClient = scuClient;
      _ssoedClient = null;
    }

    if (_ssoedClient != null) return _ssoedClient!;

    await scuClient.followRedirects(
      Uri.parse('$_baseUrl/index/login/scuMsLogin'),
      headers: {
        'Accept': 'text/html,application/xhtml+xml,*/*',
        'User-Agent': kDefaultUserAgent,
        'Authorization': 'Bearer ${_scuAuth.accessToken}',
      },
    );
    _ssoedClient = scuClient;
    return scuClient;
  }

  /// 清除缓存的 SSO client。
  void invalidate() {
    _ssoedClient = null;
  }
}
