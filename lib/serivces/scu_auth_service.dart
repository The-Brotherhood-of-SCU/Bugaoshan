import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bugaoshan/utils/sm2_crypto.dart';

/// 四川大学统一身份认证 Service
class ScuAuthService {
  static const _base = 'https://id.scu.edu.cn';
  static const _clientId = '1371cbeda563697537f28d99b4744a973uDKtgYqL5B';
  static const _enterpriseId = 'scdx';

  static final Map<String, String> _headers = {
    'Accept': 'application/json, text/plain, */*',
    'Content-Type': 'application/json;charset=UTF-8',
    'Origin': _base,
    'Referer': '$_base/frontend/login',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0',
  };

  String? _accessToken;
  String? get accessToken => _accessToken;

  _CookieClient? _cachedClient;

  /// 获取验证码，返回 [CaptchaResult]
  Future<CaptchaResult> fetchCaptcha() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final uri = Uri.parse(
      '$_base/api/public/bff/v1.2/one_time_login/captcha'
      '?_enterprise_id=$_enterpriseId&timestamp=$ts',
    );
    final resp = await http.get(uri, headers: _headers);

    final json = _parseJson(resp.body, 'captcha');
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
    // 1. 获取 SM2 公钥
    final sm2Resp = await http.post(
      Uri.parse('$_base/api/public/bff/v1.2/sm2_key'),
      headers: _headers,
      body: '{}',
    );

