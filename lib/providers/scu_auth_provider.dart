import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/serivces/scu_auth_service.dart';

const _keyAccessToken = 'scu_access_token';

/// 持久化 SCU 登录状态的 Provider，注册为 singleton
class ScuAuthProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final ScuAuthService _service = ScuAuthService();

  ScuAuthProvider(this._prefs) {
    _accessToken = _prefs.getString(_keyAccessToken);
  }

  String? _accessToken;
  String? get accessToken => _accessToken;
  bool get isLoggedIn => _accessToken != null;

  ScuAuthService get service => _service;

  Future<void> login({
    required String username,
    required String password,
    required String captchaCode,
    required String captchaText,
  }) async {
    await _service.login(
      username: username,
      password: password,
      captchaCode: captchaCode,
      captchaText: captchaText,
    );
    _accessToken = _service.accessToken;
    await _prefs.setString(_keyAccessToken, _accessToken!);
    notifyListeners();
  }

  Future<void> logout() async {
    _service.logout();
    _accessToken = null;
    await _prefs.remove(_keyAccessToken);
    notifyListeners();
  }
}
