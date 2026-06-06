import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/api/wfw_api_service.dart';
import 'package:bugaoshan/services/auth/wfw_auth.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';

const _keyUserRealname = 'scu_user_realname';
const _keyUserNumber = 'scu_user_number';

/// 用户信息 Provider（单例）
///
/// 响应式链：ScuAuth → WfwAuth (L2) → UserInfoProvider
/// - WfwAuth 状态变化时自动获取用户信息标签和用户基本信息
/// - 登出时自动清空
class UserInfoProvider extends ChangeNotifier {
  final WfwAuth _wfwAuth;
  final WfwApiService _wfwApi;

  UserInfoProvider(this._wfwAuth, this._wfwApi) {
    _wfwAuth.addListener(_onAuthChanged);
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
    if (_wfwAuth.isReady) {
      _fetchAll();
    } else if (!_wfwAuth.isReady && !_wfwAuth.isExpired) {
      // unknown 状态（logout）
      clear();
    }
  }

  /// 同时获取用户信息和标签
  Future<void> _fetchAll() async {
    if (_loading) return;
    _loading = true;
    _error = false;
    notifyListeners();

    try {
      final results = await Future.wait([
        _wfwApi.fetchUserProfile(),
        _wfwApi.fetchProfileLabels(),
      ]);

      // 更新用户基本信息
      final profile = results[0] as Map<String, dynamic>?;
      if (profile != null) {
        _userRealname = profile['realname']?.toString();
        final role = profile['role'] as Map<String, dynamic>?;
        _userNumber = role?['number']?.toString();
        final prefs = getIt<SharedPreferences>();
        await prefs.setString(_keyUserRealname, _userRealname ?? '');
        await prefs.setString(_keyUserNumber, _userNumber ?? '');
        // 同步到 ScuAuthProvider（向后兼容）
        getIt<ScuAuthProvider>().setUserInfo(_userRealname, _userNumber);
      }

      // 更新标签
      _labels = results[1] as List<Map<String, dynamic>>?;
      _error = false;
    } on UnauthenticatedException {
      _error = true;
    } catch (e) {
      _error = true;
    }
    _loading = false;
    notifyListeners();
  }

  Future<void> fetchLabels() async {
    if (_loading) return;
    if (!_wfwAuth.isReady) return;

    _loading = true;
    _error = false;
    notifyListeners();

    try {
      _labels = await _wfwApi.fetchProfileLabels();
      _error = false;
    } on UnauthenticatedException {
      _error = true;
    } catch (e) {
      _error = true;
    }
    _loading = false;
    notifyListeners();
  }

  void retry() {
    _error = false;
    _fetchAll();
  }

  void clear() {
    _labels = null;
    _error = false;
    _loading = false;
    _userRealname = null;
    _userNumber = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _wfwAuth.removeListener(_onAuthChanged);
    super.dispose();
  }
}
