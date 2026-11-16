import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/utils/system_insets.dart';
import 'package:bugaoshan/widgets/common/info_card.dart';
import 'package:bugaoshan/widgets/adaptive/adaptive_glass_controls.dart';

/// 网络代理设置页。
///
/// 目前仅提供 GitHub 镜像加速一项：开启后 GitHub 资源（软件更新包、校历）
/// 优先走 gh-proxy 镜像，失败自动回退直连；关闭则严格直连。后续若新增其他
/// 代理源，在此页追加条目即可。
class SetProxyPage extends StatelessWidget {
  const SetProxyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appConfig = getIt<AppConfigProvider>();
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
              ListenableBuilder(
                listenable: appConfig.useGithubProxy,
                builder: (context, _) => AdaptiveGlassSwitchListTile(
                  title: Text(l10n.ghProxyMirror),
                  subtitle: Text(
                    l10n.ghProxyMirrorHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  value: appConfig.useGithubProxy.value,
                  onChanged: (v) => appConfig.useGithubProxy.value = v,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
