import 'package:bugaoshan/services/auth/ccyl_auth.dart';
import 'package:bugaoshan/services/ccyl/ccyl_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';

/// 第二课堂 API Service（第1层）
///
/// dekt.scu.edu.cn 的业务 API：活动、学分等。
/// 通过 [CcylAuth] 获取已认证的 CcylService，内置自动重试。
class CcylApiService {
  final CcylAuth _auth;
  CcylApiService(this._auth);

  Future<T> _request<T>(Future<T> Function(CcylService service) fn) async {
    try {
      final service = await _auth.getService();
      return await fn(service);
    } on UnauthenticatedException {
      final service = await _auth.getService();
      return await fn(service);
    }
  }

  /// 搜索活动
  Future<List<CyclActivity>> searchActivities({
    int pageNum = 1,
    int pageSize = 10,
    String? name,
    String? level,
    String? scoreType,
    String? org,
    String? order,
    String? status,
    String? quality,
  }) {
    return _request(
      (s) => s.searchActivities(
        pageNum: pageNum,
        pageSize: pageSize,
        name: name ?? '',
        level: level ?? '',
        scoreType: scoreType ?? '',
        org: org ?? '',
        order: order ?? '',
        status: status ?? '',
        quality: quality ?? '',
      ),
    );
  }

  /// 获取我的活动
  Future<List<CyclActivity>> getMyActivities({
    int pageNum = 1,
    int pageSize = 10,
  }) {
    return _request(
      (s) => s.getMyActivities(pageNum: pageNum, pageSize: pageSize),
    );
  }

  /// 获取已预约活动
  Future<List<CyclActivity>> getOrderedActivities({
    int pageNum = 1,
    int pageSize = 10,
    String? name,
  }) {
    return _request(
      (s) => s.getOrderedActivities(
        pageNum: pageNum,
        pageSize: pageSize,
        name: name ?? '',
      ),
    );
  }

  /// 获取所有组织
  Future<List<CyclOrg>> getAllOrgs() {
    return _request((s) => s.getAllOrgs());
  }

  /// 获取活动库详情
  Future<
    ({
      List<CyclActivity> activities,
      CyclActivityLib activityLib,
      bool subscribed,
    })
  >
  getActivityLibDetail(String id) {
    return _request((s) => s.getActivityLibDetail(id));
  }

  /// 预约活动
  Future<void> subscribeActivity(String id) {
    return _request((s) => s.subscribeActivity(id));
  }

  /// 取消预约
  Future<void> cancelSubscribe(String id) {
    return _request((s) => s.cancelSubscribe(id));
  }

  /// 获取活动学分类型
  Future<List<CyclScoreType>> getActivityScoreTypes(String id) {
    return _request((s) => s.getActivityScoreTypes(id));
  }

  /// 报名活动
  Future<void> signUpActivity(String activityId, String scoreType) {
    return _request((s) => s.signUpActivity(activityId, scoreType));
  }

  /// 取消报名
  Future<void> cancelSignUp(String activityId) {
    return _request((s) => s.cancelSignUp(activityId));
  }

  /// 获取活动详情
  Future<
    ({
      CyclActivity activity,
      CyclActivityLib? activityLib,
      bool isXtwRole,
      bool signUp,
    })
  >
  getActivityDetail(String activityId) {
    return _request((s) => s.getActivityDetail(activityId));
  }

  /// 获取学分列表
  Future<List<CyclCredit>> getCreditList({int pageNum = 1, int pageSize = 10}) {
    return _request(
      (s) => s.getCreditList(pageNum: pageNum, pageSize: pageSize),
    );
  }

  /// 导出学分到邮箱
  Future<void> exportCreditsToEmail(List<String> creditIds, String email) {
    return _request((s) => s.exportCreditsToEmail(creditIds, email));
  }

  /// 获取字典
  Future<Map<String, List<CyclDict>>> getDicts(List<String> groupCodes) {
    return _request((s) => s.getDicts(groupCodes));
  }
}
