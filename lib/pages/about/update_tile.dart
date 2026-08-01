import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/update_provider.dart';
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
class UpdateTile extends StatelessWidget {
  final VoidCallback onTap;

  const UpdateTile({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final appConfig = getIt<AppConfigProvider>();
    final updateProvider = getIt<UpdateProvider>();
    final localizations = AppLocalizations.of(context)!;

    return ValueListenableBuilder<bool>(
      valueListenable: appConfig.hasUpdateNotification,
      builder: (context, hasUpdate, _) {
        return ListenableBuilder(
          listenable: Listenable.merge([
            updateProvider.isChecking,
            updateProvider.isDownloading,
            updateProvider.progressState,
          ]),
          builder: (context, _) {
            final isDownloading = updateProvider.isDownloading.value;
            final isChecking = updateProvider.isChecking.value;
            final percent = updateProvider.progressState.percent;
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
          },
        );
      },
    );
  }
}
