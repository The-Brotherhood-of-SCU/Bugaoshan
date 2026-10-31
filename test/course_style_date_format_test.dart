import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/models/date_display_format.dart';
import 'package:bugaoshan/pages/settings/set_course_style_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/services/database_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeDatabaseService implements DatabaseService {
  _FakeDatabaseService({this.schedules = const []});

  final List<ScheduleConfig> schedules;

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

/// 日期格式下拉框的接线测试：默认跟随系统，用户选择写回并持久化。
void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final appConfig = AppConfigProvider(prefs);
    await appConfig.init();
    getIt.registerSingleton<AppConfigProvider>(appConfig);
    getIt.registerSingleton<CourseProvider>(
      CourseProvider(
        _FakeDatabaseService(
          schedules: [
            ScheduleConfig(
              id: 'test_id',
              semesterName: '2026秋',
              semesterStartDate: DateTime(2026, 9, 1),
              totalWeeks: 20,
            ),
          ],
        ),
      ),
    );
  });

  tearDown(getIt.reset);

  Future<void> pumpStylePage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const SetCourseStylePage(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('下拉只有四种格式，默认跟随系统', (tester) async {
    await pumpStylePage(tester);

    expect(DateDisplayFormat.values, hasLength(4));
    // 未设置时 value 为 null，表示跟随系统。
    expect(getIt<AppConfigProvider>().dateDisplayFormat.value, isNull);

    final dropdown = find.byType(DropdownButtonFormField<DateDisplayFormat>);
    await tester.scrollUntilVisible(
      dropdown,
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(dropdown, findsOneWidget);
  });

  testWidgets('选中一项后写回设置并持久化', (tester) async {
    await pumpStylePage(tester);

    final dropdown = find.byType(DropdownButtonFormField<DateDisplayFormat>);
    await tester.scrollUntilVisible(
      dropdown,
      120,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(dropdown);
    await tester.pumpAndSettle();

    final today = DateTime.now();
    final label = DateDisplayFormat.yearMonthDay.formatFull(today);
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();

    expect(
      getIt<AppConfigProvider>().dateDisplayFormat.value,
      DateDisplayFormat.yearMonthDay,
    );
  });
}
