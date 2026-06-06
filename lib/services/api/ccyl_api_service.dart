import 'package:bugaoshan/pages/campus/ccyl/models/ccyl_models.dart';
import 'package:bugaoshan/services/auth/ccyl_auth.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/ccyl/ccyl_service.dart';

/// 第二课堂 API Service（第1层）
///
/// 通过 [CcylAuth] 获取 token，委托给 [CcylService] 的静态方法。
class CcylApiService {
  final CcylAuth _auth;
  CcylApiService(this._auth);

  /// 带 auth 重试的请求包装。
  /// CCYL token 过期时服务端返回业务错误码而非 [UnauthenticatedException]。
  /// 这里捕获 [CcylException] 后清除旧 token、重新鉴权、再试一次。
  Future<T> _retryOnCcylAuthError<T>(Future<T> Function() fn) async {
    // 首次保证 token 存在
    await _ensureToken();
    try {
      return await fn();
    } on CcylException {
      _auth.invalidate();
      final ok = await _auth.reLogin();
      if (!ok) throw const UnauthenticatedException('第二课堂 token 过期，重新登录失败');
      return await fn();
    }
  }

  /// 获取 token，未登录时自动尝试 reLogin，失败抛 [UnauthenticatedException]。
  Future<String> _ensureToken() async {
    await _auth.ensureAuthenticated();
    return _auth.token!;
  }

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
  }) async {
    return _retryOnCcylAuthError(() {
      final token = _auth.token!;
      return CcylService.searchActivities(
        token: token,
        pageNum: pageNum,
        pageSize: pageSize,
        name: name ?? '',
        level: level ?? '',
        scoreType: scoreType ?? '',
        org: org ?? '',
        order: order ?? '',
        status: status ?? '',
        quality: quality ?? '',
      );
    });
  }

  Future<List<CyclActivity>> getMyActivities({
    int pageNum = 1,
    int pageSize = 10,
  }) async {
    return _retryOnCcylAuthError(() {
      final token = _auth.token!;
      return CcylService.getMyActivities(
        token: token,
        pageNum: pageNum,
        pageSize: pageSize,
      );
    });
  }

  Future<List<CyclActivity>> getOrderedActivities({
    int pageNum = 1,
    int pageSize = 10,
    String? name,
  }) async {
    return _retryOnCcylAuthError(() {
      final token = _auth.token!;
      return CcylService.getOrderedActivities(
        token: token,
        pageNum: pageNum,
        pageSize: pageSize,
        name: name ?? '',
      );
    });
  }

  Future<List<CyclOrg>> getAllOrgs() async {
    return _retryOnCcylAuthError(() {
      final token = _auth.token!;
      return CcylService.getAllOrgs(token: token);
    });
  }

  Future<
    ({
      List<CyclActivity> activities,
      CyclActivityLib activityLib,
      bool subscribed,
    })
  >
  getActivityLibDetail(String id) async {
    return _retryOnCcylAuthError(() {
      final token = _auth.token!;
      return CcylService.getActivityLibDetail(
        token: token,
        activityLibraryId: id,
      );
    });
  }

  Future<void> subscribeActivity(String id) async {
    return _retryOnCcylAuthError(() {
      final token = _auth.token!;
      return CcylService.subscribeActivity(token: token, activityLibraryId: id);
    });
  }

  Future<void> cancelSubscribe(String id) async {
    return _retryOnCcylAuthError(() {
      final token = _auth.token!;
      return CcylService.cancelSubscribe(token: token, activityLibraryId: id);
    });
  }

  Future<List<CyclScoreType>> getActivityScoreTypes(String id) async {
    return _retryOnCcylAuthError(() {
      final token = _auth.token!;
      return CcylService.getActivityScoreTypes(
        token: token,
        activityLibraryId: id,
      );
    });
  }

  Future<void> signUpActivity(String activityId, String scoreType) async {
    return _retryOnCcylAuthError(() {
      final token = _auth.token!;
      return CcylService.signUpActivity(
        token: token,
        activityId: activityId,
        scoreType: scoreType,
      );
    });
  }

  Future<void> cancelSignUp(String activityId) async {
    return _retryOnCcylAuthError(() {
      final token = _auth.token!;
      final userId = _auth.requireUserId();
      return CcylService.cancelSignUp(
        token: token,
        activityId: activityId,
        userId: userId,
      );
    });
  }

  Future<
    ({
      CyclActivity activity,
      CyclActivityLib? activityLib,
      bool isXtwRole,
      bool signUp,
    })
  >
  getActivityDetail(String activityId) async {
    return _retryOnCcylAuthError(() {
      final token = _auth.token!;
      return CcylService.getActivityDetail(
        token: token,
        activityId: activityId,
      );
    });
  }

  Future<List<CyclCredit>> getCreditList({
    int pageNum = 1,
    int pageSize = 10,
  }) async {
    return _retryOnCcylAuthError(() {
      final token = _auth.token!;
      return CcylService.getCreditList(
        token: token,
        pageNum: pageNum,
        pageSize: pageSize,
      );
    });
  }

  Future<String> exportCreditsToEmail(
    List<String> creditIds,
    String email,
  ) async {
    return _retryOnCcylAuthError(() {
      final token = _auth.token!;
      return CcylService.exportCreditsToEmail(
        token: token,
        creditIds: creditIds,
        email: email,
      );
    });
  }

  Future<Map<String, List<CyclDict>>> getDicts(List<String> groupCodes) async {
    return _retryOnCcylAuthError(() {
      final token = _auth.token!;
      return CcylService.getDicts(token: token, groupCodes: groupCodes);
    });
  }
}
