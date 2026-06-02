import 'package:flutter/foundation.dart';
import 'package:bugaoshan/services/auth/auth_manager.dart';
import 'package:bugaoshan/services/ccyl_service.dart';

/// 第二课堂（CCYL）登录状态的 Provider。
///
/// 内部委托给 [AuthManager.ccyl]（[CcylAuthSession]）执行实际鉴权逻辑。
class CcylProvider extends ChangeNotifier {
  final AuthManager _authManager;

  CcylProvider._(this._authManager) {
    _authManager.addListener(_onAuthChanged);
  }

  static Future<CcylProvider> create(AuthManager authManager) async {
    final provider = CcylProvider._(authManager);
    return provider;
  }

  void _onAuthChanged() => notifyListeners();

  String? get token => _authManager.ccyl.token;
  bool get isLoggedIn => _authManager.isCcylLoggedIn;
  CcylService get service => _authManager.ccyl.service;
  CcylUser? get currentUser => _authManager.ccyl.service.currentUser;

  @override
  void dispose() {
    _authManager.removeListener(_onAuthChanged);
    super.dispose();
  }

  Future<void> loginWithOAuthCode(String code) async {
    await _authManager.ccyl.loginWithCode(code);
    notifyListeners();
  }

  Future<void> logout() async {
    await _authManager.ccyl.logout();
    notifyListeners();
  }

  Future<void> reLogin() async {
    final success = await _authManager.ccyl.reLogin();
    if (success) notifyListeners();
  }
}
