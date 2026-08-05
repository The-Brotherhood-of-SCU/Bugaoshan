import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/api/wfw_api_service.dart';
import 'package:bugaoshan/services/auth/auth_state.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/auth/wfw_auth.dart';

const _keyUserRealname = 'scu_user_realname';
const _keyUserNumber = 'scu_user_number';

typedef _UserInfoResult = ({
  Map<String, dynamic>? profile,
  List<Map<String, dynamic>> labels,
});
typedef UserInfoPersistence =
    Future<void> Function(String? realname, String? number);

Future<void> _persistUserInfoToPreferences(
  String? realname,
  String? number,
) async {
  final prefs = getIt<SharedPreferences>();
  if (realname == null) {
    await prefs.remove(_keyUserRealname);
  } else {
    await prefs.setString(_keyUserRealname, realname);
  }
  if (number == null) {
    await prefs.remove(_keyUserNumber);
  } else {
    await prefs.setString(_keyUserNumber, number);
  }
}

/// 用户信息 Provider（单例）
///
/// 监听 [WfwAuth] 状态变化：
/// - 登录成功（ready）→ 自动获取用户信息标签和用户基本信息
/// - 登出（unknown）→ 自动清空
class UserInfoProvider extends ChangeNotifier {
  final WfwAuth _wfwAuth;
  final WfwApiService _wfwApi;
  final UserInfoPersistence _persistUserInfo;
  int _requestGeneration = 0;
  Future<void> _persistenceTail = Future<void>.value();
  AuthState _lastAuthState = AuthState.unknown;

  UserInfoProvider(
    this._wfwAuth,
    this._wfwApi, {
    UserInfoPersistence? persistUserInfo,
  }) : _persistUserInfo = persistUserInfo ?? _persistUserInfoToPreferences {
    _wfwAuth.addListener(_onAuthChanged);
    // ScuAuth.init() 在 DI 阶段完成，此时本 Provider 还没创建，
    // init() 的 notifyListeners 没人接收。构造后主动检查一次。
    _lastAuthState = _wfwAuth.state;
    if (_wfwAuth.isReady) {
      _scheduleFetch(Duration.zero);
    }
  }

  List<Map<String, dynamic>>? _labels;
  bool _loading = false;
  bool _error = false;

  String? _userRealname;
  String? _userNumber;

  List<Map<String, dynamic>>? get labels => _labels;
  bool get loading => _loading;
  bool get error => _error;
  bool get hasData => _labels != null;
  String? get userRealname => _userRealname;
  String? get userNumber => _userNumber;

  void _onAuthChanged() {
    final current = _wfwAuth.state;
    // 只在 unknown→ready 边沿触发取数。会话失效后的自动重试路径
    // （invalidate → 预热 → ready）会再次 notify ready，若按电平触发，
    // 每次重试预热都会重新调度取数；一旦 wfw session 始终无法建立，
    // 「ready → 取数失败 → invalidate → 预热误报 ready → 再取数」
    // 就会无限循环。
    final becameReady =
        current == AuthState.ready && _lastAuthState != AuthState.ready;
    _lastAuthState = current;
    if (becameReady) {
      // ready 通知时 WfwAuth 的 SSO 登录链已完成、wfw session 已绑定
      // 用户；但 warmUpAll 中 payapp 等模块可能还在共享同一 CookieClient
      // 跑各自的 SSO 链，短延迟避让并发窗口，同时 _fetchAll 内部有一次
      // 自动重试兜底。
      _scheduleFetch(const Duration(milliseconds: 300));
    } else if (current == AuthState.unknown) {
      clear();
    }
  }

  void _scheduleFetch(Duration delay) {
    final generation = ++_requestGeneration;
    if (delay == Duration.zero) {
      Future.microtask(() => _fetchAll(generation));
    } else {
      Future.delayed(delay, () => _fetchAll(generation));
    }
  }

  bool _isCurrent(int generation) => generation == _requestGeneration;

