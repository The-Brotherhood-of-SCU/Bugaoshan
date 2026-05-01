import 'dart:io';

import 'package:flutter/material.dart';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/about/release_notes_page.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:bugaoshan/services/update_service.dart';

class _DownloadProgressState extends ChangeNotifier {
  String _status = 'Downloading...';
  int _received = 0;
  int _total = 0;

  String get status => _status;
  int get received => _received;
  int get total => _total;
  int get percent => _total > 0 ? ((_received / _total) * 100).toInt() : 0;

  void setStatus(String status) {
    _status = status;
    notifyListeners();
  }

  void setProgress(int received, int total) {
    _received = received;
    _total = total;
    notifyListeners();
  }
}

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  final _versionInfoProvider = getIt<AppInfoProvider>();
  final _stableResult = _ResultNotifier();
  final _previewResult = _ResultNotifier();

  bool get _supportsUpdate =>
      Platform.isAndroid || Platform.isWindows || Platform.isLinux;

  Future<void> _checkForUpdates() async {
    if (!_supportsUpdate) return;
    final updateService = getIt<UpdateService>();
    final currentVersion = _versionInfoProvider.currentVersion;

    _stableResult.value = UpdateCheckResult.checking();
    _previewResult.value = UpdateCheckResult.checking();

    final results = await Future.wait([
      updateService.checkStableUpdate(currentVersion),
      updateService.checkPreviewUpdate(currentVersion),
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
    final progressState = _DownloadProgressState();
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
            _EnvironmentInfoButton(
              onPressed: () => _showEnvironmentInfoDialog(context),
            ),
            const SizedBox(height: 32),
            const _SectionTitle(title: 'Wizard'),
            const SizedBox(height: 12),
            const _WizardResetButton(),
            const SizedBox(height: 32),
            if (_supportsUpdate) ...[
              _SectionTitle(title: localizations.updateToLatest),
              const SizedBox(height: 12),
              _UpdateCard(
                icon: Icons.system_update_alt,
                title: localizations.updateToStable,
                result: _stableResult,
                onUpdate: () => _showUpdateDialog(_stableResult.value),
              ),
              const SizedBox(height: 16),
              _UpdateCard(
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

class _ResultNotifier extends ChangeNotifier {
  UpdateCheckResult _value = UpdateCheckResult.initial();

  UpdateCheckResult get value => _value;

  set value(UpdateCheckResult v) {
    _value = v;
    notifyListeners();
  }
}

class _UpdateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final _ResultNotifier result;
  final VoidCallback onUpdate;

  const _UpdateCard({
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

class _EnvironmentInfoButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _EnvironmentInfoButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: const Icon(Icons.info_outline),
        title: Text(AppLocalizations.of(context)!.environmentInfo),
        trailing: const Icon(Icons.chevron_right),
        onTap: onPressed,
      ),
    );
  }
}

class _WizardResetButton extends StatelessWidget {
  const _WizardResetButton();

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: ListTile(
        leading: const Icon(Icons.auto_awesome),
        title: const Text('Reset Wizard Status'),
        subtitle: const Text('Set firstLaunchWizardCompleted to false'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          getIt<AppConfigProvider>().firstLaunchWizardCompleted.value = false;
          Navigator.of(logicRootContext).popUntil((route) => route.isFirst);
        },
      ),
    );
  }
}
