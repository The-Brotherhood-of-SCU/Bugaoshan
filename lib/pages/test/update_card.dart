import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/test/update_result_notifier.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/services/update_service.dart';

class UpdateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final UpdateResultNotifier result;
  final VoidCallback onUpdate;

  const UpdateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.result,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: result,
      builder: (context, _) {
        final r = result.value;
        return Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 20),
                    const SizedBox(width: 8),
                    Text(title, style: Theme.of(context).textTheme.bodyMedium),
                    if (r.checking) ...[
                      const Spacer(),
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ],
                  ],
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: appCurve,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (r.status == UpdateCheckStatus.error) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Error: ${r.error}',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ],
                      if (r.noUpdate) ...[
                        const SizedBox(height: 8),
                        Text(
                          localizations.noUpdateAvailable,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                      if (r.hasUpdate && r.downloadUrl != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          r.isPrerelease
                              ? 'Preview: ${r.version}'
                              : 'Stable: ${r.version}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: onUpdate,
                          icon: Icon(icon),
                          label: Text(localizations.newVersionAvailable),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
