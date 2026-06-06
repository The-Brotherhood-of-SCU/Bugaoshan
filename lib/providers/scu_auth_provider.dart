import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/utils/secure_storage.dart';
import 'package:bugaoshan/services/auth/auth_coordinator.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/ccyl_auth.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/ocr_service.dart';

const _keyAutoLogin = 'scu_auto_login';
const _keyUserRealname = 'scu_user_realname';
const _keyUserNumber = 'scu_user_number';

/// 持久化 SCU 登录状态的 Provider，注册为 singleton。
///
/// 认证控制器：管理登录/登出/自动登录/凭据。
/// 子系统登录由 [AuthCoordinator] 按依赖后台预热。
class ScuAuthProvider extends ChangeNotifier {
  final ScuAuth _scuAuth;
  final CcylAuth _ccylAuth;
  final AuthCoordinator _authCoordinator;

  ScuAuthProvider(this._scuAuth, this._ccylAuth, this._authCoordinator) {
    _scuAuth.addListener(_onAuthChanged);
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
    _scuAuth.removeListener(_onAuthChanged);
    super.dispose();
  }

  String? get accessToken => _scuAuth.accessToken;
  String? get userRealname => _userRealname;
  String? get userNumber => _userNumber;
  bool get isAutoLoggingIn => _isAutoLoggingIn;
  bool get isLoggedIn => _scuAuth.isReady;
  bool get isExpired => _scuAuth.isExpired;

  /// 更新用户信息（由 UserInfoProvider 获取后调用）
  void setUserInfo(String? realname, String? number) {
    _userRealname = realname;
    _userNumber = number;
    notifyListeners();
  }

  Future<void> login({
    required String username,
    required String password,
    required String captchaCode,
    required String captchaText,
  }) async {
    await _scuAuth.login(
      username: username,
      password: password,
      captchaCode: captchaCode,
      captchaText: captchaText,
    );
    // 登录成功后后台预热子模块；页面不等待慢模块。
    unawaited(_authCoordinator.warmUpAll());
    notifyListeners();
  }

  Future<void> logout() async {
    await _scuAuth.logout();
    await _ccylAuth.logout();
    _authCoordinator.invalidateAll();
    _userRealname = null;
    _userNumber = null;
    final prefs = getIt<SharedPreferences>();
    await prefs.remove(_keyUserRealname);
    await prefs.remove(_keyUserNumber);
    notifyListeners();
  }

  Future<CaptchaResult> fetchCaptcha() => _scuAuth.fetchCaptcha();

  Future<Map<String, String>?> getSavedCredentials() async {
    return await _scuAuth.getSavedCredentials();
  }

  Future<void> saveCredentials(String username, String password) async {
    await _scuAuth.saveCredentials(username, password);
  }

  Future<void> clearCredentials() async {
    await _scuAuth.clearCredentials();
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
          final captcha = await _scuAuth.fetchCaptcha();

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
