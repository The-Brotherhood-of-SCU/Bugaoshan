import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/serivces/ccyl_service.dart';

const _keyCcylToken = 'ccyl_token';

class CcylProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final CcylService _service = CcylService();

  CcylProvider(this._prefs) {
    _token = _prefs.getString(_keyCcylToken);
    if (_token != null) {
      _service.restoreToken(_token!);
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
    notifyListeners();
  }

  void logout() {
    _service.logout();
    _token = null;
    _prefs.remove(_keyCcylToken);
    notifyListeners();
  }
}
