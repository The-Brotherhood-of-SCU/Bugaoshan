import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';

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
  String? _latestVersion;
  String? _latestDownloadUrl;
  String? _prereleaseVersion;
  String? _prereleaseDownloadUrl;
  bool _isPrerelease = false;
  bool _checkingUpdate = false;
  bool _checkingPrerelease = false;
  String? _updateError;
  String? _prereleaseError;

  bool get _isWindowsOrLinux => Platform.isWindows || Platform.isLinux;

  Future<void> _checkForUpdates() async {
    if (!_isWindowsOrLinux) return;
    setState(() {
      _checkingUpdate = true;
      _updateError = null;
    });

    try {
      final latest = await _getLatestReleaseFromGitHub();
      setState(() {
        _latestVersion = latest?.$1;
        _latestDownloadUrl = latest?.$2;
        _checkingUpdate = false;
      });
    } catch (e) {
      setState(() {
        _updateError = e.toString();
        _checkingUpdate = false;
      });
    }
  }

  Future<(String, String)?> _getLatestReleaseFromGitHub() async {
    const repo = 'The-Brotherhood-of-SCU/Bugaoshan';
    final response = await http.get(
      Uri.parse('https://api.github.com/repos/$repo/releases/latest'),
      headers: {'Accept': 'application/vnd.github+json'},
    );
    if (response.statusCode == 200) {
      if (response.body.isEmpty) return null;
      final data = jsonDecode(response.body);
      final tagName = (data['tag_name'] as String);
      final assets = data['assets'] as List<dynamic>;
      final platform = Platform.isWindows ? 'windows' : 'linux';
      for (final asset in assets) {
        final name = asset['name'] as String;
        if (name.toLowerCase().contains(platform)) {
          return (
            tagName.replaceFirst('v', ''),
            asset['browser_download_url'] as String,
          );
        }
      }
    }
    throw Exception('GitHub API error: ${response.statusCode}');
  }

  Future<(String?, String?, bool)> _getLatestPrereleaseFromGitHub() async {
    const repo = 'The-Brotherhood-of-SCU/Bugaoshan';
    final response = await http.get(
      Uri.parse('https://api.github.com/repos/$repo/releases'),
      headers: {'Accept': 'application/vnd.github+json'},
    );
    if (response.statusCode == 200) {
      if (response.body.isEmpty) return (null, null, false);
      final List<dynamic> releases = jsonDecode(response.body);
      if (releases.isNotEmpty && releases[0]['tag_name'] != null) {
        final tagName = (releases[0]['tag_name'] as String).replaceFirst(
          'v',
          '',
        );
        final isPrerelease = releases[0]['prerelease'] == true;
        // Find download URL from assets
        final assets = releases[0]['assets'] as List<dynamic>;
        final platform = Platform.isWindows ? 'windows' : 'linux';
        String? downloadUrl;
        for (final asset in assets) {
          final name = asset['name'] as String;
          if (name.toLowerCase().contains(platform)) {
            downloadUrl = asset['browser_download_url'] as String;
            break;
          }
        }
        return (tagName, downloadUrl, isPrerelease);
      }
      return (null, null, false);
    }
    throw Exception('GitHub API error: ${response.statusCode}');
  }

  Future<void> _checkForPrereleaseUpdates() async {
    if (!_isWindowsOrLinux) return;
    setState(() {
      _checkingPrerelease = true;
      _prereleaseError = null;
    });

    try {
      final (prerelease, downloadUrl, isPrerelease) =
          await _getLatestPrereleaseFromGitHub();
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

  void _showUpdateDialog(String latestVersion, String downloadUrl) {
    final localizations = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.system_update_alt),
            const SizedBox(width: 8),
            Text(localizations.newVersionAvailable),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [Text('${localizations.version}: $latestVersion')],
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
            child: Text(localizations.goToReleases),
          ),
        ],
      ),
    );
  }

  void _startUpdate(String latestVersion, String downloadUrl) async {
    final dialogContext = context;
    final updateService = getIt<UpdateService>();

    // Show downloading dialog
    showDialog(
      context: dialogContext,
      barrierDismissible: false,
      builder: (dialogContext) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(),
            SizedBox(width: 16),
            Text('Downloading update...'),
          ],
        ),
      ),
    );

    try {
      await updateService.downloadAndInstall(
        latestVersion,
        downloadUrl,
        onStatus: (status) {
          // Could update dialog text here if needed
        },
      );
    } catch (e) {
      if (!dialogContext.mounted) return;
      Navigator.pop(dialogContext);
      ScaffoldMessenger.of(dialogContext).showSnackBar(
        SnackBar(content: Text('Update failed: $e')),
      );
    }
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
              _UpdateCard(
                latestVersion: _latestVersion,
                checkingUpdate: _checkingUpdate,
                updateError: _updateError,
                currentVersion: _versionInfoProvider.currentVersion,
                onCheck: _checkForUpdates,
                onUpdate: () {
                  if (_latestVersion != null && _latestDownloadUrl != null) {
                    _showUpdateDialog(_latestVersion!, _latestDownloadUrl!);
                  }
                },
              ),
              const SizedBox(height: 16),
              _PrereleaseUpdateCard(
                prereleaseVersion: _prereleaseVersion,
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
            child: Text(localizations.goToReleases),
          ),
        ],
      ),
    );
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
}

class _PrereleaseUpdateCard extends StatelessWidget {
  final String? prereleaseVersion;
  final bool checkingPrerelease;
  final String? prereleaseError;
  final VoidCallback onCheck;
  final VoidCallback onUpdate;

  const _PrereleaseUpdateCard({
    required this.prereleaseVersion,
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
                const Icon(Icons.science, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Preview Version',
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
                'Preview: $prereleaseVersion',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: onUpdate,
                icon: const Icon(Icons.science),
                label: Text('${localizations.newVersionAvailable} (Preview)'),
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

class _UpdateCard extends StatelessWidget {
  final String? latestVersion;
  final bool checkingUpdate;
  final String? updateError;
  final String currentVersion;
  final VoidCallback onCheck;
  final VoidCallback onUpdate;

  const _UpdateCard({
    required this.latestVersion,
    required this.checkingUpdate,
    required this.updateError,
    required this.currentVersion,
    required this.onCheck,
    required this.onUpdate,
  });

  bool get _hasNewVersion {
    if (latestVersion == null) return false;
    try {
      final current = Version.parse(currentVersion);
      final latest = Version.parse(latestVersion!);
      return latest > current;
    } catch (_) {
      return false;
    }
  }

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
                Text(
                  '${localizations.version}: $currentVersion',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const Spacer(),
                if (checkingUpdate)
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
            if (updateError != null) ...[
              const SizedBox(height: 8),
              Text(
                'Error: $updateError',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            if (latestVersion != null) ...[
              const SizedBox(height: 8),
              Text(
                'Latest: $latestVersion',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 12),
              if (_hasNewVersion)
                ElevatedButton.icon(
                  onPressed: onUpdate,
                  icon: const Icon(Icons.system_update_alt),
                  label: Text(localizations.newVersionAvailable),
                )
              else
                Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green[600],
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      localizations.noUpdateAvailable,
                      style: TextStyle(color: Colors.green[600]),
                    ),
                  ],
                ),
            ],
          ],
        ),
      ),
    );
  }
}
