import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/balance_query/widgets/balance_trend_format.dart';
import 'package:bugaoshan/services/balance/balance_trend_calculator.dart';

/// 余额趋势折线图卡片。
///
/// 三种状态:
/// - 加载中:保留卡片骨架,图表区域显示 `—` 占位避免闪烁
/// - 无数据:显示空态图标 + 文案
/// - 正常:fl_chart 折线图
class BalanceTrendChartCard extends StatelessWidget {
  final TrendResult trend;
  final bool isLoading;
  final Color themeColor;

  const BalanceTrendChartCard({
    super.key,
    required this.trend,
    required this.isLoading,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (isLoading) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 8),
                child: Text(
                  l10n.balanceTrendYAxisBalance,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              SizedBox(
                height: 240,
                child: Center(
                  child: Text(
                    '—',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (trend.dailyPoints.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.show_chart,
                size: 48,
                color: theme.colorScheme.outline,
              ),
              const SizedBox(height: 12),
              Text(
                l10n.balanceTrendNoData,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final spots = <FlSpot>[];
    for (final p in trend.dailyPoints) {
      spots.add(
        FlSpot(p.timestamp.millisecondsSinceEpoch.toDouble(), p.balance),
      );
    }
    final minX = spots.first.x;
    final maxX = spots.last.x;
    final ys = spots.map((s) => s.y).toList();
    var minY = ys.reduce((a, b) => a < b ? a : b);
    var maxY = ys.reduce((a, b) => a > b ? a : b);
    if (minY == maxY) {
      minY -= 1;
      maxY += 1;
    }
    final padding = (maxY - minY) * 0.1;
    minY -= padding;
    maxY += padding;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 12, bottom: 8),
              child: Text(
                l10n.balanceTrendYAxisBalance,
                style: theme.textTheme.titleSmall,
              ),
            ),
            SizedBox(
              height: 240,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: niceInterval(minY, maxY),
                    getDrawingHorizontalLine: (v) => FlLine(
                      color: theme.colorScheme.outlineVariant.withValues(
                        alpha: 0.5,
                      ),
                      strokeWidth: 1,
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      axisNameWidget: const SizedBox.shrink(),
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: niceTimeInterval(minX, maxX),
                        getTitlesWidget: (value, meta) =>
                            _bottomTitle(context, value, meta, minX, maxX),
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 48,
                        interval: niceInterval(minY, maxY),
                        getTitlesWidget: (value, meta) =>
                            _leftTitle(value, meta, theme),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  minX: minX,
                  maxX: maxX,
                  minY: minY,
                  maxY: maxY,
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      curveSmoothness: 0.3,
                      color: themeColor,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: themeColor.withValues(alpha: 0.15),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipColor: (_) => theme.colorScheme.inverseSurface,
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final point = trend.dailyPoints[spot.spotIndex];
                          final dateStr = formatDate(point.timestamp);
                          final balanceStr =
                              '${formatNumber(point.balance, decimals: 3)} ${l10n.unitKwh}';
                          final priceStr =
                              '${l10n.balanceTrendTooltipPrice}: ${formatNumber(point.price, decimals: 4)} ${l10n.balanceTrendUnitYuanPerKwh}';
                          return LineTooltipItem(
                            '$dateStr\n$balanceStr\n$priceStr',
                            TextStyle(
                              color: theme.colorScheme.onInverseSurface,
                              fontSize: 12,
                              height: 1.4,
                            ),
                          );
                        }).toList();
                      },
                    ),
                    handleBuiltInTouches: true,
                  ),
                  clipData: const FlClipData.all(),
                  extraLinesData: const ExtraLinesData(),
                ),
                duration: const Duration(milliseconds: 250),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _bottomTitle(
    BuildContext context,
    double value,
    TitleMeta meta,
    double minX,
    double maxX,
  ) {
    final range = maxX - minX;
    if (range <= 0) return const SizedBox.shrink();
    final pos = (value - minX) / range;
    if ((pos - pos.round()).abs() > 0.02) {
      return const SizedBox.shrink();
    }
    final dt = DateTime.fromMillisecondsSinceEpoch(
      value.toInt(),
      isUtc: true,
    ).toLocal();
    return SideTitleWidget(
      meta: meta,
      child: Text(
        DateFormat('MM/dd').format(dt),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 10),
      ),
    );
  }

  Widget _leftTitle(double value, TitleMeta meta, ThemeData theme) {
    return SideTitleWidget(
      meta: meta,
      child: Text(
        formatNumber(value, decimals: 1),
        style: theme.textTheme.bodySmall?.copyWith(fontSize: 10),
      ),
    );
  }
}
