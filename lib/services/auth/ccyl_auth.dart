import 'package:flutter/foundation.dart';
import 'package:bugaoshan/pages/campus/ccyl/models/ccyl_models.dart';
import 'package:bugaoshan/utils/secure_storage.dart';
import 'package:bugaoshan/services/auth/ccyl_oauth_service.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/ccyl/ccyl_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/auth/subsystem_auth.dart';

const _keyCcylToken = 'ccyl_token';
const _keyCcylUserId = 'ccyl_user_id';

/// 第二课堂认证（第2层）
///
/// 管理 CCYL 的 token、用户信息、登录/登出。
/// CCYL 拥有独立于 SCU 的 OAuth token 体系，不共享 session cookie。
/// reLogin 时通过 [CcylOAuthService] 从 SCU 获取 OAuth code。
class CcylAuth extends ChangeNotifier implements SubsystemAuth {
  final ScuAuth _scuAuth;
  String? _token;
  CcylUser? _currentUser;
  Future<bool>? _reLoginFuture;

  CcylAuth(this._scuAuth);

  @override
  String get moduleId => 'ccyl';

  @override
  List<SubsystemAuth> get dependencies => const [];

  String? get token => _token;
  bool get isLoggedIn => _token != null;
  CcylUser? get currentUser => _currentUser;

  /// 从安全存储恢复 token（应用启动时调用）。
  Future<void> init() async {
    final secure = SecureStorageProvider.instance;
    _token = await secure.read(key: _keyCcylToken);
    final userId = await secure.read(key: _keyCcylUserId);
    if (_token != null && userId != null) {
      _currentUser = CcylUser(
        id: userId,
        userName: '',
        realname: '',
        orgName: '',
      );
    }
  }

  /// 获取当前 token，未登录时抛 [UnauthenticatedException]。
  String requireToken() {
    if (_token == null) throw const UnauthenticatedException('第二课堂未登录');
    return _token!;
  }

  @override
  Future<void> ensureAuthenticated() async {
    if (_token != null) return;
    final ok = await reLogin();
    if (!ok) throw const UnauthenticatedException('第二课堂未登录');
  }

  /// 获取当前用户 ID，未登录时抛 [UnauthenticatedException]。
  String requireUserId() {
    if (_currentUser == null) throw const UnauthenticatedException('第二课堂未登录');
    return _currentUser!.id;
  }

  /// 使用 OAuth code 登录。
  Future<void> loginWithCode(String code) async {
    final result = await CcylService.login(code);
    _token = result.token;
    _currentUser = result.user;
    await _saveToSecure();
    notifyListeners();
  }

  /// 通过 SCU 自动恢复 CCYL 登录（OAuth 静默绑定）。
  Future<bool> reLogin() async {
    if (_reLoginFuture != null) return _reLoginFuture!;
    _reLoginFuture = _doReLogin();
    try {
      return await _reLoginFuture!;
    } finally {
      _reLoginFuture = null;
    }
  }

  Future<bool> _doReLogin() async {
    try {
      final oauth = CcylOAuthService(_scuAuth);
      final oauthCode = await oauth.getOAuthCode();
      if (oauthCode == null) return false;
      final result = await CcylService.login(oauthCode);
      _token = result.token;
      _currentUser = result.user;
      await _saveToSecure();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('CcylAuth.reLogin error: $e');
      return false;
    }
  }

  @override
  void invalidate() {
    _reLoginFuture = null;
  }

  Future<void> _saveToSecure() async {
    final secure = SecureStorageProvider.instance;
    await secure.write(key: _keyCcylToken, value: _token!);
    if (_currentUser != null) {
      await secure.write(key: _keyCcylUserId, value: _currentUser!.id);
    }
  }

  Future<void> logout() async {
    _token = null;
    _currentUser = null;
    _reLoginFuture = null;
    final secure = SecureStorageProvider.instance;
    await secure.delete(key: _keyCcylToken);
    await secure.delete(key: _keyCcylUserId);
    notifyListeners();
  }
}
