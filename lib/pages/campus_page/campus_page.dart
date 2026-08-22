import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/campus_item_config.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/widgets/common/styled_card.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:url_launcher/url_launcher.dart';
import 'section_header.dart';
import 'list_card.dart';
import 'grid_card.dart';
import 'grid_view_switch.dart';
import 'item_accent.dart';
import 'package:bugaoshan/theme_shape.dart';

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

  bool _searchExpanded = false;
  String _searchQuery = '';
  final _searchTextController = TextEditingController();
  final _searchFocusNode = FocusNode();

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
    _searchTextController.dispose();
    _searchFocusNode.dispose();
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

  void _startSearch() {
    setState(() => _searchExpanded = true);
    _searchFocusNode.requestFocus();
  }

  void _stopSearch() {
    _searchFocusNode.unfocus();
    setState(() {
      _searchExpanded = false;
      _searchQuery = '';
      _searchTextController.clear();
    });
  }

  void _clearSearch() {
    _searchTextController.clear();
    setState(() => _searchQuery = '');
    _searchFocusNode.requestFocus();
  }

  /// 按标题/描述过滤校园功能，忽略大小写。
  List<CampusItemConfig> _searchResults(AppLocalizations l10n) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return [
      for (final section in campusSections)
        for (final item in section.items)
          if (item.dockLabel(l10n).toLowerCase().contains(query) ||
              item.dockFullLabel(l10n).toLowerCase().contains(query) ||
              item.desc(l10n).toLowerCase().contains(query))
            item,
    ];
  }

  void _openItem(CampusItemConfig item) {
    final rootCtx = logicRootContext;
    if (rootCtx.mounted) {
      popupOrNavigate(rootCtx, item.page());
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
                      padding: const EdgeInsets.fromLTRB(
                        AppShapes.medium,
                        AppShapes.medium,
                        AppShapes.medium,
                        0,
                      ),
                      sliver: SliverToBoxAdapter(child: _buildSearchArea(l10n)),
                    ),
                    if (_searchExpanded && _searchQuery.trim().isNotEmpty)
                      SliverPadding(
                        padding: const EdgeInsets.all(AppShapes.medium),
                        sliver: _buildSearchResults(l10n, isGridView),
                      )
                    else
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

  /// 顶部搜索区：收起时与第一个分区标题同行显示右侧圆形角标，点击后展开为搜索框。
  Widget _buildSearchArea(AppLocalizations l10n) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      alignment: Alignment.topCenter,
      child: _searchExpanded
          ? _buildSearchField(l10n)
          : _buildSearchBadgeRow(l10n),
    );
  }

  /// 角标与第一个分区标题同行：标题在左、角标在右，避免独占一行留白。
  Widget _buildSearchBadgeRow(AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: CampusSectionHeader(title: campusSections.first.title(l10n)),
        ),
        const SizedBox(width: 8),
        _buildSearchBadge(l10n),
      ],
    );
  }

  Widget _buildSearchBadge(AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: l10n.campusSearchHint,
      child: StyledCard(
        onTap: _startSearch,
        borderRadius: AppShapes.full,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(Icons.search, color: colorScheme.onSurfaceVariant),
        ),
      ),
    );
  }

  Widget _buildSearchField(AppLocalizations l10n) {
    return StyledCard(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          children: [
            IconButton(
              tooltip: l10n.close,
              onPressed: _stopSearch,
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: TextField(
                controller: _searchTextController,
                focusNode: _searchFocusNode,
                autofocus: true,
                textInputAction: TextInputAction.search,
                style: Theme.of(context).textTheme.bodyLarge,
                decoration: InputDecoration(
                  hintText: l10n.campusSearchHint,
                  border: InputBorder.none,
                  isDense: true,
                ),
                onChanged: (value) => setState(() => _searchQuery = value),
                onSubmitted: (_) => _searchFocusNode.unfocus(),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                tooltip: l10n.clear,
                onPressed: _clearSearch,
                icon: const Icon(Icons.close),
              ),
          ],
        ),
      ),
    );
  }

  /// 搜索结果：网格/列表布局，与正常模式保持一致。
  Widget _buildSearchResults(AppLocalizations l10n, bool isGridView) {
    final results = _searchResults(l10n);
    if (results.isEmpty) {
      return SliverToBoxAdapter(child: _buildNoSearchResults(l10n));
    }
    if (isGridView) {
      return SliverMainAxisGroup(
        slivers: [
          SliverToBoxAdapter(
            child: CampusSectionHeader(title: l10n.campusSearchResults),
          ),
          SliverPadding(
            padding: const EdgeInsets.only(top: 8, bottom: 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 140,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.9,
              ),
              delegate: SliverChildBuilderDelegate((context, index) {
                final item = results[index];
                return CampusGridCard(
                  icon: item.icon,
                  title: item.dockLabel(l10n),
                  accentColor: campusItemAccent(item.id),
                  onTap: () => _openItem(item),
                );
              }, childCount: results.length),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 60)),
        ],
      );
    }
    return SliverList.list(
      children: [
        CampusSectionHeader(title: l10n.campusSearchResults),
        const SizedBox(height: 8),
        for (final item in results) ...[
          CampusListCard(
            icon: item.icon,
            title: item.dockFullLabel(l10n),
            desc: item.desc(l10n),
            accentColor: campusItemAccent(item.id),
            trailing: Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onTap: () => _openItem(item),
          ),
          const SizedBox(height: 8),
        ],
        const SizedBox(height: 60),
      ],
    );
  }

  Widget _buildNoSearchResults(AppLocalizations l10n) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.campusNoSearchResults,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListView(AppLocalizations l10n) {
    final children = <Widget>[];
    for (var i = 0; i < campusSections.length; i++) {
      final section = campusSections[i];
      // 收起搜索时第一个分区标题已与角标同行展示，不再重复渲染。
      final showHeader = _searchExpanded || i != 0;
      if (showHeader) {
        children.add(CampusSectionHeader(title: section.title(l10n)));
        children.add(const SizedBox(height: 8));
      }
      for (final item in section.items) {
        children.add(
          CampusListCard(
            icon: item.icon,
            title: item.dockFullLabel(l10n),
            desc: item.desc(l10n),
            accentColor: campusItemAccent(item.id),
            trailing: Icon(
              Icons.chevron_right,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            onTap: () => _openItem(item),
          ),
        );
        children.add(const SizedBox(height: 8));
      }
      children.add(const SizedBox(height: 16));
    }
    children
      ..add(CampusSectionHeader(title: l10n.otherSection))
      ..add(const SizedBox(height: 8))
      ..add(_buildOtherSection(l10n))
      ..add(const SizedBox(height: 60));
    return SliverList.list(children: children);
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
    final slivers = <Widget>[];
    for (var i = 0; i < campusSections.length; i++) {
      final section = campusSections[i];
      // 收起搜索时第一个分区标题已与角标同行展示，不再重复渲染。
      final showHeader = _searchExpanded || i != 0;
      if (showHeader) {
        slivers.add(
          SliverToBoxAdapter(
            child: CampusSectionHeader(title: section.title(l10n)),
          ),
        );
      }
      slivers.add(
        SliverPadding(
          padding: EdgeInsets.only(top: showHeader ? 8 : 0, bottom: 8),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
              maxCrossAxisExtent: 140,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.9,
            ),
            delegate: SliverChildBuilderDelegate((context, index) {
              final item = section.items[index];
              return CampusGridCard(
                icon: item.icon,
                title: item.dockLabel(l10n),
                accentColor: campusItemAccent(item.id),
                onTap: () => _openItem(item),
              );
            }, childCount: section.items.length),
          ),
        ),
      );
    }
    slivers.addAll([
      SliverToBoxAdapter(child: CampusSectionHeader(title: l10n.otherSection)),
      const SliverToBoxAdapter(child: SizedBox(height: 8)),
      SliverToBoxAdapter(child: _buildOtherSection(l10n)),
      const SliverToBoxAdapter(child: SizedBox(height: 60)),
    ]);
    return SliverMainAxisGroup(slivers: slivers);
  }
}
