import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/widgets/eula_content.dart';

class EulaPage extends StatelessWidget {
  final ValueChanged<bool> onAgreedChanged;

  const EulaPage({super.key, required this.onAgreedChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 16),
          Text(
            l10n.eulaTitle,
            style: colorScheme.textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            l10n.wizardWelcomeDesc,
            style: colorScheme.textTheme.bodyLarge?.copyWith(
              color: colorScheme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: EulaContent(onAgreedChanged: onAgreedChanged),
          ),
        ],
      ),
    );
  }
}
