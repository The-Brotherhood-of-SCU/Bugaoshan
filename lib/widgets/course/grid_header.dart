import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/utils/app_shapes.dart';
import 'package:bugaoshan/utils/holiday_utils.dart';

/// 课程网格表头行，显示星期名称、日期和节假日/节气标记。
class GridHeaderRow extends StatelessWidget {
  final ScheduleConfig config;
  final int displayWeek;
  final bool showAllWeeks;
  final bool hasBackground;
  final double sectionWidth;
  final void Function(DateTime date, SpecialDayInfo info)? onSpecialDayTap;

  const GridHeaderRow({
    super.key,
    required this.config,
    required this.displayWeek,
    required this.showAllWeeks,
    required this.hasBackground,
    required this.sectionWidth,
    this.onSpecialDayTap,
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
    final visibleDays = config.showWeekend ? dayNames : dayNames.sublist(1, 6);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final semesterStart = config.semesterStartDate;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: hasBackground ? null : theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          // 左侧空白区域，与节次列对齐
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
                // 周日为 index 0，计算当前列对应的星期几
                final dayOfWeek = config.showWeekend
                    ? (index == 0 ? 7 : index)
                    : index + 1;
                // 周日在周一之前，dayOfWeek=7 时应为 -1 而非 6
                final daysFromMonday = dayOfWeek == 7 ? -1 : dayOfWeek - 1;
                final mondayOffset = (1 - semesterStart.weekday) % 7;
                final date = semesterStart.add(
                  Duration(
                    days: (displayWeek - 1) * 7 + mondayOffset + daysFromMonday,
                  ),
                );
                final isToday = !showAllWeeks && date.isAtSameMomentAs(today);
                final specialDay = !showAllWeeks
                    ? HolidayUtils.getSpecialDay(date)
                    : SpecialDayInfo(type: SpecialDayType.ordinary);
                final isHoliday =
                    !showAllWeeks && specialDay.type == SpecialDayType.holiday;
                final isFestival =
                    !showAllWeeks && specialDay.type == SpecialDayType.festival;
                final isSolarTerm =
                    !showAllWeeks &&
                    specialDay.type == SpecialDayType.solarTerm;
                final isSpecial = isHoliday || isFestival || isSolarTerm;

                return Expanded(
                  child: GestureDetector(
                    onTap: !showAllWeeks && isSpecial && onSpecialDayTap != null
                        ? () => onSpecialDayTap!(date, specialDay)
                        : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isHoliday
                            ? Colors.red.withAlpha(15)
                            : isFestival
                            ? Colors.orange.withAlpha(15)
                            : isSolarTerm
                            ? Colors.green.withAlpha(15)
                            : isToday
                            ? theme.colorScheme.primaryContainer.withAlpha(180)
                            : null,
                        border: Border(
                          right: BorderSide(
                            color: theme.colorScheme.outlineVariant,
                            width: 0.5,
                          ),
                        ),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  name,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    fontSize: 13,
                                    fontWeight: isToday
                                        ? FontWeight.bold
                                        : FontWeight.w600,
                                    color: isToday
                                        ? theme.colorScheme.primary
                                        : theme.colorScheme.onSurface,
                                  ),
                                ),
                                if (isHoliday) ...[
                                  const SizedBox(width: 2),
                                  _buildLabelBadge(
                                    l10n.holidayLabel,
                                    Colors.red,
                                  ),
                                ],
                                if (isFestival) ...[
                                  const SizedBox(width: 2),
                                  _buildLabelBadge(
                                    l10n.festivalLabel,
                                    Colors.orange,
                                  ),
                                ],
                                if (isSolarTerm) ...[
                                  const SizedBox(width: 2),
                                  _buildLabelBadge(
                                    l10n.solarTermLabel,
                                    Colors.green,
                                  ),
                                ],
                              ],
                            ),
                            if (!showAllWeeks)
                              Text(
                                l10n.dateMonthDay(date.month, date.day),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 10,
                                  fontWeight: isToday
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: isHoliday
                                      ? Colors.red
                                      : isFestival
                                      ? Colors.orange
                                      : isSolarTerm
                                      ? Colors.green
                                      : isToday
                                      ? theme.colorScheme.primary.withAlpha(200)
                                      : theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                          ],
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

  Widget _buildLabelBadge(String label, Color color) {
    return Builder(
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 1),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppShapes.small),
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            fontSize: 9,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}
