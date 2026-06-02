import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/services/auth/auth_session.dart';
import 'package:bugaoshan/services/auth/auth_state.dart';
import 'package:bugaoshan/services/auth/scu_auth_session.dart';
import 'package:bugaoshan/services/auth/payapp_auth_session.dart';
import 'package:bugaoshan/services/auth/fitness_auth_session.dart';
import 'package:bugaoshan/services/auth/ccyl_auth_session.dart';
import 'package:bugaoshan/services/scu_api/scu_api_service.dart';

/// 认证管理器 — 持有所有 [AuthSession] 实例，提供统一的生命周期管理。
///
/// ## 用法
/// ```dart
/// final mgr = AuthManager(prefs);
/// await mgr.init();          // 恢复各 session 持久化状态
/// await mgr.refreshAll();    // 并行刷新所有 session
///
/// // 通过特定 session 发起带自动重试的请求
/// final data = await mgr.scu.request((client) => client.get(...));
/// final balance = await mgr.payApp.request((client) => client.post(...));
/// ```
class AuthManager {
  /// SCU 统一认证
  late final ScuAuthSession scu;

  /// 电费/空调余额查询
  late final PayAppAuthSession payApp;

  /// 体测查询
  late final FitnessAuthSession fitness;

  /// 第二课堂（CCYL）
  late final CcylAuthSession ccyl;

  /// SCU 教务系统数据 API Service
  late final ScuApiService apiService;

  AuthManager(SharedPreferences prefs) {
    scu = ScuAuthSession(prefs);
    apiService = ScuApiService();
    apiService.bindAuthManager(this);
    payApp = PayAppAuthSession(scu);
    fitness = FitnessAuthSession(scu);
    ccyl = CcylAuthSession();
  }

  /// 注册状态变更监听。当任一 session 状态变化时触发 [listener]。
  void addListener(VoidCallback listener) {
    scu.addListener(listener);
    payApp.addListener(listener);
    fitness.addListener(listener);
    ccyl.addListener(listener);
  }

  /// 移除监听。
  void removeListener(VoidCallback listener) {
    scu.removeListener(listener);
    payApp.removeListener(listener);
    fitness.removeListener(listener);
    ccyl.removeListener(listener);
  }

  /// 注册全局 session 过期回调。任一 session 刷新失败时触发。
  void onSessionExpired(void Function() callback) {
    scu.onSessionExpired = callback;
    payApp.onSessionExpired = callback;
    fitness.onSessionExpired = callback;
    ccyl.onSessionExpired = callback;
  }

  /// 初始化所有 session（从持久化存储恢复 token 等）。
  Future<void> init() async {
    await Future.wait([scu.init(), ccyl.init()]);
  }

  /// 并行刷新所有 session 的登录态。
  ///
  /// 独立的 session（SCU、CCYL）并行刷新；
  /// 依赖 SCU 的 session（PayApp、Fitness）在 SCU 刷新成功后自动恢复。
  Future<void> refreshAll() async {
    // SCU 与 CCYL 互相独立，可并行
    final results = await Future.wait([scu.refresh(), ccyl.refresh()]);

    if (results[0] == true) {
      // SCU 刷新成功 → 依赖 SCU 的 session 也标记为就绪
      payApp.forceState(AuthState.ready);
      fitness.forceState(AuthState.ready);
    }
  }

  /// SCU 是否已完全登录（含 token + session）。
  bool get isScuLoggedIn => scu.isReady;

  /// CCYL 是否已登录。
  bool get isCcylLoggedIn => ccyl.isReady;

  /// 登出所有 session。
  Future<void> logoutAll() async {
    await Future.wait([
      scu.logout(),
      payApp.logout(),
      fitness.logout(),
      ccyl.logout(),
    ]);
  }
}
