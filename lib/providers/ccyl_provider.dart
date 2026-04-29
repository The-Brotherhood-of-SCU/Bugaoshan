import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/services/ccyl_service.dart';

const _keyCcylToken = 'ccyl_token';
const _keyCcylUserId = 'ccyl_user_id';

class CcylProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final CcylService _service = CcylService();

  CcylProvider(this._prefs) {
    _token = _prefs.getString(_keyCcylToken);
    final userId = _prefs.getString(_keyCcylUserId);
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
    await _prefs.setString(_keyCcylToken, _token!);
    if (_service.currentUser != null) {
      await _prefs.setString(_keyCcylUserId, _service.currentUser!.id);
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
    _prefs.remove(_keyCcylToken);
    _prefs.remove(_keyCcylUserId);
    notifyListeners();
  }
}
