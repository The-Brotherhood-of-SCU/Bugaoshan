import 'package:bugaoshan/scu_backend/core/api_session.dart';
import 'package:bugaoshan/scu_backend/core/scu_exceptions.dart';
import 'package:bugaoshan/scu_backend/wfw/wfw_auth.dart';

/// 微服务 API Service（第1层）
///
/// wfw.scu.edu.cn 的业务 API：用户信息标签等。
class WfwApiService {
  static const _tag = 'WfwApiService';
  static final _baseUrl = Uri.parse('https://wfw.scu.edu.cn');

  final ApiSession _session;

  WfwApiService(WfwAuth auth, {ApiSession? session})
    : _session =
          session ??
          ApiSession(
            getClient: auth.getClient,
            invalidate: auth.invalidate,
            baseUrl: _baseUrl,
            logTag: _tag,
            jsonValidator: ApiEnvelope.validateWfw,
            defaultHeaders: const {
              'Origin': 'https://wfw.scu.edu.cn',
              'Referer': 'https://wfw.scu.edu.cn',
            },
          );

  /// 获取用户信息标签
  Future<List<Map<String, dynamic>>> fetchProfileLabels() async {
    final json = await _session.getJsonMap(
      '/mashupapp/wap/real/user',
      apiName: 'fetchProfileLabels',
    );
    final data = ApiEnvelope.unwrapWfw(json, fallbackError: '获取用户标签失败');
    if (data is Map && data['labels'] is List) {
      return (data['labels'] as List).cast<Map<String, dynamic>>();
    }
    throw const ServiceException('获取用户标签失败');
  }

  /// 获取用户基本信息（realname, number 等）
  Future<Map<String, dynamic>?> fetchUserProfile() async {
    final json = await _session.getJsonMap(
      '/uc/wap/user/get-info',
      apiName: 'fetchUserProfile',
    );
    final data = ApiEnvelope.unwrapWfw(json);
    if (data is Map) {
      return data['base'] as Map<String, dynamic>?;
    }
    return null;
  }

  /// 获取当前账号的校园网在线设备列表。
  Future<List<Map<String, dynamic>>> fetchNetworkDevices() async {
    final json = await _session.postJsonForJsonMap(
      '/netclient/wap/default/get-index',
      {},
      apiName: 'fetchNetworkDevices',
    );
    final data = ApiEnvelope.unwrapWfw(json, fallbackError: '获取设备信息失败');
    final list = data is Map ? data['list'] : null;
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
    final json = await _session.postFormForJsonMap(
      '/netclient/wap/default/offline',
      {'device_id': deviceId, 'ip': ip},
      apiName: 'forceNetworkDeviceOffline',
    );
    ApiEnvelope.unwrapWfw(json, fallbackError: '设备下线失败');
  }
}
