import 'package:flutter/foundation.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/services/auth/auth_state.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
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

  WfwAuth(this._scuAuth, {AuthLogger? logger})
    : _log = logger ?? getIt<AuthLogger>() {
    _scuAuth.addListener(_onScuAuthChanged);
  }

  void _onScuAuthChanged() {
    if (_scuAuth.state == AuthState.unknown) {
      if (_ready) _log.d(_tag, 'scu logged out, marking not ready');
      _ready = false;
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
    _log.d(_tag, 'ensureAuthenticated: warming wfw session');
    final client = await _scuAuth.getClient();
    // 预热 wfw session：不带 AJAX header 访问 wfw 首页，触发 SSO
    // 重定向链，在 CookieClient 中建立 wfw.scu.edu.cn 的 session cookie。
    // 不这么做的话，冷启动时页面带 X-Requested-With 的 API 请求会被
    // wfw 服务端直接返回 "用户信息已失效" 而不走 SSO 重定向。
    try {
      await client.get(
        Uri.parse('https://wfw.scu.edu.cn/'),
        headers: {'User-Agent': kDefaultUserAgent},
      );
      _log.d(_tag, 'warm-up request ok');
    } catch (e) {
      _log.w(_tag, 'warm-up request failed (non-fatal): $e');
      // 预热失败不阻塞，实际 API 调用可能仍能触发重定向
    }
    if (!_ready) {
      _ready = true;
      _log.i(_tag, 'ready');
      notifyListeners();
    }
  }

  /// 获取已认证的 CookieClient（SSO session）。
  Future<CookieClient> getClient() async {
    final client = await _scuAuth.getClient();
    if (!_ready) {
      _ready = true;
      _log.d(_tag, 'getClient: lazy-ready');
      notifyListeners();
    }
    return client;
  }

  @override
  void invalidate() {
    if (_ready) _log.d(_tag, 'invalidate');
    _ready = false;
  }

  @override
  void dispose() {
    _scuAuth.removeListener(_onScuAuthChanged);
    super.dispose();
  }
}
