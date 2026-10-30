import 'package:bugaoshan/widgets/adaptive/adaptive_glass_controls.dart';
import 'package:bugaoshan/pages/dev/ui/ui_tile.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/dev/logs/log_tile.dart';
import 'package:bugaoshan/pages/dev/logs/log_persistence_tile.dart';
import 'package:bugaoshan/pages/dev/changelog/changelog_tile.dart';
import 'package:bugaoshan/pages/dev/environment_info_tile.dart';
import 'package:bugaoshan/pages/dev/probe_tile.dart';
import 'package:bugaoshan/pages/dev/log_stress_tile.dart';
import 'package:bugaoshan/pages/dev/update_card.dart';
import 'package:bugaoshan/pages/dev/wizard_reset_tile.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/providers/riverpod/settings/app_config_pods.dart';
import 'package:bugaoshan/providers/update_provider.dart';
import 'package:bugaoshan/services/update_service.dart';
import 'package:bugaoshan/widgets/dialog/download_progress_dialog.dart';
import 'package:bugaoshan/widgets/dialog/update_dialog.dart';
import 'package:bugaoshan/utils/system_insets.dart';

class DevPage extends ConsumerStatefulWidget {
  const DevPage({super.key});

  @override
  ConsumerState<DevPage> createState() => _DevPageState();
}

class _DevPageState extends ConsumerState<DevPage> {
  static const String _tag = 'DevPageState';

  UpdateProvider get _updateProvider => ref.read(updateProviderBridge);

  bool get _supportsUpdate => _updateProvider.supportsInAppUpdate;

  Future<void> _checkForUpdates() async {
    if (!_supportsUpdate) return;
    try {
      await _updateProvider.getAllLatestReleases();
    } catch (logError, logStackTrace) {
      AppLog.e(
        _tag,
        '_checkForUpdates 失败',
        error: logError,
        stackTrace: logStackTrace,
      );
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
    final usePreview = ref.watch(usePreviewUpdateSourceSettingProvider);
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
      AdaptiveGlassSwitchListTile(
        // 不设 contentPadding：本页其余条目都是 ListTile 默认内边距，
        // 归零会让这几行的图标与文字列整体向左错开。
        title: Text(localizations.usePreviewUpdateSource),
        subtitle: Text(
          localizations.usePreviewUpdateSourceHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        value: usePreview,
        onChanged: (v) =>
            ref.read(usePreviewUpdateSourceSettingProvider.notifier).update(v),
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
    final forceCaptcha = ref.watch(forceCaptchaForDownloadSettingProvider);

    final entries = <Widget>[
      const EnvironmentInfoTile(),
      const WizardResetTile(),
      const LogTile(),
      const LogPersistenceTile(),
      if (kDebugMode) const LogStressTile(),
      const ProbeTile(),
      const UiTile(),
      const ChangelogTile(),
      AdaptiveGlassSwitchListTile(
        // 同上：与 EnvironmentInfoTile 等 ListTile 默认内边距对齐。
        secondary: const Icon(Icons.tab),
        title: Text(localizations.forceCaptchaForDownload),
        subtitle: Text(
          localizations.forceCaptchaForDownloadHint,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        value: forceCaptcha,
        onChanged: (v) =>
            ref.read(forceCaptchaForDownloadSettingProvider.notifier).update(v),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(localizations.devPage)),
      body: ListView(
        padding: withSystemBottomInset(context, const EdgeInsets.all(24)),
        children: [
          for (var i = 0; i < entries.length; i++) ...[
            if (i > 0) const Divider(),
            entries[i],
          ],
          if (_supportsUpdate) ..._buildUpdateSection(context, localizations),
        ],
      ),
    );
  }
}
