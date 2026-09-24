import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/student_type.dart';
import 'package:bugaoshan/theme_shape.dart';

/// 学生身份（本科生 / 研究生）选择卡片组。
/// 本组件是纯受控组件，不直接读写 [AppConfigProvider]，
/// 由调用方通过 [value] / [onChanged] 接入自身状态。
class StudentTypeSelector extends StatelessWidget {
  /// 当前选中的身份。
  final StudentType value;

  /// 选中项变化回调。
  final ValueChanged<StudentType> onChanged;

  /// 两张卡片之间的垂直间距。
  final double spacing;

  /// 是否在选中卡片右侧显示勾选图标。
  final bool showCheck;

  const StudentTypeSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.spacing = 12,
    this.showCheck = true,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StudentTypeCard(
          icon: Icons.school_rounded,
          title: l10n.studentTypeUndergraduate,
          description: l10n.studentTypeUndergraduateDesc,
          selected: value == StudentType.undergraduate,
          showCheck: showCheck,
          onTap: () => onChanged(StudentType.undergraduate),
        ),
        SizedBox(height: spacing),
        _StudentTypeCard(
          icon: Icons.cast_for_education_rounded,
          title: l10n.studentTypeGraduate,
          description: l10n.studentTypeGraduateDesc,
          selected: value == StudentType.graduate,
          showCheck: showCheck,
          onTap: () => onChanged(StudentType.graduate),
        ),
      ],
    );
  }
}

/// 单个身份选项卡片：选中时使用主色描边 + 主色图标底 + 右侧勾选。
class _StudentTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final bool showCheck;
  final VoidCallback onTap;

  const _StudentTypeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.showCheck,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: selected
              ? colorScheme.primaryContainer.withValues(alpha: 0.3)
              : colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(AppShapes.largeIncreased),
          border: Border.all(
            color: selected
                ? colorScheme.primary
                : colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: selected ? 2 : 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: selected
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppShapes.medium),
                ),
                child: Icon(
                  icon,
                  size: 28,
                  color: selected
                      ? colorScheme.onPrimaryContainer
                      : colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: selected ? colorScheme.primary : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
