import 'dart:io';

import 'package:flutter/material.dart';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/release_notes_page.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';
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
  final UpdateInfo _stableInfo = UpdateInfo();
  final UpdateInfo _previewInfo = UpdateInfo();

  bool get _supportsUpdate =>
      Platform.isAndroid || Platform.isWindows || Platform.isLinux;

  Future<void> _checkForUpdates() async {
    if (!_supportsUpdate) return;
    final updateService = getIt<UpdateService>();
    final currentVersion = _versionInfoProvider.currentVersion;

    _stableInfo.setChecking(true, null);
    _previewInfo.setChecking(true, null);

    await Future.wait([
      _checkStableUpdate(updateService, currentVersion),
      _checkPreviewUpdate(updateService, currentVersion),
    ]);

    if (!_stableInfo.hasVersion && !_previewInfo.hasVersion && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.noUpdateAvailable),
        ),
      );
    }
  }

  Future<void> _checkStableUpdate(
    UpdateService service,
    String currentVersion,
  ) async {
    try {
      final latest = await service.getLatestReleaseFromGitHub();
      if (latest != null &&
          latest.tagName != null &&
          service.hasUpdate(currentVersion, latest.tagName!)) {
        _stableInfo.setResult(
          latest.tagName,
          latest.downloadUrl,
          null,
          latest.body,
        );
      } else {
        _stableInfo.setChecking(false, null);
      }
    } catch (e) {
      _stableInfo.setChecking(false, e.toString());
    }
  }

  Future<void> _checkPreviewUpdate(
    UpdateService service,
    String currentVersion,
  ) async {
    try {
      final release = await service.getLatestPrereleaseFromGitHub();
      if (release.tagName != null && release.downloadUrl != null) {
        _previewInfo.setResult(
          release.tagName,
          release.downloadUrl,
          release.isPrerelease,
          release.body,
        );
      } else {
        _previewInfo.setChecking(false, null);
      }
    } catch (e) {
      _previewInfo.setChecking(false, e.toString());
    }
  }

  void _showUpdateDialog(
    String latestVersion,
    String downloadUrl,
    bool isPreview,
    String? releaseNotes,
  ) {
    final localizations = AppLocalizations.of(context)!;
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
            Text('${localizations.version}: $latestVersion'),
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
          if (releaseNotes != null && releaseNotes.isNotEmpty)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ReleaseNotesPage(
                      version: latestVersion,
                      releaseNotes: releaseNotes,
                    ),
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
              _startUpdate(latestVersion, downloadUrl);
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
            if (_supportsUpdate) ...[
              _SectionTitle(title: localizations.updateToLatest),
              const SizedBox(height: 12),
              _UpdateCard(
                icon: Icons.system_update_alt,
                title: localizations.updateToStable,
                info: _stableInfo,
                onUpdate: () => _showUpdateDialog(
                  _stableInfo.version!,
                  _stableInfo.downloadUrl!,
                  false,
                  _stableInfo.releaseNotes,
                ),
              ),
              const SizedBox(height: 16),
              _UpdateCard(
                icon: Icons.science,
                title: localizations.updateToPreview,
                info: _previewInfo,
                onUpdate: () => _showUpdateDialog(
                  _previewInfo.version!,
                  _previewInfo.downloadUrl!,
                  true,
                  _previewInfo.releaseNotes,
                ),
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

class UpdateInfo extends ChangeNotifier {
  String? _version;
  String? _downloadUrl;
  bool _isPrerelease = false;
  bool _checking = false;
  String? _error;
  String? _releaseNotes;

  String? get version => _version;
  String? get downloadUrl => _downloadUrl;
  bool get isPrerelease => _isPrerelease;
  bool get checking => _checking;
  String? get error => _error;
  String? get releaseNotes => _releaseNotes;
  bool get hasVersion => _version != null;

  void setChecking(bool checking, String? error) {
    _checking = checking;
    _error = error;
    notifyListeners();
  }

  void setResult(
    String? version,
    String? downloadUrl,
    bool? isPrerelease,
    String? releaseNotes,
  ) {
    _version = version;
    _downloadUrl = downloadUrl;
    if (isPrerelease != null) _isPrerelease = isPrerelease;
    _releaseNotes = releaseNotes;
    _checking = false;
    notifyListeners();
  }
}

class _UpdateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final UpdateInfo info;
  final VoidCallback onUpdate;

  const _UpdateCard({
    required this.icon,
    required this.title,
    required this.info,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: info,
      builder: (context, _) => Card(
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
                  if (info.checking) ...[
                    const Spacer(),
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ],
                ],
              ),
              if (info.error != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Error: ${info.error}',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              if (info.hasVersion && info.downloadUrl != null) ...[
                const SizedBox(height: 8),
                Text(
                  info.isPrerelease
                      ? 'Preview: ${info.version}'
                      : 'Stable: ${info.version}',
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
