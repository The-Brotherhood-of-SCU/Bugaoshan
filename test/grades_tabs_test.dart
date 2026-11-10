import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/campus/grades/custom_stats_tab.dart';
import 'package:bugaoshan/pages/campus/grades/grades_page.dart';
import 'package:bugaoshan/pages/campus/grades/scheme_scores_tab.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/providers/grades_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:bugaoshan/services/course_teacher_index.dart';
import 'package:bugaoshan/services/database_service.dart';
import 'package:bugaoshan/widgets/common/auth_scoped_indexed_stack.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('scheme scores default to main plan and allow plan switching', (
    tester,
  ) async {
    final provider = await _createProvider(
      schemeData: _schemeData(),
      passingData: _passingData(),
    );
    await provider.refreshSchemeScores();
    getIt.registerSingleton(provider);

    await tester.pumpWidget(_testApp(const SchemeScoresTab()));

    expect(find.text('主专业课程'), findsOneWidget);
    expect(find.text('微专业课程'), findsNothing);
    expect(find.byType(SchemeScoreSelector), findsOneWidget);

    await tester.tap(find.byType(SchemeScoreSelector));
    await tester.pumpAndSettle();
    await tester.tap(find.text('电气电子创新设计（微专业）教学计划').last);
    await tester.pumpAndSettle();

    expect(find.text('微专业课程'), findsOneWidget);
    expect(find.text('主专业课程'), findsNothing);
  });

  testWidgets('custom statistics follow the selected scheme', (tester) async {
    final provider = await _createProvider(
      schemeData: _schemeData(),
      passingData: _passingData(),
    );
    await provider.refreshSchemeScores();
    getIt.registerSingleton(provider);

    await tester.pumpWidget(_testApp(const CustomStatsTab()));

    expect(find.text('主专业课程'), findsOneWidget);
    expect(find.text('微专业课程'), findsNothing);
    expect(find.byType(SchemeScoreSelector), findsOneWidget);

    await tester.tap(find.text('主专业课程'));
    await tester.pump();
    expect(find.text('已选 1 门'), findsOneWidget);

    await tester.tap(find.byType(SchemeScoreSelector));
    await tester.pumpAndSettle();
    await tester.tap(find.text('电气电子创新设计（微专业）教学计划').last);
    await tester.pumpAndSettle();

    expect(find.text('微专业课程'), findsOneWidget);
    expect(find.text('主专业课程'), findsNothing);
    expect(find.text('已选 0 门'), findsOneWidget);
  });

  testWidgets('GradesPage 下方案成绩与及格成绩共享页面级教师索引展示教师，卸载时正常释放', (tester) async {
    final authProvider = _FakeScuAuthProvider();
    getIt.registerSingleton<ScuAuthProvider>(authProvider);

    final provider = await _createProvider(
      schemeData: _schemeData(),
      passingData: _passingData(),
    );
    await provider.refreshSchemeScores();
    await provider.refreshPassingScores();
    getIt.registerSingleton<GradesProvider>(provider);

    final teacherIndex = CourseTeacherIndex.fromSchedules([
      (
        config: ScheduleConfig(
          id: 's1',
          semesterStartDate: DateTime(2025, 9, 1),
          academicYearCode: '2025-2026',
          termName: '秋',
          semesterName: '2025-2026学年秋',
        ),
        courses: [
          Course(
            name: '主专业课程',
            teacher: '共享教师张三',
            location: '',
            startWeek: 1,
            endWeek: 16,
            dayOfWeek: 1,
            startSection: 1,
            endSection: 2,
            colorValue: 0,
          ),
        ],
      ),
    ]);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: GradesPage(initialTeacherIndex: teacherIndex),
      ),
    );
    await tester.pumpAndSettle();

    // 1. 第一个 Tab（方案成绩）：显示「共享教师张三」
    expect(find.text('授课教师：共享教师张三'), findsOneWidget);

    // 2. 切换到第二个 Tab（及格成绩）
    await tester.tap(find.text('及格成绩'));
    await tester.pumpAndSettle();

    // 及格成绩 Tab 也使用同一个教师索引展示「共享教师张三」
    expect(find.text('授课教师：共享教师张三'), findsOneWidget);

    // 3. 卸载页面（pump 空容器）
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();

    // 卸载无异常抛出
    expect(tester.takeException(), isNull);
  });

  testWidgets('GradesPage 不因 GradesProvider 数据变更重新加载教师索引', (tester) async {
    final authProvider = _FakeScuAuthProvider();
    getIt.registerSingleton<ScuAuthProvider>(authProvider);

    final controllableDb = _ControllableDatabaseService([
      (
        config: ScheduleConfig(
          id: 's1',
          semesterStartDate: DateTime(2025, 9, 1),
          academicYearCode: '2025-2026',
          termName: '秋',
          semesterName: '2025-2026学年秋',
        ),
        courses: [
          Course(
            name: '主专业课程',
            teacher: '初始任课教师',
            location: '',
            startWeek: 1,
            endWeek: 16,
            dayOfWeek: 1,
            startSection: 1,
            endSection: 2,
            colorValue: 0,
          ),
        ],
      ),
    ]);
    getIt.registerSingleton<DatabaseService>(controllableDb);

    final provider = await _createProvider(
      schemeData: _schemeData(),
      passingData: _passingData(),
    );
    await provider.refreshSchemeScores();
    await provider.refreshPassingScores();
    getIt.registerSingleton<GradesProvider>(provider);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('zh'),
        home: GradesPage(),
      ),
    );
    await tester.pumpAndSettle();

    // 初始渲染：显示「初始任课教师」
    expect(find.text('授课教师：初始任课教师'), findsOneWidget);
    final initialDbCallCount = controllableDb.getCoursesCallCount;

    // 1. 模拟非数据实例变更的 notify（如切换方案类型）：不触发教师索引重新加载
    provider.selectScheme(provider.schemes.last);
    await tester.pumpAndSettle();
    expect(controllableDb.getCoursesCallCount, initialDbCallCount);

    // 2. 数据库更新，同时 GradesProvider 刷新数据；教师索引只依赖课表库，
    // 不因成绩数据实例变化而重查。
    controllableDb.schedules = [
      (
        config: ScheduleConfig(
          id: 's1',
          semesterStartDate: DateTime(2025, 9, 1),
          academicYearCode: '2025-2026',
          termName: '秋',
          semesterName: '2025-2026学年秋',
        ),
        courses: [
          Course(
            name: '主专业课程',
            teacher: '更新后的新任课教师',
            location: '',
            startWeek: 1,
            endWeek: 16,
            dayOfWeek: 1,
            startSection: 1,
            endSection: 2,
            colorValue: 0,
          ),
        ],
      ),
    ];

    await provider.refreshSchemeScores();
    await tester.pumpAndSettle();

    expect(find.text('授课教师：初始任课教师'), findsOneWidget);
    expect(find.text('授课教师：更新后的新任课教师'), findsNothing);
    expect(controllableDb.getCoursesCallCount, initialDbCallCount);

    // 3. 卸载页面（pump 空容器）
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('GradesPage 初次数据库加载失败后通过下拉刷新重试恢复教师展示', (tester) async {
    final authProvider = _FakeScuAuthProvider();
    getIt.registerSingleton<ScuAuthProvider>(authProvider);

    final controllableDb = _ControllableDatabaseService([
      (
        config: ScheduleConfig(
          id: 's1',
          semesterStartDate: DateTime(2025, 9, 1),
          academicYearCode: '2025-2026',
          termName: '秋',
          semesterName: '2025-2026学年秋',
        ),
        courses: [
          Course(
            name: '主专业课程',
            teacher: '恢复后的任课教师',
            location: '',
            startWeek: 1,
            endWeek: 16,
            dayOfWeek: 1,
            startSection: 1,
            endSection: 2,
            colorValue: 0,
          ),
        ],
      ),
    ]);
    // 初始 DB 加载抛出异常
    controllableDb.shouldThrowOnGetSchedules = true;
    getIt.registerSingleton<DatabaseService>(controllableDb);

    final provider = await _createProvider(
      schemeData: _schemeData(),
      passingData: _passingData(),
    );
    await provider.refreshSchemeScores();
    await provider.refreshPassingScores();
    getIt.registerSingleton<GradesProvider>(provider);

    await tester.pumpWidget(
      const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: Locale('zh'),
        home: GradesPage(),
      ),
    );
    await tester.pumpAndSettle();

    // 初始 DB 失败：页面正常展示成绩，但不展示教师
    expect(find.text('主专业课程'), findsOneWidget);
    expect(find.textContaining('授课教师'), findsNothing);

    // 数据库恢复
    controllableDb.shouldThrowOnGetSchedules = false;

    // 触发下拉刷新（按要求使用 fling 保证跨平台一致）
    await tester.fling(
      find.byType(CustomScrollView).first,
      const Offset(0, 300),
      1000,
    );
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    // 刷新后教师信息成功恢复展示
    expect(find.text('授课教师：恢复后的任课教师'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('AuthScopedIndexedStack 缓存 GradesPage 且课表变更时自动同步更新教师展示', (
    tester,
  ) async {
    final authProvider = _FakeScuAuthProvider();
    getIt.registerSingleton<ScuAuthProvider>(authProvider);

    final controllableDb = _ControllableDatabaseService([
      (
        config: ScheduleConfig(
          id: 's1',
          semesterStartDate: DateTime(2025, 9, 1),
          academicYearCode: '2025-2026',
          termName: '秋',
          semesterName: '2025-2026学年秋',
        ),
        courses: [
          Course(
            name: '主专业课程',
            teacher: '初始课表教师',
            location: '',
            startWeek: 1,
            endWeek: 16,
            dayOfWeek: 1,
            startSection: 1,
            endSection: 2,
            colorValue: 0,
          ),
        ],
      ),
    ]);
    getIt.registerSingleton<DatabaseService>(controllableDb);

    final courseProvider = CourseProvider(controllableDb);
    getIt.registerSingleton<CourseProvider>(courseProvider);

    final gradesProvider = await _createProvider(
      schemeData: _schemeData(),
      passingData: _passingData(),
    );
    await gradesProvider.refreshSchemeScores();
    await gradesProvider.refreshPassingScores();
    getIt.registerSingleton<GradesProvider>(gradesProvider);

    final selectedIndex = ValueNotifier<int>(1); // 初始选中 grades (index 1)

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('zh'),
        home: ValueListenableBuilder<int>(
          valueListenable: selectedIndex,
          builder: (context, index, _) {
            return AuthScopedIndexedStack(
              authListenable: authProvider,
              isAuthenticated: () => authProvider.isLoggedIn,
              visibleIds: const ['course', 'grades'],
              selectedIndex: index,
              pageBuilder: (id) => id == 'course'
                  ? const Scaffold(body: Center(child: Text('课表占位页')))
                  : const GradesPage(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 初始停留在成绩页，展示初始教师
    expect(find.text('授课教师：初始课表教师'), findsOneWidget);

    // 1. 切换到课表页（GradesPage 被缓存并未销毁）
    selectedIndex.value = 0;
    await tester.pumpAndSettle();
    expect(find.text('课表占位页'), findsOneWidget);

    // 2. 通过 CourseProvider 修改课程任课教师
    await courseProvider.updateCourse(
      Course(
        name: '主专业课程',
        teacher: '课表修改后的新教师',
        location: '',
        startWeek: 1,
        endWeek: 16,
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        colorValue: 0,
      ),
    );
    await tester.pumpAndSettle();

    // 3. 切回成绩页（GradesPage 状态保持，且任课教师已由 courseDataVersion 触发自动同步）
    selectedIndex.value = 1;
    await tester.pumpAndSettle();
    expect(find.text('授课教师：课表修改后的新教师'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

class _ControllableDatabaseService implements DatabaseService {
  _ControllableDatabaseService(this.schedules);

  List<({ScheduleConfig config, List<Course> courses})> schedules;
  int getCoursesCallCount = 0;
  bool shouldThrowOnGetSchedules = false;
  String currentScheduleId = 's1';

  @override
  List<ScheduleConfig> getAllSchedules() {
    if (shouldThrowOnGetSchedules) {
      throw StateError('DB simulated failure');
    }
    return schedules.map((e) => e.config).toList();
  }

  @override
  Future<List<Course>> getCoursesAsync({String? scheduleId}) async {
    getCoursesCallCount++;
    final match = schedules.firstWhere((e) => e.config.id == scheduleId);
    return match.courses;
  }

  @override
  List<Course> getCourses({String? scheduleId}) {
    final targetId = scheduleId ?? currentScheduleId;
    final match = schedules.firstWhere(
      (e) => e.config.id == targetId,
      orElse: () => schedules.first,
    );
    return match.courses;
  }

  @override
  ScheduleConfig? getScheduleConfig() =>
      schedules.isNotEmpty ? schedules.first.config : null;

  @override
  String getCurrentScheduleId() => currentScheduleId;

  @override
  Future<void> updateCourse(Course course) async {
    for (var i = 0; i < schedules.length; i++) {
      final s = schedules[i];
      final idx = s.courses.indexWhere((c) => c.name == course.name);
      if (idx != -1) {
        final newCourses = List<Course>.from(s.courses);
        newCourses[idx] = course;
        schedules[i] = (config: s.config, courses: newCourses);
      }
    }
  }

  @override
  Future<void> replaceScheduleCourses(
    String scheduleId,
    List<Course> newCourses,
  ) async {
    final idx = schedules.indexWhere((e) => e.config.id == scheduleId);
    if (idx != -1) {
      schedules[idx] = (config: schedules[idx].config, courses: newCourses);
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _testApp(Widget home) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('zh'),
  home: Scaffold(body: home),
);

Future<GradesProvider> _createProvider({
  required Map<String, dynamic> schemeData,
  required Map<String, dynamic> passingData,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return GradesProvider(
    prefs,
    _FakeZhjwApiService(schemeData, passingData),
    initialUserId: 'account-A',
  );
}

Map<String, dynamic> _schemeData() => {
  'lnList': [
    {
      'cjlx': '电气电子创新设计（微专业）教学计划',
      'cjList': [_courseData('微专业课程')],
    },
    {
      'cjlx': '计算机科学与技术教学计划',
      'cjList': [_courseData('主专业课程')],
    },
  ],
};

Map<String, dynamic> _passingData() => {
  'lnList': [
    {
      'cjlx': '2025-2026学年秋(两学期)',
      'cjList': [_courseData('微专业课程'), _courseData('主专业课程')],
    },
  ],
};

Map<String, dynamic> _courseData(String name) => {
  'courseName': name,
  'courseAttributeName': '必修',
  'credit': '2',
  'cj': '90',
  'courseScore': 90,
  'gradePointScore': 4,
  'gradeName': 'A',
  'academicYearCode': '2025-2026',
  'termName': '秋',
};

class _FakeZhjwApiService implements ZhjwApiService {
  const _FakeZhjwApiService(this.schemeData, this.passingData);

  final Map<String, dynamic> schemeData;
  final Map<String, dynamic> passingData;

  @override
  Future<Map<String, dynamic>> fetchSchemeScores() async => schemeData;

  @override
  Future<Map<String, dynamic>> fetchPassingScores() async => passingData;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeScuAuthProvider extends ChangeNotifier implements ScuAuthProvider {
  @override
  bool get isLoggedIn => true;

  @override
  bool get isAutoLoggingIn => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
