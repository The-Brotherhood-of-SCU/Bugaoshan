import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bugaoshan/pages/campus/models/classroom_model.dart';
import 'package:bugaoshan/services/auth/auth_manager.dart';
import 'package:bugaoshan/services/scu_auth/cookie_client.dart';
import 'package:bugaoshan/services/scu_auth/scu_auth_models.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/utils/json_utils.dart';
import 'package:bugaoshan/utils/sm2_crypto.dart';

part 'scu_auth_schedule.dart';
part 'scu_auth_grades.dart';
part 'scu_auth_classroom.dart';

/// 四川大学统一身份认证 Service
class ScuAuthService {
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

  late AuthManager _authManager;

  String? _accessToken;
  String? get accessToken => _accessToken;

  CookieClient? _cachedClient;
  Future<CookieClient>? _bindSessionFuture;

  /// 绑定 [AuthManager] 引用，使 fetchXxx 方法可以使用 `request()` 自动重试。
  void bindAuthManager(AuthManager mgr) => _authManager = mgr;

  void restoreAccessToken(String? token) {
    _accessToken = token;
    _cachedClient = null;
  }

  /// 清除缓存的 Client，下次 [bindSession] 会重新执行 SSO 握手。
  void invalidateCachedClient() {
    _cachedClient = null;
  }

  /// 通用请求包装，供不走 fetchXxx 的调用方使用（如 ProfileLabelsProvider）。
  Future<T> request<T>(Future<T> Function(CookieClient client) fn) async {
    return _authManager.scu.request(fn);
  }

  // ─── 登录认证 ─────────────────────────────────────────────────────────────

  /// 获取验证码，返回 [CaptchaResult]
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
      throw ScuLoginException('验证码字段解析失败，实际响应: ${resp.body}');
    }
    return CaptchaResult(code: code, captchaBase64: captchaImg);
  }

  /// 登录，成功后 [accessToken] 会被保存
  Future<void> login({
    required String username,
    required String password,
    required String captchaCode,
    required String captchaText,
  }) async {
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
      throw ScuLoginException('SM2 公钥接口返回异常: $lastSm2Body');
    }
    final publicKey = sm2Data['publicKey']?.toString();
    final sm2Code = sm2Data['code']?.toString();
    if (publicKey == null || sm2Code == null) {
      throw ScuLoginException('SM2 公钥字段缺失: $lastSm2Body');
    }

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
      throw ScuLoginException(msg);
    }

    final tokenData = result['data'] as Map<String, dynamic>?;
    final token = tokenData?['access_token']?.toString();
    if (token == null) {
      throw ScuLoginException('Token 字段缺失: ${tokenResp.body}');
    }

    // 登录成功，清掉旧 client，新 token 需要重新建立 session
    _accessToken = token;
    _cachedClient = null;
  }

  /// 将 token 绑定到服务端 session，返回携带 cookie 的 Client。
  Future<CookieClient> bindSession() async {
    if (_accessToken == null) throw ScuLoginException('未登录');

    if (_cachedClient != null) return _cachedClient!;

    // 并发保护：多个调用者同时 bindSession 时，只执行一次 SSO 握手
    if (_bindSessionFuture != null) return _bindSessionFuture!;

    _bindSessionFuture = _doBindSession();
    try {
      return await _bindSessionFuture!;
    } finally {
      _bindSessionFuture = null;
    }
  }

  Future<CookieClient> _doBindSession() async {
    final client = CookieClient();

    // ── Step 1: 保存 token 到服务端 session（必须成功）──────────────────────
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
      throw ScuLoginException('session/save 失败: ${sessionResp.body}');
    }

    // ── Step 2 & 3: 预热 JWT SSO + CAS Apereo SSO（相互独立，并行执行）─────
    await Future.wait([_warmupJwtSso(client), _warmupCasSso(client)]);

    client.reusable = true;
    _cachedClient = client;
    return client;
  }

  Future<void> _warmupJwtSso(CookieClient client) async {
    try {
      await client.followRedirects(
        Uri.parse(
          '$_base/enduser/sp/sso/scdxplugin_jwt23'
          '?enterpriseId=scdx&target_url=index',
        ),
        headers: {
          'Accept': 'text/html,application/xhtml+xml,*/*',
          'User-Agent': _headers['User-Agent']!,
          'Authorization': 'Bearer $_accessToken',
        },
      );
    } catch (_) {
      // JWT SSO 预热失败不影响非教务功能
    }
  }

  Future<void> _warmupCasSso(CookieClient client) async {
    try {
      await client.followRedirects(
        Uri.parse(
          '$_base/api/bff/v1.2/commons/sp_logged'
          '?access_token=$_accessToken'
          '&sp_code=$kCcylSpCode'
          '&application_key=scdxplugin_cas_apereo17',
        ),
        headers: {
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*',
          'User-Agent': _headers['User-Agent']!,
        },
      );
    } catch (_) {
      // CAS SSO 预热失败不影响非 CCYL 功能
    }
  }

  void logout() {
    _accessToken = null;
    _cachedClient = null;
  }

  // ─── 内部工具 ─────────────────────────────────────────────────────────────

  /// 检查会话是否过期，过期则抛出 [ScuLoginException]。
  void _checkSessionExpiry(String body, int statusCode) {
    if (statusCode == 302) {
      throw ScuLoginException('登录已过期，请重新登录', sessionExpired: true);
    }
    if (body.trim().isEmpty) {
      throw ScuLoginException('登录已过期，请重新登录', sessionExpired: true);
    }
    if (body.startsWith('<') && body.contains('login')) {
      throw ScuLoginException('登录已过期，请重新登录', sessionExpired: true);
    }
  }
}
