import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/models/passpoint.dart';
import 'package:bugaoshan/services/api/api_session.dart';
import 'package:bugaoshan/services/auth/new_service_auth.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/utils/app_logger.dart';

/// 智慧线上服务平台（后勤 newservice）API Service（第1层）
///
/// service.scu.edu.cn/newservice 的无感认证（passpoint）接口。认证通过
/// [NewServiceAuth]（会话 cookie `process_uid` / `process_number`），请求由
/// [ApiSession] 统一调度。
class NewServiceApiService {
  static const String _tag = 'NewServiceApiService';

  // ignore: unused_field
  final NewServiceAuth _auth;
  final ApiSession _session;
  final AppLogger _log;

  NewServiceApiService(
    this._auth, {
    ApiSession? session,
    AppLogger? logger,
  }) : _log = logger ?? getIt<AppLogger>(),
       _session =
           session ??
           ApiSession(
             getClient: _auth.getClient,
             invalidate: _auth.invalidate,
             baseUrl: Uri.parse('https://service.scu.edu.cn/newservice'),
             logTag: _tag,
             jsonValidator: (json) {
               final code = json['e']?.toString() ?? '';
               if (code == 'UN_AUTH') {
                 throw const UnauthenticatedException('newservice 登录已失效');
               }
             },
             defaultHeaders: const {
               'Origin': 'https://service.scu.edu.cn',
               'Referer':
                   'https://service.scu.edu.cn/newservice/fe/site/m_passpoint',
             },
           );

  /// 检查业务信封及 `d` 内的业务错误码（0 成功）。
  Map<String, dynamic> _checkData(Map<String, dynamic> json) {
    if (json['e']?.toString() != 'OK') {
      final message = json['m']?.toString() ?? '服务暂不可用';
      throw ServiceException(message);
    }
    final d = json['d'] as Map<String, dynamic>? ?? {};
    final errorCode = d['errorCode'];
    if (errorCode != null && errorCode.toString() != '0') {
      final message = d['errorMessage']?.toString() ?? '操作失败';
      _log.e(
        _tag,
        'passpoint 业务错误 errorCode=$errorCode: $message',
        category: LogCategory.business,
      );
      throw ServiceException(message);
    }
    return d;
  }

  /// 获取无感设备列表。
  Future<List<PasspointDevice>> fetchDevices({int limit = 100}) async {
    final json = await _session.getJsonMap(
      '/site/passpoint/query-user-mab-info',
      query: {'limit': '$limit'},
      apiName: 'fetchDevices',
    );
    final d = _checkData(json);
    final list = d['data'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => PasspointDevice.fromJson(Map<String, dynamic>.from(e)))
        .toList(growable: false);
  }

  /// 获取校园网账户信息。
  Future<PasspointUserInfo?> fetchUserInfo() async {
    final json = await _session.getJsonMap(
      '/site/passpoint/query-user',
      apiName: 'fetchUserInfo',
    );
    final d = _checkData(json);
    final result = d['queryUserResult'];
    final data = (result is Map) ? result['data'] : null;
    if (data is! Map) return null;
    return PasspointUserInfo.fromJson(Map<String, dynamic>.from(data));
  }

  /// 添加无感设备。
  Future<void> addDevice({
    required String userMac,
    required int macExpireTime,
    String defaultServiceName = '',
  }) async {
    final json = await _session.postFormForJsonMap(
      '/site/passpoint/add-user-mab-info',
      {
        'userMac': userMac,
        'macExpireTime': '$macExpireTime',
        'defaultServiceName': defaultServiceName,
      },
      apiName: 'addDevice',
    );
    _checkData(json);
  }

  /// 取消指定设备的无感认证。
  Future<void> cancelDevice({required String userMac, String? userId}) async {
    final json = await _session.postFormForJsonMap(
      '/site/passpoint/cancel-user-mab-info',
      {
        'userMac': userMac,
        if (userId != null && userId.isNotEmpty) 'userId': userId,
      },
      apiName: 'cancelDevice',
    );
    _checkData(json);
  }
}
