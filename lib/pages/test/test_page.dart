import 'dart:io';

import 'package:flutter/material.dart';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/about/release_notes_page.dart';
import 'package:bugaoshan/pages/test/environment_info_button.dart';
import 'package:bugaoshan/pages/test/update_card.dart';
import 'package:bugaoshan/pages/test/update_progress_state.dart';
import 'package:bugaoshan/pages/test/update_result_notifier.dart';
import 'package:bugaoshan/pages/test/wizard_reset_button.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:bugaoshan/services/update_service.dart';

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  final _versionInfoProvider = getIt<AppInfoProvider>();
  final _stableResult = UpdateResultNotifier();
  final _previewResult = UpdateResultNotifier();

  bool get _supportsUpdate =>
      Platform.isAndroid || Platform.isWindows || Platform.isLinux;

  Future<void> _checkForUpdates() async {
    if (!_supportsUpdate) return;
    final updateService = getIt<UpdateService>();
    final currentVersion = _versionInfoProvider.currentVersion;
    final gitTag = _versionInfoProvider.gitTag;

    _stableResult.value = UpdateCheckResult.checking();
    _previewResult.value = UpdateCheckResult.checking();

    final results = await Future.wait([
      updateService.checkStableUpdate(currentVersion),
      updateService.checkPreviewUpdate(currentVersion, gitTag),
    ]);

    _stableResult.value = results[0];
    _previewResult.value = results[1];
  }

  void _showUpdateDialog(UpdateCheckResult result) {
    final localizations = AppLocalizations.of(context)!;
    final isPreview = result.isPrerelease;
    final outerContext = context;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(isPreview ? Icons.science : Icons.system_update_alt),
            const SizedBox(width: 8),
            Text(localizations.newVersionAvailable),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${localizations.version}: ${result.version}'),
            if (isPreview) ...[
              const SizedBox(height: 8),
              Text(
                localizations.preReleaseWarning,
                style: const TextStyle(color: Colors.orange),
              ),
            ],
          ],
        ),
        actions: [
          if (result.releaseNotes != null && result.releaseNotes!.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                popupOrNavigate(
                  outerContext,
                  ReleaseNotesPage(
                    version: result.version!,
                    releaseNotes: result.releaseNotes!,
                  ),
                );
              },
              child: Text(localizations.releaseNotes),
            ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.neverMind),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startUpdate(result.version!, result.downloadUrl!);
            },
            child: Text(
              isPreview
                  ? localizations.startUpdatePreview
                  : localizations.startUpdate,
            ),
          ),
        ],
      ),
    );
  }

  String _proxyDownloadUrl(String url) => 'https://gh-proxy.org/$url';

  void _startUpdate(String latestVersion, String downloadUrl) async {
    final updateService = getIt<UpdateService>();
    final localizations = AppLocalizations.of(context)!;
    downloadUrl = _proxyDownloadUrl(downloadUrl);
    final progressState = UpdateProgressState();
    final cancelToken = CancelToken();

    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        content: ListenableBuilder(
          listenable: progressState,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('${progressState.status} ${progressState.percent}%'),
              if (progressState.total > 0) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: progressState.received / progressState.total,
                ),
                const SizedBox(height: 4),
                Text(
                  '${_formatBytes(progressState.received)} / ${_formatBytes(progressState.total)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              cancelToken.cancel();
              Navigator.of(dialogContext).pop();
            },
            child: Text(localizations.cancel),
          ),
        ],
      ),
    );

    try {
      await updateService.downloadAndInstall(
        latestVersion,
        downloadUrl,
        cancelToken: cancelToken,
        onStatus: (status) => progressState.setStatus(status),
        onProgress: (received, total) =>
            progressState.setProgress(received, total),
      );
    } on UpdateCancelledException {
      return; // already popped
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).maybePop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${localizations.updateFailed}: $e')),
        );
      }
      return;
    }

    if (mounted) {
      Navigator.of(context, rootNavigator: true).maybePop();
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void _showEnvironmentInfoDialog(BuildContext context) async {
    final localizations = AppLocalizations.of(context)!;
    final versionInfo = await _versionInfoProvider.getVersionInfo();
    if (!context.mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.info_outline),
            const SizedBox(width: 8),
            Text(localizations.environmentInfo),
          ],
        ),
        content: SelectableText(
          versionInfo,
          style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.confirm),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.testPage)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: localizations.environmentInfo),
            const SizedBox(height: 12),
            EnvironmentInfoButton(
              onPressed: () => _showEnvironmentInfoDialog(context),
            ),
            const SizedBox(height: 32),
            const _SectionTitle(title: 'Wizard'),
            const SizedBox(height: 12),
            const WizardResetButton(),
            const SizedBox(height: 32),
            if (_supportsUpdate) ...[
              _SectionTitle(title: localizations.updateToLatest),
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
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
    );
  }
}
