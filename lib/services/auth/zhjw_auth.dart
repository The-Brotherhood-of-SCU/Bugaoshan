import 'package:flutter/foundation.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/auth/subsystem_auth.dart';
import 'package:bugaoshan/utils/constants.dart';

/// 教务系统认证（第2层）
///
/// 通过 SCU JWT SSO 获取 zhjw.scu.edu.cn 的 session cookie。
///
/// 监听 [ScuAuth] 状态变化并转发通知，Provider 可通过 addListener 感知。
class ZhjwAuth extends ChangeNotifier implements SubsystemAuth {
  final ScuAuth _scuAuth;
  CookieClient? _cachedClient;
  CookieClient? _lastScuClient;
  Future<CookieClient>? _loginFuture;

  ZhjwAuth(this._scuAuth) {
    _scuAuth.addListener(notifyListeners);
  }

  @override
  String get moduleId => 'zhjw';

  @override
  List<SubsystemAuth> get dependencies => const [];

  @override
  Future<void> ensureAuthenticated() async {
    await getClient();
  }

  /// 获取已认证的教务系统 CookieClient。
  ///
  /// 如果 SCU 认证失败，[UnauthenticatedException] 自动穿透。
  Future<CookieClient> getClient() async {
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

  Future<CookieClient> _login(CookieClient client) async {
    final auth = _scuAuth.accessToken;
    if (auth == null) throw const UnauthenticatedException();

    await client.followRedirects(
      Uri.parse(
        'https://id.scu.edu.cn/enduser/sp/sso/scdxplugin_jwt23'
        '?enterpriseId=scdx&target_url=index',
      ),
      headers: {
        'Accept': 'text/html,application/xhtml+xml,*/*',
        'User-Agent': kDefaultUserAgent,
        'Authorization': 'Bearer $auth',
      },
    );
    _cachedClient = client;
    return client;
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
