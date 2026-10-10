import 'package:flutter/material.dart';

/// 课程编辑界面中按周排布的周次多选网格组件。
///
/// 直接内联显示 1～[totalWeeks] 周按钮，支持点击任意周次进行独立点选/反选。
class WeekSelectorGrid extends StatelessWidget {
  final int totalWeeks;
  final Set<int> selectedWeeks;
  final ValueChanged<int> onWeekToggled;

  const WeekSelectorGrid({
    super.key,
    required this.totalWeeks,
    required this.selectedWeeks,
    required this.onWeekToggled,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: totalWeeks,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.6,
      ),
      itemBuilder: (context, index) {
        final week = index + 1;
        final isSelected = selectedWeeks.contains(week);

        return Material(
          color: isSelected
              ? colorScheme.primary
              : colorScheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: () => onWeekToggled(week),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? colorScheme.primary
                      : colorScheme.outlineVariant.withValues(alpha: 0.6),
                ),
              ),
              child: Text(
                '$week',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? colorScheme.onPrimary
                      : colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
