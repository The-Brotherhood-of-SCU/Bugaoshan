import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/campus_item_config.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'section_header.dart';
import 'list_card.dart';
import 'grid_card.dart';
import 'grid_view_switch.dart';
import 'package:bugaoshan/utils/app_shapes.dart';

class CampusPage extends StatefulWidget {
  const CampusPage({super.key});

  @override
  State<CampusPage> createState() => _CampusPageState();
}

class _CampusPageState extends State<CampusPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _arrowController;
  late final Animation<double> _arrowAnimation;
  bool _showHint = true;

  @override
  void initState() {
    super.initState();
    _arrowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    ); //..repeat(reverse: true); //disabled animation
    _arrowAnimation = Tween<double>(begin: 0, end: 6).animate(
      CurvedAnimation(parent: _arrowController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _arrowController.dispose();
    super.dispose();
  }

  void _onScroll(ScrollNotification notification) {
    if (notification.metrics.pixels > 40 && _showHint) {
      setState(() => _showHint = false);
    } else if (notification.metrics.pixels <= 40 && !_showHint) {
      setState(() => _showHint = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bgColor = Theme.of(context).scaffoldBackgroundColor;
    final appConfig = getIt<AppConfigProvider>();

    return ValueListenableBuilder<bool>(
      valueListenable: appConfig.campusGridView,
      builder: (context, isGridView, _) {
        return Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                _onScroll(notification);
                return false;
              },
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                switchInCurve: Curves.easeInOut,
                switchOutCurve: Curves.easeInOut,
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: CustomScrollView(
                  key: ValueKey(isGridView),
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.all(AppShapes.medium),
                      sliver: isGridView
                          ? _buildGridView(l10n)
                          : _buildListView(l10n),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _showHint ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          bgColor.withValues(alpha: 0),
                          bgColor.withValues(alpha: 0.95),
                        ],
                      ),
                    ),
                    alignment: Alignment.center,
                    child: AnimatedBuilder(
                      animation: _arrowAnimation,
                      builder: (context, child) => Transform.translate(
                        offset: Offset(0, _arrowAnimation.value),
                        child: child,
                      ),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
                        size: AppShapes.extraLarge,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildListView(AppLocalizations l10n) {
    return SliverList.list(
      children: [
        for (final section in campusSections) ...[
          CampusSectionHeader(title: section.title(l10n)),
          const SizedBox(height: 8),
          for (final item in section.items) ...[
            CampusListCard(
              icon: item.icon,
              title: item.dockFullLabel(l10n),
              desc: item.desc(l10n),
              trailing: Icon(
                Icons.chevron_right,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onTap: () {
                final rootCtx = logicRootContext;
                if (rootCtx.mounted) {
                  popupOrNavigate(rootCtx, item.page());
                }
              },
            ),
            const SizedBox(height: 8),
          ],
          const SizedBox(height: 16),
        ],
        CampusSectionHeader(title: l10n.otherSection),
        const SizedBox(height: 8),
        _buildOtherSection(l10n),
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildOtherSection(AppLocalizations l10n) {
    return Column(
      children: [
        GridViewSwitchListCard(),
        const SizedBox(height: 8),
        CampusListCard(
          icon: Icons.add_comment_outlined,
          title: l10n.moreFeaturesTitle,
          desc: l10n.moreFeaturesDesc,
          iconContainerColor: Theme.of(context).colorScheme.secondaryContainer,
          iconColor: Theme.of(context).colorScheme.onSecondaryContainer,
          trailing: Icon(
            Icons.open_in_new,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          onTap: () => launchUrl(
            Uri.parse('$appLink/issues/new?template=feature_request.yml'),
            mode: LaunchMode.externalApplication,
          ),
        ),
      ],
    );
  }

  Widget _buildGridView(AppLocalizations l10n) {
    return SliverMainAxisGroup(
      slivers: [
        for (final section in campusSections) ...[
          SliverToBoxAdapter(
            child: CampusSectionHeader(title: section.title(l10n)),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(top: 8, bottom: 16),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 160,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = section.items[index];
                return CampusGridCard(
                  icon: item.icon,
                  title: item.dockLabel(l10n),
                  onTap: () {
                    final rootCtx = logicRootContext;
                    if (rootCtx.mounted) {
                      popupOrNavigate(rootCtx, item.page());
                    }
                  },
                );
              }, childCount: section.items.length),
            ),
          ),
        ],
        SliverToBoxAdapter(
          child: CampusSectionHeader(title: l10n.otherSection),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 8)),
        SliverToBoxAdapter(child: _buildOtherSection(l10n)),
        const SliverToBoxAdapter(child: SizedBox(height: 60)),
      ],
    );
  }
}
