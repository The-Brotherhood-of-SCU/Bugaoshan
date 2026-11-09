import 'dart:async';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/campus/plan_completion/models/plan_completion.dart';
import 'package:bugaoshan/pages/campus/plan_completion/plan_completion_page.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/providers/plan_completion_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:bugaoshan/services/course_teacher_index.dart';
import 'package:bugaoshan/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    await getIt.reset();
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('多方案：顶部显示方案名与计数，滑动切换方案内容', (tester) async {
    await _pumpPlanPage(
      tester,
      plans: [
        PlanCompletionPlan(
          id: '10101',
          name: '主修培养方案',
          nodes: [PlanCompletionNode.fromJson(_rootNodeJson('主修公共课'))],
        ),
        PlanCompletionPlan(
          id: '10102',
          name: '辅修培养方案',
          nodes: [PlanCompletionNode.fromJson(_rootNodeJson('辅修公共课'))],
        ),
      ],
    );

    // 顶部指示栏显示当前方案名与页码
    expect(find.text('主修培养方案'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    // 第一页内容
    expect(find.text('主修公共课'), findsOneWidget);

    // 左滑切换到第二个方案
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('辅修培养方案'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('辅修公共课'), findsOneWidget);
  });

  testWidgets('单方案：显示方案名但不显示计数', (tester) async {
    await _pumpPlanPage(
      tester,
      plans: [
        PlanCompletionPlan(
          id: '',
          name: '唯一培养方案',
          nodes: [PlanCompletionNode.fromJson(_rootNodeJson('唯一公共课'))],
        ),
      ],
    );

    expect(find.text('唯一培养方案'), findsOneWidget);
    // 单方案不显示 1/1 计数
    expect(find.text('1/1'), findsNothing);
    expect(find.text('唯一公共课'), findsOneWidget);
  });

  group('培养方案完成度页面教师信息展示测试', () {
    testWidgets('1. 正确显示同学期课程教师', (tester) async {
      final index = CourseTeacherIndex.fromSchedules([
        (
          config: ScheduleConfig(
            semesterStartDate: DateTime(2023, 9, 1),
            semesterName: '2023-2024学年秋',
          ),
          courses: [_mockCourse('新生研讨课 (01)', '张老师')],
        ),
      ]);

      final node = PlanCompletionNode.fromJson(
        _courseNodeJson(
          id: 'c1',
          code: '304112010',
          name: '新生研讨课',
          credits: '1',
          term: '2023-2024学年秋',
          gradeInfo: '(必修,96.0(20240107))',
        ),
      );

      await _pumpPlanPage(tester, nodes: [node], teacherIndex: index);

      expect(find.text('新生研讨课'), findsOneWidget);
      expect(find.text('授课教师：张老师'), findsOneWidget);
    });

    testWidgets('2. 相同课程名、不同学期显示不同教师', (tester) async {
      final index = CourseTeacherIndex.fromSchedules([
        (
          config: ScheduleConfig(
            semesterStartDate: DateTime(2023, 9, 1),
            semesterName: '2023-2024学年秋',
          ),
          courses: [_mockCourse('高等数学 (01)', '张老师')],
        ),
        (
          config: ScheduleConfig(
            semesterStartDate: DateTime(2024, 9, 1),
            semesterName: '2024-2025学年秋',
          ),
          courses: [_mockCourse('高等数学 (02)', '李老师')],
        ),
      ]);

      final node1 = PlanCompletionNode.fromJson(
        _courseNodeJson(
          id: 'c1',
          code: '304475020',
          name: '高等数学',
          credits: '4',
          term: '2023-2024学年秋',
          gradeInfo: '(必修,90.0(20240107))',
        ),
      );
      final node2 = PlanCompletionNode.fromJson(
        _courseNodeJson(
          id: 'c2',
          code: '304475020',
          name: '高等数学',
          credits: '4',
          term: '2024-2025学年秋',
          gradeInfo: '(必修,88.0(20250107))',
        ),
      );

      await _pumpPlanPage(tester, nodes: [node1, node2], teacherIndex: index);

      expect(find.text('授课教师：张老师'), findsOneWidget);
      expect(find.text('授课教师：李老师'), findsOneWidget);
    });

    testWidgets('3. 无匹配教师时不显示教师行', (tester) async {
      final index = CourseTeacherIndex.fromSchedules([]);

      final node = PlanCompletionNode.fromJson(
        _courseNodeJson(
          id: 'c1',
          code: '101010010',
          name: '未导入课程',
          credits: '2',
          term: '2023-2024学年秋',
          gradeInfo: '(必修,85.0(20240107))',
        ),
      );

      await _pumpPlanPage(tester, nodes: [node], teacherIndex: index);

      expect(find.text('未导入课程'), findsOneWidget);
      expect(find.textContaining('授课教师'), findsNothing);
      expect(find.textContaining('未知教师'), findsNothing);
    });

    testWidgets('4. gradeInfo 为空时不显示教师（即使课表存在同名课程）', (tester) async {
      final index = CourseTeacherIndex.fromSchedules([
        (
          config: ScheduleConfig(
            semesterStartDate: DateTime(2026, 3, 1),
            semesterName: '2025-2026学年春',
          ),
          courses: [_mockCourse('形势与政策-6 (01)', '王老师')],
        ),
      ]);

      // gradeInfo 为空，表示未修读/计划中
      final node = PlanCompletionNode.fromJson(
        _courseNodeJson(
          id: 'c1',
          code: '107120000',
          name: '形势与政策-6',
          credits: '0',
          term: '2025-2026学年春',
          gradeInfo: '',
          passed: false,
        ),
      );

      await _pumpPlanPage(tester, nodes: [node], teacherIndex: index);

      expect(find.text('形势与政策-6'), findsOneWidget);
      expect(find.textContaining('授课教师'), findsNothing);
    });

    testWidgets('5. 多教师正常显示', (tester) async {
      final index = CourseTeacherIndex.fromSchedules([
        (
          config: ScheduleConfig(
            semesterStartDate: DateTime(2023, 9, 1),
            semesterName: '2023-2024学年秋',
          ),
          courses: [_mockCourse('软件工程 (01)', '张老师, 李老师')],
        ),
      ]);

      final node = PlanCompletionNode.fromJson(
        _courseNodeJson(
          id: 'c1',
          code: '304112020',
          name: '软件工程',
          credits: '3',
          term: '2023-2024学年秋',
          gradeInfo: '(必修,92.0(20240107))',
        ),
      );

      await _pumpPlanPage(tester, nodes: [node], teacherIndex: index);

      expect(find.text('授课教师：张老师、李老师'), findsOneWidget);
    });

    testWidgets('6. 同名课程教师冲突时不显示', (tester) async {
      final index = CourseTeacherIndex.fromSchedules([
        (
          config: ScheduleConfig(
            semesterStartDate: DateTime(2023, 9, 1),
            semesterName: '2023-2024学年秋',
          ),
          courses: [
            _mockCourse('程序设计 (01)', '王老师'),
            _mockCourse('程序设计 (02)', '赵老师'),
          ],
        ),
      ]);

      final node = PlanCompletionNode.fromJson(
        _courseNodeJson(
          id: 'c1',
          code: '304112030',
          name: '程序设计',
          credits: '3',
          term: '2023-2024学年秋',
          gradeInfo: '(必修,88.0(20240107))',
        ),
      );

      await _pumpPlanPage(tester, nodes: [node], teacherIndex: index);

      expect(find.text('程序设计'), findsOneWidget);
      expect(find.textContaining('授课教师'), findsNothing);
    });

    testWidgets('7. 分类节点不显示教师', (tester) async {
      final categoryNode = PlanCompletionNode.fromJson(_rootNodeJson('公共基础课'));

      await _pumpPlanPage(tester, nodes: [categoryNode]);

      expect(find.text('公共基础课'), findsOneWidget);
      expect(find.textContaining('授课教师'), findsNothing);
    });

    testWidgets('8. 教师索引加载失败不影响培养方案页面', (tester) async {
      final node = PlanCompletionNode.fromJson(
        _courseNodeJson(
          id: 'c1',
          code: '304112010',
          name: '新生研讨课',
          credits: '1',
          term: '2023-2024学年秋',
          gradeInfo: '(必修,96.0(20240107))',
        ),
      );

      // 注册一个查询必定抛异常的 DatabaseService
      final failingDb = _FailingDatabaseService();
      await _pumpPlanPage(tester, nodes: [node], customDb: failingDb);

      expect(tester.takeException(), isNull);
      expect(find.text('新生研讨课'), findsOneWidget);
      expect(find.textContaining('授课教师'), findsNothing);
    });

    testWidgets('9. 长教师姓名不会破坏布局', (tester) async {
      final index = CourseTeacherIndex.fromSchedules([
        (
          config: ScheduleConfig(
            semesterStartDate: DateTime(2023, 9, 1),
            semesterName: '2023-2024学年秋',
          ),
          courses: [
            _mockCourse(
              '综合实验课 (01)',
              '张一老师、张二老师、张三老师、张四老师、张五老师、张六老师、张七老师、张八老师',
            ),
          ],
        ),
      ]);

      final node = PlanCompletionNode.fromJson(
        _courseNodeJson(
          id: 'c1',
          code: '304112099',
          name: '综合实验课',
          credits: '3',
          term: '2023-2024学年秋',
          gradeInfo: '(必修,90.0(20240107))',
        ),
      );

      await _pumpPlanPage(tester, nodes: [node], teacherIndex: index);

      expect(tester.takeException(), isNull);
      expect(find.text('综合实验课'), findsOneWidget);
      expect(find.textContaining('授课教师：'), findsOneWidget);
    });

    testWidgets('10. 当前课表切换不改变历史课程匹配结果', (tester) async {
      final index = CourseTeacherIndex.fromSchedules([
        (
          config: ScheduleConfig(
            id: 'sch1',
            semesterName: '2023-2024学年秋',
            semesterStartDate: DateTime(2023, 9, 1),
          ),
          courses: [_mockCourse('大学物理 (01)', '张老教授')],
        ),
        (
          config: ScheduleConfig(
            id: 'sch2',
            semesterName: '2024-2025学年秋',
            semesterStartDate: DateTime(2024, 9, 1),
          ),
          courses: [_mockCourse('大学物理 (02)', '李新老师')],
        ),
      ]);

      final node = PlanCompletionNode.fromJson(
        _courseNodeJson(
          id: 'c1',
          code: '201010010',
          name: '大学物理',
          credits: '3',
          term: '2023-2024学年秋',
          gradeInfo: '(必修,88.0(20240107))',
        ),
      );

      await _pumpPlanPage(tester, nodes: [node], teacherIndex: index);

      expect(find.text('授课教师：张老教授'), findsOneWidget);
    });

    testWidgets('11. 培养方案数据变更不触发教师索引重载', (tester) async {
      final controllableDb = _ControllableDatabaseService([
        (
          config: ScheduleConfig(
            id: 's1',
            semesterStartDate: DateTime(2023, 9, 1),
            semesterName: '2023-2024学年秋',
          ),
          courses: [_mockCourse('新生研讨课 (01)', '初始教师')],
        ),
      ]);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final api = _ControllablePlanApi();
      final provider = PlanCompletionProvider(prefs, api);

      final node = PlanCompletionNode.fromJson(
        _courseNodeJson(
          id: 'c1',
          code: '304112010',
          name: '新生研讨课',
          credits: '1',
          term: '2023-2024学年秋',
          gradeInfo: '(必修,96.0(20240107))',
        ),
      );

      final initialPlans = [
        PlanCompletionPlan(id: 'p1', name: '测试培养方案一', nodes: [node]),
        PlanCompletionPlan(id: 'p2', name: '测试培养方案二', nodes: [node]),
      ];
      final future = provider.fetchPlanCompletion(forceRefresh: true);
      api.completeWith(initialPlans);
      await future;

      getIt.registerSingleton<PlanCompletionProvider>(provider);
      getIt.registerSingleton<ScuAuthProvider>(_FakeScuAuthProvider());
      getIt.registerSingleton<DatabaseService>(controllableDb);

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('zh'),
          home: PlanCompletionPage(),
        ),
      );
      await tester.pumpAndSettle();

      // 初始渲染：展示初始教师
      expect(find.text('授课教师：初始教师'), findsOneWidget);
      final initialDbCallCount = controllableDb.getCoursesCallCount;

      // 1. 模拟非 plans 数据变更的普通通知（如 selectPlan）：不触发教师索引重新加载
      provider.selectPlan(1);
      await tester.pumpAndSettle();
      expect(controllableDb.getCoursesCallCount, initialDbCallCount);

      // 2. 数据库更新，同时点击刷新按钮重新拉取；教师索引不随 plans
      // 实例变化重查课表数据库。
      controllableDb.schedules = [
        (
          config: ScheduleConfig(
            id: 's1',
            semesterStartDate: DateTime(2023, 9, 1),
            semesterName: '2023-2024学年秋',
          ),
          courses: [_mockCourse('新生研讨课 (01)', '更新后的新教师')],
        ),
      ];

      final newPlans = [
        PlanCompletionPlan(id: 'p1', name: '测试培养方案一', nodes: [node]),
        PlanCompletionPlan(id: 'p2', name: '测试培养方案二', nodes: [node]),
      ];
      await tester.tap(find.byIcon(Icons.refresh));
      api.completeWith(newPlans);
      await tester.pumpAndSettle();

      expect(find.text('授课教师：初始教师'), findsOneWidget);
      expect(find.text('授课教师：更新后的新教师'), findsNothing);
      expect(controllableDb.getCoursesCallCount, initialDbCallCount);

      // 3. 卸载页面（pump 空容器）
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('12. 培养方案页冷启动首开（接口异步返回 plans）只查一次课表数据库', (tester) async {
      final controllableDb = _ControllableDatabaseService([
        (
          config: ScheduleConfig(
            id: 's1',
            semesterStartDate: DateTime(2023, 9, 1),
            semesterName: '2023-2024学年秋',
          ),
          courses: [_mockCourse('新生研讨课 (01)', '冷启动首开教师')],
        ),
        (
          config: ScheduleConfig(
            id: 's2',
            semesterStartDate: DateTime(2024, 2, 25),
            semesterName: '2023-2024学年春',
          ),
          courses: [_mockCourse('大学物理 (01)', '王老师')],
        ),
      ]);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final api = _ControllablePlanApi();
      final provider = PlanCompletionProvider(prefs, api);

      getIt.registerSingleton<PlanCompletionProvider>(provider);
      getIt.registerSingleton<ScuAuthProvider>(_FakeScuAuthProvider());
      getIt.registerSingleton<DatabaseService>(controllableDb);

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('zh'),
          home: PlanCompletionPage(),
        ),
      );

      final node = PlanCompletionNode.fromJson(
        _courseNodeJson(
          id: 'c1',
          code: '304112010',
          name: '新生研讨课',
          credits: '1',
          term: '2023-2024学年秋',
          gradeInfo: '(必修,96.0(20240107))',
        ),
      );

      final plans = [
        PlanCompletionPlan(id: 'p1', name: '测试培养方案一', nodes: [node]),
      ];

      api.completeWith(plans);
      await tester.pumpAndSettle();

      expect(find.text('授课教师：冷启动首开教师'), findsOneWidget);
      expect(controllableDb.getCoursesCallCount, 2);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('13. 初始数据库加载失败后通过顶部刷新按钮重试恢复教师展示', (tester) async {
      final controllableDb = _ControllableDatabaseService([
        (
          config: ScheduleConfig(
            id: 's1',
            semesterStartDate: DateTime(2023, 9, 1),
            semesterName: '2023-2024学年秋',
          ),
          courses: [_mockCourse('新生研讨课 (01)', '重试恢复首开教师')],
        ),
      ]);
      controllableDb.shouldThrowOnGetSchedules = true;

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final api = _ControllablePlanApi();
      final provider = PlanCompletionProvider(prefs, api);

      getIt.registerSingleton<PlanCompletionProvider>(provider);
      getIt.registerSingleton<ScuAuthProvider>(_FakeScuAuthProvider());
      getIt.registerSingleton<DatabaseService>(controllableDb);

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('zh'),
          home: PlanCompletionPage(),
        ),
      );

      final node = PlanCompletionNode.fromJson(
        _courseNodeJson(
          id: 'c1',
          code: '304112010',
          name: '新生研讨课',
          credits: '1',
          term: '2023-2024学年秋',
          gradeInfo: '(必修,96.0(20240107))',
        ),
      );
      final plans = [
        PlanCompletionPlan(id: 'p1', name: '测试培养方案一', nodes: [node]),
      ];
      api.completeWith(plans);
      await tester.pumpAndSettle();

      // 初始渲染时数据库失败：展示课程但无教师
      expect(find.textContaining('新生研讨课'), findsOneWidget);
      expect(find.textContaining('授课教师'), findsNothing);

      // 数据库恢复
      controllableDb.shouldThrowOnGetSchedules = false;

      // 点击 AppBar 刷新按钮
      await tester.tap(find.byIcon(Icons.refresh));
      api.completeWith(plans);
      await tester.pumpAndSettle();

      // 重试后教师正常展示
      expect(find.text('授课教师：重试恢复首开教师'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });

    testWidgets('14. CourseProvider 课程修改自动同步更新培养方案页展示的任课教师', (tester) async {
      final controllableDb = _ControllableDatabaseService([
        (
          config: ScheduleConfig(
            id: 's1',
            semesterStartDate: DateTime(2023, 9, 1),
            semesterName: '2023-2024学年秋',
          ),
          courses: [_mockCourse('新生研讨课 (01)', '初始方案教师')],
        ),
      ]);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final api = _ControllablePlanApi();
      final provider = PlanCompletionProvider(prefs, api);
      final courseProvider = CourseProvider(controllableDb);

      getIt.registerSingleton<PlanCompletionProvider>(provider);
      getIt.registerSingleton<ScuAuthProvider>(_FakeScuAuthProvider());
      getIt.registerSingleton<DatabaseService>(controllableDb);
      getIt.registerSingleton<CourseProvider>(courseProvider);

      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: Locale('zh'),
          home: PlanCompletionPage(),
        ),
      );

      final node = PlanCompletionNode.fromJson(
        _courseNodeJson(
          id: 'c1',
          code: '304112010',
          name: '新生研讨课',
          credits: '1',
          term: '2023-2024学年秋',
          gradeInfo: '(必修,96.0(20240107))',
        ),
      );
      final plans = [
        PlanCompletionPlan(id: 'p1', name: '测试培养方案一', nodes: [node]),
      ];
      api.completeWith(plans);
      await tester.pumpAndSettle();

      // 初始展示
      expect(find.text('授课教师：初始方案教师'), findsOneWidget);

      // 通过 CourseProvider 修改课程信息（课表数据变更版本号自增）
      await courseProvider.updateCourse(_mockCourse('新生研讨课 (01)', '更新后的方案新教师'));
      await tester.pumpAndSettle();

      // 验证培养方案页自动更新展示新教师
      expect(find.text('授课教师：更新后的方案新教师'), findsOneWidget);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });
}

Map<String, dynamic> _rootNodeJson(String name) => {
  'id': 'root-1',
  'pId': '-1',
  'flagId': 'root-1',
  'flagType': '001',
  'name': name,
  'sfwc': '否',
  'yxxf': '0',
  'zsxf': '1',
};

Map<String, dynamic> _courseNodeJson({
  required String id,
  String pId = '-1',
  required String code,
  required String name,
  required String credits,
  required String term,
  String gradeInfo = '',
  bool passed = true,
}) {
  final iconHtml = passed
      ? '<i class="fa fa-smile-o green"></i>'
      : '<i class="fa fa-frown-o red"></i>';
  final rawName = '$iconHtml [$code]$name[$credits学分,$term]$gradeInfo';
  return {
    'id': id,
    'pId': pId,
    'flagId': id,
    'flagType': 'kch',
    'name': rawName,
    'sfwc': passed ? '是' : '否',
    'yxxf': passed ? credits : '0',
    'zsxf': credits,
  };
}

Future<void> _pumpPlanPage(
  WidgetTester tester, {
  List<PlanCompletionNode>? nodes,
  List<PlanCompletionPlan>? plans,
  CourseTeacherIndex? teacherIndex,
  bool registerDb = true,
  DatabaseService? customDb,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final api = _ControllablePlanApi();
  final provider = PlanCompletionProvider(prefs, api);

  final future = provider.fetchPlanCompletion(forceRefresh: true);
  final targetPlans =
      plans ??
      [PlanCompletionPlan(id: '', name: '测试培养方案', nodes: nodes ?? const [])];
  api.completeWith(targetPlans);
  await future;

  getIt.registerSingleton<PlanCompletionProvider>(provider);
  getIt.registerSingleton<ScuAuthProvider>(_FakeScuAuthProvider());
  if (registerDb) {
    getIt.registerSingleton<DatabaseService>(
      customDb ?? _MockDatabaseService(),
    );
  }

  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: PlanCompletionPage(initialTeacherIndex: teacherIndex),
    ),
  );
  await tester.pumpAndSettle();
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
      final idx = s.courses.indexWhere(
        (c) => c.name == course.name || c.id == course.id,
      );
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

class _MockDatabaseService implements DatabaseService {
  @override
  List<ScheduleConfig> getAllSchedules() => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingDatabaseService implements DatabaseService {
  @override
  List<ScheduleConfig> getAllSchedules() {
    throw Exception('Simulated Database failure');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Course _mockCourse(String name, String teacher) => Course(
  name: name,
  teacher: teacher,
  location: '',
  startWeek: 1,
  endWeek: 16,
  dayOfWeek: 1,
  startSection: 1,
  endSection: 2,
  colorValue: 0,
);

class _ControllablePlanApi implements ZhjwApiService {
  final _completers = <Completer<List<PlanCompletionPlan>>>[];

  @override
  Future<List<PlanCompletionPlan>> fetchPlanCompletion() {
    final completer = Completer<List<PlanCompletionPlan>>();
    _completers.add(completer);
    return completer.future;
  }

  void completeWith(List<PlanCompletionPlan> plans) {
    if (_completers.isNotEmpty) {
      _completers.removeAt(0).complete(plans);
    }
  }

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
