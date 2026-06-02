import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/providers/secure_storage_provider.dart';
import 'package:bugaoshan/services/auth/auth_session.dart';
import 'package:bugaoshan/services/auth/auth_state.dart';
import 'package:bugaoshan/services/ocr_service.dart';
import 'package:bugaoshan/services/scu_auth_service.dart';

const _keyAccessToken = 'scu_access_token';
const _keyLoginTimestamp = 'scu_login_timestamp';
const _sessionDurationSeconds = 3600;

/// SCU 统一认证会话。
///
/// 管理 access token + cookie session 的生命周期：
/// - token 存储在 [FlutterSecureStorage] 中
/// - 过期检测: 1 小时 TTL（自 _loginTimestamp 起 3600 秒）
/// - 自动刷新: 检测到过期后尝试静默重新登录
class ScuAuthSession extends AuthSession<CookieClient> {
  final SharedPreferences _prefs;

  final ScuAuthService _service;

  String? _accessToken;
  int? _loginTimestamp;

  ScuAuthSession(this._prefs, {ScuAuthService? service})
    : _service = service ?? ScuAuthService();

  /// 从安全存储恢复 token（应用启动时调用）。
  Future<void> init() async {
    _accessToken = await SecureStorageProvider.instance.read(
      key: _keyAccessToken,
    );
    _service.restoreAccessToken(_accessToken);
    _loginTimestamp = _prefs.getInt(_keyLoginTimestamp);

    if (_accessToken != null && !isExpired) {
      state = AuthState.ready;
    }
  }

  @override
  String get serviceName => 'SCU统一认证';

  String? get accessToken => _accessToken;
  int? get loginTimestamp => _loginTimestamp;
  ScuAuthService get service => _service;

  @override
  bool get isExpired {
    if (_loginTimestamp == null) return true;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now - _loginTimestamp! > _sessionDurationSeconds;
  }

  /// SCU 登录（密码 + 验证码）。
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
    state = AuthState.ready;
  }

  @override
  Future<CookieClient> getClient() async {
    // 如果已过期，尝试自动刷新
    if (isExpired) {
      final refreshed = await refresh();
      if (!refreshed) {
        throw ScuLoginException('登录已过期，请重新登录', sessionExpired: true);
      }
    }

    if (_accessToken == null) {
      throw ScuLoginException('未登录');
    }

    return await _service.bindSession();
  }

  @override
  Future<bool> refresh() async {
    if (_accessToken == null) {
      state = AuthState.expired;
      return false;
    }

    // 1. 清除缓存的 client，强制下次 bindSession 重新执行 SSO 握手
    _service.invalidateCachedClient();

    // 2. 尝试用现有 token 重新绑定 session（服务端若 token 有效则返回新 client）
    try {
      final client = await _service.bindSession();
      client.close();
      _loginTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _prefs.setInt(_keyLoginTimestamp, _loginTimestamp!);
      state = AuthState.ready;
      return true;
    } catch (_) {
      // 3. token 已失效 → 尝试完整的自动登录（凭据 + OCR 验证码）
      debugPrint('ScuAuthSession: bindSession failed, trying autoLogin...');
    }

    try {
      final success = await autoLogin();
      if (success) {
        state = AuthState.ready;
        return true;
      }
    } catch (e) {
      debugPrint('ScuAuthSession: autoLogin failed: $e');
    }

    state = AuthState.expired;
    return false;
  }

  @override
  Future<void> logout() async {
    _service.logout();
    _accessToken = null;
    _loginTimestamp = null;
    await SecureStorageProvider.instance.delete(key: _keyAccessToken);
    await _prefs.remove(_keyLoginTimestamp);
    state = AuthState.unknown;
  }

  static const _keyRememberPassword = 'scu_remember_password';
  static const _keySavedUsername = 'scu_saved_username';
  static const _keySavedPassword = 'scu_saved_password';

  /// 保存凭据（用于自动登录）。
  Future<void> saveCredentials(String username, String password) async {
    final storage = SecureStorageProvider.instance;
    await storage.write(key: _keyRememberPassword, value: 'true');
    await storage.write(key: _keySavedUsername, value: username);
    await storage.write(key: _keySavedPassword, value: password);
  }

  /// 获取保存的凭据。
  Future<Map<String, String>?> getSavedCredentials() async {
    final storage = SecureStorageProvider.instance;
    final remember = await storage.read(key: _keyRememberPassword);
    if (remember != 'true') return null;
    final username = await storage.read(key: _keySavedUsername);
    final password = await storage.read(key: _keySavedPassword);
    if (username != null && password != null) {
      return {'username': username, 'password': password};
    }
    return null;
  }

  /// 清除保存的凭据。
  Future<void> clearCredentials() async {
    final storage = SecureStorageProvider.instance;
    await storage.delete(key: _keyRememberPassword);
    await storage.delete(key: _keySavedUsername);
    await storage.delete(key: _keySavedPassword);
  }

  /// 自动登录（从安全存储恢复凭据 + OCR 验证码）。
  Future<bool> autoLogin() async {
    final credentials = await getSavedCredentials();
    if (credentials == null) return false;

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
        username: credentials['username']!,
        password: credentials['password']!,
        captchaCode: captcha.code,
        captchaText: captchaText,
      );
      return true;
    } catch (e) {
      debugPrint('Auto login failed: $e');
      return false;
    }
  }
}
