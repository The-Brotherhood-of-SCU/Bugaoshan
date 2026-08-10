import 'package:flutter/foundation.dart';
import 'package:bugaoshan/pages/campus/models/class_schedule_inquiry_model.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';

enum ClassScheduleInquiryLoadState { idle, loading, loaded, error }

class ClassScheduleDetailState {
  const ClassScheduleDetailState({
    this.courses = const [],
    this.state = ClassScheduleInquiryLoadState.idle,
    this.error,
  });

  final List<ClassScheduleInquiryItem> courses;
  final ClassScheduleInquiryLoadState state;
  final LoadErrorType? error;
}

class ClassScheduleInquiryProvider extends ChangeNotifier {
  ClassScheduleInquiryProvider(this._api);

  static const pageSize = 30;

  final ZhjwApiService _api;
  List<SemesterOption> _semesters = const [];
  List<String> _grades = const [];
  List<DepartmentOption> _departments = const [];
  List<SubjectOption> _subjects = const [];
  List<ClassOption> _classOptions = const [];
  List<ClassInfo> _classes = const [];
  final Map<_ClassScheduleKey, ClassScheduleDetailState> _details = {};

  String _selectedSemester = '';
  String _selectedGrade = '';
  String _selectedDepartment = '';
  String _selectedSubject = '';
  String _selectedClass = '';
  int _pageNum = 1;
  int _totalCount = 0;

  ClassScheduleInquiryLoadState _indexState =
      ClassScheduleInquiryLoadState.idle;
  ClassScheduleInquiryLoadState _classesState =
      ClassScheduleInquiryLoadState.idle;
  ClassScheduleInquiryLoadState _subjectsState =
      ClassScheduleInquiryLoadState.idle;
  ClassScheduleInquiryLoadState _classOptionsState =
      ClassScheduleInquiryLoadState.idle;
  LoadErrorType? _indexError;
  LoadErrorType? _classesError;
  int _indexGeneration = 0;
  int _subjectsGeneration = 0;
  int _classOptionsGeneration = 0;
  int _classesGeneration = 0;
  final Map<_ClassScheduleKey, int> _detailGenerations = {};

  List<SemesterOption> get semesters => _semesters;
  List<String> get grades => _grades;
  List<DepartmentOption> get departments => _departments;
  List<SubjectOption> get subjects => _subjects;
  List<ClassOption> get classOptions => _classOptions;
  List<ClassInfo> get classes => _classes;
  String get selectedSemester => _selectedSemester;
  String get selectedGrade => _selectedGrade;
  String get selectedDepartment => _selectedDepartment;
  String get selectedSubject => _selectedSubject;
  String get selectedClass => _selectedClass;
  ClassScheduleInquiryLoadState get indexState => _indexState;
  ClassScheduleInquiryLoadState get classesState => _classesState;
  ClassScheduleInquiryLoadState get subjectsState => _subjectsState;
  ClassScheduleInquiryLoadState get classOptionsState => _classOptionsState;
  LoadErrorType? get indexError => _indexError;
  LoadErrorType? get classesError => _classesError;
  bool get isLoadingMore =>
      _classesState == ClassScheduleInquiryLoadState.loading && _pageNum > 1;
  bool get hasMore => _classes.length < _totalCount;

  void setSelectedSemester(String value) {
    if (_selectedSemester == value) return;
    _selectedSemester = value;
    notifyListeners();
  }

  Future<void> setSelectedGrade(String value) async {
    if (_selectedGrade == value) return;
    _selectedGrade = value;
    _selectedClass = '';
    notifyListeners();
    await loadClassOptions();
  }

  Future<void> setSelectedDepartment(String value) async {
    if (_selectedDepartment == value) return;
    _selectedDepartment = value;
    _selectedSubject = '';
    _selectedClass = '';
    _subjects = const [];
    _classOptions = const [];
    _subjectsGeneration++;
    _classOptionsGeneration++;
    notifyListeners();
    await Future.wait([loadSubjects(), loadClassOptions()]);
  }

  Future<void> setSelectedSubject(String value) async {
    if (_selectedSubject == value) return;
    _selectedSubject = value;
    _selectedClass = '';
    notifyListeners();
    await loadClassOptions();
  }

  void setSelectedClass(String value) {
    if (_selectedClass == value) return;
    _selectedClass = value;
    notifyListeners();
  }

  Future<void> ensureIndex() => loadIndex();

