import 'package:flutter/foundation.dart';
import 'package:bugaoshan/pages/campus/ccyl/models/ccyl_models.dart';
import 'package:bugaoshan/scu_backend/ccyl/ccyl_api_service.dart';
import 'package:bugaoshan/scu_backend/ccyl/ccyl_auth.dart';

/// 第二课堂（CCYL）登录状态的 Provider。
///
/// 内部委托给 [CcylAuth] 执行实际鉴权逻辑。
/// UI 通过 [service] 访问 API 方法（自动携带 token）。
class CcylProvider extends ChangeNotifier {
  final CcylAuth _ccylAuth;
  final CcylApiService _apiService;

  CcylProvider(this._ccylAuth, this._apiService) {
    _ccylAuth.addListener(_onAuthChanged);
  }

  void _onAuthChanged() => notifyListeners();

  String? get token => _ccylAuth.token;
  bool get isLoggedIn => _ccylAuth.isLoggedIn;
  CcylUser? get currentUser => _ccylAuth.currentUser;

  /// API Service，UI 通过此访问所有 CCYL 数据 API。
  /// 自动处理 token 注入，未登录时抛 [UnauthenticatedException]。
  CcylApiService get service => _apiService;

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
    final success = await _ccylAuth.reLogin();
    if (success) notifyListeners();
  }
}
