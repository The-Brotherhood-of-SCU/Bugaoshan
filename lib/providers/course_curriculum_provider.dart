import 'package:flutter/foundation.dart';
import 'package:bugaoshan/pages/campus/models/course_curriculum_model.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';

enum CourseCurriculumLoadState { idle, loading, loaded, error }

class CourseScheduleDetailState {
  const CourseScheduleDetailState({
    this.courses = const [],
    this.state = CourseCurriculumLoadState.idle,
    this.error,
  });

  final List<ClassScheduleInquiryItem> courses;
  final CourseCurriculumLoadState state;
  final LoadErrorType? error;
}

class CourseCurriculumProvider extends ChangeNotifier {
  CourseCurriculumProvider(this._api);

  static const pageSize = 30;

  /// 课程课表详情按课程（教学班）缓存；超过上限时按 LRU 淘汰，
  /// 避免长时间使用会话内 Map 无界增长。
  static const _maxDetailEntries = 50;

  final ZhjwApiService _api;
  List<SemesterOption> _semesters = const [];
  List<DepartmentOption> _departments = const [];
  List<CourseCategoryOption> _categories = const [];
  List<CourseSectionInfo> _courses = const [];
  final Map<_CourseScheduleKey, CourseScheduleDetailState> _details = {};

  String _selectedSemester = '';
  String _selectedDepartment = '';
  String _selectedCategory = '';
  String _courseName = '';
  String _courseCode = '';
  String _courseSeq = '';
  int _pageNum = 1;
  int _totalCount = 0;

  CourseCurriculumLoadState _indexState = CourseCurriculumLoadState.idle;
  CourseCurriculumLoadState _coursesState = CourseCurriculumLoadState.idle;
  LoadErrorType? _indexError;
  LoadErrorType? _coursesError;
  bool _isLoadingMorePage = false;
  int _indexGeneration = 0;
  int _coursesGeneration = 0;
  final Map<_CourseScheduleKey, int> _detailGenerations = {};

  List<SemesterOption> get semesters => _semesters;
  List<DepartmentOption> get departments => _departments;
  List<CourseCategoryOption> get categories => _categories;
  List<CourseSectionInfo> get courses => _courses;
  String get selectedSemester => _selectedSemester;
  String get selectedDepartment => _selectedDepartment;
  String get selectedCategory => _selectedCategory;
  String get courseName => _courseName;
  String get courseCode => _courseCode;
  String get courseSeq => _courseSeq;
  CourseCurriculumLoadState get indexState => _indexState;
  CourseCurriculumLoadState get coursesState => _coursesState;
  LoadErrorType? get indexError => _indexError;
  LoadErrorType? get coursesError => _coursesError;
  bool get isLoadingMore =>
      _coursesState == CourseCurriculumLoadState.loading && _isLoadingMorePage;
  bool get hasMore => _courses.length < _totalCount;

  void setSelectedSemester(String value) {
    if (_selectedSemester == value) return;
    _selectedSemester = value;
    notifyListeners();
  }

  void setSelectedDepartment(String value) {
    if (_selectedDepartment == value) return;
    _selectedDepartment = value;
    notifyListeners();
  }

  void setSelectedCategory(String value) {
    if (_selectedCategory == value) return;
    _selectedCategory = value;
    notifyListeners();
  }

  void setCourseName(String value) {
    if (_courseName == value) return;
    _courseName = value;
    notifyListeners();
  }

  void setCourseCode(String value) {
    if (_courseCode == value) return;
    _courseCode = value;
    notifyListeners();
  }

  void setCourseSeq(String value) {
    if (_courseSeq == value) return;
    _courseSeq = value;
    notifyListeners();
  }

  Future<void> ensureIndex() => loadIndex();

