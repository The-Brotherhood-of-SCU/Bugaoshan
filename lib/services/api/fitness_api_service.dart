import 'dart:convert';

import 'package:bugaoshan/services/api/api_request.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/services/auth/fitness_auth.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/utils/constants.dart';

/// 体测系统业务 API 的最小契约，供 [FitnessTestProvider] 注入和测试替身使用。
abstract interface class FitnessTestApi {
  Future<List<Map<String, dynamic>>> fetchNotices();

  Future<Map<String, dynamic>?> fetchScore(int year);
}

/// 体测系统 API Service（第 1 层）。
///
/// 请求认证、体测子系统 session 失效识别和单次重试均在这里完成，调用方无需
/// 直接接触 [CookieClient] 或 [FitnessAuth]。
class FitnessApiService implements FitnessTestApi {
  FitnessApiService(this._auth);

  static const _baseUrl =
      'https://pead.scu.edu.cn/bdlp_h5_fitness_test/public/index.php';

  final FitnessAuth _auth;

  Future<T> _request<T>(Future<T> Function(CookieClient client) fn) {
    return retryOnUnauthenticated(
      _auth.getClient,
      fn,
      invalidate: _auth.invalidate,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> fetchNotices() {
    return _request((client) async {
      final response = await client.post(
        Uri.parse('$_baseUrl/index/News/getSchoolNoticeList'),
        headers: _headers,
      );
      final json = _decodeResponse(response.body, 'getSchoolNoticeList');
      final data = json['data'];
      if (data is! List) {
        throw const ServiceException('体测通知响应格式错误');
      }
      return data
          .map(
            (item) => Map<String, dynamic>.from(item as Map<dynamic, dynamic>),
          )
          .toList();
    });
  }

  @override
  Future<Map<String, dynamic>?> fetchScore(int year) {
    return _request((client) async {
      final response = await client.post(
        Uri.parse('$_baseUrl/index/Report/getStudentScore'),
        headers: _headers,
        body: 'year_num=$year',
      );
      final json = _decodeResponse(response.body, 'getStudentScore');
      final data = json['data'];
      return data is Map ? Map<String, dynamic>.from(data) : null;
    });
  }

  Map<String, dynamic> _decodeResponse(String body, String api) {
    final dynamic decoded;
    try {
      decoded = jsonDecode(body);
    } on FormatException {
      throw ServiceException('[$api] JSON 解析失败');
    }
    if (decoded is! Map) {
      throw ServiceException('[$api] 响应格式错误');
    }
    final json = Map<String, dynamic>.from(decoded);
    if (json['status']?.toString() == '1') return json;

    final message = json['info']?.toString() ?? '体测服务请求失败';
    if (message.contains('登录信息失效') || message.contains('请重新登录')) {
      // 统一转换为认证异常，使 retryOnUnauthenticated 执行
      // invalidate -> 新建 SSO session -> 重试一次。
      throw UnauthenticatedException(message);
    }
    throw ServiceException(message);
  }

  Map<String, String> get _headers => {
    'Accept': 'application/json, text/plain, */*',
    'Accept-Encoding': 'gzip, deflate, br, zstd',
    'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8,en-GB;q=0.7,en-US;q=0.6',
    'Cache-Control': 'no-cache',
    'Connection': 'keep-alive',
    'Content-Type': 'application/x-www-form-urlencoded',
    'Origin': 'https://pead.scu.edu.cn',
    'Pragma': 'no-cache',
    'Referer':
        'https://pead.scu.edu.cn/bdlp_h5_fitness_test/public/index.php/index/index',
    'User-Agent': kDefaultUserAgent,
    'X-Requested-With': 'XMLHttpRequest',
    'sec-ch-ua':
        '"Microsoft Edge";v="147", "Not.A/Brand";v="8", "Chromium";v="147"',
    'sec-ch-ua-mobile': '?0',
    'sec-ch-ua-platform': '"Windows"',
  };
}
