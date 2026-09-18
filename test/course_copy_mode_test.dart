import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/course/edit/course_edit_page.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/services/database_service.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// 「复制课程」在编辑页上的行为：以「新建副本」模式打开，保存走新增，
/// 保持源时段会被既有冲突校验拦下，取消则不落库。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  // 必须使用 no-isolate 工厂：后台 isolate 版 sqflite 与本绑定下的
  // pumpWidget 组合会互相等待，导致用例永久挂起。
  databaseFactory = databaseFactoryFfiNoIsolate;

  setUp(() async {
    await getIt.reset();
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('副本模式：标题与保存按钮为副本文案，且不提供删除入口', (tester) async {
    final harness = await _openHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(_wrap(_copyPage(harness), harness.l10n));
    await tester.pumpAndSettle();

    expect(find.text(harness.l10n.copyCourseTitle), findsOneWidget);
    expect(find.text(harness.l10n.copyCourseSave), findsOneWidget);
    expect(find.text(harness.l10n.editCourse), findsNothing);
    expect(find.text(harness.l10n.save), findsNothing);
    expect(find.byIcon(Icons.delete), findsNothing);
    // 名称预填为「源课程名 (副本)」，用户可在保存前继续修改。
    expect(
      find.text('${harness.source.name}${harness.l10n.copySuffix}'),
      findsOneWidget,
    );
  });

  testWidgets('保持源课程的时段保存：被冲突校验拦下且不新增课程', (tester) async {
    final harness = await _openHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(_wrap(_copyPage(harness), harness.l10n));
    await tester.pumpAndSettle();

    await tester.tap(find.text(harness.l10n.copyCourseSave));
    await tester.pumpAndSettle();

    expect(find.text(harness.l10n.timeConflict), findsOneWidget);
    expect(await harness.courseNames(), [harness.source.name]);
  });

  testWidgets('改到空闲时段保存：按新增落库，源课程不被改动', (tester) async {
    final harness = await _openHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(_wrap(_copyPage(harness), harness.l10n));
    await tester.pumpAndSettle();

    // 星期选择位于滚动区下方，需先滚动到可见位置再点击。
    final tuesday = find.text(harness.l10n.tuesday);
    await tester.ensureVisible(tuesday);
    await tester.pumpAndSettle();
    await tester.tap(tuesday);
    await tester.pumpAndSettle();
    await tester.tap(find.text(harness.l10n.copyCourseSave));
    await tester.pumpAndSettle();

    expect(find.text(harness.l10n.timeConflict), findsNothing);
    final courses = await harness.courses();
    expect(courses, hasLength(2), reason: '复制应新增一门课程');
    final source = courses.singleWhere(
      (course) => course.id == harness.source.id,
    );
    expect(source.name, harness.source.name, reason: '源课程不应被改名');
    final copy = courses.singleWhere((course) => course.id != harness.source.id);
    expect(copy.name, '${harness.source.name}${harness.l10n.copySuffix}');
    expect(copy.dayOfWeek, DateTime.tuesday);
    expect(copy.startSection, harness.source.startSection);
    expect(copy.campus, harness.source.campus);
  });

  testWidgets('只打开副本页不保存：不产生任何课程', (tester) async {
    final harness = await _openHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(_wrap(_copyPage(harness), harness.l10n));
    await tester.pumpAndSettle();

    expect(await harness.courseNames(), [harness.source.name]);
  });

  testWidgets('对照：编辑既有课程仍是编辑模式，保存后课程数不变', (tester) async {
    final harness = await _openHarness();
    addTearDown(harness.dispose);

    await tester.pumpWidget(
      _wrap(
        CourseEditPage(scheduleConfig: harness.config, course: harness.source),
        harness.l10n,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(harness.l10n.editCourse), findsOneWidget);
    expect(find.byIcon(Icons.delete), findsOneWidget);

    await tester.tap(find.text(harness.l10n.save));
    await tester.pumpAndSettle();

    expect(await harness.courseNames(), [harness.source.name]);
  });
}

Widget _wrap(Widget child, AppLocalizations l10n) => MaterialApp(
  navigatorKey: navigatorKey,
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

CourseEditPage _copyPage(_Harness harness) => CourseEditPage.createCopy(
  scheduleConfig: harness.config,
  source: harness.source,
  nameSuffix: harness.l10n.copySuffix,
);

class _Harness {
  const _Harness({
    required this.db,
    required this.config,
    required this.source,
    required this.service,
    required this.l10n,
  });

  final Database db;
  final ScheduleConfig config;
  final Course source;
  final DatabaseService service;
  final AppLocalizations l10n;

  Future<List<Course>> courses() => service.getCoursesAsync();

  Future<List<String>> courseNames() async =>
      (await courses()).map((course) => course.name).toList()..sort();

  Future<void> dispose() => db.close();
}

/// 内存库中准备一张课表与一门源课程，并注册好供编辑页注入的 Provider。
Future<_Harness> _openHarness() async {
  final db = await openDatabase(inMemoryDatabasePath, version: 1);
  await db.execute('''
    CREATE TABLE metadata (
      key TEXT PRIMARY KEY,
      value TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE schedules (
      id TEXT PRIMARY KEY,
      config_json TEXT NOT NULL
    )
  ''');
  await db.execute('''
    CREATE TABLE courses (
      id TEXT PRIMARY KEY,
      schedule_id TEXT NOT NULL,
      name TEXT,
      teacher TEXT,
      location TEXT,
      campus TEXT NOT NULL DEFAULT '',
      start_week INTEGER,
      end_week INTEGER,
      day_of_week INTEGER,
      start_section INTEGER,
      end_section INTEGER,
      color_value INTEGER,
      week_type INTEGER
    )
  ''');

  final service = DatabaseService.forTesting(db);
  final config = ScheduleConfig(
    id: 'S1',
    semesterName: '测试课表',
    semesterStartDate: DateTime(2026, 9, 1),
  );
  await service.addSchedule(config);
  await service.switchSchedule(config.id);

  final source = Course(
    id: 'course-source',
    name: '高等数学',
    teacher: '张三',
    location: '江安一教 A101',
    campus: '江安校区',
    startWeek: 1,
    endWeek: 16,
    dayOfWeek: DateTime.monday,
    startSection: 1,
    endSection: 2,
    colorValue: 0xFF2196F3,
  );
  await service.addCourse(source);

  getIt.registerSingleton<CourseProvider>(CourseProvider(service));
  return _Harness(
    db: db,
    config: config,
    source: source,
    service: service,
    l10n: lookupAppLocalizations(const Locale('zh')),
  );
}
