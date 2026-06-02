import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/ccyl_provider.dart';
import 'package:bugaoshan/providers/plan_completion_provider.dart';
import 'package:bugaoshan/providers/profile_labels_provider.dart';
import 'package:bugaoshan/providers/secure_storage_provider.dart';
import 'package:bugaoshan/services/auth/auth_manager.dart';
import 'package:bugaoshan/services/ocr_service.dart';
import 'package:bugaoshan/services/scu_api_service.dart';

const _keyAutoLogin = 'scu_auto_login';
const _keyUserRealname = 'scu_user_realname';
const _keyUserNumber = 'scu_user_number';

/// 持久化 SCU 登录状态的 Provider，注册为 singleton。
///
/// 内部委托给 [AuthManager.scu]（[ScuAuthSession]）执行实际鉴权逻辑。
class ScuAuthProvider extends ChangeNotifier {
  final AuthManager _authManager;

  ScuAuthProvider(this._authManager) {
    _authManager.addListener(_onAuthChanged);
  }

  void _onAuthChanged() => notifyListeners();

  Future<void> init() async {
    final prefs = getIt<SharedPreferences>();
    _userRealname = prefs.getString(_keyUserRealname);
    _userNumber = prefs.getString(_keyUserNumber);
  }

  String? _userRealname;
  String? _userNumber;
  bool _isAutoLoggingIn = false;

  @override
  void dispose() {
    _authManager.removeListener(_onAuthChanged);
    super.dispose();
  }

  String? get accessToken => _authManager.scu.accessToken;
  ScuAuthService get authService => _authManager.scu.authService;
  String? get userRealname => _userRealname;
  String? get userNumber => _userNumber;
  bool get isAutoLoggingIn => _isAutoLoggingIn;
  bool get isLoggedIn => _authManager.isScuLoggedIn;
  bool get isExpired => _authManager.scu.isExpired;
  ScuApiService get service => _authManager.apiService;

  Future<void> login({
    required String username,
    required String password,
    required String captchaCode,
    required String captchaText,
  }) async {
    await _authManager.scu.login(
      username: username,
      password: password,
      captchaCode: captchaCode,
      captchaText: captchaText,
    );

    // 获取用户信息 与 绑定第二课堂 互相独立，并行执行
    await Future.wait([fetchUserInfo(), getIt<CcylProvider>().reLogin()]);

    notifyListeners();
  }

  Future<void> logout() async {
    await _authManager.logoutAll();
    _userRealname = null;
    _userNumber = null;
    final prefs = getIt<SharedPreferences>();
    await prefs.remove(_keyUserRealname);
    await prefs.remove(_keyUserNumber);
    getIt<PlanCompletionProvider>().clearCache();
    getIt<ProfileLabelsProvider>().clear();
    notifyListeners();
  }

  Future<void> fetchUserInfo() async {
    try {
      final client = await _authManager.scu.getClient();
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
            final prefs = getIt<SharedPreferences>();
            await prefs.setString(_keyUserRealname, _userRealname ?? '');
            await prefs.setString(_keyUserNumber, _userNumber ?? '');
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
    return await _authManager.scu.getSavedCredentials();
  }

  Future<void> saveCredentials(String username, String password) async {
    await _authManager.scu.saveCredentials(username, password);
  }

  Future<void> clearCredentials() async {
    await _authManager.scu.clearCredentials();
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
    if (!await isAutoLoginEnabled()) return false;
    if (isLoggedIn) return true;

    final credentials = await getSavedCredentials();
    if (credentials == null) return false;
    final username = credentials['username']!;
    final password = credentials['password']!;

    _isAutoLoggingIn = true;
    notifyListeners();

    try {
      const maxRetries = 5;
      for (int attempt = 0; attempt < maxRetries; attempt++) {
        try {
          final captcha = await _authManager.scu.authService.fetchCaptcha();

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

          _isAutoLoggingIn = false;
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
    } finally {
      _isAutoLoggingIn = false;
      notifyListeners();
    }
  }
}
