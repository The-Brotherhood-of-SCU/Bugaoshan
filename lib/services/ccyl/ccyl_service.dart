import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:bugaoshan/pages/campus/ccyl/models/ccyl_models.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/utils/json_utils.dart';

/// 第二课堂纯数据 API（无状态）
///
/// 所有认证逻辑（login / token / logout）在 [CcylAuth] 中管理。
/// API 方法通过 [authHeaders] 参数接收已注入 token 的请求头。
class CcylService {
  static const _base = 'https://dekt.scu.edu.cn';
  static const apiBase = 'https://dekt.scu.edu.cn/ccyl-api';

  static final Map<String, String> baseHeaders = {
    'Accept': 'application/json, text/plain, */*',
    'Content-Type': 'application/json;charset=UTF-8',
    'Origin': _base,
    'Referer': _base,
    'User-Agent': kDefaultUserAgent,
  };

  /// 构造带 token 的请求头
  static Map<String, String> authHeaders(String token) {
    return {...baseHeaders, 'token': token};
  }

  // ═══════════════════════════════════════════════════════════════════
  //  登录（由 CcylAuth 调用）
  // ═══════════════════════════════════════════════════════════════════

  /// 用 OAuth code 登录，返回 (token, user)
  static Future<({String token, CcylUser user})> login(String oauthCode) async {
    final json = await _httpPost(
      'loginByUc',
      Uri.parse('$apiBase/app/auth/loginByUc'),
      baseHeaders,
      {'code': oauthCode},
    );

    if (json['code'] != 0) {
      final msg = json['msg']?.toString() ?? '登录失败';
      throw CcylException(msg);
    }

    final token = json['token']?.toString();
    if (token == null) {
      throw CcylException('Token 字段缺失');
    }

    final user = CcylUser.fromJson(json['user'] as Map<String, dynamic>);
    return (token: token, user: user);
  }

  // ═══════════════════════════════════════════════════════════════════
  //  数据 API（需要 token）
  // ═══════════════════════════════════════════════════════════════════

