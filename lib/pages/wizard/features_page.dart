import 'package:bugaoshan/widgets/common/third_center.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';

class FeaturesPage extends StatelessWidget {
  const FeaturesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final title = Text(
      l10n.wizardFeatureTitle,
      style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
      textAlign: TextAlign.center,
    );

    final listView = ListView(
      shrinkWrap: true,
      children: [
        title,
        const SizedBox(height: 22),
        _FeatureCard(
          icon: Icons.menu_book_rounded,
          iconBackground: colorScheme.tertiaryContainer,
          iconColor: colorScheme.onTertiaryContainer,
          title: l10n.wizardFeatureCourse,
          description: l10n.wizardFeatureCourseDesc,
        ),
        const SizedBox(height: 12),
        _FeatureCard(
          icon: Icons.school_rounded,
          iconBackground: colorScheme.secondaryContainer,
          iconColor: colorScheme.onSecondaryContainer,
          title: l10n.wizardFeatureCampus,
          description: l10n.wizardFeatureCampusDesc,
        ),
        const SizedBox(height: 12),
        _FeatureCard(
          icon: Icons.person_rounded,
          iconBackground: colorScheme.primaryContainer,
          iconColor: colorScheme.onPrimaryContainer,
          title: l10n.wizardFeatureProfile,
          description: l10n.wizardFeatureProfileDesc,
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: ThirdCenter(child: listView),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final String description;

  const _FeatureCard({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: iconBackground,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(icon, size: 28, color: iconColor),
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
    );
  }
}
