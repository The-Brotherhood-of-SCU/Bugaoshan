import 'dart:io';

import 'package:flutter/material.dart';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
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

  bool get _supportsUpdate => Platform.isAndroid || Platform.isWindows || Platform.isLinux;

  Future<void> _checkForUpdates(bool isPreview) async {
    if (!_supportsUpdate) return;
    final info = isPreview ? _previewInfo : _stableInfo;
    info.setChecking(true, null);

    try {
      final updateService = getIt<UpdateService>();
      if (isPreview) {
        final (version, url, isPrerelease) = await updateService.getLatestPrereleaseFromGitHub();
        info.setResult(version, url, isPrerelease);
      } else {
        final latest = await updateService.getLatestReleaseFromGitHub();
        if (latest != null) {
          info.setResult(latest.$1, latest.$2, null);
        } else {
          info.setChecking(false, 'No release found');
        }
      }
    } catch (e) {
      info.setChecking(false, e.toString());
    }
  }

  void _showUpdateDialog(String latestVersion, String downloadUrl, bool isPreview) {
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(localizations.neverMind),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _startUpdate(latestVersion, downloadUrl);
            },
            child: Text(isPreview ? localizations.startUpdatePreview : localizations.startUpdate),
          ),
        ],
      ),
    );
  }

  void _startUpdate(String latestVersion, String downloadUrl) async {
    final updateService = getIt<UpdateService>();
    final localizations = AppLocalizations.of(context)!;
    final progressState = _DownloadProgressState();

    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (context) => ListenableBuilder(
        listenable: progressState,
        builder: (context, _) => AlertDialog(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('${progressState.status} ${progressState.percent}%'),
              if (progressState.total > 0) ...[
                const SizedBox(height: 8),
                LinearProgressIndicator(value: progressState.received / progressState.total),
                const SizedBox(height: 4),
                Text(
                  '${_formatBytes(progressState.received)} / ${_formatBytes(progressState.total)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    try {
      await updateService.downloadAndInstall(
        latestVersion,
        downloadUrl,
        onStatus: (status) => progressState.setStatus(status),
        onProgress: (received, total) => progressState.setProgress(received, total),
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${localizations.updateFailed}: $e')),
        );
      }
      return;
    }

    if (mounted) {
      Navigator.of(context, rootNavigator: true).pop();
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
            _EnvironmentInfoButton(onPressed: () => _showEnvironmentInfoDialog(context)),
            const SizedBox(height: 32),
            if (_supportsUpdate) ...[
              _SectionTitle(title: localizations.updateToLatest),
              const SizedBox(height: 12),
              _UpdateCard(
                icon: Icons.system_update_alt,
                title: localizations.updateToStable,
                info: _stableInfo,
                onCheck: () => _checkForUpdates(false),
                onUpdate: () => _showUpdateDialog(_stableInfo.version!, _stableInfo.downloadUrl!, false),
              ),
              const SizedBox(height: 16),
              _UpdateCard(
                icon: Icons.science,
                title: localizations.updateToPreview,
                info: _previewInfo,
                onCheck: () => _checkForUpdates(true),
                onUpdate: () => _showUpdateDialog(_previewInfo.version!, _previewInfo.downloadUrl!, true),
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

  String? get version => _version;
  String? get downloadUrl => _downloadUrl;
  bool get isPrerelease => _isPrerelease;
  bool get checking => _checking;
  String? get error => _error;
  bool get hasVersion => _version != null;

  void setChecking(bool checking, String? error) {
    _checking = checking;
    _error = error;
    notifyListeners();
  }

  void setResult(String? version, String? downloadUrl, bool? isPrerelease) {
    _version = version;
    _downloadUrl = downloadUrl;
    if (isPrerelease != null) _isPrerelease = isPrerelease;
    _checking = false;
    notifyListeners();
  }
}

class _UpdateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final UpdateInfo info;
  final VoidCallback onCheck;
  final VoidCallback onUpdate;

  const _UpdateCard({
    required this.icon,
    required this.title,
    required this.info,
    required this.onCheck,
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
                  const Spacer(),
                  if (info.checking)
                    const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  else
                    ElevatedButton(onPressed: onCheck, child: Text(localizations.checkForUpdates)),
                ],
              ),
              if (info.error != null) ...[
                const SizedBox(height: 8),
                Text('Error: ${info.error}', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              if (info.hasVersion && info.downloadUrl != null) ...[
                const SizedBox(height: 8),
                Text(info.isPrerelease ? 'Preview: ${info.version}' : 'Stable: ${info.version}', style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 12),
                ElevatedButton.icon(onPressed: onUpdate, icon: Icon(icon), label: Text(localizations.newVersionAvailable)),
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
    return Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold));
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