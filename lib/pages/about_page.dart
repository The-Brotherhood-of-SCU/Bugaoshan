import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';
import 'package:bugaoshan/serivces/update_service.dart';
import 'package:bugaoshan/utils/open_link.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final versionProvider = getIt<AppInfoProvider>();
  final updateService = UpdateService();

  Future<void> _checkForUpdates() async {
    final latestVersion = await updateService.getLatestVersion();

    if (!mounted) return;

    final localizations = AppLocalizations.of(context)!;

    if (latestVersion == null) {
      showInfoDialog(
        title: localizations.checkForUpdates,
        content: localizations.loadFailed,
      );
      return;
    }

    final currentVersion = versionProvider.currentVersion;
    if (updateService.hasUpdate(currentVersion, latestVersion)) {
      final shouldNavigate = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(localizations.newVersionAvailable),
            content: Text('${localizations.version}: $latestVersion'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text(localizations.neverMind),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text(localizations.goToReleases),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      if (shouldNavigate == true) {
        await openLink(releasesUrl);
      }
    } else {
      showInfoDialog(
        title: localizations.checkForUpdates,
        content: localizations.noUpdateAvailable,
      );
    }
  }

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
              backgroundColor: const Color.fromARGB(255, 255, 255, 255),
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
                      localizations.bugaoshan,
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
          onPressed: () async {
            showInfoDialog(
              title: localizations.environmentInfo,
              content: await versionProvider.getVersionInfo(),
            );
          },
          label: Text(localizations.environmentInfo),
          icon: Icon(Icons.info_outline),
        ),
        ElevatedButton.icon(
          onPressed: _checkForUpdates,
          label: Text(localizations.checkForUpdates),
          icon: Icon(Icons.update),
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
