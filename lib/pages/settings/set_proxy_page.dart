import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/riverpod/settings/app_config_pods.dart';
import 'package:bugaoshan/utils/system_insets.dart';
import 'package:bugaoshan/widgets/common/info_card.dart';
import 'package:bugaoshan/widgets/adaptive/adaptive_glass_controls.dart';

/// 网络代理设置页。
///
/// 目前仅提供 GitHub 镜像加速一项：开启后 GitHub 资源（软件更新包、校历）
/// 优先走 gh-proxy 镜像，失败自动回退直连；关闭则严格直连。后续若新增其他
/// 代理源，在此页追加条目即可。
class SetProxyPage extends ConsumerWidget {
  const SetProxyPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final useGithubProxy = ref.watch(useGithubProxySettingProvider);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.networkProxy)),
      body: ListView(
        padding: withSystemBottomInset(
          context,
          const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        children: [
          InfoCard(
            indent: 0,
            children: [
              AdaptiveGlassSwitchListTile(
                title: Text(l10n.ghProxyMirror),
                subtitle: Text(
                  l10n.ghProxyMirrorHint,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                value: useGithubProxy,
                onChanged: (v) =>
                    ref.read(useGithubProxySettingProvider.notifier).update(v),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
