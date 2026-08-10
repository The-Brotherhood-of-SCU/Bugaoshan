import 'dart:convert';

import 'package:bugaoshan/services/api/api_request.dart';
import 'package:bugaoshan/services/auth/wfw_auth.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/utils/constants.dart';

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
    if (statusCode == 302 ||
        statusCode == 401 ||
        statusCode == 403 ||
        body.trim().isEmpty) {
      throw const UnauthenticatedException();
    }
    if (body.trimLeft().startsWith('<') && body.contains('login')) {
      throw const UnauthenticatedException();
    }
  }

  Map<String, dynamic> _decodeResponse(String body, int statusCode) {
    _checkSessionExpiry(body, statusCode);
    final json = jsonDecode(body) as Map<String, dynamic>;
    if (json['e'] == 10013 || json['e']?.toString() == '10013') {
      throw const UnauthenticatedException('微服务登录已失效');
    }
    return json;
  }

  static const _baseUrl = 'https://wfw.scu.edu.cn';

  Map<String, String> get _networkHeaders => {
    'Accept': 'application/json, text/plain, */*',
    'Content-Type': 'application/json; charset=UTF-8',
    'Origin': _baseUrl,
    'Referer': _baseUrl,
    'User-Agent': kDefaultUserAgent,
    'X-Requested-With': 'XMLHttpRequest',
  };

  bool _isSuccess(Map<String, dynamic> json) =>
      json['e'] == 0 || json['e']?.toString() == '0';

  ServiceException _businessError(Map<String, dynamic> json, String fallback) =>
      ServiceException(json['m']?.toString() ?? fallback);

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
      return _decodeResponse(resp.body, resp.statusCode);
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
      return _decodeResponse(resp.body, resp.statusCode);
    });

    if (json['e'] == 0 && json['d'] != null) {
      return json['d']['base'] as Map<String, dynamic>?;
    }
    return null;
  }

  /// 获取当前账号的校园网在线设备列表。
  ///
  /// 认证失效响应（包括微服务的 `e == 10013`）由 [_decodeResponse]
  /// 转为 [UnauthenticatedException]，再由 [_request] 重新建立 WFW session
  /// 并只重试一次。
  Future<List<Map<String, dynamic>>> fetchNetworkDevices() async {
    final json = await _request((client) async {
      final resp = await client.post(
        Uri.parse('$_baseUrl/netclient/wap/default/get-index'),
        headers: _networkHeaders,
      );
      return _decodeResponse(resp.body, resp.statusCode);
    });

    if (!_isSuccess(json)) {
      throw _businessError(json, '获取设备信息失败');
    }
    final list = json['d']?['list'];
    if (list is! List) {
      throw const ServiceException('获取设备信息失败');
    }
    return list
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  /// 强制指定校园网设备下线。
  Future<void> forceNetworkDeviceOffline({
    required String deviceId,
    required String ip,
  }) async {
    final json = await _request((client) async {
      final resp = await client.post(
        Uri.parse('$_baseUrl/netclient/wap/default/offline'),
        headers: {
          ..._networkHeaders,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: {'device_id': deviceId, 'ip': ip},
      );
      return _decodeResponse(resp.body, resp.statusCode);
    });

    if (!_isSuccess(json)) {
      throw _businessError(json, '设备下线失败');
    }
  }
}
