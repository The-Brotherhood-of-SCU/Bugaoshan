import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/dock_item_config.dart';
import 'package:bugaoshan/pages/campus_page.dart';
import 'package:bugaoshan/pages/course/course_page.dart';
import 'package:bugaoshan/pages/profile_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/update_service.dart';
import 'package:bugaoshan/services/widget_update_service.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/widgets/common/navigation_item.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final _courseProvider = getIt<CourseProvider>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkForUpdateInBackground();
    _attemptAutoLogin();
  }

  Future<void> _attemptAutoLogin() async {
    try {
      await getIt.isReady<ScuAuthProvider>();
      final authProvider = getIt<ScuAuthProvider>();
      if (authProvider.isLoggedIn) return;
      await authProvider.autoLogin();
    } catch (e) {
      debugPrint('Auto login attempt error: $e');
    }
  }

  Future<void> _checkForUpdateInBackground() async {
    try {
      await Future.wait([
        getIt.isReady<AppInfoProvider>(),
        getIt.isReady<UpdateService>(),
        getIt.isReady<AppConfigProvider>(),
      ]);
      final updateService = getIt<UpdateService>();
      final appInfo = getIt<AppInfoProvider>();
      final appConfig = getIt<AppConfigProvider>();
      final result = await updateService.checkStableUpdate(appInfo.currentVersion);
      if (result.hasUpdate) {
        appConfig.hasUpdateNotification.value = true;
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateWidget();
    }
  }

  void _updateWidget() {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        getIt<WidgetUpdateService>().updateWidgetData();
      } catch (_) {}
    }
  }

  List<NavigationItemData> _buildNavigationItems(AppLocalizations l10n) {
    return [
      NavigationItemData(
        id: dockIdCourse,
        icon: Icons.menu_book_outlined,
        selectedIcon: Icons.menu_book,
        label: l10n.course,
        page: CoursePage(),
      ),
      NavigationItemData(
        id: dockIdCampus,
        icon: Icons.school_outlined,
        selectedIcon: Icons.school,
        label: l10n.campus,
        page: const CampusPage(),
      ),
      NavigationItemData(
        id: dockIdProfile,
        icon: Icons.person_outlined,
        selectedIcon: Icons.person,
        label: l10n.profile,
        page: ProfilePage(),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return _buildMainScreen();
  }

  Widget _buildUpdateBadge({required Widget child, required bool showBadge}) {
    if (!showBadge) return child;
    return Badge(child: child);
  }

  Widget _buildMainScreen() {
    final appConfig = getIt<AppConfigProvider>();
    final l10n = AppLocalizations.of(context)!;
    final allItems = _buildNavigationItems(l10n);

    return ValueListenableBuilder<List<DockItemConfig>>(
      valueListenable: appConfig.dockItems,
      builder: (context, dockConfigs, _) {
        final visibleItems = _resolveVisibleItems(dockConfigs, allItems);
        _clampCurrentIndex(visibleItems);
        final currentPage = visibleItems.isNotEmpty
            ? visibleItems[_currentIndex].page
            : ProfilePage();

        return OrientationBuilder(
          builder: (context, orientation) => orientation == Orientation.landscape
              ? _buildLandscapeLayout(visibleItems, currentPage)
              : _buildPortraitLayout(visibleItems, currentPage),
        );
      },
    );
  }

  List<NavigationItemData> _resolveVisibleItems(
    List<DockItemConfig> dockConfigs,
    List<NavigationItemData> allItems,
  ) {
    return dockConfigs
        .where((c) => c.isVisible)
        .map((c) => allItems.firstWhere(
              (item) => item.id == c.id,
              orElse: () => allItems.last,
            ))
        .toList();
  }

  void _clampCurrentIndex(List<NavigationItemData> items) {
    if (items.isEmpty) {
      _currentIndex = 0;
    } else if (_currentIndex >= items.length) {
      _currentIndex = items.length - 1;
    }
  }

  Widget _buildLandscapeLayout(
    List<NavigationItemData> visibleItems,
    Widget currentPage,
  ) {
    final appConfig = getIt<AppConfigProvider>();
    return Scaffold(
      body: Row(
        children: [
          ValueListenableBuilder<bool>(
            valueListenable: appConfig.hasUpdateNotification,
            builder: (context, hasUpdate, _) {
              return NavigationRail(
                selectedIndex: _currentIndex,
                onDestinationSelected: (index) {
                  setState(() => _currentIndex = index);
                  _onTabSelected(visibleItems[index].id);
                },
                labelType: NavigationRailLabelType.all,
                destinations: visibleItems
                    .map((item) => _buildRailDestination(item, hasUpdate))
                    .toList(),
              );
            },
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(child: SafeArea(child: currentPage)),
        ],
      ),
    );
  }

  Widget _buildPortraitLayout(
    List<NavigationItemData> visibleItems,
    Widget currentPage,
  ) {
    final appConfig = getIt<AppConfigProvider>();
    return Scaffold(
      body: SafeArea(child: currentPage),
      bottomNavigationBar: ValueListenableBuilder<bool>(
        valueListenable: appConfig.hasUpdateNotification,
        builder: (context, hasUpdate, _) {
          return NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) {
              setState(() => _currentIndex = index);
              _onTabSelected(visibleItems[index].id);
            },
            destinations: visibleItems
                .map((item) => _buildBarDestination(item, hasUpdate))
                .toList(),
          );
        },
      ),
    );
  }

  NavigationRailDestination _buildRailDestination(
    NavigationItemData item,
    bool hasUpdate,
  ) {
    return NavigationRailDestination(
      icon: item.id == dockIdProfile
          ? _buildUpdateBadge(showBadge: hasUpdate, child: Icon(item.icon))
          : Icon(item.icon),
      selectedIcon: item.id == dockIdProfile
          ? _buildUpdateBadge(
              showBadge: hasUpdate, child: Icon(item.selectedIcon))
          : Icon(item.selectedIcon),
      label: Text(item.label),
    );
  }

  NavigationDestination _buildBarDestination(
    NavigationItemData item,
    bool hasUpdate,
  ) {
    return NavigationDestination(
      icon: item.id == dockIdProfile
          ? _buildUpdateBadge(showBadge: hasUpdate, child: Icon(item.icon))
          : Icon(item.icon),
      selectedIcon: item.id == dockIdProfile
          ? _buildUpdateBadge(
              showBadge: hasUpdate, child: Icon(item.selectedIcon))
          : Icon(item.selectedIcon),
      label: item.label,
    );
  }

  void _onTabSelected(String id) {
    if (id == dockIdCourse) {
      _courseProvider.updateCurrentWeek(
        _courseProvider.scheduleConfig.value.getCurrentWeek(),
      );
    }
  }
}
