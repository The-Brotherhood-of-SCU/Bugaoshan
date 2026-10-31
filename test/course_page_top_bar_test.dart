import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/models/date_display_format.dart';
import 'package:bugaoshan/pages/course/main/course_page_top_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

CoursePageTopBar _buildBar({
  required List<ScheduleConfig> schedules,
  String? currentScheduleId,
  required ValueChanged<String> onSwitchSchedule,
  required VoidCallback onOpenScheduleManagement,
  int visibleWeek = 1,
  int totalWeeks = 20,
  int actualWeek = 1,
  DateDisplayFormat dateFormat = const DateDisplayFormat(
    monthFirst: true,
    separator: '/',
  ),
}) {
  return CoursePageTopBar(
    visibleWeek: visibleWeek,
    totalWeeks: totalWeeks,
    actualWeek: actualWeek,
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
    dateFormat: dateFormat,
  );
}

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

/// 顶栏左上角日期文本（宽屏 `2026/10/18` / 窄屏 `10/18`）。
/// 取顶栏里唯一的日期文本（分隔符可能是 `/`、`.` 或 `-`）。
String _dateText(WidgetTester tester) {
  final matches = find
      .byType(Text)
      .evaluate()
      .map((element) => (element.widget as Text).data)
      .whereType<String>()
      .where(
        (text) =>
            RegExp(r'^\d{1,4}[/.-]\d{1,2}([/.-]\d{1,4})?$').hasMatch(text),
      )
      .toList();
  expect(matches, hasLength(1));
  return matches.single;
}

/// 以指定逻辑宽度 + 文字缩放渲染顶栏，并把 view 配置还原留给测试结束。
Future<void> _pumpAt(
  WidgetTester tester,
  CoursePageTopBar bar, {
  required double width,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = Size(width, 800);
  tester.view.devicePixelRatio = 1.0;
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(_wrap(bar));
}

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

  group('窄屏布局', () {
    /// 最挤的状态：多课表（4 个操作按钮）+ 正在看别的周（徽章显示「本周第 N 周」）。
    List<ScheduleConfig> twoSchedules() => [
      _schedule('a', '2026秋'),
      _schedule('b', '2026春'),
    ];

    for (final width in <double>[320, 360, 393, 430]) {
      testWidgets('宽 $width 下「第 N 周」不被省略号截断且无溢出', (tester) async {
        await _pumpAt(
          tester,
          _buildBar(
            schedules: twoSchedules(),
            currentScheduleId: 'a',
            onSwitchSchedule: (_) {},
            onOpenScheduleManagement: () {},
            visibleWeek: 12,
            actualWeek: 3,
          ),
          width: width,
        );

        final l10n = AppLocalizations.of(
          tester.element(find.byType(CoursePageTopBar)),
        )!;
        final weekPara = tester.renderObject<RenderParagraph>(
          find.text(l10n.currentWeek(12)),
        );
        expect(weekPara.didExceedMaxLines, isFalse);

        // 四个操作入口在窄屏同样必须全部可见（不做溢出菜单收纳）。
        expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
        expect(find.byIcon(Icons.download_rounded), findsOneWidget);
        expect(find.byIcon(Icons.share_rounded), findsOneWidget);
        expect(find.byIcon(Icons.add_circle_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('操作按钮收掉 IconButton 默认的 48×48 触控尺寸', (tester) async {
      await _pumpAt(
        tester,
        _buildBar(
          schedules: twoSchedules(),
          currentScheduleId: 'a',
          onSwitchSchedule: (_) {},
          onOpenScheduleManagement: () {},
        ),
        width: 393,
      );

      for (final icon in [
        Icons.swap_horiz,
        Icons.download_rounded,
        Icons.share_rounded,
        Icons.add_circle_rounded,
      ]) {
        final size = tester.getSize(
          find.ancestor(
            of: find.byIcon(icon),
            matching: find.byType(IconButton),
          ),
        );
        expect(size.width, lessThanOrEqualTo(40));
        expect(size.height, lessThanOrEqualTo(40));
      }
    });

    testWidgets('大文字缩放 + 320 宽不溢出', (tester) async {
      await _pumpAt(
        tester,
        _buildBar(
          schedules: twoSchedules(),
          currentScheduleId: 'a',
          onSwitchSchedule: (_) {},
          onOpenScheduleManagement: () {},
          visibleWeek: 12,
          actualWeek: 3,
        ),
        width: 320,
        textScale: 2.0,
      );

      expect(tester.takeException(), isNull);
    });

    // 极窄窗口（桌面端可随意拖拽）的下界：4 个紧凑按钮 160px + 左右 padding 32px。
    // 再窄连课表网格本身都无法使用，不在支持范围内。
    testWidgets('窗口宽 200px 时不溢出', (tester) async {
      await _pumpAt(
        tester,
        _buildBar(
          schedules: twoSchedules(),
          currentScheduleId: 'a',
          onSwitchSchedule: (_) {},
          onOpenScheduleManagement: () {},
          visibleWeek: 12,
          actualWeek: 3,
        ),
        width: 200,
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('顶栏始终显示完整日期，与宽度无关', (tester) async {
      for (final width in <double>[430, 320]) {
        await _pumpAt(
          tester,
          _buildBar(
            schedules: twoSchedules(),
            currentScheduleId: 'a',
            onSwitchSchedule: (_) {},
            onOpenScheduleManagement: () {},
          ),
          width: width,
        );
        // 默认格式为「月/日/年」且不补零，窄屏也不再省掉年份。
        expect(
          _dateText(tester),
          matches(RegExp(r'^\d{1,2}/\d{1,2}/\d{4}$')),
          reason: '宽 $width 下日期应为完整日期',
        );
      }
    });

    testWidgets('顶栏日期顺序跟随全局日期格式设置', (tester) async {
      await _pumpAt(
        tester,
        _buildBar(
          schedules: twoSchedules(),
          currentScheduleId: 'a',
          onSwitchSchedule: (_) {},
          onOpenScheduleManagement: () {},
          dateFormat: const DateDisplayFormat(
            monthFirst: false,
            separator: '.',
          ),
        ),
        width: 430,
      );
      expect(_dateText(tester), matches(RegExp(r'^\d{2}\.\d{2}\.\d{4}$')));
    });
  });
}
