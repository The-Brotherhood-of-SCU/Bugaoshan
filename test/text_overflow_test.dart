import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/widgets/common/info_row.dart';
import 'package:bugaoshan/widgets/common/status_chip.dart';
import 'package:bugaoshan/widgets/common/styled_tile.dart';
import 'package:bugaoshan/widgets/common/styled_widget.dart';
import 'package:bugaoshan/widgets/course/grid_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 文字溢出回归测试：用「大文字缩放 + 窄宽度 + 长文本」渲染被修复的组件，
/// 断言没有 RenderFlex overflow（溢出会在 debug 下通过 FlutterError 上报）。
///
/// 覆盖 fix(ui) 提交中修改的公开共享组件与课程表网格表头。
Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: Center(child: child)),
  );
}

/// 设置全局文字缩放 2.0（相当于系统「最大字体」），测试结束自动还原。
void _useLargeTextScale(WidgetTester tester) {
  tester.platformDispatcher.textScaleFactorTestValue = 2.0;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  group('文字溢出防护', () {
    testWidgets('InfoRow 在大文字缩放 + 窄宽度下不溢出', (tester) async {
      _useLargeTextScale(tester);
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 200,
            child: InfoRow(
              label: '学号/工号',
              value: '2024141912345678901234567890123',
              labelWidth: 90,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('StatusChip 长状态文本不溢出', (tester) async {
      _useLargeTextScale(tester);
      await tester.pumpWidget(
        _wrap(
          SizedBox(width: 140, child: StatusChip(label: '一个非常非常长的状态标签文本内容')),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('IconTile 长 label + value + trailing 不溢出', (tester) async {
      _useLargeTextScale(tester);
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 240,
            child: IconTile(
              icon: Icons.settings,
              label: '这个设置项的名称很长很长很长',
              value: '其值也超级长很长很长很长很长',
              trailing: const Icon(Icons.chevron_right),
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('ButtonWithMaxWidth 长按钮文字不溢出', (tester) async {
      _useLargeTextScale(tester);
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 200,
            child: ButtonWithMaxWidth(
              onPressed: () {},
              icon: const Icon(Icons.arrow_forward),
              child: const Text('一个非常长的按钮文字内容示例'),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('GridHeaderRow 窄列宽 + 大文字缩放不溢出', (tester) async {
      _useLargeTextScale(tester);
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 260,
            child: GridHeaderRow(
              config: ScheduleConfig(
                semesterStartDate: DateTime(2026, 9, 1),
                semesterName: '2026-2027-1',
              ),
              displayWeek: 1,
              showAllWeeks: false,
              hasBackground: false,
              showWeekend: true,
              sectionWidth: 24,
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
