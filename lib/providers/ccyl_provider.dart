import 'package:flutter/foundation.dart';
import 'package:bugaoshan/services/auth/ccyl_auth.dart';
import 'package:bugaoshan/services/ccyl/ccyl_service.dart';

/// 第二课堂（CCYL）登录状态的 Provider。
///
/// 内部委托给 [CcylAuth] 执行实际鉴权逻辑。
class CcylProvider extends ChangeNotifier {
  final CcylAuth _ccylAuth;

  CcylProvider(this._ccylAuth) {
    _ccylAuth.addListener(_onAuthChanged);
  }

  void _onAuthChanged() => notifyListeners();

  String? get token => _ccylAuth.token;
  bool get isLoggedIn => _ccylAuth.isLoggedIn;
  CcylService get service => _ccylAuth.service;
  CcylUser? get currentUser => _ccylAuth.service.currentUser;

  @override
  void dispose() {
    _ccylAuth.removeListener(_onAuthChanged);
    super.dispose();
  }

  Future<void> loginWithOAuthCode(String code) async {
    await _ccylAuth.loginWithCode(code);
    notifyListeners();
  }

  Future<void> logout() async {
    await _ccylAuth.logout();
    notifyListeners();
  }

  Future<void> reLogin() async {
    // 触发 getService，如果未登录会自动尝试 reLogin
    try {
      await _ccylAuth.getService();
      notifyListeners();
    } catch (_) {}
  }
}
