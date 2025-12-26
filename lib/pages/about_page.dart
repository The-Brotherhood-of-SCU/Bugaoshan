import 'package:flutter/material.dart';
import 'package:rubbish_plan/injection/injector.dart';
import 'package:rubbish_plan/l10n/app_localizations.dart';
import 'package:rubbish_plan/providers/app_info_provider.dart';
import 'package:rubbish_plan/utils/open_link.dart';
import 'package:rubbish_plan/widgets/dialog/dialog.dart';

class AboutPage extends StatelessWidget {
  AboutPage({super.key});
  final versionProvider = getIt<AppInfoProvider>();

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(localizations.about)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            CircleAvatar(
              radius: 60,
              backgroundImage: const AssetImage('assets/avater.png'),
              backgroundColor: Colors.grey.shade600,
            ),
            const SizedBox(height: 24),
            Text(
              localizations.developedBy("The Brotherhood of SCU"),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.projectInfo,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoItem(
                      context,
                      Icons.apps,
                      localizations.appName,
                      localizations.rubbishPlan,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoItem(
                      context,
                      Icons.info_outline,
                      localizations.version,
                      versionProvider.currentVersion,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoItem(
                      context,
                      Icons.description,
                      localizations.description,
                      localizations.appDescription,
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            externalResources(localizations),
          ],
        ),
      ),
    );
  }

  Widget externalResources(AppLocalizations localizations) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 24,
      runSpacing: 16,
      children: [
        ElevatedButton.icon(
          onPressed: () async {
            await openProjectRepository();
          },
          label: Text(localizations.projectRepository),
          icon: Icon(Icons.open_in_new),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            await openDeveloperTeam();
          },
          label: Text(localizations.developmentTeam),
          icon: Icon(Icons.open_in_new),
        ),
        ElevatedButton.icon(
          onPressed: () {
            showInfoDialog(
              title: localizations.environmentInfo,
              content: versionProvider.getVersionInfo(),
            );
          },
          label: Text(localizations.environmentInfo),
          icon: Icon(Icons.info_outline),
        ),
      ],
    );
  }

  Widget _buildInfoItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(value, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