  /// 同时获取用户信息和标签
  Future<void> _fetchAll(int generation) async {
    if (generation != _requestGeneration) return;
    _loading = true;
    _error = false;
    notifyListeners();

    try {
      final result = await _doFetch(generation);
      // 只有被更新的 generation 取代时才无声退出；
      // 同 generation 下即便 wfw 掉线 isReady 变 false，也必须复位 loading。
      if (generation != _requestGeneration) return;
      if (result == null) {
        _error = true;
      } else {
        await _applyResult(result);
      }
    } finally {
      if (generation == _requestGeneration) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  Future<_UserInfoResult?> _doFetch(int generation) async {
    try {
      return await _attemptFetch();
    } on UnauthenticatedException {
      return null;
    } catch (_) {
      // 非认证错误（如服务端限流、网络瞬断），自动重试一次
      try {
        await Future.delayed(const Duration(seconds: 1));
        if (!_isCurrent(generation)) return null;
        return await _attemptFetch();
      } catch (_) {
        return null;
      }
    }
  }

  Future<_UserInfoResult> _attemptFetch() async {
    final results = await Future.wait([
      _wfwApi.fetchUserProfile(),
      _wfwApi.fetchProfileLabels(),
    ]);
    return (
      profile: results[0] as Map<String, dynamic>?,
      labels: results[1] as List<Map<String, dynamic>>,
    );
  }

  Future<void> _applyResult(_UserInfoResult result) async {
    // 所有内存字段都在首次 await 前提交；若持久化期间登出，clear() 会最终清空它们。
    _labels = result.labels;
    _error = false;

    // 更新用户基本信息
    final profile = result.profile;
    if (profile != null) {
      _userRealname = profile['realname']?.toString();
      final role = profile['role'] as Map<String, dynamic>?;
      _userNumber = role?['number']?.toString();
      // 同步到 ScuAuthProvider（向后兼容）
      getIt<ScuAuthProvider>().setUserInfo(_userRealname, _userNumber);
      await _enqueuePersistence(_userRealname, _userNumber);
    }
  }

  Future<void> _enqueuePersistence(String? realname, String? number) {
    final operation = _persistenceTail.then(
      (_) => _persistUserInfo(realname, number),
    );
    _persistenceTail = operation.then<void>(
      (_) {},
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('User info persistence error: $error');
      },
    );
    return operation;
  }

  Future<void> fetchLabels() async {
    if (_loading) return;
    if (!_wfwAuth.isReady) return;
    final generation = ++_requestGeneration;

    _loading = true;
    _error = false;
    notifyListeners();

    try {
      final labels = await _wfwApi.fetchProfileLabels();
      if (!_isCurrent(generation)) return;
      _labels = labels;
      _error = false;
    } on UnauthenticatedException {
      if (!_isCurrent(generation)) return;
      _error = true;
    } catch (e) {
      if (!_isCurrent(generation)) return;
      _error = true;
    }
    if (!_isCurrent(generation)) return;
    _loading = false;
    notifyListeners();
  }

  void retry() {
    _error = false;
    if (_wfwAuth.isReady) {
      _scheduleFetch(Duration.zero);
    } else {
      // wfw 会话已失效：先刷新 UI 清除过期 error 帧，再主动预热恢复 ready。
      notifyListeners();
      unawaited(
        _wfwAuth
            .ensureAuthenticated()
            .then((_) {
              // 会话可能是「无声失效后重建」（invalidate 不发通知，
              // _lastAuthState 仍停留在 ready）：此时 ready 重通知不构成
              // 状态边沿，_onAuthChanged 不会再调度，这里显式兜底。
              // 正常边沿路径下通知已调度过一次，generation 会去重。
              if (_wfwAuth.isReady) {
                _scheduleFetch(const Duration(milliseconds: 300));
              }
            })
            .catchError((Object _) {}),
      );
    }
  }

  void clear() {
    _requestGeneration++;
    _labels = null;
    _error = false;
    _loading = false;
    _userRealname = null;
    _userNumber = null;
    unawaited(_enqueuePersistence(null, null));
    notifyListeners();
  }

  @override
  void dispose() {
    _requestGeneration++;
    _wfwAuth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
