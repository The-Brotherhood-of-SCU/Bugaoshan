import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/models/date_display_format.dart';
import 'package:bugaoshan/pages/course/widgets/grid_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 表头日期只显示月与日，顺序与分隔符跟随全局日期格式设置。
///
/// 低分辨率屏上 5~7 天平摊后每列只剩 45~60px，原先中文的「9月7日」会被
/// FittedBox 压成一团；定宽数字不受语言文案长度影响。
void main() {
  Future<void> pumpHeader(
    WidgetTester tester, {
    required DateDisplayFormat format,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 360,
            child: GridHeaderRow(
              config: ScheduleConfig(
                semesterStartDate: DateTime(2026, 9, 7), // 周一
                semesterName: '2026-2027-1',
              ),
              displayWeek: 1,
              hasBackground: false,
              showWeekend: false,
              sectionWidth: 24,
              dateFormat: format,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('月在前时表头为补零的「月/日」', (tester) async {
    await pumpHeader(
      tester,
      format: const DateDisplayFormat(monthFirst: true, separator: '/'),
    );

    // 周一~周五 = 9/7 ~ 9/11（教学周以周日为首日成行）。
    for (final label in ['09/07', '09/08', '09/09', '09/10', '09/11']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.textContaining('月'), findsNothing);
    expect(find.textContaining('年'), findsNothing);
  });

  testWidgets('日在前 + 点号时表头为「日.月」且不带年份', (tester) async {
    await pumpHeader(
      tester,
      format: const DateDisplayFormat(monthFirst: false, separator: '.'),
    );

    expect(find.text('07.09'), findsOneWidget);
    expect(find.text('11.09'), findsOneWidget);
    // 年份只出现在顶栏，表头窄列不放。
    expect(find.text('2026'), findsNothing);
  });
}
