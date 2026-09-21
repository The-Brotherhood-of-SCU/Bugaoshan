import 'package:flutter/material.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/student_type.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';

/// 引导页身份选择步骤：本科生 / 研究生。
///
/// 选择立即写入 [AppConfigProvider.studentType]（默认本科生），
/// 决定后续登录步骤的课表导入入口与校园页功能分区。
class StudentTypePage extends StatelessWidget {
  const StudentTypePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appConfig = getIt<AppConfigProvider>();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(AppShapes.largeIncreased),
            ),
            child: Icon(
              Icons.badge_rounded,
              size: 36,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.wizardStudentTypeTitle,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            l10n.wizardStudentTypeDesc,
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ValueListenableBuilder<StudentType>(
            valueListenable: appConfig.studentType,
            builder: (context, studentType, _) => Column(
              children: [
                _StudentTypeCard(
                  icon: Icons.school_rounded,
                  title: l10n.studentTypeUndergraduate,
                  description: l10n.studentTypeUndergraduateDesc,
                  selected: studentType == StudentType.undergraduate,
                  onTap: () =>
                      appConfig.studentType.value = StudentType.undergraduate,
                ),
                const SizedBox(height: 12),
                _StudentTypeCard(
                  icon: Icons.cast_for_education_rounded,
                  title: l10n.studentTypeGraduate,
                  description: l10n.studentTypeGraduateDesc,
                  selected: studentType == StudentType.graduate,
                  onTap: () =>
                      appConfig.studentType.value = StudentType.graduate,
                ),
              ],
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _StudentTypeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  const _StudentTypeCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
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
            width: selected ? 2 : 1,
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
              if (selected) ...[
                const SizedBox(width: 12),
                Icon(Icons.check_circle, color: colorScheme.primary),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
