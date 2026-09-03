import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/balance_record.dart';
import 'package:bugaoshan/pages/campus/balance_query/widgets/balance_trend_stats_card.dart';
import 'package:bugaoshan/services/balance/balance_trend_calculator.dart';

TrendResult _trend() {
  final points = <BalanceRecord>[
    for (var i = 0; i < 30; i++)
      BalanceRecord(
        roomKey: 'r',
        balanceType: 1,
        timestamp: DateTime.utc(2026, 8, 1 + i, 10),
        balance: 272.5 + 0.2 * i / 29,
        price: 0.5,
      ),
  ];
  return TrendResult(
    dailyPoints: points,
    dailyAvgCost: 1.2,
    dailyAvgKwh: 2.4,
    totalCost: 36.0,
    totalKwh: 72.0,
    totalDays: 30,
    skippedRechargeSegments: 0,
    recordCount: 30,
    firstRecordTime: points.first.timestamp,
    lastRecordTime: points.last.timestamp,
    currentPrice: 0.5,
  );
}

Future<void> _pumpStats(WidgetTester tester, {double width = 320}) async {
  await tester.pumpWidget(
    MaterialApp(
      // 使用中文 locale,与真实页面一致(英文 label 较长,240px 测试
      // 环境下会溢出,与本修复无关)。
      locale: const Locale('zh'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: width,
            // 卡片内容高于测试默认视口,用滚动容器避免测试环境溢出异常
            // (真实页面中本卡片在可滚动页面内)。
            child: SingleChildScrollView(
              child: BalanceTrendStatsCard(
                trend: _trend(),
                isLoading: false,
                themeColor: Colors.blue,
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

/// 返回渲染"记录时间范围"行值的 Text widget,找不到返回 null。
Text? _recordRangeText(WidgetTester tester) {
  final l10n = AppLocalizations.of(tester.element(find.byType(Scaffold)));
  if (l10n == null) return null;
  if (find.text(l10n.balanceTrendRecordRange).evaluate().isEmpty) {
    return null;
  }
  const expectedRange = '2026-08-01 ~ 2026-08-30';
  final value = find.text(expectedRange);
  if (value.evaluate().isEmpty) return null;
  return tester.widget<Text>(value);
}

/// 断言渲染值文本没有单行省略截断:
/// `maxLines` 为 null(允许折行)且未设置 ellipsis。
void _expectNotTruncated(Text value) {
  expect(value.maxLines, isNull, reason: '记录时间范围应允许折行(maxLines 不应为 1)');
  expect(
    value.overflow,
    isNot(TextOverflow.ellipsis),
    reason: '记录时间范围不应被省略号截断',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BalanceTrendStatsCard 记录时间范围', () {
    testWidgets('窄屏(320px)下完整显示日期范围,不截断为省略号', (tester) async {
      await _pumpStats(tester, width: 320);
      final value = _recordRangeText(tester);
      expect(value, isNotNull, reason: '记录时间范围应渲染出完整值文本');
      _expectNotTruncated(value!);
    });

    testWidgets('超窄屏(240px)下日期范围可折行显示', (tester) async {
      await _pumpStats(tester, width: 240);
      // 240px 很窄,完整单行放不下时允许折行,但仍应完整显示。
      final value = _recordRangeText(tester);
      expect(value, isNotNull, reason: '记录时间范围应渲染出完整值文本');
      _expectNotTruncated(value!);
    });
  });
}
