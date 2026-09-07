import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/course/main/course_page_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

CoursePageTopBar _buildBar({
  required List<ScheduleConfig> schedules,
  String? currentScheduleId,
  required ValueChanged<String> onSwitchSchedule,
  required VoidCallback onOpenScheduleManagement,
}) {
  return CoursePageTopBar(
    visibleWeek: 1,
    totalWeeks: 20,
    actualWeek: 1,
    animationDuration: Duration.zero,
    onPreviousWeek: () {},
    onNextWeek: () {},
    onGoToCurrentWeek: () {},
    onImport: () {},
    onExport: () {},
    onAddCourse: () {},
    schedules: schedules,
    currentScheduleId: currentScheduleId,
    onSwitchSchedule: onSwitchSchedule,
    onOpenScheduleManagement: onOpenScheduleManagement,
  );
}

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

ScheduleConfig _schedule(String id, String name) => ScheduleConfig(
  id: id,
  semesterName: name,
  semesterStartDate: DateTime(2026, 9, 7),
);

void main() {
  testWidgets('单课表时不显示切换按钮', (tester) async {
    await tester.pumpWidget(
      _wrap(
        _buildBar(
          schedules: [_schedule('a', '2026秋')],
          currentScheduleId: 'a',
          onSwitchSchedule: (_) {},
          onOpenScheduleManagement: () {},
        ),
      ),
    );

    expect(find.byIcon(Icons.swap_horiz), findsNothing);
  });

  testWidgets('多课时展示菜单：当前课表打勾，点选触发切换回调', (tester) async {
    String? switchedId;
    await tester.pumpWidget(
      _wrap(
        _buildBar(
          schedules: [_schedule('a', '2026秋'), _schedule('b', '2026春')],
          currentScheduleId: 'a',
          onSwitchSchedule: (id) => switchedId = id,
          onOpenScheduleManagement: () {},
        ),
      ),
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(CoursePageTopBar)),
    )!;

    await tester.tap(find.byIcon(Icons.swap_horiz));
    await tester.pumpAndSettle();

    // 两个课表项 + 「管理课表」入口都在菜单里。
    expect(find.text('2026秋'), findsOneWidget);
    expect(find.text('2026春'), findsOneWidget);
    expect(find.text(l10n.scheduleManagement), findsOneWidget);
    // 只有当前课表打勾。
    expect(find.byIcon(Icons.check), findsOneWidget);

    await tester.tap(find.text('2026春'));
    await tester.pumpAndSettle();

    expect(switchedId, equals('b'));
  });

  testWidgets('菜单里的「管理课表」触发管理页回调', (tester) async {
    var managementOpened = false;
    await tester.pumpWidget(
      _wrap(
        _buildBar(
          schedules: [_schedule('a', '2026秋'), _schedule('b', '2026春')],
          currentScheduleId: 'a',
          onSwitchSchedule: (_) {},
          onOpenScheduleManagement: () => managementOpened = true,
        ),
      ),
    );

    final l10n = AppLocalizations.of(
      tester.element(find.byType(CoursePageTopBar)),
    )!;

    await tester.tap(find.byIcon(Icons.swap_horiz));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.scheduleManagement));
    await tester.pumpAndSettle();

    expect(managementOpened, isTrue);
  });
}
