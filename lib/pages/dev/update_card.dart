import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/update_provider.dart';
import 'package:bugaoshan/services/update_service.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';

class UpdateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final ValueNotifier<UpdateCheckResult> result;
  final VoidCallback onUpdate;

  const UpdateCard({
    super.key,
    required this.icon,
    required this.title,
    required this.result,
    required this.onUpdate,
  });

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context)!;
    final updateProvider = getIt<UpdateProvider>();

    // 与 About 页的 UpdateTile 一致:同时监听下载状态,
    // 在下载中展示进度百分比并禁用按钮,避免重入。
    return ListenableBuilder(
      listenable: Listenable.merge([
        updateProvider.isDownloading,
        updateProvider.progressState,
      ]),
      builder: (context, _) {
        final isDownloading = updateProvider.isDownloading.value;
        final percent = updateProvider.progressState.percent;
        return ValueListenableBuilder<UpdateCheckResult>(
          valueListenable: result,
          builder: (context, r, _) {
            return StyledCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(icon, size: 20),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            title,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
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
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
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
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: isDownloading ? null : onUpdate,
                                    icon: Icon(icon),
                                    label: Text(
                                      localizations.newVersionAvailable,
                                    ),
                                  ),
                                ),
                                if (isDownloading) ...[
                                  const SizedBox(width: 12),
                                  Text(
                                    '$percent%',
                                    style: Theme.of(context).textTheme.bodySmall
                                        ?.copyWith(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ],
                              ],
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
      },
    );
  }
}
