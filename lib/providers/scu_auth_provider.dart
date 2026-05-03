import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:os_type/os_type.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/services/ocr_service.dart';
import 'package:bugaoshan/services/scu_auth_service.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/pages/campus/plan_completion/plan_completion_provider.dart';
import 'package:bugaoshan/providers/ccyl_provider.dart';
import 'package:bugaoshan/providers/secure_storage_provider.dart';

const _keyAccessToken = 'scu_access_token';
const _keyLoginTimestamp = 'scu_login_timestamp';
const _keyLastAppOpenTimestamp = 'scu_last_app_open_timestamp';
const _sessionDurationSeconds = 3600;

const _keySavedUsername = 'scu_saved_username';
const _keySavedPassword = 'scu_saved_password';
const _keyRemember = 'scu_remember_password';
const _keyAutoLogin = 'scu_auto_login';

const _keyUserRealname = 'scu_user_realname';
const _keyUserNumber = 'scu_user_number';

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
    _userRealname = _prefs.getString(_keyUserRealname);
    _userNumber = _prefs.getString(_keyUserNumber);
  }

  String? _accessToken;
  int? _loginTimestamp;
  String? _userRealname;
  String? _userNumber;
  String? get accessToken => _accessToken;
  String? get userRealname => _userRealname;
  String? get userNumber => _userNumber;
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
    await fetchUserInfo();
    notifyListeners();
  }

  Future<void> logout() async {
    _service.logout();
    _accessToken = null;
    _loginTimestamp = null;
    _userRealname = null;
    _userNumber = null;
    await SecureStorageProvider.instance.delete(key: _keyAccessToken);
    await SecureStorageProvider.instance.delete(key: _keyAutoLogin);
    await _prefs.remove(_keyLoginTimestamp);
    await _prefs.remove(_keyUserRealname);
    await _prefs.remove(_keyUserNumber);
    getIt<CcylProvider>().logout();
    getIt<PlanCompletionProvider>().clearCache();
    notifyListeners();
  }

  Future<void> fetchUserInfo() async {
    try {
      final client = await _service.bindSession();
      try {
        final resp = await client.get(
          Uri.parse('https://wfw.scu.edu.cn/uc/wap/user/get-info'),
        );
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        if (json['e'] == 0 && json['d'] != null) {
          final base = json['d']['base'] as Map<String, dynamic>?;
          if (base != null) {
            _userRealname = base['realname']?.toString();
            final role = base['role'] as Map<String, dynamic>?;
            _userNumber = role?['number']?.toString();
            await _prefs.setString(_keyUserRealname, _userRealname ?? '');
            await _prefs.setString(_keyUserNumber, _userNumber ?? '');
          }
        }
      } finally {
        client.close();
      }
    } catch (e) {
      debugPrint('fetchUserInfo error: $e');
    }
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

  Future<bool> isAutoLoginEnabled() async {
    final storage = SecureStorageProvider.instance;
    final value = await storage.read(key: _keyAutoLogin);
    return value == 'true';
  }

  Future<void> setAutoLogin(bool enabled) async {
    final storage = SecureStorageProvider.instance;
    await storage.write(key: _keyAutoLogin, value: enabled ? 'true' : 'false');
  }

  Future<bool> autoLogin() async {
    if (OS.isHarmony) return false;
    if (!await isAutoLoginEnabled()) return false;
    if (isLoggedIn) return true;

    final credentials = await getSavedCredentials();
    if (credentials == null) return false;
    final username = credentials['username']!;
    final password = credentials['password']!;

    const maxRetries = 5;
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      try {
        final captcha = await _service.fetchCaptcha();

        String captchaText;
        try {
          final comma = captcha.captchaBase64.indexOf(',');
          final raw = comma >= 0
              ? captcha.captchaBase64.substring(comma + 1)
              : captcha.captchaBase64;
          final imageBytes = base64.decode(raw);
          captchaText = await OcrService.performOcr(imageBytes);
        } catch (e) {
          debugPrint('Auto login OCR error: $e');
          return false;
        }

        await login(
          username: username,
          password: password,
          captchaCode: captcha.code,
          captchaText: captchaText,
        );
        return true;
      } on ScuLoginException catch (e) {
        if (e.message == 'invalid_captcha') {
          debugPrint(
            'Auto login: invalid_captcha, retry ${attempt + 1}/$maxRetries',
          );
          continue;
        }
        debugPrint('Auto login failed (non-captcha): ${e.message}');
        return false;
      } catch (e) {
        debugPrint('Auto login network error: $e');
        return false;
      }
    }
    debugPrint('Auto login: captcha retries exhausted');
    return false;
  }
}
