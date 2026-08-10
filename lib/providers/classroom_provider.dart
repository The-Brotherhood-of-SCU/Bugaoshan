import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:bugaoshan/pages/campus/models/classroom_model.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';

enum ClassroomLoadState { idle, loading, loaded, error }

class ClassroomProvider extends ChangeNotifier {
  ClassroomProvider(this._api);

  /// 查询结果按 (校区, 楼栋, 日期) 缓存；超过上限时淘汰最旧的，
  /// 避免长时间使用会话内 Map 无界增长。
  static const _maxQueryResources = 30;

  final ZhjwApiService _api;
  final Map<_ClassroomQueryKey, _ClassroomQueryResource> _queryResources = {};

  List<ClassroomCampus> _campuses = const [];
  List<ClassroomBuilding> _buildings = const [];
  ClassroomLoadState _indexState = ClassroomLoadState.idle;
  LoadErrorType? _indexError;

  _ClassroomQueryKey? _currentQuery;
  int _indexGeneration = 0;
  int _queryEpoch = 0;

  List<ClassroomCampus> get campuses => _campuses;
  List<ClassroomBuilding> get buildings => _buildings;
  ClassroomLoadState get indexState => _indexState;
  LoadErrorType? get indexError => _indexError;
  ClassroomLoadState get queryState => _currentQuery == null
      ? ClassroomLoadState.idle
      : _queryResources[_currentQuery]?.state ?? ClassroomLoadState.idle;
  LoadErrorType? get queryError =>
      _currentQuery == null ? null : _queryResources[_currentQuery]?.error;
  ClassroomQueryResult? get queryResult =>
      _currentQuery == null ? null : _queryResources[_currentQuery]?.result;

  List<ClassroomBuilding> buildingsForCampus(String campusNumber) => _buildings
      .where((building) => building.campusNumber == campusNumber)
      .toList(growable: false);

  Future<void> ensureIndex() => loadIndex();

  Future<void> loadIndex({bool forceRefresh = false}) async {
    if (_indexState == ClassroomLoadState.loading) return;
    if (!forceRefresh && _indexState == ClassroomLoadState.loaded) return;

    final generation = ++_indexGeneration;
    _indexState = ClassroomLoadState.loading;
    _indexError = null;
    notifyListeners();
    try {
      final result = await _api.fetchClassroomIndex();
      if (generation != _indexGeneration) return;
      _campuses = result.campuses;
      _buildings = result.buildings;
      _indexState = ClassroomLoadState.loaded;
    } on UnauthenticatedException {
      if (generation != _indexGeneration) return;
      _indexState = ClassroomLoadState.error;
      _indexError = LoadErrorType.sessionExpired;
    } catch (error) {
      if (generation != _indexGeneration) return;
      debugPrint('Classroom index load error: $error');
      _indexState = ClassroomLoadState.error;
      _indexError = campusNetworkErrorType(LoadErrorType.loadFailed);
    }
    notifyListeners();
  }

  Future<void> queryAvailability({
    required ClassroomBuilding building,
    required String searchDate,
    bool forceRefresh = false,
  }) {
    final key = _ClassroomQueryKey(
      campusNumber: building.campusNumber,
      buildingNumber: building.teachingBuildingNumber,
      searchDate: searchDate,
    );
    _currentQuery = key;
    final resource = _queryResources.putIfAbsent(
      key,
      _ClassroomQueryResource.new,
    );
    if (!forceRefresh && resource.result != null) {
      resource.state = ClassroomLoadState.loaded;
      resource.error = null;
      notifyListeners();
      return Future.value();
    }
    final inFlight = resource.inFlight;
    if (inFlight != null) {
      notifyListeners();
      return inFlight;
    }

    final completer = Completer<void>();
    resource.inFlight = completer.future;
    resource.state = ClassroomLoadState.loading;
    resource.error = null;
    notifyListeners();
    unawaited(
      _loadAvailability(
        key: key,
        building: building,
        resource: resource,
        epoch: _queryEpoch,
        completer: completer,
      ),
    );
    _evictOldestQueryResources();
    return completer.future;
  }

  /// 按插入序淘汰最旧的查询缓存，但保留当前查询，避免页面回退时丢数据。
  void _evictOldestQueryResources() {
    if (_queryResources.length <= _maxQueryResources) return;
    final keys = _queryResources.keys.toList();
    for (final key in keys) {
      if (_queryResources.length <= _maxQueryResources) break;
      if (key == _currentQuery) continue;
      _queryResources.remove(key);
    }
  }

  Future<void> _loadAvailability({
    required _ClassroomQueryKey key,
    required ClassroomBuilding building,
    required _ClassroomQueryResource resource,
    required int epoch,
    required Completer<void> completer,
  }) async {
    try {
      final result = await _api.fetchClassroomAvailability(
        campusNumber: building.campusNumber,
        buildingNumber: building.teachingBuildingNumber,
        searchDate: key.searchDate,
      );
      if (epoch != _queryEpoch) return;
      resource.result = result;
      resource.state = ClassroomLoadState.loaded;
      resource.error = null;
    } on UnauthenticatedException {
      if (epoch != _queryEpoch) return;
      resource.state = ClassroomLoadState.error;
      resource.error = LoadErrorType.sessionExpired;
    } catch (error) {
      if (epoch != _queryEpoch) return;
      debugPrint('Classroom query error: $error');
      resource.state = ClassroomLoadState.error;
      resource.error = campusNetworkErrorType(LoadErrorType.loadFailed);
    } finally {
      if (identical(resource.inFlight, completer.future)) {
        resource.inFlight = null;
      }
      if (!completer.isCompleted) completer.complete();
      if (epoch == _queryEpoch && _currentQuery == key) {
        notifyListeners();
      }
    }
  }

  void clearCurrentQuery() {
    _currentQuery = null;
    notifyListeners();
  }

  void clear() {
    _indexGeneration++;
    _queryEpoch++;
    _campuses = const [];
    _buildings = const [];
    _queryResources.clear();
    _indexState = ClassroomLoadState.idle;
    _indexError = null;
    _currentQuery = null;
    notifyListeners();
  }
}

class _ClassroomQueryResource {
  ClassroomLoadState state = ClassroomLoadState.idle;
  ClassroomQueryResult? result;
  LoadErrorType? error;
  Future<void>? inFlight;
}

class _ClassroomQueryKey {
  const _ClassroomQueryKey({
    required this.campusNumber,
    required this.buildingNumber,
    required this.searchDate,
  });

  final String campusNumber;
  final String buildingNumber;
  final String searchDate;

  @override
  bool operator ==(Object other) =>
      other is _ClassroomQueryKey &&
      campusNumber == other.campusNumber &&
      buildingNumber == other.buildingNumber &&
      searchDate == other.searchDate;

  @override
  int get hashCode => Object.hash(campusNumber, buildingNumber, searchDate);
}
