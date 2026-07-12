import 'package:flutter/widgets.dart';
import 'package:bugaoshan/pages/campus/train_program/models/train_program.dart';
import 'package:bugaoshan/pages/campus/train_program/models/train_program_model.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';

enum TrainProgramLoadState { idle, loading, loaded, error }

class TrainProgramProvider extends ChangeNotifier {
  final ZhjwApiService _zhjwApi;

  TrainProgramProvider(this._zhjwApi);

  List<College> _colleges = [];
  List<Grade> _grades = [];
  List<TrainProgram> _programs = [];
  TrainProgramDetail? _currentDetail;
  CourseDetail? _currentCourseDetail;

  TrainProgramLoadState _collegesState = TrainProgramLoadState.idle;
  TrainProgramLoadState _gradesState = TrainProgramLoadState.idle;
  TrainProgramLoadState _programsState = TrainProgramLoadState.idle;
  TrainProgramLoadState _detailState = TrainProgramLoadState.idle;
  TrainProgramLoadState _courseDetailState = TrainProgramLoadState.idle;

  LoadErrorType? _collegesError;
  LoadErrorType? _gradesError;
  LoadErrorType? _programsError;
  LoadErrorType? _detailError;
  LoadErrorType? _courseDetailError;

  String? _selectedCollege;
  String? _selectedGrade;
  int _detailGeneration = 0;
  int _courseDetailGeneration = 0;

  List<College> get colleges => _colleges;
  List<Grade> get grades => _grades;
  List<TrainProgram> get programs => _programs;
  TrainProgramDetail? get currentDetail => _currentDetail;
  CourseDetail? get currentCourseDetail => _currentCourseDetail;

  TrainProgramLoadState get collegesState => _collegesState;
  TrainProgramLoadState get gradesState => _gradesState;
  TrainProgramLoadState get programsState => _programsState;
  TrainProgramLoadState get detailState => _detailState;
  TrainProgramLoadState get courseDetailState => _courseDetailState;

  LoadErrorType? get collegesError => _collegesError;
  LoadErrorType? get gradesError => _gradesError;
  LoadErrorType? get programsError => _programsError;
  LoadErrorType? get detailError => _detailError;
  LoadErrorType? get courseDetailError => _courseDetailError;

  String? get selectedCollege => _selectedCollege;
  String? get selectedGrade => _selectedGrade;

  void setSelectedCollege(String? value) {
    _selectedCollege = value;
    notifyListeners();
  }

  void setSelectedGrade(String? value) {
    _selectedGrade = value;
    notifyListeners();
  }

  void _safeNotify() {
    WidgetsBinding.instance.addPostFrameCallback((_) => notifyListeners());
  }

  Future<void> fetchCollegesAndGrades() async {
    if (_collegesState == TrainProgramLoadState.loading ||
        _gradesState == TrainProgramLoadState.loading) {
      return;
    }

    _collegesState = TrainProgramLoadState.loading;
    _gradesState = TrainProgramLoadState.loading;
    _collegesError = null;
    _gradesError = null;
    _safeNotify();

    try {
      // 学院和年级来自同一个页面，并行获取
      final results = await Future.wait([
        _zhjwApi.fetchColleges(),
        _zhjwApi.fetchGrades(),
      ]);
      _colleges = results[0] as List<College>;
      _grades = results[1] as List<Grade>;
      _collegesState = TrainProgramLoadState.loaded;
      _gradesState = TrainProgramLoadState.loaded;
    } on UnauthenticatedException {
      _collegesState = TrainProgramLoadState.error;
      _gradesState = TrainProgramLoadState.error;
      _collegesError = LoadErrorType.sessionExpired;
      _gradesError = LoadErrorType.sessionExpired;
    } on ServiceException catch (_) {
      _collegesState = TrainProgramLoadState.error;
      _gradesState = TrainProgramLoadState.error;
      _collegesError = campusNetworkErrorType(LoadErrorType.loadFailed);
      _gradesError = campusNetworkErrorType(LoadErrorType.loadFailed);
    } catch (_) {
      _collegesState = TrainProgramLoadState.error;
      _gradesState = TrainProgramLoadState.error;
      _collegesError = campusNetworkErrorType(LoadErrorType.loadFailed);
      _gradesError = campusNetworkErrorType(LoadErrorType.loadFailed);
    }
    _safeNotify();
  }

