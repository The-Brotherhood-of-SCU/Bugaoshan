import 'dart:io';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:updat/updat.dart';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';

class TestPage extends StatefulWidget {
  const TestPage({super.key});

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> {
  final _versionInfoProvider = getIt<AppInfoProvider>();
  String? _latestVersion;
  bool _checkingUpdate = false;
  String? _updateError;

  bool get _isWindowsOrLinux => Platform.isWindows || Platform.isLinux;

  Future<void> _checkForUpdates() async {
    if (!_isWindowsOrLinux) return;
    setState(() {
      _checkingUpdate = true;
      _updateError = null;
    });

    try {
      final latest = await _getLatestVersionFromGitHub();
      setState(() {
        _latestVersion = latest;
        _checkingUpdate = false;
      });
    } catch (e) {
      setState(() {
        _updateError = e.toString();
        _checkingUpdate = false;
      });
    }
  }

  Future<String> _getLatestVersionFromGitHub() async {
    const repo = 'The-Brotherhood-of-SCU/Bugaoshan';
    final response = await http.get(
      Uri.parse('https://api.github.com/repos/$repo/releases/latest'),
      headers: {'Accept': 'application/vnd.github+json'},
    );
    if (response.statusCode == 200) {
      final tagName = RegExp(r'"tag_name":\s*"([^"]+)"').firstMatch(response.body)?.group(1);
      if (tagName != null) {
        return tagName.replaceFirst('v', '');
      }
    }
    throw Exception('Failed to fetch latest version');
  }

  Future<String> _getBinaryUrl(String version) async {
    const repo = 'The-Brotherhood-of-SCU/Bugaoshan';
    final platform = Platform.isWindows ? 'windows' : 'linux';
    return 'https://github.com/$repo/releases/download/v$version/bugaoshan_${version}_${platform}_x64.zip';
  }

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(localizations.testPage)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title: localizations.environmentInfo),
            const SizedBox(height: 12),
            _EnvironmentInfoCard(versionInfoProvider: _versionInfoProvider),
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
                getBinaryUrl: _getBinaryUrl,
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
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

class _EnvironmentInfoCard extends StatelessWidget {
  final AppInfoProvider versionInfoProvider;
  const _EnvironmentInfoCard({required this.versionInfoProvider});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: FutureBuilder<String>(
          future: versionInfoProvider.getVersionInfo(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return Text('Error: ${snapshot.error}');
            }
            return SelectableText(
              snapshot.data ?? '',
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            );
          },
        ),
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
  final Future<String> Function(String version) getBinaryUrl;

  const _UpdateCard({
    required this.latestVersion,
    required this.checkingUpdate,
    required this.updateError,
    required this.currentVersion,
    required this.onCheck,
    required this.getBinaryUrl,
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
              Builder(
                builder: (context) {
                  final latest = latestVersion!;
                  return UpdatWidget(
                    currentVersion: currentVersion,
                    getLatestVersion: () async => latest,
                    getBinaryUrl: (v) => getBinaryUrl(v ?? latest),
                    appName: 'bugaoshan',
                    openOnDownload: true,
                    closeOnInstall: false,
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
