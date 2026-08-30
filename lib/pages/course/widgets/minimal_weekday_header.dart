import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';

/// 仅显示周几的最小表头，用于全量周模式（`showAllWeeks:true`）。
/// 不展示日期、不查节假日、不高亮今天，仅与左侧节次列对齐。
class MinimalWeekdayHeader extends StatelessWidget {
  final bool showWeekend;
  final double sectionWidth;

  const MinimalWeekdayHeader({
    super.key,
    required this.showWeekend,
    required this.sectionWidth,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dayNames = [
      l10n.sunday,
      l10n.monday,
      l10n.tuesday,
      l10n.wednesday,
      l10n.thursday,
      l10n.friday,
      l10n.saturday,
    ];
    final theme = Theme.of(context);
    final visibleDays = showWeekend ? dayNames : dayNames.sublist(1, 6);
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);

    return Container(
      height: 40 * textScale,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: sectionWidth,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: List.generate(visibleDays.length, (index) {
                final name = visibleDays[index];
                return Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          name,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
