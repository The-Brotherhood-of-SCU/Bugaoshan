import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/balance_record.dart';
import 'package:bugaoshan/pages/campus/balance_query/widgets/balance_trend_format.dart';

/// 原始记录可折叠卡片:展示最近 50 条原始采样记录
/// (倒序,即最新的在前)。
///
/// 记录为空时返回 [SizedBox.shrink] 不占空间。
class BalanceTrendRawRecordsCard extends StatelessWidget {
  final List<BalanceRecord> records;

  const BalanceTrendRawRecordsCard({super.key, required this.records});

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final reversed = records.reversed.take(50).toList();
    return Card(
      child: ExpansionTile(
        initiallyExpanded: false,
        title: Text(
          '${l10n.balanceTrendRawRecords} (${records.length})',
          style: theme.textTheme.titleSmall,
        ),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          for (final r in reversed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    formatDateTime(r.timestamp),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '${formatNumber(r.balance, decimals: 3)} ${l10n.unitKwh} @ ${formatNumber(r.price, decimals: 4)} ${l10n.balanceTrendUnitYuanPerKwh}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
