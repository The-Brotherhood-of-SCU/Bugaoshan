import 'package:bugaoshan/pages/dev/ui/ui_tile.dart';
import 'package:flutter/material.dart';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/dev/auth_log/auth_log_tile.dart';
import 'package:bugaoshan/pages/dev/changelog/changelog_tile.dart';
import 'package:bugaoshan/pages/dev/environment_info_tile.dart';
import 'package:bugaoshan/pages/dev/update_card.dart';
import 'package:bugaoshan/pages/dev/wizard_reset_tile.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/update_provider.dart';
import 'package:bugaoshan/services/update_service.dart';
import 'package:bugaoshan/widgets/dialog/download_progress_dialog.dart';
import 'package:bugaoshan/widgets/dialog/update_dialog.dart';

class DevPage extends StatefulWidget {
  const DevPage({super.key});

  @override
  State<DevPage> createState() => _DevPageState();
}

class _DevPageState extends State<DevPage> {
  final _appConfig = getIt<AppConfigProvider>();
  final _updateProvider = getIt<UpdateProvider>();

  bool get _supportsUpdate => _updateProvider.supportsInAppUpdate;

  Future<void> _checkForUpdates() async {
    if (!_supportsUpdate) return;
    try {
      await _updateProvider.getAllLatestReleases();
    } catch (_) {
      // provider 已将 error 状态填充到 stableResult/previewResult,此处仅吞异常
    }
  }

  void _showUpdateDialog(ValueNotifier<UpdateCheckResult> result) {
    final value = result.value;
    showUpdateDialog(
      context: context,
      version: value.version!,
      releaseNotes: value.releaseNotes,
      isPreview: value.isPrerelease,
      onStartUpdate: () => _startUpdate(
        value.version!,
        value.downloadUrl!,
        filename: value.filename!,
        checksumSha256: value.release?.checksumSha256,
      ),
    );
  }

  void _startUpdate(
    String latestVersion,
    String downloadUrl, {
    required String filename,
    String? checksumSha256,
  }) async {
    await showDownloadProgressDialog(
      context: context,
      version: latestVersion,
      downloadUrl: downloadUrl,
      filename: filename,
      checksumSha256: checksumSha256,
      updateProvider: _updateProvider,
    );
  }

  List<Widget> _buildUpdateSection(
    BuildContext context,
    AppLocalizations localizations,
  ) {
    return [
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
        builder: (BuildContext context, _) => SwitchListTile(
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
        result: _updateProvider.stableResult,
        onUpdate: () => _showUpdateDialog(_updateProvider.stableResult),
      ),
      const SizedBox(height: 16),
      UpdateCard(
        icon: Icons.science,
        title: localizations.updateToPreview,
        result: _updateProvider.previewResult,
        onUpdate: () => _showUpdateDialog(_updateProvider.previewResult),
      ),
      const SizedBox(height: 16),
      Center(
        child: ElevatedButton.icon(
          onPressed: _checkForUpdates,
          icon: const Icon(Icons.system_update),
          label: Text(localizations.checkForUpdates),
        ),
      ),
    ];
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
          const ChangelogTile(),
          const Divider(),
          if (_supportsUpdate) ..._buildUpdateSection(context, localizations),
        ],
      ),
    );
  }
}
