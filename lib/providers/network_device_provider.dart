import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:bugaoshan/services/api/wfw_api_service.dart';
import 'package:bugaoshan/services/auth/auth_state.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/auth/wfw_auth.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';

enum NetworkDeviceLoadState { idle, loading, loaded, error }

/// 校园网设备的会话级状态。
///
/// 页面只读取本 Provider 的列表和操作状态；WFW session 失效后的重建、
/// API 重试和旧异步结果屏蔽均由底层认证/API 层及本类负责。
class NetworkDeviceProvider extends ChangeNotifier {
  NetworkDeviceProvider(this._api, this._wfwAuth, this._scuAuth) {
    _lastWfwAuthState = _wfwAuth.state;
    _lastScuAuthState = _scuAuth.state;
    _wfwAuth.addListener(_onWfwAuthChanged);
    _scuAuth.addListener(_onScuAuthChanged);
    if (_canLoad) {
      final initialGeneration = _generation;
      Future.microtask(() {
        if (_isCurrent(initialGeneration)) {
          unawaited(ensureDevices());
        }
      });
    }
  }

  final WfwApiService _api;
  final WfwAuth _wfwAuth;
  final ScuAuth _scuAuth;

  List<Map<String, dynamic>> _devices = const [];
  NetworkDeviceLoadState _state = NetworkDeviceLoadState.idle;
  LoadErrorType? _error;
  Future<void>? _loadFuture;
  int _generation = 0;

  bool _isOfflining = false;
  String? _offliningDeviceId;
  LoadErrorType? _offlineError;
  int _operationGeneration = 0;
  AuthState _lastWfwAuthState = AuthState.unknown;
  AuthState _lastScuAuthState = AuthState.unknown;

  List<Map<String, dynamic>> get devices => List.unmodifiable(_devices);
  NetworkDeviceLoadState get state => _state;
  LoadErrorType? get error => _error;
  bool get isOfflining => _isOfflining;
  String? get offliningDeviceId => _offliningDeviceId;
  LoadErrorType? get offlineError => _offlineError;

  void _onWfwAuthChanged() {
    final current = _wfwAuth.state;
    final becameReady =
        current == AuthState.ready && _lastWfwAuthState != AuthState.ready;
    _lastWfwAuthState = current;
    if (current != AuthState.ready) {
      clear();
    } else if (becameReady) {
      unawaited(ensureDevices());
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
      unawaited(ensureDevices());
    }
  }

  bool get _canLoad => _scuAuth.isReady && _wfwAuth.isReady;

  /// 若当前会话已经有列表则复用；显式下拉刷新请使用 [refresh]。
  Future<void> ensureDevices() => _load(force: false);

  /// 重新请求设备列表。并发刷新合并为同一个请求。
  Future<void> refresh() => _load(force: true);

  Future<void> _load({required bool force}) {
    // WFW 的 ready 仅代表子系统 SSO 会话已建立；SCU 主认证仍是
    // 所有业务请求的前置条件。两者缺一时保持 idle，等待认证监听回调
    // 自动补拉，绝不让 API 层触发匿名请求。
    if (!_canLoad) {
      if (_state != NetworkDeviceLoadState.idle ||
          _devices.isNotEmpty ||
          _error != null) {
        clear();
      }
      return Future<void>.value();
    }
    if (!force && _state == NetworkDeviceLoadState.loaded) {
      return Future<void>.value();
    }
    final existing = _loadFuture;
    if (existing != null) return existing;

    final generation = ++_generation;
    _state = NetworkDeviceLoadState.loading;
    _error = null;
    notifyListeners();

    Future<void> execute() async {
      try {
        final devices = await _api.fetchNetworkDevices();
        if (!_isCurrent(generation)) return;
        _devices = List.unmodifiable(devices);
        _state = NetworkDeviceLoadState.loaded;
      } catch (error) {
        if (!_isCurrent(generation)) return;
        _state = NetworkDeviceLoadState.error;
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

  /// 下线设备并在成功后刷新列表。
  ///
  /// 返回值仅表示下线请求是否成功；刷新失败会写入列表资源错误，用户仍可
  /// 手动刷新。
  Future<bool> forceOffline(Map<String, dynamic> device) async {
    if (!_canLoad || _isOfflining) return false;
    final deviceId = device['device_id']?.toString();
    final ip = device['ip']?.toString();
    if (deviceId == null || deviceId.isEmpty || ip == null || ip.isEmpty) {
      _offlineError = LoadErrorType.loadFailed;
      notifyListeners();
      return false;
    }

    final generation = ++_operationGeneration;
    _isOfflining = true;
    _offliningDeviceId = deviceId;
    _offlineError = null;
    notifyListeners();

    try {
      await _api.forceNetworkDeviceOffline(deviceId: deviceId, ip: ip);
      if (!_isOperationCurrent(generation)) return false;
      await refresh();
      return _isOperationCurrent(generation);
    } catch (error) {
      if (_isOperationCurrent(generation)) {
        _offlineError = _mapError(error);
      }
      return false;
    } finally {
      if (_isOperationCurrent(generation)) {
        _isOfflining = false;
        _offliningDeviceId = null;
        notifyListeners();
      }
    }
  }

  void clear() {
    _generation++;
    _operationGeneration++;
    _loadFuture = null;
    _devices = const [];
    _state = NetworkDeviceLoadState.idle;
    _error = null;
    _isOfflining = false;
    _offliningDeviceId = null;
    _offlineError = null;
    notifyListeners();
  }

  bool _isCurrent(int generation) => generation == _generation;
  bool _isOperationCurrent(int generation) =>
      generation == _operationGeneration;

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
    _wfwAuth.removeListener(_onWfwAuthChanged);
    _scuAuth.removeListener(_onScuAuthChanged);
    super.dispose();
  }
}
