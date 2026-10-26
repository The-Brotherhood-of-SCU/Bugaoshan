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

/// 页面里有课表实时预览，需要 CourseProvider 才能布局。
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

/// 日期格式下拉框的接线测试。
///
/// 下拉嵌在「课程表样式」页里（该页已有课表实时预览），不再单独占一个
/// 设置页；这里验证下拉可达、选中项写回全局设置。
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

  testWidgets('课程表样式页内嵌日期格式下拉框，选中项写回设置', (tester) async {
    await pumpStylePage(tester);

    final appConfig = getIt<AppConfigProvider>();
    expect(
      appConfig.dateDisplayFormat.value,
      DateDisplayFormat.monthDayYearSlash,
    );

    final dropdown = find.byType(DropdownButtonFormField<DateDisplayFormat>);
    await tester.scrollUntilVisible(
      dropdown,
      120,
      scrollable: find.byType(Scrollable).last,
    );
    expect(dropdown, findsOneWidget);

    await tester.tap(dropdown);
    await tester.pumpAndSettle();

    final today = DateTime.now();
    final target = DateDisplayFormat.dayMonthYearDot.formatFull(today);
    await tester.tap(find.text(target).last);
    await tester.pumpAndSettle();

    expect(
      appConfig.dateDisplayFormat.value,
      DateDisplayFormat.dayMonthYearDot,
    );
  });
}
