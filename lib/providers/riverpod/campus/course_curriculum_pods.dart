import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bugaoshan/pages/campus/models/course_curriculum_model.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';

part 'course_curriculum_pods.g.dart';

enum CourseCurriculumLoadState { idle, loading, loaded, error }

class CourseCurriculumState {
  final List<SemesterOption> semesters;
  final List<DepartmentOption> departments;
  final List<CourseCategoryOption> categories;
  final List<CourseSectionInfo> courses;
  final String selectedSemester;
  final String selectedDepartment;
  final String selectedCategory;
  final String courseName;
  final String courseCode;
  final String courseSeq;
  final int pageNum;
  final int totalCount;
  final CourseCurriculumLoadState indexState;
  final CourseCurriculumLoadState coursesState;
  final LoadErrorType? indexError;
  final LoadErrorType? coursesError;
  final bool isLoadingMorePage;

  const CourseCurriculumState({
    this.semesters = const [],
    this.departments = const [],
    this.categories = const [],
    this.courses = const [],
    this.selectedSemester = '',
    this.selectedDepartment = '',
    this.selectedCategory = '',
    this.courseName = '',
    this.courseCode = '',
    this.courseSeq = '',
    this.pageNum = 1,
    this.totalCount = 0,
    this.indexState = CourseCurriculumLoadState.idle,
    this.coursesState = CourseCurriculumLoadState.idle,
    this.indexError,
    this.coursesError,
    this.isLoadingMorePage = false,
  });

  bool get isLoadingMore =>
      coursesState == CourseCurriculumLoadState.loading && isLoadingMorePage;
  bool get hasMore => courses.length < totalCount;

  CourseCurriculumState copyWith({
    List<SemesterOption>? semesters,
    List<DepartmentOption>? departments,
    List<CourseCategoryOption>? categories,
    List<CourseSectionInfo>? courses,
    String? selectedSemester,
    String? selectedDepartment,
    String? selectedCategory,
    String? courseName,
    String? courseCode,
    String? courseSeq,
    int? pageNum,
    int? totalCount,
    CourseCurriculumLoadState? indexState,
    CourseCurriculumLoadState? coursesState,
    LoadErrorType? indexError,
    bool clearIndexError = false,
    LoadErrorType? coursesError,
    bool clearCoursesError = false,
    bool? isLoadingMorePage,
  }) {
    return CourseCurriculumState(
      semesters: semesters ?? this.semesters,
      departments: departments ?? this.departments,
      categories: categories ?? this.categories,
      courses: courses ?? this.courses,
      selectedSemester: selectedSemester ?? this.selectedSemester,
      selectedDepartment: selectedDepartment ?? this.selectedDepartment,
      selectedCategory: selectedCategory ?? this.selectedCategory,
      courseName: courseName ?? this.courseName,
      courseCode: courseCode ?? this.courseCode,
      courseSeq: courseSeq ?? this.courseSeq,
      pageNum: pageNum ?? this.pageNum,
      totalCount: totalCount ?? this.totalCount,
      indexState: indexState ?? this.indexState,
      coursesState: coursesState ?? this.coursesState,
      indexError: clearIndexError ? null : (indexError ?? this.indexError),
      coursesError:
          clearCoursesError ? null : (coursesError ?? this.coursesError),
      isLoadingMorePage: isLoadingMorePage ?? this.isLoadingMorePage,
    );
  }
}

@riverpod
class CourseCurriculumNotifier extends _$CourseCurriculumNotifier {
  static const String _tag = 'CourseCurriculumNotifier';
  static const pageSize = 30;

  int _indexGeneration = 0;
  int _coursesGeneration = 0;

  @override
  CourseCurriculumState build() {
    return const CourseCurriculumState();
  }

  void setSelectedSemester(String value) {
    if (state.selectedSemester == value) return;
    state = state.copyWith(selectedSemester: value);
  }

  void setSelectedDepartment(String value) {
    if (state.selectedDepartment == value) return;
    state = state.copyWith(selectedDepartment: value);
  }

  void setSelectedCategory(String value) {
    if (state.selectedCategory == value) return;
    state = state.copyWith(selectedCategory: value);
  }

  void setCourseName(String value) {
    if (state.courseName == value) return;
    state = state.copyWith(courseName: value);
  }

  void setCourseCode(String value) {
    if (state.courseCode == value) return;
    state = state.copyWith(courseCode: value);
  }

  void setCourseSeq(String value) {
    if (state.courseSeq == value) return;
    state = state.copyWith(courseSeq: value);
  }

  Future<void> ensureIndex() => loadIndex();

