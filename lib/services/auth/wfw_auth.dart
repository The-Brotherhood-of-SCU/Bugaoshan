import 'package:flutter/foundation.dart';
import 'package:bugaoshan/services/auth/auth_state.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/services/auth/subsystem_auth.dart';

/// 微服务认证（第2层）
///
/// wfw.scu.edu.cn 通过 SCU 统一认证 session 认证（CookieClient），
/// 不依赖教务系统 SSO。
///
/// [isReady] 为 true 仅当 session 已实际绑定（[ensureAuthenticated] 成功），
/// 而非 [ScuAuth] 恢复 token 即视为就绪。Provider 应据此决定是否发起数据请求。
class WfwAuth extends ChangeNotifier implements SubsystemAuth {
  final ScuAuth _scuAuth;
  bool _ready = false;

  WfwAuth(this._scuAuth) {
    _scuAuth.addListener(_onScuAuthChanged);
  }

  void _onScuAuthChanged() {
    if (_scuAuth.state == AuthState.unknown) {
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
    await getClient();
    if (!_ready) {
      _ready = true;
      notifyListeners();
    }
  }

  /// 获取已认证的 CookieClient（SSO session）。
  Future<CookieClient> getClient() async {
    final client = await _scuAuth.getClient();
    if (!_ready) {
      _ready = true;
      notifyListeners();
    }
    return client;
  }

  @override
  void invalidate() {
    _ready = false;
  }

  @override
  void dispose() {
    _scuAuth.removeListener(_onScuAuthChanged);
    super.dispose();
  }
}
