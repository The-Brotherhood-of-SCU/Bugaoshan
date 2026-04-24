import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';
import 'package:bugaoshan/serivces/update_service.dart';

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  final _versionInfoProvider = getIt<AppInfoProvider>();
  String? _prereleaseVersion;
  String? _prereleaseDownloadUrl;
  bool _isPrerelease = false;
  bool _checkingPrerelease = false;
  String? _prereleaseError;

  bool get _isWindowsOrLinux => Platform.isWindows || Platform.isLinux;

  Future<void> _checkForPrereleaseUpdates() async {
    if (!_isWindowsOrLinux) return;
    setState(() {
      _checkingPrerelease = true;
      _prereleaseError = null;
    });

    try {
      final updateService = getIt<UpdateService>();
      final (prerelease, downloadUrl, isPrerelease) =
          await updateService.getLatestPrereleaseFromGitHub();
      setState(() {
        _prereleaseVersion = prerelease;
        _prereleaseDownloadUrl = downloadUrl;
        _isPrerelease = isPrerelease;
        _checkingPrerelease = false;
      });
    } catch (e) {
      setState(() {
        _prereleaseError = e.toString();
        _checkingPrerelease = false;
      });
    }
  }

  void _showPrereleaseUpdateDialog(String latestVersion, String downloadUrl) {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(_isPrerelease ? Icons.science : Icons.system_update_alt),
            const SizedBox(width: 8),
            Text(localizations.newVersionAvailable),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${localizations.version}: $latestVersion'),
            if (_isPrerelease) ...[
              const SizedBox(height: 8),
              const Text(
                'This is a pre-release version. Use with caution.',
                style: TextStyle(color: Colors.orange),
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
            child: Text(_isPrerelease ? localizations.startUpdatePreview : localizations.startUpdate),
          ),
        ],
      ),
    );
  }

  void _startUpdate(String latestVersion, String downloadUrl) async {
    final updateService = getIt<UpdateService>();

    final downloadProgress = ValueNotifier<(int, int)>((0, 0));

    showDialog(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (context) => ValueListenableBuilder<(int, int)>(
        valueListenable: downloadProgress,
        builder: (context, progress, _) {
          final percent = progress.$2 > 0
              ? ((progress.$1 / progress.$2) * 100).toInt()
              : 0;
          return AlertDialog(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Downloading update... $percent%'),
                if (progress.$2 > 0) ...[
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: progress.$1 / progress.$2,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_formatBytes(progress.$1)} / ${_formatBytes(progress.$2)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );

    try {
      await updateService.downloadAndInstall(
        latestVersion,
        downloadUrl,
        onStatus: (status) {},
        onProgress: (received, total) {
          downloadProgress.value = (received, total);
        },
      );
    } catch (e) {
      if (mounted) {
        Navigator.of(context, rootNavigator: true).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Update failed: $e')),
        );
      }
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
            if (_isWindowsOrLinux) ...[
              _SectionTitle(title: localizations.forceUpdate),
              const SizedBox(height: 12),
              _UpdateToLatestCard(
                prereleaseVersion: _prereleaseVersion,
                isPrerelease: _isPrerelease,
                checkingPrerelease: _checkingPrerelease,
                prereleaseError: _prereleaseError,
                onCheck: _checkForPrereleaseUpdates,
                onUpdate: () {
                  if (_prereleaseVersion != null &&
                      _prereleaseDownloadUrl != null) {
                    _showPrereleaseUpdateDialog(
                      _prereleaseVersion!,
                      _prereleaseDownloadUrl!,
                    );
                  }
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UpdateToLatestCard extends StatelessWidget {
  final String? prereleaseVersion;
  final bool isPrerelease;
  final bool checkingPrerelease;
  final String? prereleaseError;
  final VoidCallback onCheck;
  final VoidCallback onUpdate;

  const _UpdateToLatestCard({
    required this.prereleaseVersion,
    required this.isPrerelease,
    required this.checkingPrerelease,
    required this.prereleaseError,
    required this.onCheck,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(isPrerelease ? Icons.science : Icons.system_update_alt, size: 20),
                const SizedBox(width: 8),
                Text(
                  isPrerelease ? 'Preview Version Available' : 'Update to Latest Version',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Spacer(),
                if (checkingPrerelease)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  ElevatedButton(
                    onPressed: onCheck,
                    child: Text(localizations.checkForUpdates),
                  ),
              ],
            ),
            if (prereleaseError != null) ...[
              const SizedBox(height: 8),
              Text(
                'Error: $prereleaseError',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (prereleaseVersion != null) ...[
              const SizedBox(height: 8),
              Text(
                isPrerelease ? 'Preview: $prereleaseVersion' : 'Latest: $prereleaseVersion',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: onUpdate,
                icon: Icon(isPrerelease ? Icons.science : Icons.system_update_alt),
                label: Text(localizations.newVersionAvailable),
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