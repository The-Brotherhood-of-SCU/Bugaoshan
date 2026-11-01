import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/campus/grades/custom_stats_tab.dart';
import 'package:bugaoshan/pages/campus/grades/grades_page.dart';
import 'package:bugaoshan/pages/campus/grades/scheme_scores_tab.dart';
import 'package:bugaoshan/providers/grades_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:bugaoshan/services/course_teacher_index.dart';
import 'package:bugaoshan/services/database_service.dart';
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

  testWidgets(
    'GradesPage 监听 GradesProvider：接口数据变更时触发重新加载并展示新教师，未变更数据的 notify 不重新加载',
    (tester) async {
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

      // 2. 数据库更新，同时 GradesProvider 刷新数据（生成新的 schemes 列表实例）
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

      // 教师信息已重新加载并展示新教师
      expect(find.text('授课教师：更新后的新任课教师'), findsOneWidget);
      expect(
        controllableDb.getCoursesCallCount,
        greaterThan(initialDbCallCount),
      );

      // 3. 卸载页面（pump 空容器）
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}

class _ControllableDatabaseService implements DatabaseService {
  _ControllableDatabaseService(this.schedules);

  List<({ScheduleConfig config, List<Course> courses})> schedules;
  int getCoursesCallCount = 0;

  @override
  List<ScheduleConfig> getAllSchedules() =>
      schedules.map((e) => e.config).toList();

  @override
  Future<List<Course>> getCoursesAsync({String? scheduleId}) async {
    getCoursesCallCount++;
    final match = schedules.firstWhere((e) => e.config.id == scheduleId);
    return match.courses;
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
