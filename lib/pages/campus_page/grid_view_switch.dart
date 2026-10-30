import 'package:bugaoshan/widgets/adaptive/adaptive_glass_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus_page/list_card.dart';
import 'package:bugaoshan/pages/campus_page/grid_card.dart';
import 'package:bugaoshan/providers/riverpod/settings/app_config_pods.dart';

/// Grid view switch in list style.
class GridViewSwitchListCard extends ConsumerWidget {
  const GridViewSwitchListCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isGridView = ref.watch(campusGridViewSettingProvider);

    return CampusListCard(
      icon: Icons.grid_view,
      title: l10n.campusGridView,
      desc: l10n.campusGridViewDesc,
      trailing: AdaptiveGlassSwitch(
        semanticLabel: l10n.campusGridView,
        value: isGridView,
        onChanged: (value) {
          ref.read(campusGridViewSettingProvider.notifier).update(value);
        },
      ),
      onTap: () {
        ref.read(campusGridViewSettingProvider.notifier).update(!isGridView);
      },
    );
  }
}

/// Grid view switch in grid style - looks like a regular grid card.
class GridViewSwitchGridCard extends ConsumerWidget {
  const GridViewSwitchGridCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isGridView = ref.watch(campusGridViewSettingProvider);

    return CampusGridCard(
      icon: isGridView ? Icons.view_list : Icons.grid_view,
      title: l10n.campusGridView,
      onTap: () {
        ref.read(campusGridViewSettingProvider.notifier).update(!isGridView);
      },
    );
  }
}
