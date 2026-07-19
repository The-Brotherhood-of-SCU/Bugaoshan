import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/balance_query/widgets/balance_trend_time_range.dart';

/// 第一层时间范围筛选:仅 4 个预设 tab
/// (全部 / 近30天 / 近90天 / 自定义)。
///
/// 选中"自定义"时不弹任何 picker,仅通过 [onChanged] 通知父级切换到
/// custom 模式;真正的日期选择由 [BalanceTrendCustomRangeCard]
/// 在第二层独立处理。
class BalanceTrendRangeSelector extends StatelessWidget {
  final BalanceTrendTimeRange range;
  final ValueChanged<BalanceTrendTimeRange> onChanged;

  const BalanceTrendRangeSelector({
    super.key,
    required this.range,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SegmentedButton<BalanceTrendTimeRange>(
      segments: [
        ButtonSegment(
          value: BalanceTrendTimeRange.days7,
          label: Text(l10n.balanceTrendTimeRange7),
        ),
        ButtonSegment(
          value: BalanceTrendTimeRange.days30,
          label: Text(l10n.balanceTrendTimeRange30),
        ),
        ButtonSegment(
          value: BalanceTrendTimeRange.days90,
          label: Text(l10n.balanceTrendTimeRange90),
        ),
        ButtonSegment(
          value: BalanceTrendTimeRange.custom,
          label: Text(l10n.balanceTrendTimeRangeCustom),
        ),
      ],
      selected: {range},
      onSelectionChanged: (s) => onChanged(s.first),
    );
  }
}