  Future<void> loadIndex({bool forceRefresh = false}) async {
    if (_indexState == CourseCurriculumLoadState.loading) return;
    if (!forceRefresh && _indexState == CourseCurriculumLoadState.loaded) {
      return;
    }
    final generation = ++_indexGeneration;
    _indexState = CourseCurriculumLoadState.loading;
    _indexError = null;
    notifyListeners();
    try {
      final result = await _api.fetchCourseCurriculumIndex();
      if (generation != _indexGeneration) return;
      _semesters = result.semesters;
      _departments = result.departments;
      _categories = result.categories;
      // 默认选中第一个学期（教务系统页面同样预选当前学期）。
      if (_selectedSemester.isEmpty && result.semesters.isNotEmpty) {
        _selectedSemester = result.semesters.first.value;
      }
      _indexState = CourseCurriculumLoadState.loaded;
      notifyListeners();
      await search();
    } on UnauthenticatedException {
      if (generation != _indexGeneration) return;
      _indexState = CourseCurriculumLoadState.error;
      _indexError = LoadErrorType.sessionExpired;
      notifyListeners();
    } catch (error) {
      if (generation != _indexGeneration) return;
      AppLog.e('CourseCurriculumProvider', 'Index load error: $error');
      _indexState = CourseCurriculumLoadState.error;
      _indexError = campusNetworkErrorType(LoadErrorType.loadFailed);
      notifyListeners();
    }
  }

  Future<void> search() async {
    _totalCount = 0;
    _courses = const [];
    _coursesError = null;
    await _loadCourses(page: 1, replace: true);
  }

  Future<void> refresh() => search();

  Future<void> loadMore() async {
    if (_coursesState == CourseCurriculumLoadState.loading || !hasMore) return;
    // 页码用局部变量传递，成功后才提交到 _pageNum：
    // 失败时重试仍请求同一页，避免一次失败导致整页数据被跳过。
    await _loadCourses(page: _pageNum + 1, replace: false);
  }

  Future<void> _loadCourses({required int page, required bool replace}) async {
    final semester = _selectedSemester;
    final department = _selectedDepartment;
    final category = _selectedCategory;
    final courseName = _courseName;
    final courseCode = _courseCode;
    final courseSeq = _courseSeq;
    final generation = ++_coursesGeneration;
    _isLoadingMorePage = !replace;
    _coursesState = CourseCurriculumLoadState.loading;
    _coursesError = null;
    notifyListeners();
    try {
      final result = await _api.fetchCourseList(
        pageNum: page,
        pageSize: pageSize,
        semester: semester,
        department: department,
        courseName: courseName,
        courseCode: courseCode,
        courseSeq: courseSeq,
        category: category,
      );
      if (generation != _coursesGeneration ||
          semester != _selectedSemester ||
          department != _selectedDepartment ||
          category != _selectedCategory ||
          courseName != _courseName ||
          courseCode != _courseCode ||
          courseSeq != _courseSeq) {
        return;
      }
      _pageNum = page;
      _courses = replace ? result.courses : [..._courses, ...result.courses];
      _totalCount = result.totalCount;
      _coursesState = CourseCurriculumLoadState.loaded;
    } on UnauthenticatedException {
      if (!_isCurrentCourseRequest(
        generation: generation,
        semester: semester,
        department: department,
        category: category,
        courseName: courseName,
        courseCode: courseCode,
        courseSeq: courseSeq,
      )) {
        return;
      }
      _coursesState = CourseCurriculumLoadState.error;
      _coursesError = LoadErrorType.sessionExpired;
    } catch (error) {
      if (!_isCurrentCourseRequest(
        generation: generation,
        semester: semester,
        department: department,
        category: category,
        courseName: courseName,
        courseCode: courseCode,
        courseSeq: courseSeq,
      )) {
        return;
      }
      AppLog.e('CourseCurriculumProvider', 'Courses load error: $error');
      _coursesState = CourseCurriculumLoadState.error;
      _coursesError = campusNetworkErrorType(LoadErrorType.loadFailed);
    }
    notifyListeners();
  }

  bool _isCurrentCourseRequest({
    required int generation,
    required String semester,
    required String department,
    required String category,
    required String courseName,
    required String courseCode,
    required String courseSeq,
  }) =>
      generation == _coursesGeneration &&
      semester == _selectedSemester &&
      department == _selectedDepartment &&
      category == _selectedCategory &&
      courseName == _courseName &&
      courseCode == _courseCode &&
      courseSeq == _courseSeq;

  CourseScheduleDetailState detailStateFor(CourseSectionInfo courseInfo) {
    final key = _CourseScheduleKey.fromCourse(courseInfo);
    final state = _details.remove(key);
    if (state == null) return const CourseScheduleDetailState();
    // 先移除再插入，把该 key 挪到迭代序末尾（LRU 访问序），
    // 保证 _evictOldestDetailEntries 淘汰的是最近最少使用的条目。
    _details[key] = state;
    return state;
  }

