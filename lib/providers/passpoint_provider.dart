import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:bugaoshan/models/passpoint.dart';
import 'package:bugaoshan/services/api/new_service_api_service.dart';
import 'package:bugaoshan/services/auth/auth_state.dart';
import 'package:bugaoshan/services/auth/new_service_auth.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';

enum PasspointLoadState { idle, loading, loaded, error }

/// 校园网无感认证（passpoint）的会话级状态。
///
/// 页面只读取本 Provider 的设备列表、账户信息与操作状态；newservice 会话
/// 失效后的重建、API 重试和旧异步结果屏蔽均由底层认证/API 层及本类负责。
class PasspointProvider extends ChangeNotifier {
  PasspointProvider(this._api, this._auth, this._scuAuth) {
    _lastAuthReady = _auth.isReady;
    _lastScuAuthState = _scuAuth.state;
    _auth.addListener(_onAuthChanged);
    _scuAuth.addListener(_onScuAuthChanged);
    if (_canLoad) {
      final initialGeneration = _generation;
      Future.microtask(() {
        if (_isCurrent(initialGeneration)) {
          unawaited(ensureLoaded());
        }
      });
    }
  }

  final NewServiceApiService _api;
  final NewServiceAuth _auth;
  final ScuAuth _scuAuth;

  List<PasspointDevice> _devices = const [];
  PasspointUserInfo? _userInfo;
  PasspointLoadState _state = PasspointLoadState.idle;
  LoadErrorType? _error;
  Future<void>? _loadFuture;
  int _generation = 0;

  bool _isAdding = false;
  LoadErrorType? _addError;
  String? _addErrorMessage;
  bool _isCancelling = false;
  String? _cancellingMac;
  String? _cancelErrorMessage;
  int _operationGeneration = 0;
  bool _lastAuthReady = false;
  AuthState _lastScuAuthState = AuthState.unknown;

  List<PasspointDevice> get devices => List.unmodifiable(_devices);
  PasspointUserInfo? get userInfo => _userInfo;
  PasspointLoadState get state => _state;
  LoadErrorType? get error => _error;
  bool get isAdding => _isAdding;
  LoadErrorType? get addError => _addError;

  /// 添加失败时服务端返回的具体错误文案（如「MAC 已绑定」），用于弹窗内联提示。
  /// 无具体文案时为 null。
  String? get addErrorMessage => _addErrorMessage;
  bool get isCancelling => _isCancelling;
  String? get cancellingMac => _cancellingMac;

  /// 取消失败时服务端返回的具体错误文案；无具体文案时为 null。
  String? get cancelErrorMessage => _cancelErrorMessage;

  void _onAuthChanged() {
    final ready = _auth.isReady;
    final becameReady = ready && !_lastAuthReady;
    _lastAuthReady = ready;
    if (!ready) {
      clear();
    } else if (becameReady) {
      unawaited(ensureLoaded());
    }
  }

  void _onScuAuthChanged() {
    final current = _scuAuth.state;
    final becameReady =
        current == AuthState.ready && _lastScuAuthState != AuthState.ready;
    _lastScuAuthState = current;
    if (current != AuthState.ready) {
      clear();
    } else if (becameReady) {
      unawaited(ensureLoaded());
    }
  }

  bool get _canLoad => _scuAuth.isReady && _auth.isReady;

  /// 若当前会话已有数据则复用；显式下拉刷新请使用 [refresh]。
  Future<void> ensureLoaded() => _load(force: false);

  /// 重新请求设备列表与账户信息。并发刷新合并为同一个请求。
  Future<void> refresh() => _load(force: true);

