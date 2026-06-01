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

  /// 本会话缓存的 client，供重复使用，避免每次调用都创建新连接。
  http.Client? _cachedClient;

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

    // 缓存 client，后续调用复用同一实例。
    // 用 identical 判断而非 ??=：当 SCU 侧 invalidateCachedClient() 后
    // bindSession() 会返回新的 CookieClient 实例（cookie 已重置），此时必须
    // 同步替换 payapp 的缓存，否则业务方会拿到旧 client + 旧 cookie，导致
    // 鉴权失败或请求落到旧 session。跟上方 _warrantedClient 的判断方式保持一致。
    if (!identical(client, _cachedClient)) {
      _cachedClient = client;
    }
    return _cachedClient!;
  }

  @override
  Future<bool> refresh() async {
    _warrantedClient = null;
    _cachedClient = null;
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
    _cachedClient?.close();
    _cachedClient = null;
    state = AuthState.unknown;
  }
}
