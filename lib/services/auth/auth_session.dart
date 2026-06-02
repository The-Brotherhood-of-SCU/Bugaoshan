import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:bugaoshan/services/auth/auth_state.dart';
import 'package:bugaoshan/services/scu_auth_service.dart';

/// 认证会话的抽象基类。
///
/// 每个后端服务（SCU 统一认证、电费、体测、CCYL 等）各自维护一个
/// [AuthSession]，封装其鉴权生命周期：
///   1. 获取/刷新登录态
///   2. 提供已认证的 HTTP Client
///   3. 通过 [request] 统一处理请求失败 → 自动刷新 → 自动重试
abstract class AuthSession<T extends http.Client> extends ChangeNotifier {
  AuthState _state = AuthState.unknown;
  AuthState get state => _state;
  bool get isReady => _state == AuthState.ready;
  bool get isExpired => _state == AuthState.expired;

  /// 服务名称（用于日志 / 调试）
  String get serviceName;

  /// 当 session 过期且自动刷新失败时调用。
  /// 用于在 UI 层显示提示（如 snackbar），由 [AuthManager] 统一注册。
  void Function()? onSessionExpired;

  @protected
  set state(AuthState value) {
    if (_state != value) {
      _state = value;
      notifyListeners();
    }
  }

  /// 供外部（如 [AuthManager]）强制设置状态。
  /// 仅在特殊场景使用，优先使用 [request] 自动管理状态。
  void forceState(AuthState value) {
    if (_state != value) {
      _state = value;
      notifyListeners();
    }
  }

  /// 获取已认证的 HTTP Client。
  ///
  /// 若当前鉴权已过期，会自动尝试刷新（刷新失败则抛出异常）。
  Future<T> getClient();

  /// 刷新互斥锁，防止多个并发请求同时触发刷新。
  Completer<bool>? _refreshCompleter;

  /// 强制刷新鉴权状态（重新登录）。
  /// 返回 `true` 表示刷新成功，`false` 表示失败或被用户取消。
  Future<bool> refresh();

  /// 带互斥的刷新调用。并发请求共享同一刷新结果。
  @protected
  Future<bool> _synchronizedRefresh() async {
    if (_refreshCompleter != null) return _refreshCompleter!.future;
    _refreshCompleter = Completer<bool>();
    try {
      final result = await refresh();
      _refreshCompleter!.complete(result);
      return result;
    } catch (e) {
      state = AuthState.error;
      _refreshCompleter!.completeError(e);
      rethrow;
    } finally {
      _refreshCompleter = null;
    }
  }

  /// 登出，清除本地鉴权信息。
  Future<void> logout();

  /// 统一请求包装。
  ///
  /// 1. 先通过 [getClient] 确保 Client 就绪（若过期会自动刷新）。
  /// 2. 执行用户提供的 [fn]（实际的 API 调用）。
  /// 3. 若 [fn] 抛出 [ScuLoginException]（sessionExpired），
  ///    标记当前会话过期、通过 [_synchronizedRefresh] 刷新、刷新成功后重试一次。
  /// 4. 若刷新失败或重试仍失败，将异常继续向上抛出。
  Future<R> request<R>(
    Future<R> Function(T client) fn, {
    Future<R> Function(T client)? retryFn,
  }) async {
    late T client;
    try {
      client = await getClient();
    } on ScuLoginException catch (e) {
      if (!e.sessionExpired) rethrow;
      return _performRequestWithRetry(fn, retryFn, e);
    }

    try {
      return await fn(client);
    } on ScuLoginException catch (e) {
      if (!e.sessionExpired) rethrow;
      return _performRequestWithRetry(fn, retryFn, e);
    }
  }

  /// 执行一次完整的 session 过期刷新 + 重试流程。
  /// 提取自 [request] 以消除两段重复逻辑。
  Future<R> _performRequestWithRetry<R>(
    Future<R> Function(T client) fn,
    Future<R> Function(T client)? retryFn,
    ScuLoginException originalException,
  ) async {
    state = AuthState.expired;
    final refreshed = await _synchronizedRefresh();
    if (!refreshed) {
      state = AuthState.error;
      onSessionExpired?.call();
      throw originalException;
    }

    // 刷新成功，用新 client 重试
    state = AuthState.ready;
    final newClient = await getClient();
    final retry = retryFn ?? fn;
    return await retry(newClient);
  }
}
