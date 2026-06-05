import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/utils/constants.dart';

/// 缴费平台认证（第2层）
///
/// payapp.scu.edu.cn 通过 SCU SSO 跳转获取 airWarrant cookie。
class PayAppAuth {
  final ScuAuth _scuAuth;

  static const _base = 'https://payapp.scu.edu.cn/eleFees';

  CookieClient? _warrantedClient;
  CookieClient? _lastScuClient;

  PayAppAuth(this._scuAuth);

  /// 获取已认证的缴费平台 CookieClient。
  ///
  /// 内部先获取 SCU CookieClient，再执行 OAuth warrant 跳转。
  /// 如果 SCU 认证失败，[UnauthenticatedException] 自动穿透。
  Future<CookieClient> getClient() async {
    final scuClient = await _scuAuth.getClient();

    // 当底层 client 与上次 warrant 过的 client 不是同一实例时，重新执行 warrant
    if (!identical(scuClient, _lastScuClient)) {
      _lastScuClient = scuClient;
      _warrantedClient = null;
    }

    if (_warrantedClient != null) return _warrantedClient!;

    final auth = _scuAuth.accessToken;
    if (auth == null) {
      throw const UnauthenticatedException('未登录');
    }

    await scuClient.followRedirects(
      Uri.parse('$_base/oauth/airWarrant'),
      headers: {
        'Accept': 'text/html,application/xhtml+xml,*/*',
        'User-Agent': kDefaultUserAgent,
        'Authorization': 'Bearer $auth',
      },
    );
    _warrantedClient = scuClient;
    return scuClient;
  }

  /// 清除缓存的 warranted client。
  void invalidate() {
    _warrantedClient = null;
  }
}
