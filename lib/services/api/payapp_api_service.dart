import 'package:bugaoshan/services/api/api_request.dart';
import 'package:bugaoshan/services/auth/payapp_auth.dart';
import 'package:bugaoshan/services/api/balance_query_service.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';

/// 缴费平台 API Service（第1层）
///
/// payapp.scu.edu.cn 的业务 API：电费、空调余额查询。
class PayAppApiService {
  final PayAppAuth _auth;
  final BalanceQueryService _service = BalanceQueryService();
  PayAppApiService(this._auth);

  Future<T> _request<T>(Future<T> Function(CookieClient client) fn) {
    return retryOnUnauthenticated(
      _auth.getClient,
      fn,
      invalidate: _auth.invalidate,
    );
  }

  /// 获取校区列表
  Future<List<CampusItem>> getCampus() {
    return _request((client) => _service.getCampus(client));
  }

  /// 获取建筑列表
  Future<List<BuildingItem>> getArchitecture(String schoolCode) {
    return _request((client) => _service.getArchitecture(client, schoolCode));
  }

  /// 获取单元列表
  Future<List<UnitItem>> getUnit(String schoolCode, String regCode) {
    return _request((client) => _service.getUnit(client, schoolCode, regCode));
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
    return _request(
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
    return _request(
      (client) => _service.queryRoomInfo(client, cusNo, type, cusName),
    );
  }
}
