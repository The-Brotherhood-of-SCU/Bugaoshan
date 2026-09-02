import 'dart:convert';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/models/passpoint.dart';
import 'package:bugaoshan/services/api/api_request.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/services/auth/new_service_auth.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/utils/auth_logger.dart';
import 'package:bugaoshan/utils/constants.dart';

/// 智慧线上服务平台（后勤 newservice）API Service（第1层）
///
/// service.scu.edu.cn/newservice 的无感认证（passpoint）接口。认证通过
/// [NewServiceAuth]（会话 cookie `process_uid` / `process_number`），请求由
/// [CookieClient] 自动携带。
///
/// # 真实接口（已通过抓包 + 页面 JS 逆向确认）
///
/// 前端 `apiUtil` 会把 `site/scuPasspoint*` 映射为 `/site/passpoint/*`，
/// 再拼接 `apiBasePath=/newservice`，最终请求：
/// - 无感设备列表：`GET /newservice/site/passpoint/query-user-mab-info`
/// - 添加无感设备：`POST /newservice/site/passpoint/add-user-mab-info`
///   （multipart/form-data：`userMac` / `macExpireTime` / `defaultServiceName`）
/// - 取消无感认证：`POST /newservice/site/passpoint/cancel-user-mab-info`
///   （multipart/form-data：`userMac` / `userId`）
/// - 校园网账户信息：`GET /newservice/site/passpoint/query-user`
///
/// # 响应约定
///
/// 与 zhjw/wfw 的 `e` 数字错误码不同，newservice 业务成功码是字符串
/// `e == "OK"`；`d` 内的 `errorCode` / `errorMessage` 才是具体业务结果
/// （0 成功，非 0 携带错误信息）。
class NewServiceApiService {
  final NewServiceAuth _auth;
  final AuthLogger _log;
  NewServiceApiService(this._auth) : _log = getIt<AuthLogger>();

  static const String _base = 'https://service.scu.edu.cn';
  static const String _basePath = '/newservice';

  Future<T> _request<T>(Future<T> Function(CookieClient client) fn) {
    return retryOnUnauthenticated(
      _auth.getClient,
      fn,
      invalidate: _auth.invalidate,
    );
  }

  Map<String, String> get _jsonHeaders => {
    'Accept': 'application/json, text/plain, */*',
    'X-Requested-With': 'XMLHttpRequest',
    'Origin': _base,
    'Referer': '$_base$_basePath/fe/site/m_passpoint',
    'User-Agent': kDefaultUserAgent,
  };

  void _checkSessionExpiry(String body, int statusCode) {
    // newservice 会话失效时后端返回 302/403 或空 body，参照 wfw 的判定
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
    if (json['e']?.toString() != 'OK') {
      final code = json['e']?.toString() ?? '';
      final message = json['m']?.toString() ?? '服务暂不可用';
      if (code == 'UN_AUTH') {
        throw const UnauthenticatedException('newservice 登录已失效');
      }
      throw ServiceException(message);
    }
    return json;
  }

  /// 检查 `d` 内的业务错误码（0 成功）。
  ///
  /// newservice 的 passpoint 接口业务结果放在 `d.errorCode` / `d.errorMessage`，
  /// `errorCode == 0` 才表示成功。返回 `d`（便于继续读取 total/data）。
  ///
  /// 非 0 时抛出 [ServiceException] 并记录到 [AuthLogger]（Dev 页可导出排查），
  /// 这样用户/开发者能看到服务端返回的具体错误文案，而不是笼统的"操作失败"。
  Map<String, dynamic> _checkData(Map<String, dynamic> d) {
    final errorCode = d['errorCode'];
    if (errorCode != null && errorCode.toString() != '0') {
      final message = d['errorMessage']?.toString() ?? '操作失败';
      _log.w('NEWSERVICE', 'passpoint 业务错误 errorCode=$errorCode: $message');
      throw ServiceException(message);
    }
    return d;
  }

  /// 获取无感设备列表。
  Future<List<PasspointDevice>> fetchDevices({int limit = 100}) async {
    final json = await _request((client) async {
      final uri = Uri.parse(
        '$_base$_basePath/site/passpoint/query-user-mab-info',
      ).replace(queryParameters: {'limit': '$limit'});
      final resp = await client.get(uri, headers: _jsonHeaders);
      return _decodeResponse(resp.body, resp.statusCode);
    });
    final d = _checkData(json['d'] as Map<String, dynamic>? ?? {});
    final list = d['data'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => PasspointDevice.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  /// 获取校园网账户信息。
  Future<PasspointUserInfo?> fetchUserInfo() async {
    final json = await _request((client) async {
      final uri = Uri.parse('$_base$_basePath/site/passpoint/query-user');
      final resp = await client.get(uri, headers: _jsonHeaders);
      return _decodeResponse(resp.body, resp.statusCode);
    });
    final d = _checkData(json['d'] as Map<String, dynamic>? ?? {});
    final result = d['queryUserResult'];
    final data = (result is Map) ? result['data'] : null;
    if (data is! Map) return null;
    return PasspointUserInfo.fromJson(Map<String, dynamic>.from(data));
  }

  /// 添加无感设备。
  ///
  /// [defaultServiceName] 为空串表示校园网出口；学生身份可填运营商（如
  /// "中国电信"）。[macExpireTime] 为 0-365 天，0 表示最长有效期 6 年。
  Future<void> addDevice({
    required String userMac,
    required int macExpireTime,
    String defaultServiceName = '',
  }) async {
    final json = await _request((client) async {
      final uri = Uri.parse(
        '$_base$_basePath/site/passpoint/add-user-mab-info',
      );
      final resp = await client.post(
        uri,
        headers: _jsonHeaders,
        body: {
          'userMac': userMac,
          'macExpireTime': '$macExpireTime',
          'defaultServiceName': defaultServiceName,
        },
      );
      return _decodeResponse(resp.body, resp.statusCode);
    });
    _checkData(json['d'] as Map<String, dynamic>? ?? {});
  }

  /// 取消指定设备的无感认证。
  Future<void> cancelDevice({required String userMac, String? userId}) async {
    final json = await _request((client) async {
      final uri = Uri.parse(
        '$_base$_basePath/site/passpoint/cancel-user-mab-info',
      );
      final resp = await client.post(
        uri,
        headers: _jsonHeaders,
        body: {
          'userMac': userMac,
          if (userId != null && userId.isNotEmpty) 'userId': userId,
        },
      );
      return _decodeResponse(resp.body, resp.statusCode);
    });
    _checkData(json['d'] as Map<String, dynamic>? ?? {});
  }
}
