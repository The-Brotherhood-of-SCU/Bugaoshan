import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';
import 'package:bugaoshan/services/update_service.dart';
import 'package:bugaoshan/utils/app_shapes.dart';
import 'package:bugaoshan/utils/open_link.dart'
    show openDeveloperTeam, openProjectRepository;
import 'package:bugaoshan/pages/settings/eula_status_page.dart';
import 'package:bugaoshan/pages/dev/dev_page.dart';
import 'package:bugaoshan/widgets/common/info_card.dart';
import 'package:bugaoshan/widgets/common/styled_tile.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:bugaoshan/widgets/dialog/download_progress_dialog.dart';
import 'package:bugaoshan/widgets/dialog/update_dialog.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final versionProvider = getIt<AppInfoProvider>();
  final updateService = getIt<UpdateService>();
  final appConfig = getIt<AppConfigProvider>();
  bool _isCheckingUpdate = false;

  Future<void> _checkForUpdates() async {
    if (_isCheckingUpdate) return;
    final localizations = AppLocalizations.of(context)!;

    appConfig.hasUpdateNotification.value = false;
    setState(() => _isCheckingUpdate = true);
    try {
      final result = await updateService.checkForUpdate();
      if (!mounted) return;

      if (result.hasUpdate && result.release != null) {
        if (result.downloadUrl != null) {
          await showUpdateDialog(
            context: context,
            version: result.version!,
            releaseNotes: result.releaseNotes,
            onStartUpdate: () => _startUpdate(
              result.version!,
              result.downloadUrl!,
              checksumSha256: result.release?.checksumSha256,
            ),
          );
        }

        if (!mounted) return;
      } else if (result.status == UpdateCheckStatus.error) {
        showInfoDialog(
          title: localizations.checkForUpdates,
          content: localizations.loadFailed,
        );
      } else {
        showInfoDialog(
          title: localizations.checkForUpdates,
          content: localizations.noUpdateAvailable,
        );
      }
    } catch (e) {
      if (mounted) {
        showInfoDialog(
          title: localizations.checkForUpdates,
          content: localizations.loadFailed,
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingUpdate = false);
    }
  }

  void _startUpdate(
    String latestVersion,
    String downloadUrl, {
    String? checksumSha256,
  }) async {
    await showDownloadProgressDialog(
      context: context,
      version: latestVersion,
      downloadUrl: downloadUrl,
      checksumSha256: checksumSha256,
      updateService: updateService,
    );
  }

  Widget _buildHeader(
    ThemeData theme,
    Color primaryColor,
    Color onSurfaceVariant,
    AppLocalizations localizations,
  ) {
    return Center(
      child: Column(
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppShapes.largeIncreased),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.2),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(AppShapes.largeIncreased),
              child: Image.asset('assets/icon.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            localizations.bugaoshan,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            localizations.appDescription,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.about)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Header section with icon and app name
          _buildHeader(theme, primaryColor, onSurfaceVariant, localizations),
          const SizedBox(height: 32),

          // Project info card
          InfoCard(
            children: [
              IconTile(
                icon: Icons.apps_rounded,
                label: localizations.appName,
                value: localizations.bugaoshan,
              ),
              IconTile(
                icon: Icons.info_outline_rounded,
                label: localizations.version,
                value: versionProvider.currentVersion,
              ),
              if (versionProvider.gitTag != 'null')
                IconTile(
                  icon: Icons.local_offer_outlined,
                  label: localizations.gitTag,
                  value: versionProvider.gitTag,
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Links card
          InfoCard(
            children: [
              LinkTile(
                icon: Icons.code_rounded,
                label: localizations.projectRepository,
                value: "Github",
                onTap: () => openProjectRepository(),
              ),
              LinkTile(
                icon: Icons.group_outlined,
                label: localizations.developmentTeam,
                value: "Brotherhood of SCU",
                onTap: () => openDeveloperTeam(),
              ),
              if (updateService.supportsInAppUpdate)
                ValueListenableBuilder<bool>(
                  valueListenable: appConfig.hasUpdateNotification,
                  builder: (context, hasUpdate, _) {
                    return BadgedTile(
                      icon: Icons.update_rounded,
                      label: localizations.checkForUpdates,
                      showBadge: hasUpdate,
                      onTap: _checkForUpdates,
                      trailing: _isCheckingUpdate
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : null,
                    );
                  },
                ),
              IconTile(
                icon: Icons.gavel,
                label: localizations.eulaTitle,
                onTap: () => popupOrNavigate(context, const EulaStatusPage()),
              ),
              IconTile(
                icon: Icons.description_outlined,
                label: localizations.openSourceLicenses,
                onTap: () => showLicensePage(
                  context: context,
                  applicationName: localizations.bugaoshan,
                  applicationVersion: versionProvider.currentVersion,
                ),
              ),
              IconTile(
                icon: Icons.bug_report_outlined,
                label: localizations.devPage,
                onTap: () => popupOrNavigate(context, const DevPage()),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Footer text
          Center(
            child: Text(
              localizations.openSourceLicenseDesc,
              style: theme.textTheme.bodySmall?.copyWith(
                color: onSurfaceVariant.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Copyright © 2026 The-Brotherhood-of-SCU',
              style: theme.textTheme.bodySmall?.copyWith(
                color: onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
