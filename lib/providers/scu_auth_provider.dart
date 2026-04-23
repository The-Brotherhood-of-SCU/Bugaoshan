import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/serivces/scu_auth_service.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/ccyl_provider.dart';
import 'package:bugaoshan/providers/secure_storage_provider.dart';

const _keyAccessToken = 'scu_access_token';
const _keyLoginTimestamp = 'scu_login_timestamp';
const _keyLastAppOpenTimestamp = 'scu_last_app_open_timestamp';
const _sessionDurationSeconds = 3600;

const _keySavedUsername = 'scu_saved_username';
const _keySavedPassword = 'scu_saved_password';
const _keyRemember = 'scu_remember_password';

/// 持久化 SCU 登录状态的 Provider，注册为 singleton
class ScuAuthProvider extends ChangeNotifier {
  final SharedPreferences _prefs;
  final ScuAuthService _service = ScuAuthService();

  ScuAuthProvider(this._prefs) {
    _loginTimestamp = _prefs.getInt(_keyLoginTimestamp);
    _updateLastAppOpenTimestamp();
  }

  Future<void> init() async {
    _accessToken = await SecureStorageProvider.instance.read(
      key: _keyAccessToken,
    );
  }

  String? _accessToken;
  int? _loginTimestamp;
  String? get accessToken => _accessToken;
  bool get isLoggedIn => _accessToken != null && !isExpired;
  bool get isExpired {
    if (_loginTimestamp == null) return false;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    if (now - _loginTimestamp! > _sessionDurationSeconds) return true;
    final lastAppOpen = _prefs.getInt(_keyLastAppOpenTimestamp);
    if (lastAppOpen != null && _loginTimestamp! < lastAppOpen) return true;
    return false;
  }

  ScuAuthService get service => _service;

  Future<void> _updateLastAppOpenTimestamp() async {
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await _prefs.setInt(_keyLastAppOpenTimestamp, now);
  }

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
    _loginTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await SecureStorageProvider.instance.write(
      key: _keyAccessToken,
      value: _accessToken!,
    );
    await _prefs.setInt(_keyLoginTimestamp, _loginTimestamp!);
    notifyListeners();
  }

  Future<void> logout() async {
    _service.logout();
    _accessToken = null;
    _loginTimestamp = null;
    await SecureStorageProvider.instance.delete(key: _keyAccessToken);
    await _prefs.remove(_keyLoginTimestamp);
    getIt<CcylProvider>().logout();
    notifyListeners();
  }

  Future<Map<String, String>?> getSavedCredentials() async {
    final storage = SecureStorageProvider.instance;
    final remember = await storage.read(key: _keyRemember);
    if (remember != 'true') return null;
    final username = await storage.read(key: _keySavedUsername);
    final password = await storage.read(key: _keySavedPassword);
    if (username != null && password != null) {
      return {'username': username, 'password': password};
    }
    return null;
  }

  Future<void> saveCredentials(String username, String password) async {
    final storage = SecureStorageProvider.instance;
    await storage.write(key: _keyRemember, value: 'true');
    await storage.write(key: _keySavedUsername, value: username);
    await storage.write(key: _keySavedPassword, value: password);
  }

  Future<void> clearCredentials() async {
    final storage = SecureStorageProvider.instance;
    await storage.delete(key: _keyRemember);
    await storage.delete(key: _keySavedUsername);
    await storage.delete(key: _keySavedPassword);
  }
}
