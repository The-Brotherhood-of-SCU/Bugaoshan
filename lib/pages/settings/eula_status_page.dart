import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/riverpod/settings/app_config_pods.dart';
import 'package:bugaoshan/services/exit_service.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:bugaoshan/widgets/eula_content.dart';

class EulaStatusPage extends ConsumerWidget {
  const EulaStatusPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final acceptedVersion = ref.watch(acceptedEulaVersionSettingProvider);
    final colorScheme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.eulaTitle),
            Text(
              l10n.eulaAgreedVersion(acceptedVersion.toString()),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          const Expanded(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: EulaContent(showCheckbox: false),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _revokeEula(context, ref, l10n),
                  icon: const Icon(Icons.gavel),
                  label: Text(l10n.revokeEula),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.colorScheme.error,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _revokeEula(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    final confirmed = await showYesNoDialog(
      title: l10n.revokeEula,
      content: l10n.revokeEulaConfirm,
    );
    if (confirmed == true) {
      ref.read(acceptedEulaVersionSettingProvider.notifier).update(0);
      await getIt<ExitService>().exitApp();
    }
  }
}
