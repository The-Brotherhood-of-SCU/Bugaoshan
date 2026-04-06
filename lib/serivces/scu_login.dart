import 'dart:convert';
import 'dart:typed_data';

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dart_sm/dart_sm.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

class SCUSession {
  final Dio dio;
  SCUSession._(this.dio);

  Future<Response> get(String url, {Options? options}) =>
      dio.get(url, options: options);

  Future<Response> post(String url, {dynamic data, Options? options}) =>
      dio.post(url, data: data, options: options);
}

class SCULogin {
  static const _base = 'https://id.scu.edu.cn';
  static const defaultClientId = '1371cbeda563697537f28d99b4744a973uDKtgYqL5B';
  static const _headers = {
    'Accept': 'application/json, text/plain, */*',
    'Content-Type': 'application/json;charset=UTF-8',
    'Origin': _base,
    'Referer': '$_base/frontend/login',
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
        '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0',
  };

  final String username;
  final String password;
  final String clientId;
  String? _capCode;

  SCULogin({
    required this.username,
    required this.password,
    this.clientId = defaultClientId,
  });

  Future<Uint8List> getCaptcha() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final resp = await _plainDio().get(
      '$_base/api/public/bff/v1.2/one_time_login/captcha'
      '?_enterprise_id=scdx&timestamp=$ts',
    );
    _capCode = resp.data['data']['code'] as String;
    return base64Decode(resp.data['data']['captcha'] as String);
  }

  Future<SCUSession> ssoLogin(String ssoUrl, {required String capText}) async {
    if (_capCode == null) throw StateError('请先调用 getCaptcha()');

    // 1. SM2 加密密码（无需 cookie，独立请求）
    final sm2Resp = await _plainDio().post(
      '$_base/api/public/bff/v1.2/sm2_key',
      data: '{}',
    );
    final sm2Data = sm2Resp.data['data'];
    final passwordEnc = _sm2Encrypt(password, sm2Data['publicKey'] as String);

    // 2. 获取 access_token（无需 cookie）
    final tokenResp = await _plainDio().post(
      '$_base/api/public/bff/v1.2/rest_token',
      data: jsonEncode({
        'client_id': clientId,
        'grant_type': 'password',
        'scope': 'read',
        'username': username,
        'password': passwordEnc,
        '_enterprise_id': 'scdx',
        'sm2_code': sm2Data['code'],
        'cap_code': _capCode,
        'cap_text': capText,
      }),
    );
    if (tokenResp.data['success'] != true) {
      throw Exception('登录失败: ${tokenResp.data}');
    }
    final accessToken = tokenResp.data['data']['access_token'] as String;

    // 3. 用带 cookie 的 session 完成后续步骤（对应 Python 的 session）
    final cookieJar = CookieJar(ignoreExpires: true);
    final session = _sessionDio(cookieJar);

    final saveResp = await session.post(
      '$_base/api/bff/v1.2/commons/session/save',
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
      data: '{}',
    );
    if (saveResp.data['success'] != true) {
      throw Exception('session/save 失败: ${saveResp.data}');
    }

    // 4. SSO 跳转，session 自动保存 cookie
    await session.get(
      ssoUrl,
      options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
    );

    return SCUSession._(session);
  }

  /// 无 cookie 的一次性 Dio（用于获取 token 等无状态请求）
  static Dio _plainDio() =>
      Dio(BaseOptions(headers: _headers, validateStatus: (_) => true));

  /// 带 cookie 管理的 Dio（用于 session 相关请求）
  static Dio _sessionDio(CookieJar jar) {
    final dio = Dio(
      BaseOptions(
        headers: _headers,
        followRedirects: true,
        maxRedirects: 10,
        validateStatus: (_) => true,
      ),
    );
    dio.interceptors.add(CookieManager(jar));
    return dio;
  }

  static String _sm2Encrypt(String content, String publicKeyB64) {
    final keyBytes = base64Decode(publicKeyB64);
    final keyHex = keyBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    final cipher = SM2.encrypt(content, keyHex, cipherMode: C1C2C3);
    final withPrefix = '04$cipher';
    final bytes = Uint8List(withPrefix.length ~/ 2);
    for (var i = 0; i < withPrefix.length; i += 2) {
      bytes[i ~/ 2] = int.parse(withPrefix.substring(i, i + 2), radix: 16);
    }
    return base64Encode(bytes);
  }
}
