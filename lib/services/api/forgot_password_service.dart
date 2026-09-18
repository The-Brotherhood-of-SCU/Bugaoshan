import 'dart:convert';

import 'package:bugaoshan/services/auth/scu_auth.dart' show CaptchaResult;
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/utils/json_utils.dart';
import 'package:http/http.dart' as http;

/// 安全验证渠道（官方接口 `type` 取值：phone / email）。
enum ResetChannel { sms, email }

/// 统一身份认证「忘记密码」流程中的账户联系方式（verify_user 响应）。
///
/// [phone] / [email] 是服务端返回的**原始值**（官方前端拿到后才本地脱敏），
/// 仅允许在内存中流转：展示前必须经 [maskedPhone] / [maskedEmail] 脱敏，
/// 禁止原样写入日志或持久化。
class ResetAccountInfo {
  final String phone;
  final String email;
  final String sToken;

  const ResetAccountInfo({
    required this.phone,
    required this.email,
    required this.sToken,
  });

  factory ResetAccountInfo.fromJson(Map<String, dynamic> json) {
    return ResetAccountInfo(
      phone: safeString(json['phone']),
      email: safeString(json['email']),
      sToken: safeString(json['sToken']),
    );
  }

  bool get hasPhone => phone.isNotEmpty;
  bool get hasEmail => email.isNotEmpty;

  /// 手机号脱敏：保留前 3 位与后 4 位（与官方前端 sensitive(3,4) 一致）。
  static String maskedPhone(String phone) {
    if (phone.length <= 7) return phone;
    return '${phone.substring(0, 3)}****${phone.substring(phone.length - 4)}';
  }

  /// 邮箱脱敏：保留 @ 前前 2 位与完整域名（如 30****@qq.com）。
  static String maskedEmail(String email) {
    final at = email.indexOf('@');
    if (at <= 0) return email;
    final local = email.substring(0, at);
    final prefix = local.length <= 2 ? local : local.substring(0, 2);
    return '$prefix****${email.substring(at)}';
  }
}

/// 统一身份认证「忘记密码」API（第1层，纯 HTTP 工具，无需登录态）。
///
/// 官方三步流程，各步由服务端下发的凭证串联：
/// 1. `verify_user` 确认账户（学/工号 + 图形验证码）→ 联系方式 + sToken
/// 2. `obtain_code` / `verify_code` 短信或邮件验证码校验 → 重置 token
/// 3. `submit` 设置新密码（官方即 JSON+HTTPS 提交，无 SM2 加密）
class ForgotPasswordService {
  static const _base = 'https://id.scu.edu.cn';
  static const _enterpriseId = 'scdx';
  static const _captchaPath = '/api/public/bff/v1.2/one_time_login/captcha';
  static const _apiPrefix = '/api/public/bff/v1.2/forgot_password';

  static final _headers = {
    'Accept': 'application/json, text/plain, */*',
    'Content-Type': 'application/json;charset=UTF-8',
    'Origin': _base,
    'Referer': '$_base/frontend/login',
    'User-Agent': kDefaultUserAgent,
  };

  final http.Client Function() _clientFactory;

  /// 进程内复用同一个 Client（连接池复用）；实例为 GetIt 懒加载单例，
  /// 与应用同生命周期，无需显式 close。
  late final http.Client _client = _clientFactory();

  ForgotPasswordService({http.Client Function()? clientFactory})
    : _clientFactory = clientFactory ?? http.Client.new;

