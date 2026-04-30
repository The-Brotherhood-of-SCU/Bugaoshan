import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';

class FeaturesPage extends StatelessWidget {
  const FeaturesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final features = [
      (Icons.menu_book_rounded, l10n.wizardFeatureCourse),
      (Icons.school_rounded, l10n.wizardFeatureCampus),
      (Icons.person_rounded, l10n.wizardFeatureProfile),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Icon(
              Icons.explore_rounded,
              size: 52,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.wizardFeatureTitle,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          ...features.map(
            (f) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(f.$1,
                        size: 20, color: colorScheme.onSecondaryContainer),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(f.$2, style: textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
