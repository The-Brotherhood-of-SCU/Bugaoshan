import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:bugaoshan/models/repair.dart';
import 'package:bugaoshan/services/api/zhhq_api_service.dart';
import 'package:bugaoshan/services/auth/auth_state.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/auth/zhhq_auth.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';

enum RepairLoadState { idle, loading, loaded, error }

/// 智慧后勤在线报修（zhhq）的会话级状态。
///
/// 页面只读取本 Provider 的地址/项目/工单列表与提交状态；zhhq 会话失效后
/// 的 token 重建、API 重试和旧异步结果屏蔽均由底层认证/API 层及本类负责。
class ZhhqRepairProvider extends ChangeNotifier {
  ZhhqRepairProvider(this._api, this._auth, this._scuAuth) {
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

  final ZhhqApiService _api;
  final ZhhqAuth _auth;
  final ScuAuth _scuAuth;

  List<RepairAddress> _addresses = const [];
  List<RepairTicket> _tickets = const [];
  RepairLoadState _state = RepairLoadState.idle;
  LoadErrorType? _error;
  Future<void>? _loadFuture;
  int _generation = 0;

  bool _isSubmitting = false;
  String? _submitError;
  int _operationGeneration = 0;
  bool _lastAuthReady = false;
  AuthState _lastScuAuthState = AuthState.unknown;

  // 工单列表状态（activeTemplateData/list 一次加载全部，无分页）
  bool _isLoadingTickets = false;
  bool _ticketsLoaded = false;

  List<RepairAddress> get addresses => List.unmodifiable(_addresses);
  List<RepairTicket> get tickets => List.unmodifiable(_tickets);
  RepairLoadState get state => _state;
  LoadErrorType? get error => _error;
  bool get isSubmitting => _isSubmitting;

  /// 是否正在加载工单列表。
  bool get isLoadingTickets => _isLoadingTickets;

  /// 提交失败时的具体错误文案（服务端返回）；无则 null。
  String? get submitError => _submitError;

  void _onAuthChanged() {
    final ready = _auth.isReady;
    final becameReady = ready && !_lastAuthReady;
    _lastAuthReady = ready;
    if (ready) {
      if (becameReady) {
        unawaited(ensureLoaded());
      }
    } else if (_auth.authFailed) {
      // 认证失败（超时/SSO 失败）：进入错误态供页面显示重试，
      // 避免因 isReady 恒为 false 而无限转圈。
      if (_state != RepairLoadState.error) {
        _state = RepairLoadState.error;
        _error = LoadErrorType.networkError;
        notifyListeners();
      }
    } else {
      clear();
    }
  }

  void _onScuAuthChanged() {
    final current = _scuAuth.state;
    final becameReady =
        current == AuthState.ready && _lastScuAuthState != AuthState.ready;
    _lastScuAuthState = current;
    if (current == AuthState.unknown) {
      // 仅真正登出才清数据；SCU 会话过期（expired，等待 refresh）不清 ——
      // zhhq tokenKey 与 SCU 会话独立，过期期间仍可走快速路径请求。
      clear();
    } else if (becameReady) {
      unawaited(ensureLoaded());
    }
  }

  /// 是否可以发起业务请求：zhhq tokenKey 就绪即可（与 SCU 会话独立）。
  bool get _canLoad => _auth.isReady;

  /// 是否可以发起业务请求（tokenKey 已就绪，不依赖 SCU 会话）。
  bool get isReadyForRequest => _canLoad;

  /// 若当前会话已有数据则复用；显式下拉刷新请使用 [refresh]。
  Future<void> ensureLoaded() => _load(force: false);

  /// 重新请求地址。并发刷新合并为同一个请求。
  Future<void> refresh() => _load(force: true);

  /// 认证失败后重试：重新走 [ZhhqAuth] 认证，成功后加载地址。
  Future<void> retryAuth() async {
    // 真正登出才不可重试；SCU 会话过期可以（getClient 内部会 refresh）
    if (_scuAuth.state == AuthState.unknown) return;
    try {
      await _auth.ensureAuthenticated();
    } catch (e) {
      debugPrint('ZhhqRepairProvider retryAuth failed: $e');
    }
    if (!_auth.isReady) {
      _state = RepairLoadState.error;
      _error = LoadErrorType.networkError;
      notifyListeners();
      return;
    }
    await _load(force: true);
  }

  Future<void> _load({required bool force}) {
    // 不 gate SCU 会话：tokenKey 就绪走快速路径；未就绪时 API 层
    // `_auth.getClient()` 自动走 SSO 自愈（SCU 真登出时页面已由
    // LoginRequiredWidget 拦截，不会到这里）。
    if (!force && _state == RepairLoadState.loaded) {
      return Future<void>.value();
    }
    final existing = _loadFuture;
    if (existing != null) return existing;

    final generation = ++_generation;
    _state = RepairLoadState.loading;
    _error = null;
    notifyListeners();

    Future<void> execute() async {
      try {
        // 只加载地址（快速接口）；工单列表由 [loadTickets] 独立加载，
        // 避免 oneNetPublish/myList 服务端慢（pageSize 大时可达 20s）阻塞页面。
        final addresses = await _api.fetchAddresses();
        if (!_isCurrent(generation)) return;
        _addresses = List.unmodifiable(addresses);
        _state = RepairLoadState.loaded;
        debugPrint('ZhhqRepairProvider loaded: addresses=${addresses.length}');
      } catch (error) {
        if (!_isCurrent(generation)) return;
        _state = RepairLoadState.error;
        _error = _mapError(error);
        debugPrint('ZhhqRepairProvider load error: $error');
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

  /// 加载我的报修工单列表。
  ///
  /// 使用 `activeTemplateData/list`（快、返回中文状态），一次加载全部；
  /// 不再需要分页。userId 从常用地址取（[RepairAddress.userId]）。
  ///
  /// 页面每次重建都会调用本方法（fire-and-forget），因此默认跳过已加载
  /// 的会话；下拉刷新或提交成功后需重新拉取时传 [force] = true。
  Future<void> loadTickets({bool force = false}) async {
    if (!_canLoad || _isLoadingTickets) return;
    if (!force && _ticketsLoaded) return;
    final userId = _addresses.isEmpty ? '' : _addresses.first.userId;
    if (userId.isEmpty) return;
    _isLoadingTickets = true;
    notifyListeners();
    try {
      final tickets = await _api.fetchDynamicTickets(userId: userId);
      _tickets = List.unmodifiable(tickets);
      _ticketsLoaded = true;
      debugPrint('ZhhqRepairProvider tickets loaded: ${tickets.length}');
    } catch (error) {
      debugPrint('ZhhqRepairProvider tickets load error: $error');
    } finally {
      _isLoadingTickets = false;
      notifyListeners();
    }
  }

  /// 新增常用报修地址，成功后刷新地址列表。
  Future<bool> addAddress({
    required String areaId,
    required String areaName,
    required String addressDetail,
    required String phone,
    String userName = '',
    bool isCommon = false,
  }) async {
    if (!_canLoad || _isSubmitting) return false;

    final generation = ++_operationGeneration;
    _isSubmitting = true;
    _submitError = null;
    notifyListeners();

    try {
      await _api.saveAddress(
        areaId: areaId,
        areaName: areaName,
        addressDetail: addressDetail,
        phone: phone,
        userName: userName,
        isCommon: isCommon,
      );
      if (!_isOperationCurrent(generation)) return false;
      await refresh();
      return _isOperationCurrent(generation);
    } catch (error) {
      if (_isOperationCurrent(generation)) {
        _submitError = _extractMessage(error);
      }
      return false;
    } finally {
      if (_isOperationCurrent(generation)) {
        _isSubmitting = false;
        notifyListeners();
      }
    }
  }

  /// 上传报修图片，返回服务端 path。失败抛异常（由页面捕获提示）。
  Future<String> uploadImage({required File file}) {
    return _api.uploadImage(file: file);
  }

  /// 提交报修工单，成功后刷新列表。
  Future<bool> submitTicket(Map<String, dynamic> payload) async {
    if (!_canLoad || _isSubmitting) return false;

    final generation = ++_operationGeneration;
    _isSubmitting = true;
    _submitError = null;
    notifyListeners();

    try {
      await _api.submitTicket(payload);
      if (!_isOperationCurrent(generation)) return false;
      // 提交成功后工单列表需重新拉取（下次页面重建时触发）
      _ticketsLoaded = false;
      await refresh();
      return _isOperationCurrent(generation);
    } catch (error) {
      if (_isOperationCurrent(generation)) {
        _submitError = _extractMessage(error);
      }
      return false;
    } finally {
      if (_isOperationCurrent(generation)) {
        _isSubmitting = false;
        notifyListeners();
      }
    }
  }

  /// 获取可预约日期。失败返回空列表（页面降级为不选时间）。
  Future<List<String>> fetchBookDates() async {
    try {
      return await _api.fetchBookDates();
    } on ScuException {
      return const [];
    }
  }

  /// 获取某日期的可预约时段。失败返回空列表。
  Future<List<String>> fetchBookTimes(String date) async {
    try {
      return await _api.fetchBookTimes(date);
    } on ScuException {
      return const [];
    }
  }

  /// 按区域获取维修项目。失败返回空列表。
  Future<List<RepairProject>> fetchProjects(String areaId) async {
    try {
      return await _api.fetchProjects(areaId);
    } on ScuException {
      return const [];
    }
  }

  /// 提交前预取维修负责部门（areaId + projectId）。失败返回 null。
  Future<RepairAcceptDept?> fetchAcceptDept({
    required String areaId,
    required String projectId,
  }) async {
    try {
      return await _api.fetchAcceptDept(areaId: areaId, projectId: projectId);
    } on ScuException {
      return null;
    }
  }

  /// 获取报修区域树（新增地址用）。失败返回空列表。
  Future<List<RepairAreaNode>> fetchAreaTree() async {
    try {
      return await _api.fetchAreaTreeNodes();
    } on ScuException {
      return const [];
    }
  }

  void clear() {
    _generation++;
    _operationGeneration++;
    _loadFuture = null;
    _addresses = const [];
    _tickets = const [];
    _state = RepairLoadState.idle;
    _error = null;
    _isSubmitting = false;
    _submitError = null;
    _isLoadingTickets = false;
    _ticketsLoaded = false;
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
    return LoadErrorType.networkError;
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
