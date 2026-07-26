import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/utils/auth_logger.dart';
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
  static const String _tag = 'ScuAuthProvider';

  final ScuAuth _scuAuth;
  final CcylAuth _ccylAuth;
  final AuthCoordinator _authCoordinator;
  final AuthLogger _log;

  ScuAuthProvider(
    this._scuAuth,
    this._ccylAuth,
    this._authCoordinator, {
    AuthLogger? logger,
  }) : _log = logger ?? getIt<AuthLogger>() {
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
    _log.i(_tag, 'login: start');
    await _scuAuth.login(
      username: username,
      password: password,
      captchaCode: captchaCode,
      captchaText: captchaText,
    );
    _log.i(_tag, 'login: ok, warming up subsystems');
    // 登录成功后后台预热子模块；页面不等待慢模块。
    unawaited(_authCoordinator.warmUpAll());
    notifyListeners();
  }

  Future<void> logout() async {
    _log.i(_tag, 'logout');
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
    try {
      final storage = SecureStorageProvider.instance;
      final value = await storage.read(key: _keyAutoLogin);
      return value == 'true';
    } catch (e) {
      // 安全存储读取失败（如 Android keystore 损坏）回退为未开启
      _log.w(_tag, 'isAutoLoginEnabled: read failed, fallback false: $e');
      return false;
    }
  }

  Future<void> setAutoLogin(bool enabled) async {
    _log.i(_tag, 'setAutoLogin: $enabled');
    try {
      final storage = SecureStorageProvider.instance;
      await storage.write(
        key: _keyAutoLogin,
        value: enabled ? 'true' : 'false',
      );
    } catch (e) {
      // 写入失败仅记录日志，避免登录成功后被误判为网络错误而无法跳转
      _log.w(_tag, 'setAutoLogin: write failed, ignored: $e');
    }
  }

  Future<bool> autoLogin() async {
    if (!await isAutoLoginEnabled()) {
      _log.d(_tag, 'autoLogin: disabled');
      return false;
    }
    if (isLoggedIn) return true;

    final credentials = await getSavedCredentials();
    if (credentials == null) {
      _log.d(_tag, 'autoLogin: no saved credentials');
      return false;
    }
    final username = credentials['username']!;
    final password = credentials['password']!;

    _log.i(_tag, 'autoLogin: starting');
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
            _log.e(_tag, 'autoLogin: OCR error $e');
            return false;
          }

          // 保持 _isAutoLoggingIn 为 true 直到 finally 统一复位：
          // 依赖该标志的页面在标志翻转前不应发起数据请求（含验证码重试轮次）
          await login(
            username: username,
            password: password,
            captchaCode: captcha.code,
            captchaText: captchaText,
          );
          _log.i(_tag, 'autoLogin: ok');
          return true;
        } on ScuLoginException catch (e) {
          if (e.message == 'invalid_captcha') {
            _log.w(
              _tag,
              'autoLogin: invalid_captcha, retry ${attempt + 1}/$maxRetries',
            );
            continue;
          }
          _log.w(_tag, 'autoLogin: failed (non-captcha): ${e.message}');
          return false;
        } catch (e) {
          _log.e(_tag, 'autoLogin: network error $e');
          return false;
        }
      }
      _log.w(_tag, 'autoLogin: captcha retries exhausted');
      return false;
    } finally {
      _isAutoLoggingIn = false;
      notifyListeners();
    }
  }
}
