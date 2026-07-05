import 'package:flutter/material.dart';
import 'package:bugaoshan/models/course.dart';

/// 课程网格节次列，显示左侧的节次编号和时间段。
class GridSectionColumn extends StatelessWidget {
  final ScheduleConfig config;
  final double rowHeight;
  final double width;

  const GridSectionColumn({
    super.key,
    required this.config,
    required this.rowHeight,
    required this.width,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sections = config.sectionsPerDay;
    final timeSlots = config.timeSlots;

    // 计算边界位置
    final morningEnd = config.morningSections;
    final afternoonEnd = config.morningSections + config.afternoonSections;

    return SizedBox(
      width: width,
      child: Column(
        children: List.generate(sections, (i) {
          final slot = i < timeSlots.length ? timeSlots[i] : null;
          final startStr = slot != null
              ? '${slot.startTime.hour.toString().padLeft(2, '0')}:${slot.startTime.minute.toString().padLeft(2, '0')}'
              : '';
          final endStr = slot != null
              ? '${slot.endTime.hour.toString().padLeft(2, '0')}:${slot.endTime.minute.toString().padLeft(2, '0')}'
              : '';

          final isBoundary = (i + 1 == morningEnd) || (i + 1 == afternoonEnd);

          return Container(
            height: rowHeight,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isBoundary
                      ? theme.colorScheme.primary.withAlpha(150)
                      : theme.colorScheme.outlineVariant,
                  width: isBoundary ? 1.5 : 0.5,
                ),
                right: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${i + 1}',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (startStr.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        startStr,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (endStr.isNotEmpty && rowHeight >= 60)
                      Text(
                        endStr,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}
