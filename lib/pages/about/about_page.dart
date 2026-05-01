import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';
import 'package:bugaoshan/services/update_service.dart';
import 'package:bugaoshan/utils/open_link.dart'
    show openDeveloperTeam, openProjectRepository;
import 'package:bugaoshan/pages/about/release_notes_page.dart';
import 'package:bugaoshan/pages/about/test_page.dart';
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
  bool _isCheckingUpdate = false;

  Future<void> _checkForUpdates() async {
    if (_isCheckingUpdate) return;
    final localizations = AppLocalizations.of(context)!;

    setState(() => _isCheckingUpdate = true);
    try {
      final latest = await updateService.getLatestReleaseFromGitHub();
      if (!mounted) return;

      if (latest != null &&
          latest.tagName != null &&
          updateService.hasUpdate(
            versionProvider.currentVersion,
            latest.tagName!,
          )) {
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
                children: [Text('${localizations.version}: ${latest.tagName}')],
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
    } finally {
      if (mounted) setState(() => _isCheckingUpdate = false);
    }
  }

  String _proxyDownloadUrl(String url) => 'https://gh-proxy.org/$url';

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
    final primaryColor = theme.colorScheme.primary;
    final surfaceColor = theme.colorScheme.surface;
    final onSurfaceVariant = theme.colorScheme.onSurfaceVariant;

    return Scaffold(
      appBar: AppBar(title: Text(localizations.about)),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // Header section with icon and app name
          Center(
            child: Column(
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.2),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset('assets/icon.png', fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  localizations.bugaoshan,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  localizations.appDescription,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          // Project info card
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              children: [
                _InfoTile(
                  icon: Icons.apps_rounded,
                  label: localizations.appName,
                  value: localizations.bugaoshan,
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  color: theme.dividerColor.withValues(alpha: 0.08),
                ),
                _InfoTile(
                  icon: Icons.info_outline_rounded,
                  label: localizations.version,
                  value: versionProvider.currentVersion,
                ),
                if (versionProvider.gitTag != 'null') ...[
                  Divider(
                    height: 1,
                    indent: 56,
                    color: theme.dividerColor.withValues(alpha: 0.08),
                  ),
                  _InfoTile(
                    icon: Icons.local_offer_outlined,
                    label: localizations.gitTag,
                    value: versionProvider.gitTag,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Links card
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: theme.dividerColor.withValues(alpha: 0.08),
              ),
            ),
            child: Column(
              children: [
                _InfoTile(
                  icon: Icons.code_rounded,
                  label: localizations.projectRepository,
                  value: 'GitHub',
                  isLink: true,
                  onTap: () => openProjectRepository(),
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  color: theme.dividerColor.withValues(alpha: 0.08),
                ),
                _InfoTile(
                  icon: Icons.group_outlined,
                  label: localizations.developmentTeam,
                  value: 'The Brotherhood of SCU',
                  isLink: true,
                  onTap: () => openDeveloperTeam(),
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  color: theme.dividerColor.withValues(alpha: 0.08),
                ),
                _InfoTile(
                  icon: Icons.update_rounded,
                  label: localizations.checkForUpdates,
                  value: '',
                  loading: _isCheckingUpdate,
                  onTap: _checkForUpdates,
                ),
                Divider(
                  height: 1,
                  indent: 56,
                  color: theme.dividerColor.withValues(alpha: 0.08),
                ),
                _InfoTile(
                  icon: Icons.bug_report_outlined,
                  label: localizations.testPage,
                  value: '',
                  onTap: () => popupOrNavigate(context, const TestPage()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Footer text
          Center(
            child: Text(
              localizations.openSourceLicenseDesc,
              style: theme.textTheme.bodySmall?.copyWith(
                color: onSurfaceVariant.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Text(
              'Copyright © 2026 The-Brotherhood-of-SCU',
              style: theme.textTheme.bodySmall?.copyWith(
                color: onSurfaceVariant.withValues(alpha: 0.6),
              ),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool isLink;
  final bool loading;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.onTap,
    this.isLink = false,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = theme.colorScheme.primary;

    final tile = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: primaryColor, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(label, style: theme.textTheme.bodyLarge)),
          if (value.isNotEmpty || onTap != null)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (value.isNotEmpty)
                  Text(
                    value,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                if (loading) ...[
                  const SizedBox(width: 4),
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ] else if (onTap != null) ...[
                  const SizedBox(width: 8),
                  Icon(
                    isLink ? Icons.open_in_new : Icons.chevron_right_rounded,
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.4,
                    ),
                    size: isLink ? 18 : 20,
                  ),
                ],
              ],
            ),
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: tile,
      );
    }
    return tile;
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
