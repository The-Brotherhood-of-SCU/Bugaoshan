import 'package:flutter/foundation.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/auth/subsystem_auth.dart';
import 'package:bugaoshan/utils/auth_logger.dart';
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
  final AuthLogger _log;

  String get _tag => moduleId.toUpperCase();

  CookieClient? _cachedClient;
  CookieClient? _lastScuClient;
  Future<CookieClient>? _loginFuture;

  bool _isReady = false;

  /// 子系统 session 是否已就绪（SSO 中继已完成）。
  /// 页面应在 [isReady] 为 true 后才发起 API 请求，
  /// 避免冷启动竞态导致的 session 失效报错。
  bool get isReady => _isReady;

  SsoRelayAuth(
    this._scuAuth,
    this._ssoUrl, {
    List<SubsystemAuth> dependencies = const [],
    AuthLogger? logger,
  }) : _dependencies = List.unmodifiable(dependencies),
       _log = logger ?? getIt<AuthLogger>() {
    _scuAuth.addListener(_onScuAuthChanged);
  }

  void _onScuAuthChanged() {
    if (!_scuAuth.isReady) {
      _isReady = false;
    }
    notifyListeners();
  }

  @override
  List<SubsystemAuth> get dependencies => _dependencies;

  @override
  Future<void> ensureAuthenticated() async {
    _log.d(_tag, 'ensureAuthenticated');
    await getClient();
  }

  /// 获取已认证的子站 CookieClient。
  Future<CookieClient> getClient() async {
    await ensureAuthDependencies(_dependencies);

    final scuClient = await _scuAuth.getClient();

    if (!identical(scuClient, _lastScuClient)) {
      _log.d(_tag, 'scu client changed, clearing cache');
      _lastScuClient = scuClient;
      _cachedClient = null;
      _loginFuture = null;
    }

    if (_cachedClient != null) {
      _log.d(_tag, 'getClient: cache hit');
      return _cachedClient!;
    }
    if (_loginFuture != null) {
      _log.d(_tag, 'getClient: awaiting existing login');
      return _loginFuture!;
    }

    _log.i(_tag, 'getClient: starting SSO relay');
    _loginFuture = _login(scuClient);
    try {
      final client = await _loginFuture!;
      if (!_isReady) {
        _isReady = true;
        _log.i(_tag, 'ready');
        notifyListeners();
      }
      return client;
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
    _log.i(_tag, 'SSO relay: ok');
    return scuClient;
  }

  @override
  void invalidate() {
    _log.d(_tag, 'invalidate');
    _cachedClient = null;
    _loginFuture = null;
    _lastScuClient = null;
    _isReady = false;
  }

  @override
  void dispose() {
    _scuAuth.removeListener(_onScuAuthChanged);
    super.dispose();
  }
}
