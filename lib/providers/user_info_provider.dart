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

/// 用户信息 Provider（单例）
///
/// 监听 [WfwAuth] 状态变化：
/// - 登录成功（ready）→ 自动获取用户信息标签和用户基本信息
/// - 登出（unknown）→ 自动清空
class UserInfoProvider extends ChangeNotifier {
  final WfwAuth _wfwAuth;
  final WfwApiService _wfwApi;
  int _requestGeneration = 0;

  UserInfoProvider(this._wfwAuth, this._wfwApi) {
    _wfwAuth.addListener(_onAuthChanged);
    // ScuAuth.init() 在 DI 阶段完成，此时本 Provider 还没创建，
    // init() 的 notifyListeners 没人接收。构造后主动检查一次。
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
    if (_wfwAuth.state == AuthState.ready) {
      // SSO session 刚通过 session/save 建立，CookieClient 的 jar 里仅有
      // id.scu.edu.cn 域 cookie。立即访问 wfw.scu.edu.cn 会触发重定向链，
      // 重定向期间的并发请求可能被服务端限流或产生 session 竞态导致失败。
      // 给一个短延迟让重定向链完成，同时 _fetchAll 内部有一次自动重试兜底。
      _scheduleFetch(const Duration(milliseconds: 300));
    } else if (_wfwAuth.state == AuthState.unknown) {
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

  bool _isCurrent(int generation) =>
      generation == _requestGeneration && _wfwAuth.isReady;

  /// 同时获取用户信息和标签
  Future<void> _fetchAll(int generation) async {
    if (!_isCurrent(generation)) return;
    _loading = true;
    _error = false;
    notifyListeners();

    final result = await _doFetch(generation);
    if (!_isCurrent(generation)) return;

    if (result == null) {
      _error = true;
    } else {
      await _applyResult(result);
      if (!_isCurrent(generation)) return;
    }

    _loading = false;
    notifyListeners();
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
      final prefs = getIt<SharedPreferences>();
      await prefs.setString(_keyUserRealname, _userRealname ?? '');
      await prefs.setString(_keyUserNumber, _userNumber ?? '');
    }
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
    if (_wfwAuth.isReady) _scheduleFetch(Duration.zero);
  }

  void clear() {
    _requestGeneration++;
    _labels = null;
    _error = false;
    _loading = false;
    _userRealname = null;
    _userNumber = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _requestGeneration++;
    _wfwAuth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
