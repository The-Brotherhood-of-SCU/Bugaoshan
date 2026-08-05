import 'dart:convert';

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
    // 预热 wfw session：不带 AJAX header 访问需登录的 get-info。匿名时
    // wfw 会 302 → /uc/wap/login → /a_scu/api/cas/login → id.scu.edu.cn
    // CAS → 回跳 wfw，跟随该链在 CookieClient 中建立绑定用户的 session
    // cookie；已绑定时 get-info 直接返回 e==0，一跳完成。
    //
    // 不能用首页预热：wfw 首页匿名访问也直接 200 并下发匿名 eai-sess
    // cookie，永远不触发 SSO 链，session 并未绑定用户。仅凭状态码或
    // 「jar 里有 wfw cookie」判就绪都会把匿名 session 误报为 ready，
    // 随后业务请求必然失效：invalidate → 重新预热 → 再次误报 ready →
    // 通知监听方重新取数，形成死循环。就绪判据必须是最终响应为
    // e==0 的 JSON —— id session 失效时链路终点是 id.scu.edu.cn/login
    // 的 HTML 登录页。
    const warmUpUrl = 'https://wfw.scu.edu.cn/uc/wap/user/get-info';
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
      if (!_isBoundSessionBody(response.body)) {
        _log.w(_tag, 'warm-up: session not bound (login page or e!=0)');
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

  /// 仅当 get-info 最终响应为 e==0 的 JSON 时，才证明 wfw session
  /// 已绑定用户（而非匿名 session 或落在 SSO 登录页）。
  bool _isBoundSessionBody(String body) {
    try {
      final json = jsonDecode(body);
      return json is Map<String, dynamic> && json['e'] == 0;
    } catch (_) {
      return false;
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
