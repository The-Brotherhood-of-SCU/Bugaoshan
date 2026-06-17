import 'dart:io';

import 'package:bugaoshan/pages/dev/ui/ui_tile.dart';
import 'package:flutter/material.dart';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/dev/auth_log/auth_log_tile.dart';
import 'package:bugaoshan/pages/dev/environment_info_tile.dart';
import 'package:bugaoshan/pages/dev/update_card.dart';
import 'package:bugaoshan/pages/dev/update_result_notifier.dart';
import 'package:bugaoshan/pages/dev/wizard_reset_tile.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';
import 'package:bugaoshan/services/update_service.dart';
import 'package:bugaoshan/widgets/dialog/download_progress_dialog.dart';
import 'package:bugaoshan/widgets/dialog/update_dialog.dart';

class DevPage extends StatefulWidget {
  const DevPage({super.key});

  @override
  State<DevPage> createState() => _DevPageState();
}

class _DevPageState extends State<DevPage> {
  final _versionInfoProvider = getIt<AppInfoProvider>();
  final _appConfig = getIt<AppConfigProvider>();
  final _stableResult = UpdateResultNotifier();
  final _previewResult = UpdateResultNotifier();

  bool get _supportsUpdate =>
      Platform.isAndroid || Platform.isWindows || Platform.isLinux;

  Future<void> _checkForUpdates() async {
    if (!_supportsUpdate) return;
    final updateService = getIt<UpdateService>();

    _stableResult.value = UpdateCheckResult.checking();
    _previewResult.value = UpdateCheckResult.checking();

    try {
      final currentVersion = _versionInfoProvider.currentVersion;
      final gitTag = _versionInfoProvider.gitTag;
      final (stable, preview) = await updateService.getAllLatestReleases();
      _stableResult.value =
          stable != null &&
              stable.tagName != null &&
              updateService.hasUpdate(currentVersion, stable.tagName!)
          ? UpdateCheckResult.hasUpdate(stable)
          : UpdateCheckResult.noUpdate();
      _previewResult.value = preview != null && preview.tagName != gitTag
          ? UpdateCheckResult.hasUpdate(preview)
          : UpdateCheckResult.noUpdate();
    } catch (e) {
      final error = UpdateCheckResult.error(e.toString());
      _stableResult.value = error;
      _previewResult.value = error;
    }
  }

  void _showUpdateDialog(UpdateCheckResult result) {
    showUpdateDialog(
      context: context,
      version: result.version!,
      releaseNotes: result.releaseNotes,
      isPreview: result.isPrerelease,
      onStartUpdate: () => _startUpdate(result.version!, result.downloadUrl!),
    );
  }

  void _startUpdate(String latestVersion, String downloadUrl) async {
    final updateService = getIt<UpdateService>();
    await showDownloadProgressDialog(
      context: context,
      version: latestVersion,
      downloadUrl: downloadUrl,
      updateService: updateService,
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.devPage)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const EnvironmentInfoTile(),
          const Divider(),
          const WizardResetTile(),
          const Divider(),
          const AuthLogTile(),
          const Divider(),
          const UiTile(),
          const Divider(),
          if (_supportsUpdate) ...[
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                localizations.updateToLatest,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            ListenableBuilder(
              listenable: _appConfig.usePreviewUpdateSource,
              builder: (context, _) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(localizations.usePreviewUpdateSource),
                subtitle: Text(
                  localizations.usePreviewUpdateSourceHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                value: _appConfig.usePreviewUpdateSource.value,
                onChanged: (v) => _appConfig.usePreviewUpdateSource.value = v,
              ),
            ),
            const SizedBox(height: 12),
            UpdateCard(
              icon: Icons.system_update_alt,
              title: localizations.updateToStable,
              result: _stableResult,
              onUpdate: () => _showUpdateDialog(_stableResult.value),
            ),
            const SizedBox(height: 16),
            UpdateCard(
              icon: Icons.science,
              title: localizations.updateToPreview,
              result: _previewResult,
              onUpdate: () => _showUpdateDialog(_previewResult.value),
            ),
            const SizedBox(height: 16),
            Center(
              child: ElevatedButton.icon(
                onPressed: _checkForUpdates,
                icon: const Icon(Icons.system_update),
                label: Text(localizations.checkForUpdates),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