  Future<void> searchPrograms() async {
    if (_programsState == TrainProgramLoadState.loading) return;
    _programsState = TrainProgramLoadState.loading;
    _programsError = null;
    _safeNotify();

    try {
      _programs = await _zhjwApi.searchPrograms(
        college: _selectedCollege,
        grade: _selectedGrade,
      );
      _programsState = TrainProgramLoadState.loaded;
    } on UnauthenticatedException {
      _programsState = TrainProgramLoadState.error;
      _programsError = LoadErrorType.sessionExpired;
    } on ServiceException catch (_) {
      _programsState = TrainProgramLoadState.error;
      _programsError = campusNetworkErrorType(LoadErrorType.loadFailed);
    } catch (_) {
      _programsState = TrainProgramLoadState.error;
      _programsError = campusNetworkErrorType(LoadErrorType.loadFailed);
    }
    _safeNotify();
  }

  Future<void> fetchProgramDetail(String fajhh) async {
    final generation = ++_detailGeneration;
    _detailState = TrainProgramLoadState.loading;
    _detailError = null;
    _safeNotify();

    try {
      final detail = await _zhjwApi.fetchProgramDetail(fajhh);
      if (generation != _detailGeneration) return;
      _currentDetail = detail;
      _detailState = TrainProgramLoadState.loaded;
    } on UnauthenticatedException {
      if (generation != _detailGeneration) return;
      _detailState = TrainProgramLoadState.error;
      _detailError = LoadErrorType.sessionExpired;
    } on ServiceException catch (_) {
      if (generation != _detailGeneration) return;
      _detailState = TrainProgramLoadState.error;
      _detailError = campusNetworkErrorType(LoadErrorType.loadFailed);
    } catch (_) {
      if (generation != _detailGeneration) return;
      _detailState = TrainProgramLoadState.error;
      _detailError = campusNetworkErrorType(LoadErrorType.loadFailed);
    }
    _safeNotify();
  }

  void clearDetail() {
    _detailGeneration++;
    _currentDetail = null;
    _detailState = TrainProgramLoadState.idle;
    _detailError = null;
    _safeNotify();
  }

  Future<void> fetchCourseDetail(String urlPath) async {
    final generation = ++_courseDetailGeneration;
    _courseDetailState = TrainProgramLoadState.loading;
    _courseDetailError = null;
    _safeNotify();

    try {
      final detail = await _zhjwApi.fetchCourseDetail(urlPath);
      if (generation != _courseDetailGeneration) return;
      _currentCourseDetail = detail;
      _courseDetailState = TrainProgramLoadState.loaded;
    } on UnauthenticatedException {
      if (generation != _courseDetailGeneration) return;
      _courseDetailState = TrainProgramLoadState.error;
      _courseDetailError = LoadErrorType.sessionExpired;
    } on ServiceException catch (_) {
      if (generation != _courseDetailGeneration) return;
      _courseDetailState = TrainProgramLoadState.error;
      _courseDetailError = campusNetworkErrorType(LoadErrorType.loadFailed);
    } catch (_) {
      if (generation != _courseDetailGeneration) return;
      _courseDetailState = TrainProgramLoadState.error;
      _courseDetailError = campusNetworkErrorType(LoadErrorType.loadFailed);
    }
    _safeNotify();
  }

  void clearCourseDetail() {
    _courseDetailGeneration++;
    _currentCourseDetail = null;
    _courseDetailState = TrainProgramLoadState.idle;
    _courseDetailError = null;
    _safeNotify();
  }
}
