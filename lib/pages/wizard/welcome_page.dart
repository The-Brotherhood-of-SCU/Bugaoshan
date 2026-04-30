import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';

class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Icon(
              Icons.rocket_launch_rounded,
              size: 64,
              color: colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            l10n.wizardWelcomeTitle,
            style: textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.wizardWelcomeDesc,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(flex: 3),
        ],
      ),
    );
  }
}
