import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bugaoshan/pages/campus/models/class_schedule_inquiry_model.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';

part 'class_schedule_inquiry_pods.g.dart';

enum ClassScheduleInquiryLoadState { idle, loading, loaded, error }

class ClassScheduleInquiryState {
  final List<SemesterOption> semesters;
  final List<String> grades;
  final List<DepartmentOption> departments;
  final List<SubjectOption> subjects;
  final List<ClassOption> classOptions;
  final List<ClassInfo> classes;

  final String selectedSemester;
  final String selectedGrade;
  final String selectedDepartment;
  final String selectedSubject;
  final String selectedClass;
  final int pageNum;
  final int totalCount;

  final ClassScheduleInquiryLoadState indexState;
  final ClassScheduleInquiryLoadState classesState;
  final ClassScheduleInquiryLoadState subjectsState;
  final ClassScheduleInquiryLoadState classOptionsState;
  final LoadErrorType? indexError;
  final LoadErrorType? classesError;
  final bool isLoadingMorePage;

  const ClassScheduleInquiryState({
    this.semesters = const [],
    this.grades = const [],
    this.departments = const [],
    this.subjects = const [],
    this.classOptions = const [],
    this.classes = const [],
    this.selectedSemester = '',
    this.selectedGrade = '',
    this.selectedDepartment = '',
    this.selectedSubject = '',
    this.selectedClass = '',
    this.pageNum = 1,
    this.totalCount = 0,
    this.indexState = ClassScheduleInquiryLoadState.idle,
    this.classesState = ClassScheduleInquiryLoadState.idle,
    this.subjectsState = ClassScheduleInquiryLoadState.idle,
    this.classOptionsState = ClassScheduleInquiryLoadState.idle,
    this.indexError,
    this.classesError,
    this.isLoadingMorePage = false,
  });

  bool get isLoadingMore =>
      classesState == ClassScheduleInquiryLoadState.loading &&
      isLoadingMorePage;
  bool get hasMore => classes.length < totalCount;

  ClassScheduleInquiryState copyWith({
    List<SemesterOption>? semesters,
    List<String>? grades,
    List<DepartmentOption>? departments,
    List<SubjectOption>? subjects,
    List<ClassOption>? classOptions,
    List<ClassInfo>? classes,
    String? selectedSemester,
    String? selectedGrade,
    String? selectedDepartment,
    String? selectedSubject,
    String? selectedClass,
    int? pageNum,
    int? totalCount,
    ClassScheduleInquiryLoadState? indexState,
    ClassScheduleInquiryLoadState? classesState,
    ClassScheduleInquiryLoadState? subjectsState,
    ClassScheduleInquiryLoadState? classOptionsState,
    LoadErrorType? indexError,
    bool clearIndexError = false,
    LoadErrorType? classesError,
    bool clearClassesError = false,
    bool? isLoadingMorePage,
  }) {
    return ClassScheduleInquiryState(
      semesters: semesters ?? this.semesters,
      grades: grades ?? this.grades,
      departments: departments ?? this.departments,
      subjects: subjects ?? this.subjects,
      classOptions: classOptions ?? this.classOptions,
      classes: classes ?? this.classes,
      selectedSemester: selectedSemester ?? this.selectedSemester,
      selectedGrade: selectedGrade ?? this.selectedGrade,
      selectedDepartment: selectedDepartment ?? this.selectedDepartment,
      selectedSubject: selectedSubject ?? this.selectedSubject,
      selectedClass: selectedClass ?? this.selectedClass,
      pageNum: pageNum ?? this.pageNum,
      totalCount: totalCount ?? this.totalCount,
      indexState: indexState ?? this.indexState,
      classesState: classesState ?? this.classesState,
      subjectsState: subjectsState ?? this.subjectsState,
      classOptionsState: classOptionsState ?? this.classOptionsState,
      indexError: clearIndexError ? null : (indexError ?? this.indexError),
      classesError:
          clearClassesError ? null : (classesError ?? this.classesError),
      isLoadingMorePage: isLoadingMorePage ?? this.isLoadingMorePage,
    );
  }
}

@riverpod
class ClassScheduleInquiryNotifier extends _$ClassScheduleInquiryNotifier {
  static const String _tag = 'ClassScheduleInquiryNotifier';
  static const pageSize = 30;

  int _indexGeneration = 0;
  int _subjectsGeneration = 0;
  int _classOptionsGeneration = 0;
  int _classesGeneration = 0;

  @override
  ClassScheduleInquiryState build() {
    return const ClassScheduleInquiryState();
  }

  void setSelectedSemester(String value) {
    if (state.selectedSemester == value) return;
    state = state.copyWith(selectedSemester: value);
  }