    final sm2Json = _parseJson(sm2Resp.body, 'sm2_key');
    final sm2Data = sm2Json['data'] as Map<String, dynamic>?;
    if (sm2Data == null) {
      throw ScuLoginException('SM2 公钥接口返回异常: ${sm2Resp.body}');
    }
    final publicKey = sm2Data['publicKey']?.toString();
    final sm2Code = sm2Data['code']?.toString();
    if (publicKey == null || sm2Code == null) {
      throw ScuLoginException('SM2 公钥字段缺失: ${sm2Resp.body}');
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

    final tokenResp = await http.post(
      Uri.parse('$_base/api/public/bff/v1.2/rest_token'),
      headers: _headers,
      body: payload,
    );

    final result = _parseJson(tokenResp.body, 'rest_token');
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
  ///
  /// 预热两个 SSO SP：
  ///   - scdxplugin_jwt23       → 教务系统（zhjw.scu.edu.cn）
  ///   - scdxplugin_cas_apereo17 → 团委系统（CCYL / dekt.scu.edu.cn）
  Future<_CookieClient> bindSession() async {
    if (_accessToken == null) throw ScuLoginException('未登录');

    if (_cachedClient != null) return _cachedClient!;

    final client = _CookieClient();

    // ── Step 1: 保存 token 到服务端 session ──────────────────────────────────
    final sessionResp = await client.post(
      Uri.parse('$_base/api/bff/v1.2/commons/session/save'),
      headers: {..._headers, 'Authorization': 'Bearer $_accessToken'},
      body: '{}',
    );
    final sessionResult = _parseJson(sessionResp.body, 'session/save');
    if (sessionResult['success'] != true) {
      throw ScuLoginException('session/save 失败: ${sessionResp.body}');
    }

    // ── Step 2: 预热 JWT SSO（教务系统用）───────────────────────────────────
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

    // ── Step 3: 预热 CAS Apereo SSO（CCYL 团委系统用）──────────────────────
    // 必须在这里先走一次 sp_logged，让服务端在当前 session 里记录
    // scdxplugin_cas_apereo17 这个 SP 已被授权。
    // 此处 sp_code 使用固定值（与 CcylOAuthService 保持一致）。
    await client.followRedirects(
      Uri.parse(
        '$_base/api/bff/v1.2/commons/sp_logged'
        '?access_token=$_accessToken'
        '&sp_code=${CcylSpCode.value}'
        '&application_key=scdxplugin_cas_apereo17',
      ),
      headers: {
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*',
        'User-Agent': _headers['User-Agent']!,
      },
    );

    client._reusable = true;
    _cachedClient = client;
    return client;
  }

  /// 获取历年学期列表（需要先登录），返回 [{value: '2025-2026-2-1', label: '2025-2026学年春(当前)'}, ...]
  Future<List<({String value, String label})>> fetchSemesters() async {
    final client = await bindSession();
    try {
      final resp = await client.get(
        Uri.parse(
          'http://zhjw.scu.edu.cn/student/courseSelect'
          '/calendarSemesterCurriculum/index',
        ),
        headers: {
          'Accept': 'text/html,*/*',
          'Referer': 'http://zhjw.scu.edu.cn/',
          'User-Agent': _headers['User-Agent']!,
        },
      );
      final body = resp.body.trim();
      if (body.startsWith('<html') && body.contains('login') ||
          resp.statusCode == 302) {
        throw ScuLoginException('登录已过期，请重新登录', sessionExpired: true);
      }
      final regex = RegExp(
        r'<option[^>]+value="([^"]+)"[^>]*>(.*?)</option>',
        dotAll: true,
      );
      final matches = regex.allMatches(body);
      final semesters = matches.map((m) {
        final value = m.group(1)!.trim();
        final label = m.group(2)!.replaceAll(RegExp(r'<[^>]+>'), '').trim();
        return (value: value, label: label);
      }).toList();
      if (semesters.isEmpty) {
        throw ScuLoginException('无法获取学期列表，请检查登录状态');
      }
      return semesters;
    } finally {
      client.close();
    }
  }

  /// 获取指定学期课表 JSON（需要先登录），[planCode] 如 '2025-2026-2-1'
  Future<Map<String, dynamic>> fetchJwxtSchedule({
    required String planCode,
  }) async {
    final client = await bindSession();
    try {
      final resp = await client.post(
        Uri.parse(
          'http://zhjw.scu.edu.cn/student/courseSelect'
          '/thisSemesterCurriculum/ajaxStudentSchedule/callback',
        ),
        headers: {
          'Accept': 'application/json, text/javascript, */*; q=0.01',
          'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
          'Referer':
              'http://zhjw.scu.edu.cn/student/courseSelect/calendarSemesterCurriculum/index',
          'User-Agent': _headers['User-Agent']!,
          'X-Requested-With': 'XMLHttpRequest',
        },
        body: 'planCode=$planCode',
      );
      final body = resp.body.trim();
      if (body.startsWith('<') || resp.statusCode == 302) {
        throw ScuLoginException('登录已过期，请重新登录', sessionExpired: true);
      }
      return _parseJson(body, 'jwxt/schedule');
    } finally {
      client.close();
    }
  }

  /// 获取及格成绩（需要先登录）
  Future<Map<String, dynamic>> fetchPassingScores() async {
    final client = await bindSession();
    try {
      final indexResp = await client.get(
        Uri.parse(
          'http://zhjw.scu.edu.cn/student/integratedQuery/scoreQuery/allPassingScores/index',
        ),
        headers: {
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Referer': 'http://zhjw.scu.edu.cn/',
          'User-Agent': _headers['User-Agent']!,
        },
      );
      final indexBody = indexResp.body;
      if (indexBody.trim().isEmpty || indexResp.statusCode == 302) {
        throw ScuLoginException('登录已过期，请重新登录', sessionExpired: true);
      }
      final urlMatch = RegExp(
        r'var\s+url\s*=\s*"(/student/integratedQuery/scoreQuery/[^/]+/allPassingScores/callback)"',
      ).firstMatch(indexBody);
      if (urlMatch == null) {
        if (indexBody.contains('login') || indexBody.contains('Login')) {
          throw ScuLoginException('登录已过期，请重新登录', sessionExpired: true);
        }
        throw ScuLoginException('无法从页面提取 allPassingScores callback URL');
      }
      final callbackPath = urlMatch.group(1)!;

      final callbackResp = await client.get(
        Uri.parse('http://zhjw.scu.edu.cn$callbackPath'),
        headers: {
          'Accept': 'application/json, text/plain, */*',
          'Referer':
              'http://zhjw.scu.edu.cn/student/integratedQuery/scoreQuery/allPassingScores/index',
          'User-Agent': _headers['User-Agent']!,
        },
      );
      final body = callbackResp.body.trim();
      if (body.startsWith('<') || callbackResp.statusCode == 302) {
        throw ScuLoginException('登录已过期，请重新登录', sessionExpired: true);
      }
      return _parseJson(body, 'allPassingScores/callback');
    } finally {
      client.close();
    }
  }

  /// 获取方案成绩（需要先登录）
  Future<Map<String, dynamic>> fetchSchemeScores() async {
    final client = await bindSession();
    try {
      final indexResp = await client.get(
        Uri.parse(
          'http://zhjw.scu.edu.cn/student/integratedQuery/scoreQuery/schemeScores/index',
        ),
        headers: {
          'Accept':
              'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          'Referer': 'http://zhjw.scu.edu.cn/',
          'User-Agent': _headers['User-Agent']!,
        },
      );

      final indexBody = indexResp.body;
      if (indexBody.trim().isEmpty || indexResp.statusCode == 302) {
        throw ScuLoginException('登录已过期，请重新登录', sessionExpired: true);
      }

      final urlMatch = RegExp(
        r'var\s+url\s*=\s*"(/student/integratedQuery/scoreQuery/[^/]+/schemeScores/callback)"',
      ).firstMatch(indexBody);
      if (urlMatch == null) {
        if (indexBody.contains('login') || indexBody.contains('Login')) {
          throw ScuLoginException('登录已过期，请重新登录', sessionExpired: true);
        }
        throw ScuLoginException('无法从页面提取 schemeScores callback URL');
      }
      final callbackPath = urlMatch.group(1)!;
      final callbackResp = await client.get(
        Uri.parse('http://zhjw.scu.edu.cn$callbackPath'),
        headers: {
          'Accept': 'application/json, text/plain, */*',
          'Referer':
              'http://zhjw.scu.edu.cn/student/integratedQuery/scoreQuery/schemeScores/index',
          'User-Agent': _headers['User-Agent']!,
        },
      );

      final body = callbackResp.body.trim();
      if (body.startsWith('<') || callbackResp.statusCode == 302) {
        throw ScuLoginException('登录已过期，请重新登录', sessionExpired: true);
      }
      return _parseJson(body, 'schemeScores/callback');
    } finally {
      client.close();
    }
  }

  void logout() {
    _accessToken = null;
    _cachedClient = null;
  }

  /// 安全解析 JSON，失败时抛出带上下文的异常
  static Map<String, dynamic> _parseJson(String body, String api) {
    try {
      return jsonDecode(body) as Map<String, dynamic>;
    } catch (e) {
      throw ScuLoginException('[$api] JSON 解析失败: $body');
    }
  }
}

class CaptchaResult {
  final String code;
  final String captchaBase64;
  const CaptchaResult({required this.code, required this.captchaBase64});
}

class ScuLoginException implements Exception {
  final String message;
  final bool sessionExpired;
  const ScuLoginException(this.message, {this.sessionExpired = false});
  @override
  String toString() => message;
}

// ─────────────────────────────────────────────────────────────────────────────
// Cookie 感知的 http.Client
// ─────────────────────────────────────────────────────────────────────────────

/// Cookie 感知的 http.Client，按域名隔离存储，发送时只带当前请求域的 cookie。
class _CookieClient extends http.BaseClient {
  final _inner = http.Client();

