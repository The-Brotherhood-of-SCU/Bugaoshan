import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:bugaoshan/providers/secure_storage_provider.dart';
import 'package:bugaoshan/services/ccyl_oauth_service.dart';
import 'package:bugaoshan/services/ccyl_service.dart';

const _keyCcylToken = 'ccyl_token';
const _keyCcylUserId = 'ccyl_user_id';

class CcylProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;
  final CcylService _service = CcylService();

  CcylProvider(this._prefs) : _secure = SecureStorageProvider.instance {
    _initFromSecureStorage();
  }

  Future<void> _initFromSecureStorage() async {
    _token = await _secure.read(key: _keyCcylToken);
    final userId = await _secure.read(key: _keyCcylUserId);
    if (_token != null) {
      _service.restoreToken(_token!, userId);
    }
  }

  String? _token;
  String? get token => _token;
  bool get isLoggedIn => _token != null;
  CcylService get service => _service;
  CcylUser? get currentUser => _service.currentUser;

  Future<void> loginWithOAuthCode(String code) async {
    await _service.login(code);
    _token = _service.token;
    await _secure.write(key: _keyCcylToken, value: _token!);
    if (_service.currentUser != null) {
      await _secure.write(key: _keyCcylUserId, value: _service.currentUser!.id);
      debugPrint('Saved userId: ${_service.currentUser!.id}');
    }
    debugPrint(
      'loginWithOAuthCode: _service.currentUser=${_service.currentUser?.id}',
    );
    notifyListeners();
  }

  void logout() {
    _service.logout();
    _token = null;
    _secure.delete(key: _keyCcylToken);
    _secure.delete(key: _keyCcylUserId);
    notifyListeners();
  }

  /// 统一认证重新登录后，自动恢复二课登录状态
  Future<void> reLogin() async {
    try {
      final oauthCode = await CcylOAuthService().getOAuthCode();
      if (oauthCode == null) return;
      await loginWithOAuthCode(oauthCode);
    } catch (e) {
      debugPrint('CcylProvider.reLogin error: $e');
    }
  }
}
