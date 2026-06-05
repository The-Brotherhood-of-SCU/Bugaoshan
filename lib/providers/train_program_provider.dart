import 'package:flutter/widgets.dart';
import 'package:bugaoshan/pages/campus/train_program/models/train_program.dart';
import 'package:bugaoshan/pages/campus/train_program/models/train_program_model.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';

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

  String? _collegesError;
  String? _gradesError;
  String? _programsError;
  String? _detailError;
  String? _courseDetailError;

  String? _selectedCollege;
  String? _selectedGrade;

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

  String? get collegesError => _collegesError;
  String? get gradesError => _gradesError;
  String? get programsError => _programsError;
  String? get detailError => _detailError;
  String? get courseDetailError => _courseDetailError;

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
      _collegesError = 'unauthenticated';
      _gradesError = 'unauthenticated';
    } on ServiceException catch (e) {
      _collegesState = TrainProgramLoadState.error;
      _gradesState = TrainProgramLoadState.error;
      _collegesError = e.message;
      _gradesError = e.message;
    } catch (e) {
      _collegesState = TrainProgramLoadState.error;
      _gradesState = TrainProgramLoadState.error;
      _collegesError = e.toString();
      _gradesError = e.toString();
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
      _programsError = 'unauthenticated';
    } on ServiceException catch (e) {
      _programsState = TrainProgramLoadState.error;
      _programsError = e.message;
    } catch (e) {
      _programsState = TrainProgramLoadState.error;
      _programsError = e.toString();
    }
    _safeNotify();
  }

  Future<void> fetchProgramDetail(String fajhh) async {
    if (_detailState == TrainProgramLoadState.loading) return;
    _detailState = TrainProgramLoadState.loading;
    _detailError = null;
    _safeNotify();

    try {
      _currentDetail = await _zhjwApi.fetchProgramDetail(fajhh);
      _detailState = TrainProgramLoadState.loaded;
    } on UnauthenticatedException {
      _detailState = TrainProgramLoadState.error;
      _detailError = 'unauthenticated';
    } on ServiceException catch (e) {
      _detailState = TrainProgramLoadState.error;
      _detailError = e.message;
    } catch (e) {
      _detailState = TrainProgramLoadState.error;
      _detailError = e.toString();
    }
    _safeNotify();
  }

  void clearDetail() {
    _currentDetail = null;
    _detailState = TrainProgramLoadState.idle;
    _safeNotify();
  }

  Future<void> fetchCourseDetail(String urlPath) async {
    if (_courseDetailState == TrainProgramLoadState.loading) return;
    _courseDetailState = TrainProgramLoadState.loading;
    _courseDetailError = null;
    _safeNotify();

    try {
      _currentCourseDetail = await _zhjwApi.fetchCourseDetail(urlPath);
      _courseDetailState = TrainProgramLoadState.loaded;
    } on UnauthenticatedException {
      _courseDetailState = TrainProgramLoadState.error;
      _courseDetailError = 'unauthenticated';
    } on ServiceException catch (e) {
      _courseDetailState = TrainProgramLoadState.error;
      _courseDetailError = e.message;
    } catch (e) {
      _courseDetailState = TrainProgramLoadState.error;
      _courseDetailError = e.toString();
    }
    _safeNotify();
  }

  void clearCourseDetail() {
    _currentCourseDetail = null;
    _courseDetailState = TrainProgramLoadState.idle;
    _safeNotify();
  }
}
