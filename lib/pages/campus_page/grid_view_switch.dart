import 'package:material_ui/material_ui.dart';
import 'package:get_it/get_it.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus_page/list_card.dart';
import 'package:bugaoshan/pages/campus_page/grid_card.dart';

/// Grid view switch in list style.
class GridViewSwitchListCard extends StatelessWidget {
  const GridViewSwitchListCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appConfig = GetIt.instance<AppConfigProvider>();

    return ValueListenableBuilder<bool>(
      valueListenable: appConfig.campusGridView,
      builder: (context, isGridView, _) {
        return CampusListCard(
          icon: Icons.grid_view,
          title: l10n.campusGridView,
          desc: l10n.campusGridViewDesc,
          trailing: Switch(
            value: isGridView,
            onChanged: (value) {
              appConfig.campusGridView.value = value;
            },
          ),
          onTap: () {
            appConfig.campusGridView.value = !isGridView;
          },
        );
      },
    );
  }
}

/// Grid view switch in grid style - looks like a regular grid card.
class GridViewSwitchGridCard extends StatelessWidget {
  const GridViewSwitchGridCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final appConfig = GetIt.instance<AppConfigProvider>();

    return ValueListenableBuilder<bool>(
      valueListenable: appConfig.campusGridView,
      builder: (context, isGridView, _) {
        return CampusGridCard(
          icon: isGridView ? Icons.view_list : Icons.grid_view,
          title: l10n.campusGridView,
          onTap: () {
            appConfig.campusGridView.value = !isGridView;
          },
        );
      },
    );
  }
}