  Future<void> loadIndex({bool forceRefresh = false}) async {
    if (state.indexState == CourseCurriculumLoadState.loading) return;
    if (!forceRefresh && state.indexState == CourseCurriculumLoadState.loaded) {
      return;
    }
    final generation = ++_indexGeneration;
    state = state.copyWith(
      indexState: CourseCurriculumLoadState.loading,
      clearIndexError: true,
    );
    try {
      final api = ref.read(zhjwApiServiceBridge);
      final result = await api.fetchCourseCurriculumIndex();
      if (generation != _indexGeneration) return;
      var selectedSemester = state.selectedSemester;
      // 默认选中第一个学期（教务系统页面同样预选当前学期）。
      if (selectedSemester.isEmpty && result.semesters.isNotEmpty) {
        selectedSemester = result.semesters.first.value;
      }
      state = state.copyWith(
        semesters: result.semesters,
        departments: result.departments,
        categories: result.categories,
        selectedSemester: selectedSemester,
        indexState: CourseCurriculumLoadState.loaded,
      );
      await search();
    } on UnauthenticatedException catch (e, logStackTrace) {
      AppLog.e(_tag, 'loadIndex 失败', error: e, stackTrace: logStackTrace);
      if (generation != _indexGeneration) return;
      state = state.copyWith(
        indexState: CourseCurriculumLoadState.error,
        indexError: zhjwAuthErrorType(e),
      );
    } catch (error, logStackTrace) {
      AppLog.e(_tag, 'loadIndex 失败', error: error, stackTrace: logStackTrace);
      if (generation != _indexGeneration) return;
      state = state.copyWith(
        indexState: CourseCurriculumLoadState.error,
        indexError: campusNetworkErrorType(LoadErrorType.loadFailed),
      );
    }
  }

  Future<void> search() async {
    state = state.copyWith(
      totalCount: 0,
      courses: const [],
      clearCoursesError: true,
    );
    await _loadCourses(page: 1, replace: true);
  }

  Future<void> refresh() => search();

  Future<void> loadMore() async {
    if (state.coursesState == CourseCurriculumLoadState.loading ||
        !state.hasMore) {
      return;
    }
    // 页码用局部变量传递，成功后才提交到 pageNum：
    // 失败时重试仍请求同一页，避免一次失败导致整页数据被跳过。
    await _loadCourses(page: state.pageNum + 1, replace: false);
  }

  Future<void> _loadCourses({required int page, required bool replace}) async {
    final semester = state.selectedSemester;
    final department = state.selectedDepartment;
    final category = state.selectedCategory;
    final courseName = state.courseName;
    final courseCode = state.courseCode;
    final courseSeq = state.courseSeq;
    final generation = ++_coursesGeneration;
    state = state.copyWith(
      isLoadingMorePage: !replace,
      coursesState: CourseCurriculumLoadState.loading,
      clearCoursesError: true,
    );
    try {
      final api = ref.read(zhjwApiServiceBridge);
      final result = await api.fetchCourseList(
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
          semester != state.selectedSemester ||
          department != state.selectedDepartment ||
          category != state.selectedCategory ||
          courseName != state.courseName ||
          courseCode != state.courseCode ||
          courseSeq != state.courseSeq) {
        return;
      }
      state = state.copyWith(
        pageNum: page,
        courses:
            replace ? result.courses : [...state.courses, ...result.courses],
        totalCount: result.totalCount,
        coursesState: CourseCurriculumLoadState.loaded,
      );
    } on UnauthenticatedException catch (e, logStackTrace) {
      AppLog.e(_tag, '_loadCourses 失败', error: e, stackTrace: logStackTrace);
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
      state = state.copyWith(
        coursesState: CourseCurriculumLoadState.error,
        coursesError: zhjwAuthErrorType(e),
      );
    } catch (error, logStackTrace) {
      AppLog.e(
        _tag,
        '_loadCourses 失败',
        error: error,
        stackTrace: logStackTrace,
      );
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

      state = state.copyWith(
        coursesState: CourseCurriculumLoadState.error,
        coursesError: campusNetworkErrorType(LoadErrorType.loadFailed),
      );
    }
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
      semester == state.selectedSemester &&
      department == state.selectedDepartment &&
      category == state.selectedCategory &&
      courseName == state.courseName &&
      courseCode == state.courseCode &&
      courseSeq == state.courseSeq;

  void clear() {
    _indexGeneration++;
    _coursesGeneration++;
    state = const CourseCurriculumState();
  }
}

@riverpod
class CourseCurriculumScheduleNotifier
    extends _$CourseCurriculumScheduleNotifier {
  @override
  Future<List<ClassScheduleInquiryItem>> build({
    required String planCode,
    required String courseCode,
    required String courseSeq,
  }) async {
    final api = ref.watch(zhjwApiServiceBridge);
    return api.fetchCourseSchedule(
      planCode: planCode,
      courseCode: courseCode,
      courseSequenceCode: courseSeq,
    );
  }

  Future<void> refresh({
    required String planCode,
    required String courseCode,
    required String courseSeq,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(zhjwApiServiceBridge);
      return api.fetchCourseSchedule(
        planCode: planCode,
        courseCode: courseCode,
        courseSequenceCode: courseSeq,
      );
    });
  }
}
