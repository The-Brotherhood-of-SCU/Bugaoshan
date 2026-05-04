import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/dock_item_config.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/update_service.dart';
import 'package:bugaoshan/services/widget_update_service.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/utils/dock_utils.dart';

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
      final result = await updateService.checkStableUpdate(
        appInfo.currentVersion,
      );
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

    return ValueListenableBuilder<List<String>>(
      valueListenable: appConfig.visibleDockIds,
      builder: (context, visibleIds, _) {
        _clampCurrentIndex(visibleIds);
        final currentId = visibleIds.isNotEmpty
            ? visibleIds[_currentIndex]
            : dockIdProfile;
        final currentPage = buildDockPage(currentId);

        return ValueListenableBuilder<bool>(
          valueListenable: appConfig.hasUpdateNotification,
          builder: (context, hasUpdate, _) {
            return OrientationBuilder(
              builder: (context, orientation) =>
                  orientation == Orientation.landscape
                  ? _buildLandscapeLayout(
                      visibleIds,
                      currentPage,
                      l10n,
                      hasUpdate,
                    )
                  : _buildPortraitLayout(
                      visibleIds,
                      currentPage,
                      l10n,
                      hasUpdate,
                    ),
            );
          },
        );
      },
    );
  }

  void _clampCurrentIndex(List<String> ids) {
    if (ids.isEmpty) {
      _currentIndex = 0;
    } else if (_currentIndex >= ids.length) {
      _currentIndex = ids.length - 1;
    }
  }

  Widget _buildLandscapeLayout(
    List<String> visibleIds,
    Widget currentPage,
    AppLocalizations l10n,
    bool hasUpdate,
  ) {
    return Scaffold(
      body: Row(
        children: [
          if (visibleIds.isNotEmpty) ...[
            NavigationRail(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() => _currentIndex = index);
                _onTabSelected(visibleIds[index]);
              },
              labelType: NavigationRailLabelType.all,
              destinations: visibleIds
                  .map((id) => _buildRailDestination(id, hasUpdate, l10n))
                  .toList(),
            ),
            const VerticalDivider(thickness: 1, width: 1),
          ],
          Expanded(child: SafeArea(child: currentPage)),
        ],
      ),
    );
  }

  Widget _buildPortraitLayout(
    List<String> visibleIds,
    Widget currentPage,
    AppLocalizations l10n,
    bool hasUpdate,
  ) {
    return Scaffold(
      body: SafeArea(child: currentPage),
      bottomNavigationBar: visibleIds.isNotEmpty
          ? NavigationBar(
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                setState(() => _currentIndex = index);
                _onTabSelected(visibleIds[index]);
              },
              destinations: visibleIds
                  .map((id) => _buildBarDestination(id, hasUpdate, l10n))
                  .toList(),
            )
          : null,
    );
  }

  NavigationRailDestination _buildRailDestination(
    String id,
    bool hasUpdate,
    AppLocalizations l10n,
  ) {
    final config = dockConfigById(id);
    final isProfile = id == dockIdProfile;
    return NavigationRailDestination(
      icon: isProfile
          ? _buildUpdateBadge(showBadge: hasUpdate, child: Icon(config.icon))
          : Icon(config.icon),
      selectedIcon: isProfile
          ? _buildUpdateBadge(
              showBadge: hasUpdate,
              child: Icon(config.selectedIcon),
            )
          : Icon(config.selectedIcon),
      label: Text(dockLabel(id, l10n)),
    );
  }

  NavigationDestination _buildBarDestination(
    String id,
    bool hasUpdate,
    AppLocalizations l10n,
  ) {
    final config = dockConfigById(id);
    final isProfile = id == dockIdProfile;
    return NavigationDestination(
      icon: isProfile
          ? _buildUpdateBadge(showBadge: hasUpdate, child: Icon(config.icon))
          : Icon(config.icon),
      selectedIcon: isProfile
          ? _buildUpdateBadge(
              showBadge: hasUpdate,
              child: Icon(config.selectedIcon),
            )
          : Icon(config.selectedIcon),
      label: dockLabel(id, l10n),
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
