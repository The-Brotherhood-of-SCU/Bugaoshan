import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';
import 'package:bugaoshan/services/update_service.dart';
import 'package:bugaoshan/utils/open_link.dart';
import 'package:bugaoshan/pages/release_notes_page.dart';
import 'package:bugaoshan/pages/test_page.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

class AboutPage extends StatefulWidget {
  const AboutPage({super.key});

  @override
  State<AboutPage> createState() => _AboutPageState();
}

class _AboutPageState extends State<AboutPage> {
  final versionProvider = getIt<AppInfoProvider>();
  final updateService = UpdateService();

  Future<void> _checkForUpdates() async {
    final localizations = AppLocalizations.of(context)!;

    try {
      final latest = await updateService.getLatestReleaseFromGitHub();
      if (!mounted) return;

      if (latest != null &&
          latest.tagName != null &&
          updateService.hasUpdate(
              versionProvider.currentVersion, latest.tagName!)) {
        await showDialog(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
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
                children: [
                  Text('${localizations.version}: ${latest.tagName}'),
                ],
              ),
              actions: [
                if (latest.body != null && latest.body!.isNotEmpty)
                  TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReleaseNotesPage(
                            version: latest.tagName!,
                            releaseNotes: latest.body!,
                          ),
                        ),
                      );
                    },
                    child: Text(localizations.releaseNotes),
                  ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text(localizations.neverMind),
                ),
                if (latest.downloadUrl != null)
                  ElevatedButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      _startUpdate(latest.tagName!, latest.downloadUrl!);
                    },
                    child: Text(localizations.startUpdate),
                  ),
              ],
            );
          },
        );

        if (!mounted) return;
      } else {
        showInfoDialog(
          title: localizations.checkForUpdates,
          content: localizations.noUpdateAvailable,
        );
      }
    } catch (e) {
      if (mounted) {
        showInfoDialog(
          title: localizations.checkForUpdates,
          content: localizations.loadFailed,
        );
      }
    }
  }

  String _proxyDownloadUrl(String url) =>
      'https://gh-proxy.org/$url';

  void _startUpdate(String latestVersion, String downloadUrl) async {
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
      return;
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

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(localizations.about)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 32),
            CircleAvatar(
              radius: 60,
              backgroundImage: const AssetImage('assets/avater.png'),
              backgroundColor: const Color.fromARGB(255, 255, 255, 255),
            ),
            const SizedBox(height: 24),
            Text(
              localizations.developedBy("The Brotherhood of SCU"),
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 18,
                  horizontal: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      localizations.projectInfo,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildInfoItem(
                      context,
                      Icons.apps,
                      localizations.appName,
                      localizations.bugaoshan,
                    ),
                    const SizedBox(height: 12),
                    _buildInfoItem(
                      context,
                      Icons.info_outline,
                      localizations.version,
                      versionProvider.currentVersion,
                    ),
                    if (versionProvider.gitTag != 'null') ...[
                      const SizedBox(height: 12),
                      _buildInfoItem(
                        context,
                        Icons.local_offer,
                        localizations.gitTag,
                        versionProvider.gitTag,
                      ),
                    ],
                    const SizedBox(height: 12),
                    _buildInfoItem(
                      context,
                      Icons.description,
                      localizations.description,
                      localizations.appDescription,
                    ),
                    const SizedBox(height: 15),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            externalResources(localizations),
          ],
        ),
      ),
    );
  }

  Widget externalResources(AppLocalizations localizations) {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 24,
      runSpacing: 16,
      children: [
        ElevatedButton.icon(
          onPressed: () async {
            await openProjectRepository();
          },
          label: Text(localizations.projectRepository),
          icon: Icon(Icons.open_in_new),
        ),
        ElevatedButton.icon(
          onPressed: () async {
            await openDeveloperTeam();
          },
          label: Text(localizations.developmentTeam),
          icon: Icon(Icons.open_in_new),
        ),
        ElevatedButton.icon(
          onPressed: () => popupOrNavigate(context, const TestPage()),
          label: Text(localizations.testPage),
          icon: Icon(Icons.bug_report),
        ),
        ElevatedButton.icon(
          onPressed: _checkForUpdates,
          label: Text(localizations.checkForUpdates),
          icon: Icon(Icons.update),
        ),
      ],
    );
  }

  Widget _buildInfoItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              Text(value, style: theme.textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}

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
