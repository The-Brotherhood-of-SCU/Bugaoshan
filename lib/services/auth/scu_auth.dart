import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/utils/secure_storage.dart';
import 'package:bugaoshan/services/auth/auth_state.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/ocr_service.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/utils/auth_logger.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/utils/json_utils.dart';
import 'package:bugaoshan/utils/sm2_crypto.dart';

/// 教务系统 base URL（该服务器不支持 HTTPS）
const kZhjwBase = 'http://zhjw.scu.edu.cn';

const _keyAccessToken = 'scu_access_token';
const _keyLoginTimestamp = 'scu_login_timestamp';
const _sessionDurationSeconds = 3600;

/// SCU 统一身份认证（第3层）
///
/// 合并原 ScuAuthService + ScuAuthSession，职责：
/// - 登录（密码 + SM2 加密 + 验证码）
/// - token 持久化（FlutterSecureStorage）
/// - 统一认证 session 绑定（CookieClient）
/// - 过期检测（1小时 TTL）+ 自动续期（bindSession → autoLogin）
/// - 并发安全的刷新互斥（_synchronizedRefresh）
///
/// 续期失败时抛 [UnauthenticatedException]，由上层 API Service 捕获重试。
class ScuAuth extends ChangeNotifier {
  static const _base = 'https://id.scu.edu.cn';
  static const _clientId = '1371cbeda563697537f28d99b4744a973uDKtgYqL5B';
  static const _enterpriseId = 'scdx';

  static final _headers = {
    'Accept': 'application/json, text/plain, */*',
    'Content-Type': 'application/json;charset=UTF-8',
    'Origin': _base,
    'Referer': '$_base/frontend/login',
    'User-Agent': kDefaultUserAgent,
  };

  final SharedPreferences _prefs;
  final AuthLogger _log;

  String? _accessToken;
  int? _loginTimestamp;
  CookieClient? _cachedClient;
  Future<CookieClient>? _bindSessionFuture;

  AuthState _state = AuthState.unknown;

  /// 刷新互斥锁，防止多个并发请求同时触发刷新。
  Completer<bool>? _refreshCompleter;

  /// 当 session 过期且自动刷新失败时调用。
  /// 用于在 UI 层显示提示（如 snackbar），由 SessionExpiredListener 注册。
  VoidCallback? onSessionExpired;

  ScuAuth(this._prefs, {AuthLogger? logger})
    : _log = logger ?? getIt<AuthLogger>();

  // ─── 状态 ───────────────────────────────────────────────────────

  AuthState get state => _state;
  bool get isReady => _state == AuthState.ready;

  bool get isExpired {
    if (_loginTimestamp == null) return true;
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    return now - _loginTimestamp! > _sessionDurationSeconds;
  }

  String? get accessToken => _accessToken;

  @protected
  set state(AuthState value) {
    if (_state != value) {
      final prev = _state;
      _state = value;
      _log.i('ScuAuth', 'state ${prev.name} -> ${value.name}');
      notifyListeners();
    }
  }

  // ─── 初始化 ─────────────────────────────────────────────────────

  /// 从安全存储恢复 token（应用启动时调用）。
  Future<void> init() async {
    _accessToken = await SecureStorageProvider.instance.read(
      key: _keyAccessToken,
    );
    _loginTimestamp = _prefs.getInt(_keyLoginTimestamp);

    if (_accessToken != null && !isExpired) {
      _log.i('ScuAuth', 'init: token restored, ts=$_loginTimestamp');
      state = AuthState.ready;
    } else if (_accessToken != null) {
      _log.w('ScuAuth', 'init: token restored but expired');
    } else {
      _log.d('ScuAuth', 'init: no saved token');
    }
  }

  // ─── 登录 ─────────────────────────────────────────────────────

  /// 获取验证码
  Future<CaptchaResult> fetchCaptcha() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final uri = Uri.parse(
      '$_base/api/public/bff/v1.2/one_time_login/captcha'
      '?_enterprise_id=$_enterpriseId&timestamp=$ts',
    );
    final resp = await http.get(uri, headers: _headers).timeout(kHttpTimeout);

    final json = parseJson(
      resp.body,
      'captcha',
      (msg) => ScuLoginException(msg),
    );
    final data = json['data'];
    if (data == null) {
      _log.w('ScuAuth', 'fetchCaptcha: missing data field');
      throw ScuLoginException('验证码接口返回异常: ${resp.body}');
    }
    final dataMap = data as Map<String, dynamic>;

