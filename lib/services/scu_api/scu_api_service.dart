import 'dart:convert';

import 'package:bugaoshan/pages/campus/models/classroom_model.dart';
import 'package:bugaoshan/services/auth/auth_manager.dart';
import 'package:bugaoshan/services/scu_api/cookie_client.dart';
import 'package:bugaoshan/services/scu_auth/scu_auth_service.dart';
import 'package:bugaoshan/utils/json_utils.dart';

part 'scu_api_schedule.dart';
part 'scu_api_grades.dart';
part 'scu_api_classroom.dart';

/// 四川大学教务系统数据 API Service
///
/// 仅负责数据请求（fetchXxx / request）。认证相关（login / bindSession / logout）
/// 已在 [ScuAuthService] 中拆分出去。
class ScuApiService {
  late AuthManager _authManager;

  /// 绑定 [AuthManager] 引用，使 fetchXxx 方法可以使用 `request()` 自动重试。
  void bindAuthManager(AuthManager mgr) => _authManager = mgr;

  /// 通用请求包装，供不走 fetchXxx 的调用方使用（如 ProfileLabelsProvider）。
  Future<T> request<T>(Future<T> Function(CookieClient client) fn) async {
    return _authManager.scu.request(fn);
  }

  // ─── 内部工具 ─────────────────────────────────────────────────────────────

  /// 检查会话是否过期，过期则抛出 [ScuLoginException]。
  void _checkSessionExpiry(String body, int statusCode) {
    if (statusCode == 302) {
      throw ScuLoginException('登录已过期，请重新登录', sessionExpired: true);
    }
    if (body.trim().isEmpty) {
      throw ScuLoginException('登录已过期，请重新登录', sessionExpired: true);
    }
    if (body.startsWith('<') && body.contains('login')) {
      throw ScuLoginException('登录已过期，请重新登录', sessionExpired: true);
    }
  }
}
