import 'package:http/http.dart' as http;
import 'package:bugaoshan/services/auth/auth_session.dart';
import 'package:bugaoshan/services/auth/auth_state.dart';
import 'package:bugaoshan/services/auth/scu_auth_session.dart';
import 'package:bugaoshan/services/balance_query_service.dart';
import 'package:bugaoshan/utils/constants.dart';

/// 电费/空调余额查询系统的认证会话。
///
/// 依赖 [ScuAuthSession] 的 base session，再执行一次 OAuth warrant 跳转。
class PayAppAuthSession extends AuthSession<http.Client> {
  final ScuAuthSession _scuSession;

  static const _base = 'https://payapp.scu.edu.cn/eleFees';

  /// 上次执行过 warrant 的底层 client 身份标记。
  /// 通过对比指针/身份来判断是否需要重新执行 warrant。
  http.Client? _warrantedClient;

  PayAppAuthSession(this._scuSession);

  @override
  String get serviceName => '电费查询';

  @override
  Future<http.Client> getClient() async {
    if (isExpired) {
      final refreshed = await refresh();
      if (!refreshed) {
        throw BalanceQueryAuthException('notLoggedIn');
      }
    }

    final client = await _scuSession.getClient();

    // 当底层 client 与上次 warrant 过的 client 不是同一实例时，重新执行 warrant
    if (!identical(client, _warrantedClient)) {
      final auth = _scuSession.accessToken;
      if (auth == null) throw BalanceQueryAuthException('notLoggedIn');
      await client.followRedirects(
        Uri.parse('$_base/oauth/airWarrant'),
        headers: {
          'Accept': 'text/html,application/xhtml+xml,*/*',
          'User-Agent': kDefaultUserAgent,
          'Authorization': 'Bearer $auth',
        },
      );
      _warrantedClient = client;
      state = AuthState.ready;
    }

    return client;
  }

  @override
  Future<bool> refresh() async {
    _warrantedClient = null;
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
    _warrantedClient = null;
    state = AuthState.unknown;
  }
}