    final captchaImg =
        (dataMap['captcha'] ??
                dataMap['image'] ??
                dataMap['img'] ??
                dataMap['captchaImage'])
            ?.toString();
    final code = dataMap['code']?.toString();

    if (captchaImg == null || code == null) {
      _log.w('ScuAuth', 'fetchCaptcha: missing captcha/code fields');
      throw ScuLoginException('验证码字段解析失败，实际响应: ${resp.body}');
    }
    _log.d('ScuAuth', 'fetchCaptcha: ok (${captchaImg.length}B)');
    return CaptchaResult(code: code, captchaBase64: captchaImg);
  }

  /// 登录（密码 + SM2 加密 + 验证码）
  Future<void> login({
    required String username,
    required String password,
    required String captchaCode,
    required String captchaText,
  }) async {
    _log.i('ScuAuth', 'login: start');
    // 1. 获取 SM2 公钥（服务端偶发 500，加重试）
    Map<String, dynamic>? sm2Data;
    String? lastSm2Body;
    for (int attempt = 0; attempt < 3; attempt++) {
      final sm2Resp = await http
          .post(
            Uri.parse('$_base/api/public/bff/v1.2/sm2_key'),
            headers: _headers,
            body: '{}',
          )
          .timeout(kHttpTimeout);
      lastSm2Body = sm2Resp.body;
      final sm2Json = parseJson(
        sm2Resp.body,
        'sm2_key',
        (msg) => ScuLoginException(msg),
      );
      sm2Data = sm2Json['data'] as Map<String, dynamic>?;
      if (sm2Data != null &&
          sm2Data['publicKey'] != null &&
          sm2Data['code'] != null) {
        break;
      }
      if (attempt < 2) {
        await Future.delayed(const Duration(milliseconds: 500));
      }
    }
    if (sm2Data == null) {
      _log.w('ScuAuth', 'login: sm2_key failed after 3 attempts');
      throw ScuLoginException('SM2 公钥接口返回异常: $lastSm2Body');
    }
    final publicKey = sm2Data['publicKey']?.toString();
    final sm2Code = sm2Data['code']?.toString();
    if (publicKey == null || sm2Code == null) {
      _log.w('ScuAuth', 'login: sm2_key missing publicKey/code fields');
      throw ScuLoginException('SM2 公钥字段缺失: $lastSm2Body');
    }
    _log.d('ScuAuth', 'login: sm2 key acquired');

    // 2. SM2 C1C2C3 加密密码
    final encryptedPassword = SM2Crypto.encryptWithBase64Key(
      password,
      publicKey,
    );

    // 3. 请求 token
    final payload = jsonEncode({
      'client_id': _clientId,
      'grant_type': 'password',
      'scope': 'read',
      'username': username,
      'password': encryptedPassword,
      '_enterprise_id': _enterpriseId,
      'sm2_code': sm2Code,
      'cap_code': captchaCode,
      'cap_text': captchaText,
    });

    final tokenResp = await http
        .post(
          Uri.parse('$_base/api/public/bff/v1.2/rest_token'),
          headers: _headers,
          body: payload,
        )
        .timeout(kHttpTimeout);

    final result = parseJson(
      tokenResp.body,
      'rest_token',
      (msg) => ScuLoginException(msg),
    );
    if (result['success'] != true) {
      final msg =
          result['message']?.toString() ?? result['msg']?.toString() ?? '登录失败';
      _log.w('ScuAuth', 'login: rejected: $msg');
      throw ScuLoginException(msg);
    }

    final tokenData = result['data'] as Map<String, dynamic>?;
    final token = tokenData?['access_token']?.toString();
    if (token == null) {
      _log.w('ScuAuth', 'login: missing access_token in response');
      throw ScuLoginException('Token 字段缺失: ${tokenResp.body}');
    }

    // 登录成功
    _accessToken = token;
    _cachedClient = null;
    _bindSessionFuture = null;
    _loginTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    await SecureStorageProvider.instance.write(
      key: _keyAccessToken,
      value: _accessToken!,
    );
    await _prefs.setInt(_keyLoginTimestamp, _loginTimestamp!);
    _log.i('ScuAuth', 'login: ok, token len=${token.length}');
    state = AuthState.ready;
  }

  // ─── Session 绑定 ─────────────────────────────────────────────

  /// 将 token 绑定到统一认证服务端 session，返回携带 id.scu.edu.cn cookie 的 Client。
  /// 子系统 SSO 由各自的 Auth 模块负责，避免互不依赖的模块相互阻塞。
  Future<CookieClient> bindSession() async {
    if (_accessToken == null) {
      throw const UnauthenticatedException('未登录');
    }

    if (_cachedClient != null) {
      _log.d('ScuAuth', 'bindSession: cache hit');
      return _cachedClient!;
    }

    // 并发保护：多个调用者同时 bindSession 时，只执行一次 SSO 握手
    if (_bindSessionFuture != null) return _bindSessionFuture!;

    _log.i('ScuAuth', 'bindSession: starting SSO handshake');
    _bindSessionFuture = _doBindSession();
    try {
      return await _bindSessionFuture!;
    } finally {
      _bindSessionFuture = null;
    }
  }

  Future<CookieClient> _doBindSession() async {
    final client = CookieClient();

    // ── Step 1: 保存 token 到服务端 session（必须成功）
    final sessionResp = await client.post(
      Uri.parse('$_base/api/bff/v1.2/commons/session/save'),
      headers: {..._headers, 'Authorization': 'Bearer $_accessToken'},
      body: '{}',
    );
    final sessionResult = parseJson(
      sessionResp.body,
      'session/save',
      (msg) => ScuLoginException(msg),
    );
    if (sessionResult['success'] != true) {
      _log.w('ScuAuth', 'bindSession: session/save rejected');
      throw ScuLoginException('session/save 失败: ${sessionResp.body}');
    }

    client.reusable = true;
    _cachedClient = client;
    _log.i('ScuAuth', 'bindSession: ok');
    return client;
  }

  /// 清除缓存的 Client，下次 [bindSession] 会重新执行 SSO 握手。
  void invalidateCachedClient() {
    if (_cachedClient != null) {
      _log.d('ScuAuth', 'invalidateCachedClient');
    }
    _cachedClient = null;
  }

  // ─── 获取已认证 Client（核心方法）────────────────────────────

  /// 获取已认证的 CookieClient。
  ///
  /// 内部流程：
  /// 1. 检查 TTL（1小时），未过期直接返回
  /// 2. 过期 → 调用 [_synchronizedRefresh]（并发安全，N 并发 = 1 次刷新）
  /// 3. 刷新成功 → 返回 client
  /// 4. 刷新失败 → 调用 [onSessionExpired] → 抛 [UnauthenticatedException]
  Future<CookieClient> getClient() async {
    if (isExpired) {
      _log.w('ScuAuth', 'getClient: token expired, refreshing');
      final refreshed = await _synchronizedRefresh();
      if (!refreshed) {
        _log.e('ScuAuth', 'getClient: refresh failed, session expired');
        onSessionExpired?.call();
        throw const UnauthenticatedException();
      }
    }

    if (_accessToken == null) {
      throw const UnauthenticatedException('未登录');
    }

    return await bindSession();
  }

  /// 获取 access token（给 WfwAuth 等需要 Bearer token 的场景）。
  ///
  /// 逻辑同 [getClient]，但只返回 token 字符串。
  Future<String> getAccessToken() async {
    if (isExpired) {
      _log.w('ScuAuth', 'getAccessToken: token expired, refreshing');
      final refreshed = await _synchronizedRefresh();
      if (!refreshed) {
        _log.e('ScuAuth', 'getAccessToken: refresh failed, session expired');
        onSessionExpired?.call();
        throw const UnauthenticatedException();
      }
    }

    if (_accessToken == null) {
      throw const UnauthenticatedException('未登录');
    }

    return _accessToken!;
  }

  // ─── 续期 ─────────────────────────────────────────────────────

  /// 并发安全的续期。多个调用者共享同一刷新结果。
  Future<bool> _synchronizedRefresh() async {
    if (_refreshCompleter != null) {
      _log.d('ScuAuth', 'refresh: awaiting existing refresh');
      return _refreshCompleter!.future;
    }
    _log.i('ScuAuth', 'refresh: starting (single-flight)');
    _refreshCompleter = Completer<bool>();
    try {
      final result = await _doRefresh();
      _log.i('ScuAuth', 'refresh: ${result ? "ok" : "failed"}');
      _refreshCompleter!.complete(result);
      return result;
    } catch (e) {
      state = AuthState.error;
      _log.e('ScuAuth', 'refresh: threw $e');
      _refreshCompleter!.completeError(e);
      rethrow;
    } finally {
      _refreshCompleter = null;
    }
  }

  /// 实际续期逻辑：
  /// 1. 清除缓存 client → 尝试 bindSession（服务端 token 可能仍有效）
  /// 2. 失败 → autoLogin（凭据 + OCR 验证码）
  /// 3. 全部失败 → 返回 false
  Future<bool> _doRefresh() async {
    if (_accessToken == null) {
      _log.w('ScuAuth', '_doRefresh: no token, giving up');
      state = AuthState.expired;
      return false;
    }

    // 1. 清除缓存，强制重新 SSO 握手
    invalidateCachedClient();

    // 2. 尝试用现有 token 重新绑定
    try {
      final client = await bindSession();
      client.close();
      _loginTimestamp = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await _prefs.setInt(_keyLoginTimestamp, _loginTimestamp!);
      state = AuthState.ready;
      return true;
    } catch (e) {
      _log.w('ScuAuth', 'refresh: bindSession failed ($e), trying autoLogin');
    }

    // 3. 尝试自动登录
    try {
      final success = await autoLogin();
      if (success) {
        state = AuthState.ready;
        return true;
      }
    } catch (e) {
      _log.e('ScuAuth', 'refresh: autoLogin threw $e');
    }

    state = AuthState.expired;
    return false;
  }

  /// 强制刷新（供外部调用，如 AuthManager.refreshAll 替代逻辑）。
  Future<bool> refresh() => _synchronizedRefresh();

  // ─── 登出 ─────────────────────────────────────────────────────

  Future<void> logout() async {
    _log.i('ScuAuth', 'logout: clearing session');
    _accessToken = null;
    _cachedClient = null;
    _bindSessionFuture = null;
    _refreshCompleter = null;
    _loginTimestamp = null;
    await SecureStorageProvider.instance.delete(key: _keyAccessToken);
    await _prefs.remove(_keyLoginTimestamp);
    state = AuthState.unknown;
  }

  // ─── 凭据管理（自动登录用）──────────────────────────────────

  static const _keyRememberPassword = 'scu_remember_password';
  static const _keySavedUsername = 'scu_saved_username';
  static const _keySavedPassword = 'scu_saved_password';

  Future<void> saveCredentials(String username, String password) async {
    final storage = SecureStorageProvider.instance;
    await storage.write(key: _keyRememberPassword, value: 'true');
    await storage.write(key: _keySavedUsername, value: username);
    await storage.write(key: _keySavedPassword, value: password);
  }

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

  Future<void> clearCredentials() async {
    final storage = SecureStorageProvider.instance;
    await storage.delete(key: _keyRememberPassword);
    await storage.delete(key: _keySavedUsername);
    await storage.delete(key: _keySavedPassword);
  }

  /// 自动登录（从安全存储恢复凭据 + OCR 验证码）。
  Future<bool> autoLogin() async {
    final credentials = await getSavedCredentials();
    if (credentials == null) {
      _log.d('ScuAuth', 'autoLogin: no saved credentials');
      return false;
    }
    _log.i('ScuAuth', 'autoLogin: starting');

    try {
      final captcha = await fetchCaptcha();

      String captchaText;
      try {
        final comma = captcha.captchaBase64.indexOf(',');
        final raw = comma >= 0
            ? captcha.captchaBase64.substring(comma + 1)
            : captcha.captchaBase64;
        final imageBytes = base64.decode(raw);
        captchaText = await OcrService.performOcr(imageBytes);
      } catch (e) {
        _log.e('ScuAuth', 'autoLogin: OCR error: $e');
        return false;
      }

      await login(
        username: credentials['username']!,
        password: credentials['password']!,
        captchaCode: captcha.code,
        captchaText: captchaText,
      );
      _log.i('ScuAuth', 'autoLogin: ok');
      return true;
    } catch (e) {
      _log.w('ScuAuth', 'autoLogin: failed: $e');
      return false;
    }
  }
}

/// 验证码结果
class CaptchaResult {
  final String code;
  final String captchaBase64;
  const CaptchaResult({required this.code, required this.captchaBase64});
}
