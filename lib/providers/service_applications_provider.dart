import 'package:flutter/foundation.dart';
import 'package:bugaoshan/services/api/service_api_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';

enum ServiceApplicationsLoadState { idle, loading, loaded, error }

/// 办事大厅“我的申请”列表的会话内状态。
///
/// 页面只触发 [ensureLoaded] 或 [refresh]，不再自行保存远端列表和错误状态。
class ServiceApplicationsProvider extends ChangeNotifier {
  ServiceApplicationsProvider(this._api);

  final ServiceApiService _api;
  int _generation = 0;

  List<Map<String, dynamic>> _items = const [];
  ServiceApplicationsLoadState _state = ServiceApplicationsLoadState.idle;
  LoadErrorType? _error;

  List<Map<String, dynamic>> get items => List.unmodifiable(_items);
  ServiceApplicationsLoadState get state => _state;
  LoadErrorType? get error => _error;

  Future<void> ensureLoaded() => _load(force: false);

  Future<void> refresh() => _load(force: true);

  Future<void> _load({required bool force}) async {
    if (_state == ServiceApplicationsLoadState.loading) return;
    if (!force && _state == ServiceApplicationsLoadState.loaded) return;

    final generation = ++_generation;
    _state = ServiceApplicationsLoadState.loading;
    _error = null;
    notifyListeners();

    try {
      final items = await _api.fetchMyApplications();
      if (generation != _generation) return;
      _items = items;
      _state = ServiceApplicationsLoadState.loaded;
    } on UnauthenticatedException {
      if (generation != _generation) return;
      _state = ServiceApplicationsLoadState.error;
      _error = LoadErrorType.sessionExpired;
    } on ServiceException {
      if (generation != _generation) return;
      _state = ServiceApplicationsLoadState.error;
      _error = campusNetworkErrorType(LoadErrorType.loadFailed);
    } catch (_) {
      if (generation != _generation) return;
      _state = ServiceApplicationsLoadState.error;
      _error = campusNetworkErrorType(LoadErrorType.loadFailed);
    }
    if (generation == _generation) notifyListeners();
  }

  void clear() {
    _generation++;
    _items = const [];
    _state = ServiceApplicationsLoadState.idle;
    _error = null;
    notifyListeners();
  }
}
