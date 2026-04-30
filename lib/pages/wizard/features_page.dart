import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';

class FeaturesPage extends StatelessWidget {
  const FeaturesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    final features = [
      _FeatureData(
        icon: Icons.menu_book_rounded,
        title: l10n.wizardFeatureCourse,
      ),
      _FeatureData(
        icon: Icons.school_rounded,
        title: l10n.wizardFeatureCampus,
      ),
      _FeatureData(
        icon: Icons.person_rounded,
        title: l10n.wizardFeatureProfile,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(),
          Text(
            l10n.wizardFeatureTitle,
            style: textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, constraints) {
              final crossAxisCount = constraints.maxWidth > 400 ? 3 : 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: features.map((f) {
                  final cellWidth = (constraints.maxWidth - 12 * (crossAxisCount - 1)) / crossAxisCount;
                  return SizedBox(
                    width: cellWidth,
                    child: _FeatureCard(
                      icon: f.icon,
                      title: f.title,
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _FeatureData {
  final IconData icon;
  final String title;
  const _FeatureData({required this.icon, required this.title});
}

class _FeatureCard extends StatelessWidget {
  final IconData icon;
  final String title;

  const _FeatureCard({required this.icon, required this.title});

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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                icon,
                size: 24,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: textTheme.bodyMedium?.copyWith(height: 1.3),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
