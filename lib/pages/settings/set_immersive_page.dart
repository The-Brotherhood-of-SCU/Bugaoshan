import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/widgets/common/info_card.dart';
import 'package:bugaoshan/widgets/common/section_title.dart';

/// 沉浸光感设置页（仅 HarmonyOS 平台显示入口）。
///
/// 调节 ArkUI 原生悬浮底栏的 ImmersiveMaterial 材质参数：开关、材质强度
/// （ImmersiveStyle 0~4）、智能反色、按压光效。改动即时生效并持久化。
class SetImmersivePage extends StatelessWidget {
  const SetImmersivePage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appConfig = getIt<AppConfigProvider>();

    final styleNames = [
      l10n.immersiveStyleUltraThin,
      l10n.immersiveStyleThin,
      l10n.immersiveStyleRegular,
      l10n.immersiveStyleThick,
      l10n.immersiveStyleUltraThick,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.immersiveSetting)),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          appConfig.immersiveDockEnabled,
          appConfig.immersiveDockStyle,
          appConfig.immersiveDockColorInvert,
          appConfig.immersiveDockInteractive,
        ]),
        builder: (context, _) => ListView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          children: [
            SectionTitle(title: l10n.immersiveSetting),
            InfoCard(
              children: [
                SwitchListTile(
                  title: Text(l10n.immersiveNativeDock),
                  subtitle: Text(l10n.immersiveNativeDockDesc),
                  value: appConfig.immersiveDockEnabled.value,
                  onChanged: (v) => appConfig.immersiveDockEnabled.value = v,
                ),
                SwitchListTile(
                  title: Text(l10n.immersiveColorInvert),
                  subtitle: Text(l10n.immersiveColorInvertDesc),
                  value: appConfig.immersiveDockColorInvert.value,
                  onChanged: appConfig.immersiveDockEnabled.value
                      ? (v) => appConfig.immersiveDockColorInvert.value = v
                      : null,
                ),
                SwitchListTile(
                  title: Text(l10n.immersiveInteractive),
                  subtitle: Text(l10n.immersiveInteractiveDesc),
                  value: appConfig.immersiveDockInteractive.value,
                  onChanged: appConfig.immersiveDockEnabled.value
                      ? (v) => appConfig.immersiveDockInteractive.value = v
                      : null,
                ),
              ],
            ),
            const SizedBox(height: 14),
            SectionTitle(title: l10n.immersiveStyleStrength),
            InfoCard(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(l10n.immersiveStyleStrength),
                      Text(
                        styleNames[appConfig.immersiveDockStyle.value
                            .clamp(0, 4)],
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                Slider(
                  value: appConfig.immersiveDockStyle.value
                      .clamp(0, 4)
                      .toDouble(),
                  min: 0,
                  max: 4,
                  divisions: 4,
                  onChanged: appConfig.immersiveDockEnabled.value
                      ? (v) =>
                          appConfig.immersiveDockStyle.value = v.round()
                      : null,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: Text(
                    l10n.immersiveOhosOnly,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
