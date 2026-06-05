import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:bugaoshan/services/auth/wfw_auth.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';

/// 微服务 API Service（第1层）
///
/// wfw.scu.edu.cn 的业务 API：用户信息标签等。
class WfwApiService {
  final WfwAuth _auth;
  WfwApiService(this._auth);

  Future<T> _request<T>(Future<T> Function(http.Client client) fn) async {
    try {
      final client = await _auth.getClient();
      return await fn(client);
    } on UnauthenticatedException {
      final client = await _auth.getClient();
      return await fn(client);
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
      return jsonDecode(resp.body) as Map<String, dynamic>;
    });

    if (json['e'] == 0 && json['d']?['labels'] != null) {
      return (json['d']['labels'] as List)
          .map((e) => e as Map<String, dynamic>)
          .toList();
    }
    throw const ServiceException('获取用户标签失败');
  }
}
