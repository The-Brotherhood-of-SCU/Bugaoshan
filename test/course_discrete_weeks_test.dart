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
  });

  group('Course.formatSegments', () {
    test('formats consecutive and isolated weeks correctly', () {
      expect(Course.formatSegments([1, 2, 3, 5, 7, 8, 9]), '1-3, 5, 7-9');
      expect(Course.formatSegments([1, 3, 5, 7]), '1, 3, 5, 7');
      expect(Course.formatSegments([1, 2, 3, 4]), '1-4');
      expect(Course.formatSegments([16]), '16');
      expect(Course.formatSegments([]), '');
    });

    test('sorts unsorted input lists', () {
      expect(Course.formatSegments([9, 5, 1, 8, 3, 7, 2]), '1-3, 5, 7-9');
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
        // Week range text should now be discrete: "1-2, 4-20 周"
        expect(find.text('1-2, 4-20 周'), findsOneWidget);
      },
    );
  });
}