  // 按域名存 cookie：host -> {name: value}
  final _jar = <String, Map<String, String>>{};

  bool _reusable = false;

  /// 返回所有域 cookie 拼接的字符串（仅用于调试日志）
  String get cookieHeader {
    final all = <String, String>{};
    for (final m in _jar.values) {
      all.addAll(m);
    }
    return all.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  /// 获取适合发送给 [uri] 的 cookie（域名匹配：精确 host 或父域）
  Map<String, String> _cookiesFor(Uri uri) {
    final host = uri.host; // e.g. "id.scu.edu.cn"
    final result = <String, String>{};
    for (final entry in _jar.entries) {
      final jarHost = entry.key;
      // 精确匹配 或 host 是 jarHost 的子域（.scu.edu.cn 匹配 id.scu.edu.cn）
      if (host == jarHost || host.endsWith('.$jarHost')) {
        result.addAll(entry.value);
      }
    }
    return result;
  }

  /// 解析并存储响应中的 Set-Cookie
  void _storeCookies(Uri uri, http.BaseResponse response) {
    final raw = response.headers['set-cookie'];
    if (raw == null) return;

    final host = uri.host;
    _jar.putIfAbsent(host, () => {});

    // 按 ", " 分割，但跳过 expires 日期里的逗号（如 "Thu, 01 Jan 2099"）
    for (final part in raw.split(RegExp(r',\s*(?=[A-Za-z][^,=\s]*\s*=)'))) {
      final kv = part.split(';').first.trim();
      final eq = kv.indexOf('=');
      if (eq > 0) {
        final name = kv.substring(0, eq).trim();
        final value = kv.substring(eq + 1).trim();
        _jar[host]![name] = value;
      }
    }
  }

  /// 手动跟随重定向，每跳都：
  ///   1. 只带当前跳目标域的 cookie
  ///   2. 收集响应的 Set-Cookie 存回对应域
  Future<http.Response> followRedirects(
    Uri url, {
    Map<String, String>? headers,
    int maxRedirects = 10,
  }) async {
    Uri current = url;
    http.Response? lastResponse;

    for (int i = 0; i <= maxRedirects; i++) {
      // 只发当前域的 cookie，而非全部域
      final cookies = _cookiesFor(current);
      final reqHeaders = <String, String>{
        if (headers != null) ...headers,
        if (cookies.isNotEmpty)
          'Cookie': cookies.entries
              .map((e) => '${e.key}=${e.value}')
              .join('; '),
      };

      final request = http.Request('GET', current)
        ..followRedirects = false
        ..headers.addAll(reqHeaders);

      final streamed = await _inner.send(request);
      final response = await http.Response.fromStream(streamed);
      _storeCookies(current, response);

      if (response.statusCode >= 300 && response.statusCode < 400) {
        final location = response.headers['location'];
        if (location == null) break;
        current = current.resolve(location);
        lastResponse = response;
      } else {
        return response;
      }
    }
    return lastResponse!;
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final cookies = _cookiesFor(request.url);
    if (cookies.isNotEmpty) {
      request.headers['Cookie'] = cookies.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; ');
    }
    final response = await _inner.send(request);
    _storeCookies(request.url, response);
    return response;
  }

  @override
  void close() {
    if (_reusable) return;
    _inner.close();
    super.close();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// 将 sp_code 集中在一处，CcylOAuthService 和 bindSession 共用同一个值
// ─────────────────────────────────────────────────────────────────────────────
abstract class CcylSpCode {
  static const value =
      'bDBhREE1WDMzK3llSzZyVFZNeE81czRDd1hESTI4NWxGaFdsTnlvcGt3eVdTb2cxSjN5a1FJTDVMWTBEQkFFd2k1bWZRMy82OXN6V21ZYzFLd2NlSDdUaWlVcVJ1emxVVnF4Q3RZNWxjWlVoTEZqUktVSWVmY1ZaKzBLYUlBWDYvaU5MS1E5Y25nT1BoSzRIM0FIOWVCQjMxMXd5b0JrenNuWDBDM1BKU0FwUVVnZHdoSWYrc0hKZmEwSHRQbFZDV1o2dzFtQ3Nuci9wV1ExZHRMMytueHpLZVg5djJJcGFRbkJxZFJCQWJZWHI2dlpQNHVxNFNhcHM3Y3RkK2g1dWFuUEtNT1JZblFXRFBLUEdrcGdxNHR5eEcxclh5YXQ5a2FXN3JSZ2g2OTAxWCt0TUdTNXJDRVdNeDNTU3duTk1nNW9RSyt4WkdzSjNkR3NvVEFDMzFCQmJHUVcrVitybmszQVd0djFpUUJ5dDJySlRTajZIem1qZFYwMjVWcVpEaUtKd1AwQzI3TUpZd3FyY1hqdkxUZkFCd3JwL3ltczdXcmlTUzhZYVJPR0QwOXk2aDJIdUlCUTAvbEJWd0xzcUZXSElxaENpR0pseG1XYTZRbWlFaklERTd6TlhBQkJLdTZGUS8rNTBBYWRkcDVrRXdBM0tqejMvd1AvTklkZW5oNll4MllINlFiNVRucXNhZWtzUlh3d1BOQzBrMERSM0tId3dyS1hONkF6VDZwRGl3S3h1aDNLSGVmcTBRTktXUXMxTTZxeW1lcmgzYVlGWDNmVHdvUnJkWXVhbHN0aEtHKzU5TnFuVm1NbXU4dnhZQk8zKzQrdnV3aTJEaGY4VXRnV3lHeTVBcFFnWlUyQTFsWjdsR1RyNHh1TjV5dUlVc1VNNTRlbEtETTVVYWZoYnFPTXFrM2MxUHVNSHVHLzRtUFk4cmZzaXNUVkovWlhuSkhWWXpYQUJ4UDE4bGt2NXJkMFlXZHM0cFlYVVduKy9ZWGNKTlBDNEVrSzE3R0NVWDNxcCtiQkVyaXMzaTRXam1wWTFzYkpWZTAxYzZ0VGlxcGkvcEYyLzJPND0=';
}
