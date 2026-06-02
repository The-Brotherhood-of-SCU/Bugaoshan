import 'package:bugaoshan/services/auth/auth_session.dart';
import 'package:bugaoshan/services/auth/auth_state.dart';
import 'package:bugaoshan/services/auth/scu_auth_session.dart';
import 'package:bugaoshan/services/scu_api_service.dart';
import 'package:bugaoshan/utils/constants.dart';

/// 体测系统的认证会话。
///
/// 依赖 [ScuAuthSession] 的 base session，再执行一次 SSO 跳转。
class FitnessAuthSession extends AuthSession<CookieClient> {
  final ScuAuthSession _scuSession;

  static const _baseUrl =
      'https://pead.scu.edu.cn/bdlp_h5_fitness_test/public/index.php';

  /// 上次执行过 SSO 的底层 client 身份标记。
  CookieClient? _ssoedClient;

  FitnessAuthSession(this._scuSession);

  @override
  String get serviceName => '体测查询';

  @override
  Future<CookieClient> getClient() async {
    if (isExpired) {
      final refreshed = await refresh();
      if (!refreshed) {
        throw ScuLoginException('登录已过期，请重新登录', sessionExpired: true);
      }
    }

    final client = await _scuSession.getClient();

    // 当底层 client 与上次 SSO 过的 client 不是同一实例时，重新执行 SSO
    if (!identical(client, _ssoedClient)) {
      await client.followRedirects(
        Uri.parse('$_baseUrl/index/login/scuMsLogin'),
        headers: {
          'Accept': 'text/html,application/xhtml+xml,*/*',
          'User-Agent': kDefaultUserAgent,
          'Authorization': 'Bearer ${_scuSession.accessToken}',
        },
      );
      _ssoedClient = client;
      state = AuthState.ready;
    }

    return client;
  }

  @override
  Future<bool> refresh() async {
    _ssoedClient = null;
    final refreshed = await _scuSession.refresh();
    if (refreshed) {
      state = AuthState.ready;
      return true;
    }
    state = AuthState.expired;
    return false;
  }

  @override
  Future<void> logout() async {
    _ssoedClient = null;
    state = AuthState.unknown;
  }
}
