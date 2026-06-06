import 'dart:convert';

import 'package:bugaoshan/services/api/api_request.dart';
import 'package:bugaoshan/services/auth/wfw_auth.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';

/// 微服务 API Service（第1层）
///
/// wfw.scu.edu.cn 的业务 API：用户信息标签等。
class WfwApiService {
  final WfwAuth _auth;
  WfwApiService(this._auth);

  Future<T> _request<T>(Future<T> Function(CookieClient client) fn) {
    return retryOnUnauthenticated(
      _auth.getClient,
      fn,
      invalidate: _auth.invalidate,
    );
  }

  void _checkSessionExpiry(String body, int statusCode) {
    if (statusCode == 302 || body.trim().isEmpty) {
      throw const UnauthenticatedException();
    }
    if (body.startsWith('<') && body.contains('login')) {
      throw const UnauthenticatedException();
    }
  }

  /// 获取用户信息标签
  Future<List<Map<String, dynamic>>> fetchProfileLabels() async {
    final json = await _request((client) async {
      final resp = await client.get(
        Uri.parse('https://wfw.scu.edu.cn/mashupapp/wap/real/user'),
        headers: {
          'Accept': 'application/json, text/plain, */*',
          'X-Requested-With': 'XMLHttpRequest',
          'Referer': 'https://wfw.scu.edu.cn',
        },
      );
      _checkSessionExpiry(resp.body, resp.statusCode);
      return jsonDecode(resp.body) as Map<String, dynamic>;
    });

    if (json['e'] == 0 && json['d']?['labels'] != null) {
      return (json['d']['labels'] as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    }
    throw const ServiceException('获取用户标签失败');
  }

  /// 获取用户基本信息（realname, number 等）
  Future<Map<String, dynamic>?> fetchUserProfile() async {
    final json = await _request((client) async {
      final resp = await client.get(
        Uri.parse('https://wfw.scu.edu.cn/uc/wap/user/get-info'),
      );
      _checkSessionExpiry(resp.body, resp.statusCode);
      return jsonDecode(resp.body) as Map<String, dynamic>;
    });

    if (json['e'] == 0 && json['d'] != null) {
      return json['d']['base'] as Map<String, dynamic>?;
    }
    return null;
  }
}
