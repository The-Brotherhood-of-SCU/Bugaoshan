import 'package:flutter/foundation.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/auth/subsystem_auth.dart';
import 'package:bugaoshan/utils/constants.dart';

/// SSO 中继认证基类（第2层）
///
/// 用于"通过 SCU SSO 跳转到子站"的场景。
/// 子站通过 SCU 的 Bearer token 获取自己的 cookie/session。
///
/// [PayAppAuth] 和 [FitnessAuth] 都继承此类，只需提供不同的 SSO URL。
///
/// 监听 [ScuAuth] 状态变化并转发通知。
abstract class SsoRelayAuth extends ChangeNotifier implements SubsystemAuth {
  final ScuAuth _scuAuth;
  final String _ssoUrl;
  final List<SubsystemAuth> _dependencies;

  CookieClient? _cachedClient;
  CookieClient? _lastScuClient;
  Future<CookieClient>? _loginFuture;

  SsoRelayAuth(
    this._scuAuth,
    this._ssoUrl, {
    List<SubsystemAuth> dependencies = const [],
  }) : _dependencies = List.unmodifiable(dependencies) {
    _scuAuth.addListener(notifyListeners);
  }

  @override
  List<SubsystemAuth> get dependencies => _dependencies;

  @override
  Future<void> ensureAuthenticated() async {
    await getClient();
  }

  /// 获取已认证的子站 CookieClient。
  Future<CookieClient> getClient() async {
    await ensureAuthDependencies(_dependencies);

    final scuClient = await _scuAuth.getClient();

    if (!identical(scuClient, _lastScuClient)) {
      _lastScuClient = scuClient;
      _cachedClient = null;
      _loginFuture = null;
    }

    if (_cachedClient != null) return _cachedClient!;
    if (_loginFuture != null) return _loginFuture!;

    _loginFuture = _login(scuClient);
    try {
      return await _loginFuture!;
    } finally {
      _loginFuture = null;
    }
  }

  Future<CookieClient> _login(CookieClient scuClient) async {
    final auth = _scuAuth.accessToken;
    if (auth == null) throw const UnauthenticatedException();

    await scuClient.followRedirects(
      Uri.parse(_ssoUrl),
      headers: {
        'Accept': 'text/html,application/xhtml+xml,*/*',
        'User-Agent': kDefaultUserAgent,
        'Authorization': 'Bearer $auth',
      },
    );
    _cachedClient = scuClient;
    return scuClient;
  }

  @override
  void invalidate() {
    _cachedClient = null;
    _loginFuture = null;
  }

  @override
  void dispose() {
    _scuAuth.removeListener(notifyListeners);
    super.dispose();
  }
}
