import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/services/exit_service.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:bugaoshan/widgets/eula_content.dart';

class EulaStatusPage extends StatelessWidget {
  const EulaStatusPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appConfig = getIt<AppConfigProvider>();
    final colorScheme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.eulaTitle),
            Text(
              l10n.eulaAgreedVersion(
                appConfig.acceptedEulaVersion.value.toString(),
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: const EulaContent(showCheckbox: false),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _revokeEula(context, appConfig, l10n),
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
    AppConfigProvider appConfig,
    AppLocalizations l10n,
  ) async {
    final confirm = await showYesNoDialog(
      title: l10n.revokeEula,
      content: l10n.revokeEulaConfirm,
    );
    if (confirm == true) {
      appConfig.acceptedEulaVersion.value = 0;
      await getIt<ExitService>().exitApp();
    }
  }
}
