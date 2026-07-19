import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/balance_query/widgets/balance_trend_format.dart';
import 'package:bugaoshan/services/balance/balance_trend_calculator.dart';

/// 趋势统计卡片:日均电费主指标 + 累计明细 + 充值段提示。
///
/// 加载中([isLoading] = true)时所有数值位置显示 `—`,
/// 避免加载完成后 UI 结构跳变闪烁。
class BalanceTrendStatsCard extends StatelessWidget {
  final TrendResult trend;
  final bool isLoading;
  final Color themeColor;

  const BalanceTrendStatsCard({
    super.key,
    required this.trend,
    required this.isLoading,
    required this.themeColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;

    if (!isLoading && trend.recordCount == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Icon(
                Icons.insights_outlined,
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

    const dash = 'N/A';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 主指标:日均电费
            Center(
              child: Column(
                children: [
                  Text(
                    l10n.balanceTrendDailyAvgCost,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    isLoading ? dash : formatMoney(trend.dailyAvgCost),
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: themeColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isLoading
                        ? dash
                        : '${formatNumber(trend.dailyAvgKwh, decimals: 3)} ${l10n.unitKwh}/${l10n.balanceTrendUnitPerDay}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 32),
            _infoRow(
              context,
              l10n.balanceTrendTotalCost,
              isLoading ? dash : formatMoney(trend.totalCost),
            ),
            _infoRow(
              context,
              l10n.balanceTrendTotalKwh,
              isLoading
                  ? dash
                  : '${formatNumber(trend.totalKwh, decimals: 3)} ${l10n.unitKwh}',
            ),
            _infoRow(
              context,
              l10n.balanceTrendTotalDays,
              isLoading ? dash : formatNumber(trend.totalDays, decimals: 1),
            ),
            _infoRow(
              context,
              l10n.balanceTrendCurrentPrice,
              isLoading
                  ? dash
                  : '${formatNumber(trend.currentPrice, decimals: 4)} ${l10n.balanceTrendUnitYuanPerKwh}',
            ),
            _infoRow(
              context,
              l10n.balanceTrendRecordCount,
              isLoading ? dash : '${trend.recordCount}',
            ),
            if (!isLoading && trend.skippedRechargeSegments > 0)
              _infoRow(
                context,
                l10n.balanceTrendSkippedRecharge,
                '${trend.skippedRechargeSegments}',
              ),
            if (!isLoading &&
                trend.firstRecordTime != null &&
                trend.lastRecordTime != null)
              _infoRow(
                context,
                l10n.balanceTrendRecordRange,
                '${formatDate(trend.firstRecordTime!)} ~ ${formatDate(trend.lastRecordTime!)}',
              ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
