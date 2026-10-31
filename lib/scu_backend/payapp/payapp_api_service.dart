import 'package:bugaoshan/scu_backend/core/api_session.dart';
import 'package:bugaoshan/scu_backend/payapp/balance_query_service.dart';
import 'package:bugaoshan/scu_backend/payapp/payapp_auth.dart';

/// 缴费平台 API Service（第1层）
///
/// payapp.scu.edu.cn 的业务 API：电费、空调余额查询。
class PayAppApiService {
  static const _tag = 'PayAppApiService';

  final ApiSession _session;
  final BalanceQueryService _service;

  PayAppApiService(
    PayAppAuth auth, {
    ApiSession? session,
    BalanceQueryService? service,
  }) : _service = service ?? BalanceQueryService(),
       _session =
           session ??
           ApiSession(
             getClient: auth.getClient,
             invalidate: auth.invalidate,
             baseUrl: Uri.parse('https://payapp.scu.edu.cn/eleFees'),
             logTag: _tag,
           );

  /// 获取校区列表
  Future<List<CampusItem>> getCampus() {
    return _session.run((client) => _service.getCampus(client));
  }

  /// 获取建筑列表
  Future<List<BuildingItem>> getArchitecture(String schoolCode) {
    return _session.run(
      (client) => _service.getArchitecture(client, schoolCode),
    );
  }

  /// 获取单元列表
  Future<List<UnitItem>> getUnit(String schoolCode, String regCode) {
    return _session.run(
      (client) => _service.getUnit(client, schoolCode, regCode),
    );
  }

  /// 验证/绑定房间
  Future<bool> verificationRoom({
    required String cusNo,
    required int type,
    required String cusName,
    required String schoolCode,
    required String regCode,
    required String unitCode,
    required String roomNo,
  }) {
    return _session.run(
      (client) => _service.verificationRoom(
        client,
        cusNo,
        type,
        cusName,
        schoolCode,
        regCode,
        unitCode,
        roomNo,
      ),
    );
  }

  /// 查询房间信息（电费/空调余额）
  Future<RoomInfo> queryRoomInfo({
    required String cusNo,
    required int type,
    required String cusName,
  }) {
    return _session.run(
      (client) => _service.queryRoomInfo(client, cusNo, type, cusName),
    );
  }
}