  Future<void> ensureSchedule(CourseSectionInfo courseInfo) =>
      loadSchedule(courseInfo);

  Future<void> refreshSchedule(CourseSectionInfo courseInfo) =>
      loadSchedule(courseInfo, forceRefresh: true);

  Future<void> loadSchedule(
    CourseSectionInfo courseInfo, {
    bool forceRefresh = false,
  }) async {
    final key = _CourseScheduleKey.fromCourse(courseInfo);
    final previous = detailStateFor(courseInfo);
    if (previous.state == CourseCurriculumLoadState.loading) return;
    if (!forceRefresh && previous.state == CourseCurriculumLoadState.loaded) {
      return;
    }
    final generation = (_detailGenerations[key] ?? 0) + 1;
    _detailGenerations[key] = generation;
    _details[key] = CourseScheduleDetailState(
      courses: forceRefresh ? const [] : previous.courses,
      state: CourseCurriculumLoadState.loading,
    );
    notifyListeners();
    try {
      final courses = await _api.fetchCourseSchedule(
        planCode: courseInfo.planCode,
        courseCode: courseInfo.courseCode,
        courseSequenceCode: courseInfo.courseSeq,
      );
      if (_detailGenerations[key] != generation) return;
      _details[key] = CourseScheduleDetailState(
        courses: courses,
        state: CourseCurriculumLoadState.loaded,
      );
    } on UnauthenticatedException {
      if (_detailGenerations[key] != generation) return;
      _details[key] = CourseScheduleDetailState(
        courses: previous.courses,
        state: CourseCurriculumLoadState.error,
        error: LoadErrorType.sessionExpired,
      );
    } catch (error) {
      if (_detailGenerations[key] != generation) return;
      AppLog.e('CourseCurriculumProvider', 'Detail load error: $error');
      _details[key] = CourseScheduleDetailState(
        courses: previous.courses,
        state: CourseCurriculumLoadState.error,
        error: campusNetworkErrorType(LoadErrorType.loadFailed),
      );
    }
    _evictOldestDetailEntries();
    notifyListeners();
  }

  /// 按 LRU 淘汰最久未使用的课程课表详情缓存。
  /// Dart Map 按插入序迭代，detailStateFor / loadSchedule 的写入
  /// 都会把 key 挪到末尾，因此队首即最久未使用的条目。
  void _evictOldestDetailEntries() {
    if (_details.length <= _maxDetailEntries) return;
    final keys = _details.keys.toList();
    for (final key in keys) {
      if (_details.length <= _maxDetailEntries) break;
      _details.remove(key);
      // 同步丢弃对应代际号，使该 key 的飞行请求结果不再回写。
      _detailGenerations.remove(key);
    }
  }

  void clear() {
    _indexGeneration++;
    _coursesGeneration++;
    _semesters = const [];
    _departments = const [];
    _categories = const [];
    _courses = const [];
    _details.clear();
    for (final entry in _detailGenerations.entries.toList()) {
      _detailGenerations[entry.key] = entry.value + 1;
    }
    _selectedSemester = '';
    _selectedDepartment = '';
    _selectedCategory = '';
    _courseName = '';
    _courseCode = '';
    _courseSeq = '';
    _pageNum = 1;
    _totalCount = 0;
    _indexState = CourseCurriculumLoadState.idle;
    _coursesState = CourseCurriculumLoadState.idle;
    _indexError = null;
    _coursesError = null;
    _isLoadingMorePage = false;
    notifyListeners();
  }
}

class _CourseScheduleKey {
  const _CourseScheduleKey(this.planCode, this.courseCode, this.courseSeq);

  factory _CourseScheduleKey.fromCourse(CourseSectionInfo courseInfo) =>
      _CourseScheduleKey(
        courseInfo.planCode,
        courseInfo.courseCode,
        courseInfo.courseSeq,
      );

  final String planCode;
  final String courseCode;
  final String courseSeq;

  @override
  bool operator ==(Object other) =>
      other is _CourseScheduleKey &&
      planCode == other.planCode &&
      courseCode == other.courseCode &&
      courseSeq == other.courseSeq;

  @override
  int get hashCode => Object.hash(planCode, courseCode, courseSeq);
}