  Future<void> setSelectedGrade(String value) async {
    if (state.selectedGrade == value) return;
    state = state.copyWith(
      selectedGrade: value,
      selectedClass: '',
    );
    await loadClassOptions();
  }

  Future<void> setSelectedDepartment(String value) async {
    if (state.selectedDepartment == value) return;
    _subjectsGeneration++;
    _classOptionsGeneration++;
    state = state.copyWith(
      selectedDepartment: value,
      selectedSubject: '',
      selectedClass: '',
      subjects: const [],
      classOptions: const [],
    );
    await Future.wait([loadSubjects(), loadClassOptions()]);
  }

  Future<void> setSelectedSubject(String value) async {
    if (state.selectedSubject == value) return;
    state = state.copyWith(
      selectedSubject: value,
      selectedClass: '',
    );
    await loadClassOptions();
  }

  void setSelectedClass(String value) {
    if (state.selectedClass == value) return;
    state = state.copyWith(selectedClass: value);
  }

  Future<void> ensureIndex() => loadIndex();

  Future<void> loadIndex({bool forceRefresh = false}) async {
    if (state.indexState == ClassScheduleInquiryLoadState.loading) return;
    if (!forceRefresh &&
        state.indexState == ClassScheduleInquiryLoadState.loaded) {
      return;
    }
    final generation = ++_indexGeneration;
    state = state.copyWith(
      indexState: ClassScheduleInquiryLoadState.loading,
      clearIndexError: true,
    );
    try {
      final api = ref.read(zhjwApiServiceBridge);
      final result = await api.fetchClassScheduleInquiryIndex();
      if (generation != _indexGeneration) return;
      state = state.copyWith(
        semesters: result.semesters,
        grades: result.grades,
        departments: result.departments,
        indexState: ClassScheduleInquiryLoadState.loaded,
      );
      await search();
    } on UnauthenticatedException catch (e, logStackTrace) {
      AppLog.e(_tag, 'loadIndex 失败', error: e, stackTrace: logStackTrace);
      if (generation != _indexGeneration) return;
      state = state.copyWith(
        indexState: ClassScheduleInquiryLoadState.error,
        indexError: zhjwAuthErrorType(e),
      );
    } catch (error, logStackTrace) {
      AppLog.e(_tag, 'loadIndex 失败', error: error, stackTrace: logStackTrace);
      if (generation != _indexGeneration) return;
      state = state.copyWith(
        indexState: ClassScheduleInquiryLoadState.error,
        indexError: campusNetworkErrorType(LoadErrorType.loadFailed),
      );
    }
  }

  Future<void> loadSubjects() async {
    final department = state.selectedDepartment;
    final generation = ++_subjectsGeneration;
    if (department.isEmpty) {
      state = state.copyWith(
        subjects: const [],
        subjectsState: ClassScheduleInquiryLoadState.idle,
      );
      return;
    }
    state = state.copyWith(
      subjectsState: ClassScheduleInquiryLoadState.loading,
    );
    try {
      final api = ref.read(zhjwApiServiceBridge);
      final subjects = await api.fetchSubjectsByDepartment(department);
      if (generation != _subjectsGeneration ||
          department != state.selectedDepartment) {
        return;
      }
      state = state.copyWith(
        subjects: subjects,
        subjectsState: ClassScheduleInquiryLoadState.loaded,
      );
    } catch (error, logStackTrace) {
      AppLog.e(
        _tag,
        'loadSubjects 失败',
        error: error,
        stackTrace: logStackTrace,
      );
      if (generation != _subjectsGeneration ||
          department != state.selectedDepartment) {
        return;
      }
      state = state.copyWith(
        subjects: const [],
        subjectsState: ClassScheduleInquiryLoadState.error,
      );
    }
  }

  Future<void> loadClassOptions() async {
    final grade = state.selectedGrade;
    final department = state.selectedDepartment;
    final subject = state.selectedSubject;
    final generation = ++_classOptionsGeneration;
    if (grade.isEmpty || department.isEmpty) {
      state = state.copyWith(
        classOptions: const [],
        classOptionsState: ClassScheduleInquiryLoadState.idle,
      );
      return;
    }
    state = state.copyWith(
      classOptionsState: ClassScheduleInquiryLoadState.loading,
    );
    try {
      final api = ref.read(zhjwApiServiceBridge);
      final options = await api.fetchClassOptions(
        yearNum: grade,
        departmentNum: department,
        subjectNum: subject,
      );
      if (generation != _classOptionsGeneration ||
          grade != state.selectedGrade ||
          department != state.selectedDepartment ||
          subject != state.selectedSubject) {
        return;
      }
      state = state.copyWith(
        classOptions: options,
        classOptionsState: ClassScheduleInquiryLoadState.loaded,
      );
    } catch (error, logStackTrace) {
      AppLog.e(
        _tag,
        'loadClassOptions 失败',
        error: error,
        stackTrace: logStackTrace,
      );
      if (generation != _classOptionsGeneration ||
          grade != state.selectedGrade ||
          department != state.selectedDepartment ||
          subject != state.selectedSubject) {
        return;
      }
      state = state.copyWith(
        classOptions: const [],
        classOptionsState: ClassScheduleInquiryLoadState.error,
      );
    }
  }