  static Future<List<CyclActivity>> searchActivities({
    required String token,
    int pageNum = 1,
    int pageSize = 10,
    String name = '',
    String level = '',
    String scoreType = '',
    String org = '',
    String order = '',
    String status = '',
    String quality = '',
  }) async {
    final json = await _httpPost(
      'list-activity-library',
      Uri.parse('$apiBase/app/activity/list-activity-library'),
      authHeaders(token),
      {
        'pn': pageNum,
        'time': DateTime.now().millisecondsSinceEpoch.toString(),
        'ps': pageSize,
        'name': name,
        'level': level,
        'scoreType': scoreType,
        'org': org,
        'order': order,
        'status': status,
        'quality': quality,
      },
    );
    if (json['code'] != 0) {
      throw CcylException(json['msg']?.toString() ?? '获取活动列表失败');
    }
    final list = json['list'] as List<dynamic>?;
    if (list == null) return [];
    return list
        .map((e) => CyclActivity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<CyclActivity>> getMyActivities({
    required String token,
    int pageNum = 1,
    int pageSize = 10,
  }) async {
    final json = await _httpPost(
      'list-mine',
      Uri.parse('$apiBase/app/activity/list-mine'),
      authHeaders(token),
      {
        'pn': pageNum,
        'time': DateTime.now().millisecondsSinceEpoch.toString(),
        'ps': pageSize,
      },
    );
    if (json['code'] != 0) {
      throw CcylException(json['msg']?.toString() ?? '获取我参与的活动失败');
    }
    final content = json['content'] as List<dynamic>?;
    if (content == null) return [];
    return content
        .map((e) => CyclActivity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<CyclActivity>> getOrderedActivities({
    required String token,
    int pageNum = 1,
    int pageSize = 10,
    String name = '',
  }) async {
    final json = await _httpPost(
      'list-ordered-activity-library',
      Uri.parse('$apiBase/app/activity/list-ordered-activity-library'),
      authHeaders(token),
      {
        'pn': pageNum,
        'time': DateTime.now().millisecondsSinceEpoch.toString(),
        'ps': pageSize,
        'name': name,
      },
    );
    if (json['code'] != 0) {
      throw CcylException(json['msg']?.toString() ?? '获取预约的活动失败');
    }
    final list = json['list'] as List<dynamic>?;
    if (list == null) return [];
    return list
        .map((e) => CyclActivity.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<List<CyclOrg>> getAllOrgs({required String token}) async {
    final json = await _httpPost(
      'list-all',
      Uri.parse('$apiBase/app/org/list-all'),
      authHeaders(token),
      {},
    );
    if (json['code'] != 0) {
      throw CcylException(json['msg']?.toString() ?? '获取组织列表失败');
    }
    final list = json['list'] as List<dynamic>?;
    if (list == null) return [];
    return list
        .map((e) => CyclOrg.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<
    ({
      CyclActivityLib activityLib,
      List<CyclActivity> activities,
      bool subscribed,
    })
  >
  getActivityLibDetail({
    required String token,
    required String activityLibraryId,
  }) async {
    final json = await _httpGet(
      'get-lib-detail',
      Uri.parse('$apiBase/app/activity/get-lib-detail/$activityLibraryId'),
      authHeaders(token),
    );
    if (json['code'] != 0) {
      throw CcylException(json['msg']?.toString() ?? '获取活动系列详情失败');
    }
    final activityLibJson = json['activityLib'] as Map<String, dynamic>?;
    if (activityLibJson == null) throw const CcylException('活动系列数据缺失');
    return (
      activityLib: CyclActivityLib.fromJson(activityLibJson),
      activities:
          (json['activities'] as List<dynamic>?)
              ?.map((e) => CyclActivity.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      subscribed: json['subscribed'] == true,
    );
  }

  static Future<void> subscribeActivity({
    required String token,
    required String activityLibraryId,
  }) async {
    final json = await _httpPost(
      'subscribe-act',
      Uri.parse('$apiBase/app/activity/subscribe-act/$activityLibraryId'),
      authHeaders(token),
      {},
    );
    if (json['code'] != 0) {
      throw CcylException(json['msg']?.toString() ?? '预约活动失败');
    }
  }

  static Future<void> cancelSubscribe({
    required String token,
    required String activityLibraryId,
  }) async {
    final json = await _httpPost(
      'cancel-subscribe',
      Uri.parse('$apiBase/app/activity/cancel-subscribe/$activityLibraryId'),
      authHeaders(token),
      {},
    );
    if (json['code'] != 0) {
      throw CcylException(json['msg']?.toString() ?? '取消预约失败');
    }
  }

  static Future<List<CyclScoreType>> getActivityScoreTypes({
    required String token,
    required String activityLibraryId,
  }) async {
    final json = await _httpPost(
      'list-activity-score',
      Uri.parse('$apiBase/app/activity/list-activity-score/$activityLibraryId'),
      authHeaders(token),
      {},
    );
    if (json['code'] != 0) {
      throw CcylException(json['msg']?.toString() ?? '获取能力类型失败');
    }
    final list = json['list'] as List<dynamic>?;
    if (list == null) return [];
    return list
        .map((e) => CyclScoreType.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<void> signUpActivity({
    required String token,
    required String activityId,
    required String scoreType,
  }) async {
    final json = await _httpPost(
      'sign-up-act',
      Uri.parse('$apiBase/app/activity/sign-up-act'),
      authHeaders(token),
      {'activityId': activityId, 'scoreType': scoreType},
    );
    if (json['code'] != 0) {
      throw CcylException(json['msg']?.toString() ?? '报名失败');
    }
  }

  static Future<void> cancelSignUp({
    required String token,
    required String activityId,
    required String userId,
  }) async {
    final json = await _httpPost(
      'cancel',
      Uri.parse('$apiBase/app/activity/cancel'),
      authHeaders(token),
      {'activityId': activityId, 'userId': userId},
    );
    if (json['code'] != 0) {
      throw CcylException(json['msg']?.toString() ?? '取消报名失败');
    }
  }

  static Future<
    ({
      CyclActivity activity,
      CyclActivityLib? activityLib,
      bool isXtwRole,
      bool signUp,
    })
  >
  getActivityDetail({required String token, required String activityId}) async {
    final json = await _httpPost(
      'get-detail',
      Uri.parse('$apiBase/app/activity/get-detail'),
      authHeaders(token),
      {'activityId': activityId},
    );
    if (json['code'] != 0) {
      throw CcylException(json['msg']?.toString() ?? '获取活动详情失败');
    }
    final activityJson = json['activity'] as Map<String, dynamic>?;
    if (activityJson == null) throw const CcylException('活动数据缺失');
    return (
      activity: CyclActivity.fromJson(activityJson),
      activityLib: json['activityLib'] != null
          ? CyclActivityLib.fromJson(
              json['activityLib'] as Map<String, dynamic>,
            )
          : null,
      isXtwRole: json['isXtwRole'] == true,
      signUp: json['signUp'] == true,
    );
  }

  static Future<List<CyclCredit>> getCreditList({
    required String token,
    int pageNum = 1,
    int pageSize = 10,
  }) async {
    final json = await _httpPost(
      'list-credit',
      Uri.parse('$apiBase/app/credit/list'),
      authHeaders(token),
      {'pn': pageNum, 'ps': pageSize},
    );
    if (json['code'] != 0) {
      throw CcylException(json['msg']?.toString() ?? '获取成绩单失败');
    }
    final list = json['list'] as List<dynamic>?;
    if (list == null) return [];
    return list
        .map((e) => CyclCredit.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  static Future<String> exportCreditsToEmail({
    required String token,
    required List<String> creditIds,
    required String email,
  }) async {
    final json = await _httpPost(
      'export-pdf',
      Uri.parse('$apiBase/app/credit/exportPdfV2'),
      authHeaders(token),
      {'creditIds': creditIds.join(','), 'qqEmail': email},
    );
    if (json['code'] != 0) {
      throw CcylException(json['msg']?.toString() ?? '导出失败');
    }
    return json['msg']?.toString() ?? '成绩单已发送至邮箱';
  }

  static Future<Map<String, List<CyclDict>>> getDicts({
    required String token,
    required List<String> groupCodes,
  }) async {
    final results = <String, List<CyclDict>>{};
    for (final code in groupCodes) {
      try {
        final json = await _httpPost(
          'dict/$code',
          Uri.parse('$apiBase/app/dict/query-by-group-code'),
          authHeaders(token),
          {'groupCode': code},
        );
        if (json['code'] == 0) {
          final list = json['list'] as List<dynamic>?;
          if (list != null) {
            results[code] = list
                .map((e) => CyclDict.fromJson(e as Map<String, dynamic>))
                .toList();
          }
        }
      } on CcylAuthExpiredException {
        rethrow;
      } on CcylException {
        // 忽略单个字典请求失败
      }
    }
    return results;
  }

  // ═══════════════════════════════════════════════════════════════════
  //  HTTP 工具
  // ═══════════════════════════════════════════════════════════════════

  static Future<Map<String, dynamic>> _httpPost(
    String api,
    Uri uri,
    Map<String, String> headers,
    Map<String, dynamic> body,
  ) async {
    try {
      final resp = await http
          .post(uri, headers: headers, body: jsonEncode(body))
          .timeout(kHttpTimeout);
      if (resp.statusCode != 200) {
        throw CcylException('[$api] HTTP 错误: ${resp.statusCode}');
      }
      final json = parseJson(resp.body, api, (msg) => CcylException(msg));
      _throwOnAuthExpiry(json);
      return json;
    } on CcylException {
      rethrow;
    } catch (e) {
      throw CcylException('[$api] 网络请求失败: $e');
    }
  }

  static Future<Map<String, dynamic>> _httpGet(
    String api,
    Uri uri,
    Map<String, String> headers,
  ) async {
    try {
      final resp = await http.get(uri, headers: headers).timeout(kHttpTimeout);
      if (resp.statusCode != 200) {
        throw CcylException('[$api] HTTP 错误: ${resp.statusCode}');
      }
      final json = parseJson(resp.body, api, (msg) => CcylException(msg));
      _throwOnAuthExpiry(json);
      return json;
    } on CcylException {
      rethrow;
    } catch (e) {
      throw CcylException('[$api] 网络请求失败: $e');
    }
  }

  static void _throwOnAuthExpiry(Map<String, dynamic> json) {
    if (isCcylAuthExpiredCode(json['code'])) {
      throw CcylAuthExpiredException(
        json['msg']?.toString() ?? '第二课堂 token 已失效',
      );
    }
  }
}

/// CCYL 当前协议用 HTTP 200 + 业务码 401 表示 token 缺失或失效。
bool isCcylAuthExpiredCode(Object? code) => code?.toString() == '401';

// ═══════════════════════════════════════════════════════════════════════
//  异常
// ═══════════════════════════════════════════════════════════════════════

class CcylException implements Exception {
  final String message;
  const CcylException(this.message);
  @override
  String toString() => message;
}

class CcylAuthExpiredException extends CcylException {
  const CcylAuthExpiredException(super.message);
}
