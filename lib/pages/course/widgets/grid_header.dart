import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/models/date_display_format.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/utils/holiday_utils.dart';

/// 课程网格表头行，显示星期名称、日期和节假日/节气标记。
/// 仅服务单周模式（全量周请用 [MinimalWeekdayHeader]）。
class GridHeaderRow extends StatelessWidget {
  final ScheduleConfig config;
  final int displayWeek;
  final bool hasBackground;
  final bool showWeekend;
  final double sectionWidth;

  /// 日期列「月/日」的先后顺序，由调用方从全局设置解析后传入。
  final DateDisplayFormat dateFormat;
  final void Function(DateTime date, SpecialDayInfo info)? onSpecialDayTap;

  const GridHeaderRow({
    super.key,
    required this.config,
    required this.displayWeek,
    required this.hasBackground,
    required this.showWeekend,
    required this.sectionWidth,
    required this.dateFormat,
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
    final visibleDays = showWeekend ? dayNames : dayNames.sublist(1, 6);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);
    return Container(
      height: 40 * textScale,
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
                final dayOfWeek = showWeekend
                    ? (index == 0 ? 7 : index)
                    : index + 1;
                final date = config.dateForCourseDay(displayWeek, dayOfWeek);
                final isToday = date.isAtSameMomentAs(today);
                final specialDay = HolidayUtils.getSpecialDay(date);

                // 节假日/节气 单独 switch
                final (
                  holidayBg,
                  holidayBadge,
                  holidayDateColor,
                ) = switch (specialDay.type) {
                  SpecialDayType.holiday => (
                    Colors.red.withAlpha(30),
                    (label: l10n.holidayLabel, color: Colors.red.shade700),
                    Colors.red.shade700,
                  ),
                  SpecialDayType.festival => (
                    Colors.orange.withAlpha(30),
                    (label: l10n.festivalLabel, color: Colors.orange.shade800),
                    Colors.orange.shade800,
                  ),
                  SpecialDayType.solarTerm => (
                    Colors.green.withAlpha(30),
                    (label: l10n.solarTermLabel, color: Colors.green.shade700),
                    Colors.green.shade700,
                  ),
                  _ => (null, null, null),
                };

                // isToday 单独处理，不与节假日耦合
                final bgColor =
                    holidayBg ??
                    (isToday
                        ? theme.colorScheme.primaryContainer.withAlpha(180)
                        : null);
                final badge = holidayBadge;
                final dateColor =
                    holidayDateColor ??
                    (isToday
                        ? theme.colorScheme.primary.withAlpha(200)
                        : theme.colorScheme.onSurfaceVariant);

                final isBadgeDay = badge != null;

                return Expanded(
                  child: GestureDetector(
                    onTap: isBadgeDay && onSpecialDayTap != null
                        ? () => onSpecialDayTap!(date, specialDay)
                        : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: bgColor,
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
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
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
                                  if (badge != null) ...[
                                    const SizedBox(width: 2),
                                    _buildLabelBadge(badge.label, badge.color),
                                  ],
                                ],
                              ),
                            ),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                // 窄列宽下固定用补零数字（10/19）：低分辨率屏上
                                // 5~7 列平摊后每列只有 60px 上下，中文的
                                // 「10月19日」会被压得难以辨认，定宽数字则不会被
                                // 语言文案长度牵着走。
                                dateFormat.formatMonthDay(date),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontSize: 10,
                                  fontWeight: isToday
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  color: dateColor,
                                ),
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