  Future<void> loadIndex({bool forceRefresh = false}) async {
    if (_indexState == ClassScheduleInquiryLoadState.loading) return;
    if (!forceRefresh && _indexState == ClassScheduleInquiryLoadState.loaded) {
      return;
    }
    final generation = ++_indexGeneration;
    _indexState = ClassScheduleInquiryLoadState.loading;
    _indexError = null;
    notifyListeners();
    try {
      final result = await _api.fetchClassScheduleInquiryIndex();
      if (generation != _indexGeneration) return;
      _semesters = result.semesters;
      _grades = result.grades;
      _departments = result.departments;
      _indexState = ClassScheduleInquiryLoadState.loaded;
      notifyListeners();
      await search();
    } on UnauthenticatedException {
      if (generation != _indexGeneration) return;
      _indexState = ClassScheduleInquiryLoadState.error;
      _indexError = LoadErrorType.sessionExpired;
      notifyListeners();
    } catch (error) {
      if (generation != _indexGeneration) return;
      debugPrint('Class schedule index load error: $error');
      _indexState = ClassScheduleInquiryLoadState.error;
      _indexError = campusNetworkErrorType(LoadErrorType.loadFailed);
      notifyListeners();
    }
  }

  Future<void> loadSubjects() async {
    final department = _selectedDepartment;
    final generation = ++_subjectsGeneration;
    if (department.isEmpty) {
      _subjects = const [];
      _subjectsState = ClassScheduleInquiryLoadState.idle;
      notifyListeners();
      return;
    }
    _subjectsState = ClassScheduleInquiryLoadState.loading;
    notifyListeners();
    try {
      final subjects = await _api.fetchSubjectsByDepartment(department);
      if (generation != _subjectsGeneration ||
          department != _selectedDepartment) {
        return;
      }
      _subjects = subjects;
      _subjectsState = ClassScheduleInquiryLoadState.loaded;
    } catch (error) {
      if (generation != _subjectsGeneration ||
          department != _selectedDepartment) {
        return;
      }
      debugPrint('Class schedule subjects load error: $error');
      _subjects = const [];
      _subjectsState = ClassScheduleInquiryLoadState.error;
    }
    notifyListeners();
  }

  Future<void> loadClassOptions() async {
    final grade = _selectedGrade;
    final department = _selectedDepartment;
    final subject = _selectedSubject;
    final generation = ++_classOptionsGeneration;
    if (grade.isEmpty || department.isEmpty) {
      _classOptions = const [];
      _classOptionsState = ClassScheduleInquiryLoadState.idle;
      notifyListeners();
      return;
    }
    _classOptionsState = ClassScheduleInquiryLoadState.loading;
    notifyListeners();
    try {
      final options = await _api.fetchClassOptions(
        yearNum: grade,
        departmentNum: department,
        subjectNum: subject,
      );
      if (generation != _classOptionsGeneration ||
          grade != _selectedGrade ||
          department != _selectedDepartment ||
          subject != _selectedSubject) {
        return;
      }
      _classOptions = options;
      _classOptionsState = ClassScheduleInquiryLoadState.loaded;
    } catch (error) {
      if (generation != _classOptionsGeneration ||
          grade != _selectedGrade ||
          department != _selectedDepartment ||
          subject != _selectedSubject) {
        return;
      }
      debugPrint('Class schedule class options load error: $error');
      _classOptions = const [];
      _classOptionsState = ClassScheduleInquiryLoadState.error;
    }
    notifyListeners();
  }

  Future<void> search() async {
    _pageNum = 1;
    _totalCount = 0;
    _classes = const [];
    _classesError = null;
    await _loadClasses(replace: true);
  }

  Future<void> refresh() => search();

  Future<void> loadMore() async {
    if (isLoadingMore || !hasMore) return;
    _pageNum++;
    await _loadClasses(replace: false);
  }

  Future<void> _loadClasses({required bool replace}) async {
    final semester = _selectedSemester;
    final grade = _selectedGrade;
    final department = _selectedDepartment;
    final subject = _selectedSubject;
    final classCode = _selectedClass;
    final page = _pageNum;
    final generation = ++_classesGeneration;
    _classesState = ClassScheduleInquiryLoadState.loading;
    _classesError = null;
    notifyListeners();
    try {
      final result = await _api.fetchClassList(
        pageNum: page,
        pageSize: pageSize,
        executiveEducationPlanNum: semester,
        yearNum: grade,
        departmentNum: department,
        subjectNum: subject,
        classNum: classCode,
      );
      if (generation != _classesGeneration ||
          semester != _selectedSemester ||
          grade != _selectedGrade ||
          department != _selectedDepartment ||
          subject != _selectedSubject ||
          classCode != _selectedClass ||
          page != _pageNum) {
        return;
      }
      _classes = replace ? result.classes : [..._classes, ...result.classes];
      _totalCount = result.totalCount;
      _classesState = ClassScheduleInquiryLoadState.loaded;
    } on UnauthenticatedException {
      if (!_isCurrentClassRequest(
        generation: generation,
        semester: semester,
        grade: grade,
        department: department,
        subject: subject,
        classCode: classCode,
        page: page,
      )) {
        return;
      }
      _classesState = ClassScheduleInquiryLoadState.error;
      _classesError = LoadErrorType.sessionExpired;
    } catch (error) {
      if (!_isCurrentClassRequest(
        generation: generation,
        semester: semester,
        grade: grade,
        department: department,
        subject: subject,
        classCode: classCode,
        page: page,
      )) {
        return;
      }
      debugPrint('Class schedule classes load error: $error');
      _classesState = ClassScheduleInquiryLoadState.error;
      _classesError = campusNetworkErrorType(LoadErrorType.loadFailed);
    }
    notifyListeners();
  }

