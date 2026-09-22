import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/course/edit/course_edit_page.dart';
import 'package:bugaoshan/pages/course/widgets/week_selector_grid.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/services/database_service.dart';

void main() {
  group('Course.isActiveInWeek with discrete weeks', () {
    test('regular range without customWeeks', () {
      final course = Course(
        name: 'Math',
        teacher: 'Dr. Smith',
        location: 'Room 101',
        startWeek: 1,
        endWeek: 5,
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        colorValue: 0xFF123456,
        weekType: WeekType.odd,
      );

      expect(course.isActiveInWeek(1), isTrue);
      expect(course.isActiveInWeek(2), isFalse); // even week
      expect(course.isActiveInWeek(3), isTrue);
      expect(course.isActiveInWeek(4), isFalse);
      expect(course.isActiveInWeek(5), isTrue);
      expect(course.isActiveInWeek(6), isFalse); // out of range
    });

    test('discrete weeks via customWeeks override start/end range', () {
      final course = Course(
        name: 'Physics Lab',
        teacher: 'Dr. Jane',
        location: 'Lab 202',
        startWeek: 1,
        endWeek: 10,
        dayOfWeek: 2,
        startSection: 3,
        endSection: 4,
        colorValue: 0xFF654321,
        weekType: WeekType.every,
        customWeeks: [1, 3, 5, 8],
      );

      expect(course.isActiveInWeek(1), isTrue);
      expect(course.isActiveInWeek(2), isFalse);
      expect(course.isActiveInWeek(3), isTrue);
      expect(course.isActiveInWeek(4), isFalse);
      expect(course.isActiveInWeek(5), isTrue);
      expect(course.isActiveInWeek(6), isFalse);
      expect(course.isActiveInWeek(7), isFalse);
      expect(course.isActiveInWeek(8), isTrue);
      expect(course.isActiveInWeek(9), isFalse);
      expect(course.isActiveInWeek(10), isFalse);
    });
  });

  group('Course.conflictsWith with discrete weeks', () {
    test('non-overlapping discrete weeks do not conflict', () {
      final courseA = Course(
        name: 'Course A',
        teacher: 'T1',
        location: 'L1',
        startWeek: 1,
        endWeek: 6,
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        colorValue: 0xFF000000,
        customWeeks: [1, 3, 5],
      );

      final courseB = Course(
        name: 'Course B',
        teacher: 'T2',
        location: 'L2',
        startWeek: 2,
        endWeek: 6,
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        colorValue: 0xFF111111,
        customWeeks: [2, 4, 6],
      );

      expect(courseA.conflictsWith(courseB), isFalse);
      expect(courseB.conflictsWith(courseA), isFalse);
    });

    test('overlapping discrete week triggers conflict', () {
      final courseA = Course(
        name: 'Course A',
        teacher: 'T1',
        location: 'L1',
        startWeek: 1,
        endWeek: 8,
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        colorValue: 0xFF000000,
        customWeeks: [1, 3, 5, 8],
      );

      final courseB = Course(
        name: 'Course B',
        teacher: 'T2',
        location: 'L2',
        startWeek: 5,
        endWeek: 12,
        dayOfWeek: 1,
        startSection: 2,
        endSection: 3, // overlaps on section 2
        colorValue: 0xFF111111,
        customWeeks: [5, 7, 9], // overlaps on week 5
      );

      expect(courseA.conflictsWith(courseB), isTrue);
      expect(courseB.conflictsWith(courseA), isTrue);
    });

    test(
      'discrete course does not conflict with regular course if weeks disjoint',
      () {
        final regularOdd = Course(
          name: 'Odd Course',
          teacher: 'T1',
          location: 'L1',
          startWeek: 1,
          endWeek: 10,
          dayOfWeek: 3,
          startSection: 1,
          endSection: 2,
          colorValue: 0xFF000000,
          weekType: WeekType.odd,
        );

        final discreteEven = Course(
          name: 'Discrete Even',
          teacher: 'T2',
          location: 'L2',
          startWeek: 2,
          endWeek: 8,
          dayOfWeek: 3,
          startSection: 1,
          endSection: 2,
          colorValue: 0xFF111111,
          customWeeks: [2, 4, 6, 8],
        );

        expect(regularOdd.conflictsWith(discreteEven), isFalse);
        expect(discreteEven.conflictsWith(regularOdd), isFalse);
      },
    );

    test('起止周不重叠但离散周相交时仍判冲突（不按起止周裁剪）', () {
      // A 的 range=[1,2] 但自定义周点亮了第 10 周；B 只在第 10 周。
      // 旧实现先取起止周交集（[10,2] 为空）直接 return false → 漏报。
      final courseA = Course(
        name: 'Course A',
        teacher: 'T1',
        location: 'L1',
        startWeek: 1,
        endWeek: 2,
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        colorValue: 0xFF000000,
        customWeeks: [1, 10],
      );

      final courseB = Course(
        name: 'Course B',
        teacher: 'T2',
        location: 'L2',
        startWeek: 10,
        endWeek: 10,
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        colorValue: 0xFF111111,
        customWeeks: [10],
      );

      expect(courseA.isActiveInWeek(10), isTrue);
      expect(courseB.isActiveInWeek(10), isTrue);
      expect(courseA.conflictsWith(courseB), isTrue);
      expect(courseB.conflictsWith(courseA), isTrue);
    });

    test('非离散课程语义不变：起止周不重叠即无冲突', () {
      Course course({required int startWeek, required int endWeek}) => Course(
        name: 'c',
        teacher: '',
        location: '',
        startWeek: startWeek,
        endWeek: endWeek,
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        colorValue: 0,
      );

      expect(
        course(
          startWeek: 1,
          endWeek: 2,
        ).conflictsWith(course(startWeek: 5, endWeek: 6)),
        isFalse,
      );
      // 单双周互补仍无交集
      final odd = Course(
        name: 'odd',
        teacher: '',
        location: '',
        startWeek: 1,
        endWeek: 6,
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        colorValue: 0,
        weekType: WeekType.odd,
      );
      final even = Course(
        name: 'even',
        teacher: '',
        location: '',
        startWeek: 1,
        endWeek: 6,
        dayOfWeek: 1,
        startSection: 1,
        endSection: 2,
        colorValue: 0,
        weekType: WeekType.even,
      );
      expect(odd.conflictsWith(even), isFalse);
      expect(even.conflictsWith(odd), isFalse);
    });
  });

  group('Course.formatSegments', () {
    test('formats consecutive and isolated weeks correctly', () {
      expect(Course.formatSegments([1, 2, 3, 5, 7, 8, 9]), '1-3, 5, 7-9');
      expect(Course.formatSegments([1, 3, 5, 7]), '1, 3, 5, 7');
      expect(Course.formatSegments([1, 2, 3, 4]), '1-4');
      expect(Course.formatSegments([16]), '16');
      expect(Course.formatSegments([]), '');
    });

    test('sorts unsorted input lists and deduplicates', () {
      expect(Course.formatSegments([9, 5, 1, 8, 3, 7, 2]), '1-3, 5, 7-9');
      expect(Course.formatSegments([1, 1, 2, 2, 3]), '1-3');
      expect(Course.formatSegments([-1, 0, 1, 2]), '1-2');
    });
  });

  group('Course JSON serialization with customWeeks', () {
    test('serializes and deserializes customWeeks', () {
      final course = Course(
        id: 'c1',
        name: 'Test Course',
        teacher: 'Prof. X',
        location: 'Building A',
        startWeek: 1,
        endWeek: 15,
        dayOfWeek: 4,
        startSection: 5,
        endSection: 6,
        colorValue: 0xFF998877,
        customWeeks: [1, 2, 4, 8, 15],
      );

      final json = course.toJson();
      expect(json['customWeeks'], [1, 2, 4, 8, 15]);

      final restored = Course.fromJson(json);
      expect(restored.id, 'c1');
      expect(restored.name, 'Test Course');
      expect(restored.customWeeks, [1, 2, 4, 8, 15]);
      expect(restored.isActiveInWeek(4), isTrue);
      expect(restored.isActiveInWeek(5), isFalse);
    });

    test('handles loose/dirty customWeeks in fromJson robustly', () {
      final dirtyJson = <String, dynamic>{
        'id': 'dirty1',
        'name': 'Dirty Course',
        'customWeeks': ['1', 2, '3', 3, 'invalid', -5, 0, 5],
      };

      final course = Course.fromJson(dirtyJson);
      expect(course.customWeeks, [1, 2, 3, 5]);
    });

    test('非 List 类型的 customWeeks 不抛异常（旧实现会 TypeError）', () {
      // 旧实现 `json['customWeeks'] as List<dynamic>?` 遇到数字 / 字符串 /
      // 对象会抛 TypeError，被导入外层 catch 兜成通用的「导入失败」。
      expect(
        Course.fromJson({'name': 'x', 'customWeeks': 5}).customWeeks,
        isNull,
      );
      expect(
        Course.fromJson({
          'name': 'x',
          'customWeeks': {'1': true},
        }).customWeeks,
        isNull,
      );
      expect(
        Course.fromJson({'name': 'x', 'customWeeks': null}).customWeeks,
        isNull,
      );
      // 无有效值（全被过滤）也回落为 null，不产生非法的空离散集合
      expect(
        Course.fromJson({'name': 'x', 'customWeeks': []}).customWeeks,
        isNull,
      );
      expect(
        Course.fromJson({
          'name': 'x',
          'customWeeks': [-1, 0],
        }).customWeeks,
        isNull,
      );
    });

    test('接受 CSV 字符串形态的 customWeeks', () {
      // 数据库用 CSV 存 custom_weeks，分享/备份 JSON 可能混入同一形态。
      final course = Course.fromJson({'name': 'x', 'customWeeks': '1, 2,4'});
      expect(course.customWeeks, [1, 2, 4]);
    });

    test('起止周收敛到 customWeeks 的 min/max（维持消费方依赖的不变量）', () {
      final course = Course.fromJson({
        'name': 'x',
        'startWeek': 1,
        'endWeek': 16,
        'customWeeks': [3, 4, 9],
      });
      expect(course.startWeek, 3);
      expect(course.endWeek, 9);
      expect(
        course.customWeeks!.every(
          (w) => w >= course.startWeek && w <= course.endWeek,
        ),
        isTrue,
      );
    });

    test('超出 kMaxCourseWeeks 的脏周次被丢弃（避免撑大冲突检测循环）', () {
      final course = Course.fromJson({
        'name': 'x',
        'customWeeks': [1, 99999],
      });
      expect(course.customWeeks, [1]);
    });
  });

  group('CourseEditPage with WeekSelectorGrid widget test', () {
    testWidgets(
      'renders WeekSelectorGrid and toggling weeks updates custom indicator',
      (tester) async {
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfiNoIsolate;
        await getIt.reset();
        addTearDown(getIt.reset);

        final db = await openDatabase(inMemoryDatabasePath, version: 1);
        addTearDown(db.close);
        await db.execute('''
        CREATE TABLE IF NOT EXISTS metadata (
          key TEXT PRIMARY KEY,
          value TEXT NOT NULL
        )
      ''');
        await db.execute('''
        CREATE TABLE IF NOT EXISTS schedules (
          id TEXT PRIMARY KEY,
          config_json TEXT NOT NULL
        )
      ''');
        await db.execute('''
        CREATE TABLE IF NOT EXISTS courses (
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
          week_type INTEGER,
          custom_weeks TEXT
        )
      ''');

        final service = DatabaseService.forTesting(db);
        final config = ScheduleConfig(
          id: 'S1',
          semesterName: '测试课表',
          semesterStartDate: DateTime(2026, 9, 1),
          totalWeeks: 20,
        );
        await service.addSchedule(config);
        await service.switchSchedule(config.id);

        final courseProvider = CourseProvider(service);
        getIt.registerSingleton<CourseProvider>(courseProvider);

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            locale: const Locale('zh'),
            home: CourseEditPage(scheduleConfig: config),
          ),
        );
        await tester.pumpAndSettle();

        // WeekSelectorGrid should be present
        expect(find.byType(WeekSelectorGrid), findsOneWidget);

        // Verify button '1' and button '20' exist in WeekSelectorGrid
        expect(
          find.descendant(
            of: find.byType(WeekSelectorGrid),
            matching: find.text('1'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(WeekSelectorGrid),
            matching: find.text('20'),
          ),
          findsOneWidget,
        );

        // Initially, by default startWeek=1, endWeek=20, everyWeek -> all 20 are active
        // Now tap week '3' to deselect it
        final week3Btn = find.descendant(
          of: find.byType(WeekSelectorGrid),
          matching: find.text('3'),
        );
        expect(week3Btn, findsOneWidget);
        await tester.ensureVisible(week3Btn);
        await tester.tap(week3Btn);
        await tester.pumpAndSettle();

        // '自定义周次' hint should now appear
        final l10n = lookupAppLocalizations(const Locale('zh'));
        expect(find.text(l10n.customWeeksHint), findsOneWidget);
        // Week range text should now be discrete, via l10n (不再硬编码 "周")
        expect(find.text(l10n.weekSegments('1-2, 4-20')), findsOneWidget);
      },
    );
  });
}
