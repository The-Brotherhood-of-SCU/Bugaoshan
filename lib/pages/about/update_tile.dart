import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/riverpod/common/update_pods.dart';
import 'package:bugaoshan/providers/riverpod/settings/app_config_pods.dart';
import 'package:bugaoshan/widgets/common/styled_tile.dart';

/// "检查更新" 入口瓦片。
///
/// 整合了三种联动状态：
/// - [AppConfigProvider.hasUpdateNotification] 控制右上角红点角标；
/// - [UpdateProvider.isDownloading] 为 true 时展示下载进度百分比并禁用点击，
///   避免重入触发新的检查/下载流程；
/// - [UpdateProvider.isChecking] 为 true 时展示转圈指示器。
///
/// 实际的检查/下载逻辑由外部通过 [onTap] 注入，组件本身只负责状态展示。
class UpdateTile extends ConsumerWidget {
  final VoidCallback onTap;

  const UpdateTile({super.key, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasUpdate = ref.watch(hasUpdateNotificationSettingProvider);
    final update = ref.watch(updateProvider);
    final localizations = AppLocalizations.of(context)!;

    final isDownloading = update.isDownloading;
    final isChecking = update.isChecking;
    final percent = update.downloadPercent;

    return BadgedTile(
      icon: Icons.update_rounded,
      label: localizations.checkForUpdates,
      showBadge: hasUpdate,
      // 下载中禁用点击,避免重入触发新的检查/下载流程
      onTap: isDownloading ? null : onTap,
      trailing: isDownloading
          ? Text(
              '$percent%',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            )
          : isChecking
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : null,
    );
  }
}
