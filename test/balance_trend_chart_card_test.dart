import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/balance_record.dart';
import 'package:bugaoshan/pages/campus/balance_query/widgets/balance_trend_chart_card.dart';
import 'package:bugaoshan/pages/campus/balance_query/widgets/balance_trend_format.dart';
import 'package:bugaoshan/services/balance/balance_trend_calculator.dart';

/// 构造余额趋势结果,数据范围 [minBalance]~[maxBalance](照明电量在 272.x 度
/// 附近波动时范围很窄,是 issue #261 的重叠场景)。
TrendResult _trend({
  required double minBalance,
  required double maxBalance,
  required int days,
}) {
  final points = <BalanceRecord>[
    for (var i = 0; i < days; i++)
      BalanceRecord(
        roomKey: 'r',
        balanceType: 1,
        timestamp: DateTime.utc(2026, 8, 1 + i, 10),
        balance: minBalance + (maxBalance - minBalance) * i / (days - 1),
        price: 0.5,
      ),
  ];
  return TrendResult(
    dailyPoints: points,
    dailyAvgCost: 0.5,
    dailyAvgKwh: 0.5,
    totalCost: 0.5,
    totalKwh: 0.5,
    totalDays: days.toDouble(),
    skippedRechargeSegments: 0,
    recordCount: days,
    firstRecordTime: points.first.timestamp,
    lastRecordTime: points.last.timestamp,
    currentPrice: 0.5,
  );
}

Future<void> _pumpChart(
  WidgetTester tester, {
  required TrendResult trend,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: BalanceTrendChartCard(
          trend: trend,
          isLoading: false,
          themeColor: Colors.blue,
        ),
      ),
    ),
  );
  // 等待 fl_chart 入场动画完成,标签位置才会稳定。
  await tester.pumpAndSettle();
}

/// 收集 Y 轴刻度标签文本(形如 `272.5`),返回按像素纵坐标升序的矩形列表。
///
/// 同一文本可能在渲染树中出现多次(如标题/图例),按位置去重后只保留
/// 刻度标签本身。
List<Rect> _yAxisLabelRects(WidgetTester tester) {
  final rects = <Rect>[];
  final seen = <String>{};
  for (final element in tester.widgetList<Text>(find.byType(Text))) {
    final text = element.data;
    if (text == null) continue;
    // Y 轴刻度是数字(可带小数点),X 轴日期(MM/dd)不含小数点。
    if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(text)) continue;
    final finder = find.text(text);
    if (finder.evaluate().isEmpty) continue;
    final rect = tester.getRect(finder.first);
    final key =
        '$text@${rect.left.toStringAsFixed(1)},'
        '${rect.top.toStringAsFixed(1)}';
    if (!seen.add(key)) continue;
    rects.add(rect);
  }
  rects.sort((a, b) => a.top.compareTo(b.top));
  return rects;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('BalanceTrendChartCard Y 轴刻度', () {
    testWidgets('窄数据范围下刻度标签不重叠(issue #261)', (tester) async {
      // 照明电量在 272.5~272.7 度之间小幅波动(近 30 天典型场景)
      await _pumpChart(
        tester,
        trend: _trend(minBalance: 272.5, maxBalance: 272.7, days: 30),
      );

      final labels = _yAxisLabelRects(tester);
      expect(labels.length, greaterThanOrEqualTo(3), reason: '应渲染出足够多的 Y 轴刻度');

      // 相邻刻度标签的垂直间距必须大于标签自身高度,否则视觉上重叠。
      for (var i = 1; i < labels.length; i++) {
        final gap = labels[i].top - labels[i - 1].bottom;
        expect(
          gap,
          greaterThanOrEqualTo(0),
          reason: '刻度 ${labels[i - 1]} 与 ${labels[i]} 不应重叠(间距 $gap)',
        );
      }
    });

    testWidgets('常规数据范围刻度标签同样不重叠', (tester) async {
      // 正常波动范围(近 90 天耗电几十度)
      await _pumpChart(
        tester,
        trend: _trend(minBalance: 240, maxBalance: 280, days: 90),
      );

      final labels = _yAxisLabelRects(tester);
      expect(labels.length, greaterThanOrEqualTo(3));
      for (var i = 1; i < labels.length; i++) {
        final gap = labels[i].top - labels[i - 1].bottom;
        expect(
          gap,
          greaterThanOrEqualTo(0),
          reason: '刻度 ${labels[i - 1]} 与 ${labels[i]} 不应重叠(间距 $gap)',
        );
      }
    });
  });

  group('niceInterval 最小像素间距', () {
    test('窄范围数据的间隔保证刻度间距不小于 40px(240px 高)', () {
      // 与图表卡片实际使用一致的约束
      const chartHeight = 240.0;
      const minPixelSpacing = 40.0;
      for (final (label, min, max) in [
        ('272.5~272.7', 272.5, 272.7),
        ('272.58~272.66', 272.58, 272.66),
        ('272.6~272.65', 272.6, 272.65),
        ('270~273', 270.0, 273.0),
        ('260~280', 260.0, 280.0),
      ]) {
        final iv = niceInterval(
          min,
          max,
          chartHeight: chartHeight,
          minPixelSpacing: minPixelSpacing,
        );
        final range = max - min;
        final nIntervals = (range / iv).floor();
        final pxSpacing = chartHeight / nIntervals;
        expect(
          pxSpacing,
          greaterThanOrEqualTo(minPixelSpacing),
          reason: '$label: interval=$iv 的刻度间距 $pxSpacing < $minPixelSpacing',
        );
      }
    });

    test('默认参数保持原有行为(范围较大时不受影响)', () {
      // 原实现 range/4 向上取 1/2/5,大范围下像素间距足够,结果不变
      expect(niceInterval(0, 100), 20);
      expect(niceInterval(0, 50), 10);
      expect(niceInterval(0, 10), 2);
    });
  });
}