  Future<void> search() async {
    state = state.copyWith(
      totalCount: 0,
      classes: const [],
      clearClassesError: true,
    );
    await _loadClasses(page: 1, replace: true);
  }

  Future<void> refresh() => search();

  Future<void> loadMore() async {
    if (state.classesState == ClassScheduleInquiryLoadState.loading ||
        !state.hasMore) {
      return;
    }
    await _loadClasses(page: state.pageNum + 1, replace: false);
  }

  Future<void> _loadClasses({required int page, required bool replace}) async {
    final semester = state.selectedSemester;
    final grade = state.selectedGrade;
    final department = state.selectedDepartment;
    final subject = state.selectedSubject;
    final classCode = state.selectedClass;
    final generation = ++_classesGeneration;
    state = state.copyWith(
      isLoadingMorePage: !replace,
      classesState: ClassScheduleInquiryLoadState.loading,
      clearClassesError: true,
    );
    try {
      final api = ref.read(zhjwApiServiceBridge);
      final result = await api.fetchClassList(
        pageNum: page,
        pageSize: pageSize,
        executiveEducationPlanNum: semester,
        yearNum: grade,
        departmentNum: department,
        subjectNum: subject,
        classNum: classCode,
      );
      if (generation != _classesGeneration ||
          semester != state.selectedSemester ||
          grade != state.selectedGrade ||
          department != state.selectedDepartment ||
          subject != state.selectedSubject ||
          classCode != state.selectedClass) {
        return;
      }
      state = state.copyWith(
        pageNum: page,
        classes:
            replace ? result.classes : [...state.classes, ...result.classes],
        totalCount: result.totalCount,
        classesState: ClassScheduleInquiryLoadState.loaded,
      );
    } on UnauthenticatedException catch (e, logStackTrace) {
      AppLog.e(_tag, '_loadClasses 失败', error: e, stackTrace: logStackTrace);
      if (!_isCurrentClassRequest(
        generation: generation,
        semester: semester,
        grade: grade,
        department: department,
        subject: subject,
        classCode: classCode,
      )) {
        return;
      }
      state = state.copyWith(
        classesState: ClassScheduleInquiryLoadState.error,
        classesError: zhjwAuthErrorType(e),
      );
    } catch (error, logStackTrace) {
      AppLog.e(
        _tag,
        '_loadClasses 失败',
        error: error,
        stackTrace: logStackTrace,
      );
      if (!_isCurrentClassRequest(
        generation: generation,
        semester: semester,
        grade: grade,
        department: department,
        subject: subject,
        classCode: classCode,
      )) {
        return;
      }

      state = state.copyWith(
        classesState: ClassScheduleInquiryLoadState.error,
        classesError: campusNetworkErrorType(LoadErrorType.loadFailed),
      );
    }
  }

  bool _isCurrentClassRequest({
    required int generation,
    required String semester,
    required String grade,
    required String department,
    required String subject,
    required String classCode,
  }) =>
      generation == _classesGeneration &&
      semester == state.selectedSemester &&
      grade == state.selectedGrade &&
      department == state.selectedDepartment &&
      subject == state.selectedSubject &&
      classCode == state.selectedClass;

  void clear() {
    _indexGeneration++;
    _subjectsGeneration++;
    _classOptionsGeneration++;
    _classesGeneration++;
    state = const ClassScheduleInquiryState();
  }
}

@riverpod
class ClassScheduleInquiryScheduleNotifier
    extends _$ClassScheduleInquiryScheduleNotifier {
  @override
  Future<List<ClassScheduleInquiryItem>> build({
    required String planCode,
    required String classCode,
  }) async {
    final api = ref.watch(zhjwApiServiceBridge);
    return api.fetchClassSchedule(
      planCode: planCode,
      classCode: classCode,
    );
  }

  Future<void> refresh({
    required String planCode,
    required String classCode,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(zhjwApiServiceBridge);
      return api.fetchClassSchedule(
        planCode: planCode,
        classCode: classCode,
      );
    });
  }
}
