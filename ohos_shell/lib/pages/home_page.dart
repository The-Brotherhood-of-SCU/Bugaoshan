import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus_page.dart';
import 'package:bugaoshan/pages/course/course_page.dart';
import 'package:bugaoshan/pages/profile_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/update_service.dart';
import 'package:bugaoshan/services/widget_update_service.dart';
import 'package:bugaoshan/widgets/common/navigation_item.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final _courseProvider = getIt<CourseProvider>();
  late AppLocalizations _localizations;
  late final List<NavigationItemData> _navigationItems;

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

  bool _itemsInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _localizations = AppLocalizations.of(context)!;
    if (!_itemsInitialized) {
      _itemsInitialized = true;
      _navigationItems = [
        NavigationItemData(
          icon: Icons.menu_book_outlined,
          selectedIcon: Icons.menu_book,
          label: _localizations.course,
          page: CoursePage(),
        ),
        NavigationItemData(
          icon: Icons.school_outlined,
          selectedIcon: Icons.school,
          label: _localizations.campus,
          page: const CampusPage(),
        ),
        NavigationItemData(
          icon: Icons.person_outlined,
          selectedIcon: Icons.person,
          label: _localizations.profile,
          page: ProfilePage(),
        ),
      ];
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
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape) {
          // Landscape mode: use left navigation rail
          return Scaffold(
            body: Row(
              children: [
                ValueListenableBuilder<bool>(
                  valueListenable: appConfig.hasUpdateNotification,
                  builder: (context, hasUpdate, _) {
                    return NavigationRail(
                      selectedIndex: _currentIndex,
                      onDestinationSelected: (index) {
                        setState(() {
                          _currentIndex = index;
                        });
                        if (index == 0) {
                          _courseProvider.updateCurrentWeek(
                            _courseProvider.scheduleConfig.value.getCurrentWeek(),
                          );
                        }
                      },
                      labelType: NavigationRailLabelType.all,
                      destinations: _navigationItems.asMap().entries.map((entry) {
                        final item = entry.value;
                        final isProfileTab = entry.key == 2;
                        return NavigationRailDestination(
                          icon: isProfileTab
                              ? _buildUpdateBadge(
                                  showBadge: hasUpdate,
                                  child: Icon(item.icon),
                                )
                              : Icon(item.icon),
                          selectedIcon: isProfileTab
                              ? _buildUpdateBadge(
                                  showBadge: hasUpdate,
                                  child: Icon(item.selectedIcon),
                                )
                              : Icon(item.selectedIcon),
                          label: Text(item.label),
                        );
                      }).toList(),
                    );
                  },
                ),
                const VerticalDivider(thickness: 1, width: 1),
                Expanded(
                  child: SafeArea(child: _navigationItems[_currentIndex].page),
                ),
              ],
            ),
          );
        } else {
          // Portrait mode: use bottom navigation bar
          return Scaffold(
            body: SafeArea(child: _navigationItems[_currentIndex].page),
            bottomNavigationBar: ValueListenableBuilder<bool>(
              valueListenable: appConfig.hasUpdateNotification,
              builder: (context, hasUpdate, _) {
                return NavigationBar(
                  selectedIndex: _currentIndex,
                  onDestinationSelected: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                    if (index == 0) {
                      _courseProvider.updateCurrentWeek(
                        _courseProvider.scheduleConfig.value.getCurrentWeek(),
                      );
                    }
                  },
                  destinations: _navigationItems.asMap().entries.map((entry) {
                    final item = entry.value;
                    final isProfileTab = entry.key == 2;
                    return NavigationDestination(
                      icon: isProfileTab
                          ? _buildUpdateBadge(
                              showBadge: hasUpdate,
                              child: Icon(item.icon),
                            )
                          : Icon(item.icon),
                      selectedIcon: isProfileTab
                          ? _buildUpdateBadge(
                              showBadge: hasUpdate,
                              child: Icon(item.selectedIcon),
                            )
                          : Icon(item.selectedIcon),
                      label: item.label,
                    );
                  }).toList(),
                );
              },
            ),
          );
        }
      },
    );
  }
}