  Future<void> _load({required bool force}) {
    if (!_canLoad) {
      if (_state != PasspointLoadState.idle ||
          _devices.isNotEmpty ||
          _error != null) {
        clear();
      }
      return Future<void>.value();
    }
    if (!force && _state == PasspointLoadState.loaded) {
      return Future<void>.value();
    }
    final existing = _loadFuture;
    if (existing != null) return existing;

    final generation = ++_generation;
    _state = PasspointLoadState.loading;
    _error = null;
    notifyListeners();

    Future<void> execute() async {
      try {
        final devices = await _api.fetchDevices();
        PasspointUserInfo? userInfo;
        // 账户信息查询失败不阻断列表展示（保持与页面"列表 + 用户卡"的容错）
        try {
          userInfo = await _api.fetchUserInfo();
        } on ScuException {
          userInfo = null;
        }
        if (!_isCurrent(generation)) return;
        _devices = List.unmodifiable(devices);
        _userInfo = userInfo;
        _state = PasspointLoadState.loaded;
      } catch (error) {
        if (!_isCurrent(generation)) return;
        _state = PasspointLoadState.error;
        _error = _mapError(error);
      } finally {
        if (_isCurrent(generation)) {
          _loadFuture = null;
          notifyListeners();
        }
      }
    }

    final future = execute();
    _loadFuture = future;
    return future;
  }

  /// 添加无感设备，成功后刷新列表。
  Future<bool> addDevice({
    required String userMac,
    required int macExpireTime,
    String defaultServiceName = '',
  }) async {
    if (!_canLoad || _isAdding) return false;

    final generation = ++_operationGeneration;
    _isAdding = true;
    _addError = null;
    _addErrorMessage = null;
    notifyListeners();

    try {
      await _api.addDevice(
        userMac: userMac,
        macExpireTime: macExpireTime,
        defaultServiceName: defaultServiceName,
      );
      if (!_isOperationCurrent(generation)) return false;
      await refresh();
      return _isOperationCurrent(generation);
    } catch (error) {
      if (_isOperationCurrent(generation)) {
        _addError = _mapError(error);
        _addErrorMessage = _extractMessage(error);
      }
      return false;
    } finally {
      if (_isOperationCurrent(generation)) {
        _isAdding = false;
        notifyListeners();
      }
    }
  }

  /// 取消指定设备的无感认证，成功后刷新列表。
  ///
  /// 取消失败时写入 [cancelErrorMessage]（操作级错误），不污染列表加载
  /// 状态 [_error]（与 [NetworkDeviceProvider.forceOffline] 的 `_offlineError`
  /// 语义一致），避免页面同时出现"加载失败"横幅与操作失败提示。
  Future<bool> cancelDevice(PasspointDevice device) async {
    if (!_canLoad || _isCancelling) return false;

    final generation = ++_operationGeneration;
    _isCancelling = true;
    _cancellingMac = device.userMac;
    _cancelErrorMessage = null;
    notifyListeners();

    try {
      await _api.cancelDevice(userMac: device.userMac);
      if (!_isOperationCurrent(generation)) return false;
      await refresh();
      return _isOperationCurrent(generation);
    } catch (error) {
      if (_isOperationCurrent(generation)) {
        _cancelErrorMessage = _extractMessage(error);
      }
      return false;
    } finally {
      if (_isOperationCurrent(generation)) {
        _isCancelling = false;
        _cancellingMac = null;
        notifyListeners();
      }
    }
  }

  void clear() {
    _generation++;
    _operationGeneration++;
    _loadFuture = null;
    _devices = const [];
    _userInfo = null;
    _state = PasspointLoadState.idle;
    _error = null;
    _isAdding = false;
    _addError = null;
    _addErrorMessage = null;
    _isCancelling = false;
    _cancellingMac = null;
    _cancelErrorMessage = null;
    notifyListeners();
  }

  bool _isCurrent(int generation) => generation == _generation;
  bool _isOperationCurrent(int generation) =>
      generation == _operationGeneration;

  /// 从异常中提取可供 UI 展示的具体文案；无则返回 null。
  static String? _extractMessage(Object error) {
    if (error is ScuException) {
      final message = error.message;
      if (message.isNotEmpty && message != '未登录或登录已过期') {
        return message;
      }
    }
    return null;
  }

  LoadErrorType _mapError(Object error) {
    if (error is UnauthenticatedException) {
      return LoadErrorType.sessionExpired;
    }
    return campusNetworkErrorType(LoadErrorType.networkError);
  }

  @override
  void dispose() {
    _generation++;
    _operationGeneration++;
    _auth.removeListener(_onAuthChanged);
    _scuAuth.removeListener(_onScuAuthChanged);
    super.dispose();
  }
}