  bool _isCurrentClassRequest({
    required int generation,
    required String semester,
    required String grade,
    required String department,
    required String subject,
    required String classCode,
    required int page,
  }) =>
      generation == _classesGeneration &&
      semester == _selectedSemester &&
      grade == _selectedGrade &&
      department == _selectedDepartment &&
      subject == _selectedSubject &&
      classCode == _selectedClass &&
      page == _pageNum;

  ClassScheduleDetailState detailStateFor(ClassInfo classInfo) =>
      _details[_ClassScheduleKey.fromClass(classInfo)] ??
      const ClassScheduleDetailState();

  Future<void> ensureSchedule(ClassInfo classInfo) => loadSchedule(classInfo);

  Future<void> refreshSchedule(ClassInfo classInfo) =>
      loadSchedule(classInfo, forceRefresh: true);

  Future<void> loadSchedule(
    ClassInfo classInfo, {
    bool forceRefresh = false,
  }) async {
    final key = _ClassScheduleKey.fromClass(classInfo);
    final previous = detailStateFor(classInfo);
    if (previous.state == ClassScheduleInquiryLoadState.loading) return;
    if (!forceRefresh &&
        previous.state == ClassScheduleInquiryLoadState.loaded) {
      return;
    }
    final generation = (_detailGenerations[key] ?? 0) + 1;
    _detailGenerations[key] = generation;
    _details[key] = ClassScheduleDetailState(
      courses: forceRefresh ? const [] : previous.courses,
      state: ClassScheduleInquiryLoadState.loading,
    );
    notifyListeners();
    try {
      final courses = await _api.fetchClassSchedule(
        planCode: classInfo.planCode,
        classCode: classInfo.classCode,
      );
      if (_detailGenerations[key] != generation) return;
      _details[key] = ClassScheduleDetailState(
        courses: courses,
        state: ClassScheduleInquiryLoadState.loaded,
      );
    } on UnauthenticatedException {
      if (_detailGenerations[key] != generation) return;
      _details[key] = ClassScheduleDetailState(
        courses: previous.courses,
        state: ClassScheduleInquiryLoadState.error,
        error: LoadErrorType.sessionExpired,
      );
    } catch (error) {
      if (_detailGenerations[key] != generation) return;
      debugPrint('Class schedule detail load error: $error');
      _details[key] = ClassScheduleDetailState(
        courses: previous.courses,
        state: ClassScheduleInquiryLoadState.error,
        error: campusNetworkErrorType(LoadErrorType.loadFailed),
      );
    }
    notifyListeners();
  }

  void clear() {
    _indexGeneration++;
    _subjectsGeneration++;
    _classOptionsGeneration++;
    _classesGeneration++;
    _semesters = const [];
    _grades = const [];
    _departments = const [];
    _subjects = const [];
    _classOptions = const [];
    _classes = const [];
    _details.clear();
    for (final entry in _detailGenerations.entries.toList()) {
      _detailGenerations[entry.key] = entry.value + 1;
    }
    _selectedSemester = '';
    _selectedGrade = '';
    _selectedDepartment = '';
    _selectedSubject = '';
    _selectedClass = '';
    _pageNum = 1;
    _totalCount = 0;
    _indexState = ClassScheduleInquiryLoadState.idle;
    _classesState = ClassScheduleInquiryLoadState.idle;
    _subjectsState = ClassScheduleInquiryLoadState.idle;
    _classOptionsState = ClassScheduleInquiryLoadState.idle;
    _indexError = null;
    _classesError = null;
    notifyListeners();
  }
}

class _ClassScheduleKey {
  const _ClassScheduleKey(this.planCode, this.classCode);

  factory _ClassScheduleKey.fromClass(ClassInfo classInfo) =>
      _ClassScheduleKey(classInfo.planCode, classInfo.classCode);

  final String planCode;
  final String classCode;

  @override
  bool operator ==(Object other) =>
      other is _ClassScheduleKey &&
      planCode == other.planCode &&
      classCode == other.classCode;

  @override
  int get hashCode => Object.hash(planCode, classCode);
}
