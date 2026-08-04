import 'package:flutter/foundation.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/services/auth/auth_state.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/auth/subsystem_auth.dart';
import 'package:bugaoshan/utils/auth_logger.dart';
import 'package:bugaoshan/utils/constants.dart';

/// 微服务认证（第2层）
///
/// wfw.scu.edu.cn 通过 SCU 统一认证 session 认证（CookieClient），
/// 不依赖教务系统 SSO。
///
/// [isReady] 为 true 仅当 session 已实际绑定（[ensureAuthenticated] 成功），
/// 而非 [ScuAuth] 恢复 token 即视为就绪。Provider 应据此决定是否发起数据请求。
class WfwAuth extends ChangeNotifier implements SubsystemAuth {
  static const String _tag = 'WfwAuth';

  final ScuAuth _scuAuth;
  final AuthLogger _log;
  bool _ready = false;
  CookieClient? _lastScuClient;
  Future<void>? _warmUpFuture;

  WfwAuth(this._scuAuth, {AuthLogger? logger})
    : _log = logger ?? getIt<AuthLogger>() {
    _scuAuth.addListener(_onScuAuthChanged);
  }

  void _onScuAuthChanged() {
    if (_scuAuth.state == AuthState.unknown) {
      if (_ready) _log.d(_tag, 'scu logged out, marking not ready');
      _ready = false;
      _lastScuClient = null;
      _warmUpFuture = null;
    }
    notifyListeners();
  }

  @override
  String get moduleId => 'wfw';

  @override
  List<SubsystemAuth> get dependencies => const [];

  AuthState get state => _ready ? AuthState.ready : AuthState.unknown;
  bool get isReady => _ready;

  @override
  Future<void> ensureAuthenticated() async {
    final client = await _scuAuth.getClient();
    await _ensureClientReady(client);
  }

  Future<void> _ensureClientReady(CookieClient client) async {
    if (!identical(client, _lastScuClient)) {
      final wasReady = _ready;
      _log.d(_tag, 'scu client changed, clearing ready state');
      _lastScuClient = client;
      _warmUpFuture = null;
      _ready = false;
      if (wasReady) notifyListeners();
    }

    if (_ready) return;
    final existing = _warmUpFuture;
    if (existing != null) {
      await existing;
      return;
    }

    final future = _warmUp(client);
    _warmUpFuture = future;
    try {
      await future;
    } finally {
      if (identical(_warmUpFuture, future)) {
        _warmUpFuture = null;
      }
    }
  }

  Future<void> _warmUp(CookieClient client) async {
    _log.d(_tag, 'ensureAuthenticated: warming wfw session');
    // 预热 wfw session：不带 AJAX header 访问 wfw 首页，触发 SSO
    // 重定向链，在 CookieClient 中建立 wfw.scu.edu.cn 的 session cookie。
    // 不这么做的话，冷启动时页面带 X-Requested-With 的 API 请求会被
    // wfw 服务端直接返回 "用户信息已失效" 而不走 SSO 重定向。
    const warmUpUrl = 'https://wfw.scu.edu.cn/';
    try {
      final response = await client.followRedirects(
        Uri.parse(warmUpUrl),
        headers: {'User-Agent': kDefaultUserAgent},
      );
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw const UnauthenticatedException('微服务登录已失效');
      }
      if (response.statusCode < 200 || response.statusCode >= 400) {
        throw ServiceException('微服务预热失败', statusCode: response.statusCode);
      }
      // 匿名访问首页也可能直接 200（不走 SSO 重定向、不下发 Set-Cookie）。
      // 仅凭状态码会把「session 未建立」误判为 ready，随后业务请求必然失效：
      // invalidate → 重新预热 → 再次误报 ready → 通知监听方重新取数，
      // 形成死循环。必须确认 wfw 域 cookie 已实际写入 jar。
      if (!client.hasCookiesFor(Uri.parse(warmUpUrl))) {
        _log.w(_tag, 'warm-up: no wfw cookie bound, session not established');
        throw const UnauthenticatedException('微服务 session 未建立');
      }
      _log.d(_tag, 'warm-up request ok');
      if (identical(client, _lastScuClient) && !_ready) {
        _ready = true;
        _log.i(_tag, 'ready');
        notifyListeners();
      }
    } catch (e) {
      _log.w(_tag, 'warm-up request failed: $e');
      rethrow;
    }
  }

  /// 获取已认证的 CookieClient（SSO session）。
  Future<CookieClient> getClient() async {
    final client = await _scuAuth.getClient();
    await _ensureClientReady(client);
    return client;
  }

  @override
  void invalidate() {
    if (_ready) _log.d(_tag, 'invalidate');
    _ready = false;
    _lastScuClient = null;
    _warmUpFuture = null;
  }

  @override
  void dispose() {
    _scuAuth.removeListener(_onScuAuthChanged);
    super.dispose();
  }
}
