import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';

/// 第二层:自定义日期范围卡片。
///
/// 包含两个独立的按钮 [startLabel]/[endLabel],分别用于单独修改
/// 起始日期和结束日期。用户每次只改一个端点,不会同时重置两端。
///
/// 父级传入当前 [start]/[end](本地日期,不含时分),
/// 通过 [onStartChanged]/[onEndChanged] 回传新的本地日期。
class BalanceTrendCustomRangeCard extends StatelessWidget {
  /// 起始日期(本地,仅日期部分有效)。
  final DateTime start;

  /// 结束日期(本地,仅日期部分有效)。
  final DateTime end;

  /// 最早可选日期(默认 2 年前的 1 月 1 日)。
  final DateTime? firstDate;

  /// 最晚可选日期(默认今天)。
  final DateTime? lastDate;

  final ValueChanged<DateTime> onStartChanged;
  final ValueChanged<DateTime> onEndChanged;

  const BalanceTrendCustomRangeCard({
    super.key,
    required this.start,
    required this.end,
    required this.onStartChanged,
    required this.onEndChanged,
    this.firstDate,
    this.lastDate,
  });

  Future<void> _pickDate({
    required BuildContext context,
    required DateTime current,
    required ValueChanged<DateTime> onPicked,
    DateTime? selectableFirst,
    DateTime? selectableLast,
  }) async {
    final now = DateTime.now();
    final first = selectableFirst ?? DateTime(now.year - 2, 1, 1);
    final last = selectableLast ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: current.isAfter(last)
          ? last
          : (current.isBefore(first) ? first : current),
      firstDate: first,
      lastDate: last,
    );
    if (picked == null) return;
    onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final df = DateFormat('yyyy-MM-dd');
    final now = DateTime.now();
    final first = firstDate ?? DateTime(now.year - 2, 1, 1);
    final last = lastDate ?? now;

    // 起始按钮可选范围:[first, end]
    // 结束按钮可选范围:[start, last]
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: _dateButton(
                context: context,
                label: l10n.balanceTrendCustomStart,
                value: df.format(start),
                onTap: () => _pickDate(
                  context: context,
                  current: start,
                  onPicked: onStartChanged,
                  selectableFirst: first,
                  selectableLast: end,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                '~',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            Expanded(
              child: _dateButton(
                context: context,
                label: l10n.balanceTrendCustomEnd,
                value: df.format(end),
                onTap: () => _pickDate(
                  context: context,
                  current: end,
                  onPicked: onEndChanged,
                  selectableFirst: start,
                  selectableLast: last,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateButton({
    required BuildContext context,
    required String label,
    required String value,
    required VoidCallback onTap,
  }) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
