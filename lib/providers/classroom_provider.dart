import 'package:flutter/foundation.dart';
import 'package:bugaoshan/pages/campus/models/classroom_model.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';

enum ClassroomLoadState { idle, loading, loaded, error }

class ClassroomProvider extends ChangeNotifier {
  ClassroomProvider(this._api);

  final ZhjwApiService _api;
  final Map<_ClassroomQueryKey, ClassroomQueryResult> _queryCache = {};

  List<ClassroomCampus> _campuses = const [];
  List<ClassroomBuilding> _buildings = const [];
  ClassroomLoadState _indexState = ClassroomLoadState.idle;
  LoadErrorType? _indexError;

  _ClassroomQueryKey? _currentQuery;
  ClassroomLoadState _queryState = ClassroomLoadState.idle;
  LoadErrorType? _queryError;
  int _indexGeneration = 0;
  int _queryGeneration = 0;

  List<ClassroomCampus> get campuses => _campuses;
  List<ClassroomBuilding> get buildings => _buildings;
  ClassroomLoadState get indexState => _indexState;
  LoadErrorType? get indexError => _indexError;
  ClassroomLoadState get queryState => _queryState;
  LoadErrorType? get queryError => _queryError;
  ClassroomQueryResult? get queryResult =>
      _currentQuery == null ? null : _queryCache[_currentQuery];

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
  }) async {
    final key = _ClassroomQueryKey(
      campusNumber: building.campusNumber,
      buildingNumber: building.teachingBuildingNumber,
      searchDate: searchDate,
    );
    _currentQuery = key;
    if (!forceRefresh && _queryCache.containsKey(key)) {
      _queryState = ClassroomLoadState.loaded;
      _queryError = null;
      notifyListeners();
      return;
    }
    if (_currentQuery == key && _queryState == ClassroomLoadState.loading) {
      return;
    }

    final generation = ++_queryGeneration;
    _queryState = ClassroomLoadState.loading;
    _queryError = null;
    notifyListeners();
    try {
      final result = await _api.fetchClassroomAvailability(
        campusNumber: building.campusNumber,
        buildingNumber: building.teachingBuildingNumber,
        searchDate: searchDate,
      );
      if (generation != _queryGeneration || _currentQuery != key) return;
      _queryCache[key] = result;
      _queryState = ClassroomLoadState.loaded;
    } on UnauthenticatedException {
      if (generation != _queryGeneration || _currentQuery != key) return;
      _queryState = ClassroomLoadState.error;
      _queryError = LoadErrorType.sessionExpired;
    } catch (error) {
      if (generation != _queryGeneration || _currentQuery != key) return;
      debugPrint('Classroom query error: $error');
      _queryState = ClassroomLoadState.error;
      _queryError = campusNetworkErrorType(LoadErrorType.loadFailed);
    }
    notifyListeners();
  }

  void clearCurrentQuery() {
    _queryGeneration++;
    _currentQuery = null;
    _queryState = ClassroomLoadState.idle;
    _queryError = null;
    notifyListeners();
  }

  void clear() {
    _indexGeneration++;
    _queryGeneration++;
    _campuses = const [];
    _buildings = const [];
    _queryCache.clear();
    _indexState = ClassroomLoadState.idle;
    _indexError = null;
    _currentQuery = null;
    _queryState = ClassroomLoadState.idle;
    _queryError = null;
    notifyListeners();
  }
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
