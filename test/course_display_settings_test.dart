import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/course/widgets/course_card.dart';
import 'package:bugaoshan/pages/settings/set_course_style_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeDatabaseService implements DatabaseService {
  final List<ScheduleConfig> schedules;

  _FakeDatabaseService({this.schedules = const []});

  @override
  List<ScheduleConfig> getAllSchedules() => schedules;

  @override
  ScheduleConfig? getScheduleConfig() =>
      schedules.isNotEmpty ? schedules.first : null;

  @override
  List<Course> getCourses({String? scheduleId}) => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  setUp(() async {
    await getIt.reset();
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('showCourseWeeks setting and display', () {
    test('loads and persists showCourseWeeks in AppConfigProvider', () async {
      SharedPreferences.setMockInitialValues({'showCourseWeeks': false});
      final prefs = await SharedPreferences.getInstance();
      final provider = AppConfigProvider(prefs);
      await provider.init();

      expect(provider.showCourseWeeks.value, isFalse);

      provider.showCourseWeeks.value = true;
      expect(prefs.getBool('showCourseWeeks'), isTrue);

      provider.showCourseWeeks.value = false;
      expect(prefs.getBool('showCourseWeeks'), isFalse);
    });

    test(
      'defaults to true when showCourseWeeks is absent from SharedPreferences',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final provider = AppConfigProvider(prefs);
        await provider.init();

        expect(provider.showCourseWeeks.value, isTrue);
      },
    );

    testWidgets(
      'CourseCard toggles week range display based on showCourseWeeks',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final appConfig = AppConfigProvider(prefs);
        await appConfig.init();
        getIt.registerSingleton<AppConfigProvider>(appConfig);

        final course = Course(
          name: '高等数学',
          teacher: '张老师',
          location: '一教101',
          startWeek: 1,
          endWeek: 16,
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          colorValue: 0xFF2196F3,
        );
        final config = ScheduleConfig(
          semesterStartDate: DateTime(2026, 9, 1),
          totalWeeks: 20,
        );

        await tester.pumpWidget(
          _wrap(
            Scaffold(
              body: SizedBox(
                height: 200,
                width: 100,
                child: CourseCard(
                  course: course,
                  config: config,
                  displayWeek: 1,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(CourseCard)),
        )!;
        final weekRangeText = l10n.weekRange(1, 16);

        expect(find.text('高等数学'), findsOneWidget);
        expect(find.text('张老师'), findsOneWidget);
        expect(find.text('一教101'), findsOneWidget);
        expect(find.text(weekRangeText), findsOneWidget);

        // Turn off showCourseWeeks
        appConfig.showCourseWeeks.value = false;
        await tester.pumpAndSettle();

        expect(find.text('高等数学'), findsOneWidget);
        expect(find.text('张老师'), findsOneWidget);
        expect(find.text('一教101'), findsOneWidget);
        expect(find.text(weekRangeText), findsNothing);

        // Turn on showCourseWeeks again
        appConfig.showCourseWeeks.value = true;
        await tester.pumpAndSettle();

        expect(find.text(weekRangeText), findsOneWidget);
      },
    );

    testWidgets(
      'SetCourseStylePage displays toggle, controls showCourseWeeks, and resets to default',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final appConfig = AppConfigProvider(prefs);
        await appConfig.init();
        getIt.registerSingleton<AppConfigProvider>(appConfig);

        final fakeDb = _FakeDatabaseService(
          schedules: [
            ScheduleConfig(
              id: 'test_id',
              semesterName: '2026秋',
              semesterStartDate: DateTime(2026, 9, 1),
              totalWeeks: 20,
            ),
          ],
        );
        getIt.registerSingleton<CourseProvider>(CourseProvider(fakeDb));

        await tester.pumpWidget(_wrap(const SetCourseStylePage()));
        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(SetCourseStylePage)),
        )!;

        // Verify the switch tile is rendered
        final scrollableFinder = find.byType(Scrollable).last;
        final switchFinder = find.widgetWithText(
          SwitchListTile,
          l10n.showCourseWeeks,
        );
        await tester.scrollUntilVisible(
          switchFinder,
          100,
          scrollable: scrollableFinder,
        );
        expect(switchFinder, findsOneWidget);

        final switchWidget = tester.widget<SwitchListTile>(switchFinder);
        expect(switchWidget.value, isTrue);

        // Verify preview updates reactively when showCourseWeeks changes
        final demoWeekRangeText = l10n.weekRange(1, 20);
        expect(find.text(demoWeekRangeText), findsWidgets);

        // Tap the switch to toggle it off
        await tester.tap(switchFinder);
        await tester.pumpAndSettle();

        expect(appConfig.showCourseWeeks.value, isFalse);
        final switchOff = tester.widget<SwitchListTile>(switchFinder);
        expect(switchOff.value, isFalse);
        // In preview, week range text should no longer be visible
        expect(find.text(demoWeekRangeText), findsNothing);

        // Scroll to and click Reset to default
        final resetFinder = find.widgetWithText(
          TextButton,
          l10n.resetToDefault,
        );
        await tester.scrollUntilVisible(
          resetFinder,
          100,
          scrollable: scrollableFinder,
        );
        await tester.tap(resetFinder);
        await tester.pumpAndSettle();

        expect(appConfig.showCourseWeeks.value, isTrue);
        final switchReset = tester.widget<SwitchListTile>(switchFinder);
        expect(switchReset.value, isTrue);
      },
    );
  });
}