  /// 获取步骤1的图形验证码（与登录共用同一端点，实例各自独立）。
  Future<CaptchaResult> fetchCaptcha() async {
    final ts = DateTime.now().millisecondsSinceEpoch;
    final uri = Uri.parse(
      '$_base$_captchaPath?_enterprise_id=$_enterpriseId&time=$ts',
    );
    final resp = await _client
        .get(uri, headers: _headers)
        .timeout(kHttpTimeout);
    final json = _parseResponse(resp, 'captcha');
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const ForgotPasswordException('验证码接口返回异常');
    }
    final captchaImg = safeString(
      data['captcha'] ?? data['image'] ?? data['img'],
    );
    final code = safeString(data['code']);
    if (captchaImg.isEmpty || code.isEmpty) {
      throw const ForgotPasswordException('验证码字段解析失败');
    }
    return CaptchaResult(code: code, captchaBase64: captchaImg);
  }

  /// 步骤1：确认账户。返回绑定的联系方式（原始值）与后续步骤的 sToken。
  Future<ResetAccountInfo> verifyUser({
    required String username,
    required String captchaText,
    required String captchaCode,
  }) async {
    final json = await _post('$_apiPrefix/verify_user', {
      '_enterprise_id': _enterpriseId,
      'username': username,
      'phoneRegion': '',
      'captcha': captchaText,
      'captchaCode': captchaCode,
    }, api: 'verify_user');
    final data = json['data'];
    if (data is! Map<String, dynamic>) {
      throw const ForgotPasswordException('账户信息返回异常');
    }
    final info = ResetAccountInfo.fromJson(data);
    if (!info.hasPhone && !info.hasEmail) {
      throw const ForgotPasswordException('该账户未绑定手机号或邮箱，请联系管理员处理');
    }
    AppLog.i(
      'ForgotPassword',
      'verifyUser: ok (phone=${info.hasPhone}, email=${info.hasEmail})',
    );
    return info;
  }

  /// 步骤2a：向指定渠道发送验证码。
  Future<void> sendVerifyCode({
    required String username,
    required ResetChannel channel,
    required String sToken,
  }) async {
    await _post('$_apiPrefix/obtain_code', {
      '_enterprise_id': _enterpriseId,
      'username': username,
      'type': channel == ResetChannel.sms ? 'phone' : 'email',
      'sToken': sToken,
    }, api: 'obtain_code');
    AppLog.i('ForgotPassword', 'obtainCode: sent (${channel.name})');
  }

  /// 步骤2b：校验验证码，返回步骤3所需的重置 token。
  Future<String> verifyCode({
    required String username,
    required ResetChannel channel,
    required String code,
    required String sToken,
  }) async {
    final json = await _post('$_apiPrefix/verify_code', {
      '_enterprise_id': _enterpriseId,
      'username': username,
      'type': channel == ResetChannel.sms ? 'phone' : 'email',
      'code': code,
      'sToken': sToken,
    }, api: 'verify_code');
    final data = json['data'];
    final token = data is Map<String, dynamic> ? safeString(data['token']) : '';
    if (token.isEmpty) {
      throw const ForgotPasswordException('验证码校验返回异常');
    }
    AppLog.i('ForgotPassword', 'verifyCode: ok');
    return token;
  }

  /// 步骤3：提交新密码。官方不加密（JSON over HTTPS），rePassword 为确认字段。
  Future<void> submitNewPassword({
    required String username,
    required ResetChannel channel,
    required String token,
    required String password,
  }) async {
    final body = <String, dynamic>{
      '_enterprise_id': _enterpriseId,
      'token': token,
      'password': password,
      'rePassword': password,
    };
    // 官方按渠道以 phone / email 字段回传账户名
    body[channel == ResetChannel.sms ? 'phone' : 'email'] = username;
    await _post('$_apiPrefix/submit', body, api: 'submit');
    AppLog.i('ForgotPassword', 'submit: password reset ok');
  }

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, dynamic> body, {
    required String api,
  }) async {
    final uri = Uri.parse('$_base$endpoint?_enterprise_id=$_enterpriseId');
    final resp = await _client
        .post(uri, headers: _headers, body: jsonEncode(body))
        .timeout(kHttpTimeout);
    return _parseResponse(resp, api);
  }

  /// 统一响应校验：非 2xx 或业务 code 非 200/成功标记缺失时抛业务异常。
  ///
  /// 官方网关对业务失败返回 `{"code": 4xx, "message": "..."}`，与登录接口
  /// 的 `success` 字段两种格式并存，这里做兼容判定。
  Map<String, dynamic> _parseResponse(http.Response resp, String api) {
    Map<String, dynamic>? json;
    try {
      json = parseJson(resp.body, api, (msg) => ForgotPasswordException(msg));
    } on ForgotPasswordException {
      // 非 JSON 响应（网关错误页等）：非 2xx 时回退状态码描述，2xx 则原样抛出
      if (resp.statusCode < 200 || resp.statusCode >= 300) {
        throw ForgotPasswordException(
          '$api 请求失败(HTTP ${resp.statusCode})',
          businessCode: resp.statusCode,
        );
      }
      rethrow;
    }

    final code = json['code'];
    final hasSuccess = json.containsKey('success');
    final ok = hasSuccess
        ? json['success'] == true
        : code == null || (code is num && code == 200) || code == '200';
    if (!ok) {
      throw ForgotPasswordException(
        _extractErrorMessage(json) ?? '$api 失败',
        businessCode: code is num ? code.toInt() : int.tryParse('$code'),
      );
    }
    return json;
  }

  String? _extractErrorMessage(Map<String, dynamic> json) {
    for (final key in const ['message', 'msg', 'error_description']) {
      final value = json[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }
}
