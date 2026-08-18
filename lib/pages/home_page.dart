import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/campus_item_config.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/providers/update_provider.dart';
import 'package:bugaoshan/services/auth/auth_coordinator.dart';
import 'package:bugaoshan/services/immersive_dock_service.dart';
import 'package:bugaoshan/services/widget_update_service.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/widgets/common/auth_scoped_indexed_stack.dart';
import 'package:bugaoshan/widgets/common/immersive_dock_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with WidgetsBindingObserver, RouteAware {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // 原生沉浸光感底栏（HarmonyOS）：接收 ArkUI 侧点击事件
    ImmersiveDockService.instance.onDockTap = _onNativeDockTap;
    ImmersiveDockService.instance.init();
    _checkForUpdateInBackground();
    _attemptAutoLogin();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 系统级监听：首页被二级页面覆盖时隐藏原生底栏（仅 HarmonyOS）
    if (ImmersiveDockService.isOhos) {
      final route = ModalRoute.of(context);
      if (route != null) {
        ImmersiveDockService.routeObserver.subscribe(this, route);
      }
    }
  }

  /// 二级页面压入：隐藏原生底栏
  @override
  void didPushNext() {
    ImmersiveDockService.instance.setCovered(true);
  }

  /// 二级页面返回：恢复原生底栏
  @override
  void didPopNext() {
    ImmersiveDockService.instance.setCovered(false);
  }

  void _onNativeDockTap(int index) {
    final ids = getIt<AppConfigProvider>().visibleDockIds.value;
    if (index < 0 || index >= ids.length) return;
    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
    }
  }

  /// 把底栏配置推送给 ArkUI 原生沉浸光感底栏（仅 HarmonyOS）
  void _syncNativeDock(
    AppConfigProvider appConfig,
    List<String> visibleIds,
    bool hasUpdate,
    AppLocalizations l10n,
    bool showBar,
  ) {
    if (!ImmersiveDockService.isOhos) return;
    final tabs = [
      for (final id in visibleIds)
        DockTabInfo(
          id: id,
          label: campusItemConfigById(id).dockLabel(l10n),
          icon: id,
          badge: id == dockIdProfile && hasUpdate,
        ),
    ];
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ImmersiveDockService.instance.sync(
        enabled: showBar && appConfig.immersiveDockEnabled.value,
        tabs: tabs,
        selectedIndex: _currentIndex,
        style: appConfig.immersiveDockStyle.value,
        colorInvert: appConfig.immersiveDockColorInvert.value,
        interactive: appConfig.immersiveDockInteractive.value,
      );
    });
  }

  Future<void> _attemptAutoLogin() async {
    try {
      await getIt.isReady<ScuAuthProvider>();
      final authProvider = getIt<ScuAuthProvider>();
      if (authProvider.isLoggedIn) {
        unawaited(getIt<AuthCoordinator>().warmUpAll());
        return;
      }
      await authProvider.autoLogin();
    } catch (e) {
      debugPrint('Auto login attempt error: $e');
    }
  }

  Future<void> _checkForUpdateInBackground() async {
    try {
      await Future.wait([
        getIt.isReady<AppInfoProvider>(),
        getIt.isReady<UpdateProvider>(),
        getIt.isReady<AppConfigProvider>(),
      ]);
      final updateProvider = getIt<UpdateProvider>();
      final appConfig = getIt<AppConfigProvider>();
      final result = await updateProvider.checkForUpdate();
      if (result.hasUpdate) {
        appConfig.hasUpdateNotification.value = true;
      }
    } catch (e) {
      debugPrint('HomePage._checkForUpdateInBackground error: $e');
    }
  }

  @override
  void dispose() {
    ImmersiveDockService.routeObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _updateWidget();
    }
  }

  Future<void> _updateWidget() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        await getIt<WidgetUpdateService>().updateWidgetData();
      } catch (e) {
        debugPrint('Widget update failed: $e');
      }
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
    final authProvider = getIt<ScuAuthProvider>();
    final l10n = AppLocalizations.of(context)!;

    return ValueListenableBuilder<List<String>>(
      valueListenable: appConfig.visibleDockIds,
      builder: (context, visibleIds, _) {
        _clampCurrentIndex(visibleIds);

        return ValueListenableBuilder<bool>(
          valueListenable: appConfig.hasUpdateNotification,
          builder: (context, hasUpdate, _) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 600;
                final showRail = isWide && visibleIds.length >= 2;
                final showBar = !isWide && visibleIds.length >= 2;
                final pageContent = ListenableBuilder(
                  listenable: Listenable.merge([
                    appConfig.cardSizeAnimationDuration,
                    appConfig.enablePageTransitionAnimation,
                    appConfig.immersiveDockEnabled,
                  ]),
                  builder: (context, _) {
                    // 原生沉浸光感底栏模式下关闭切页滑动/淡入动画：
                    // 两个重型页面同屏动画是切换掉帧的主因，瞬时切换
                    // 与 HarmonyOS 原生应用（AppGallery 等）行为一致
                    final nativeDockActive = ImmersiveDockService.isOhos &&
                        showBar &&
                        appConfig.immersiveDockEnabled.value;
                    return AuthScopedIndexedStack(
                      authListenable: authProvider,
                      isAuthenticated: () => authProvider.isLoggedIn,
                      visibleIds: visibleIds,
                      selectedIndex: _currentIndex,
                      duration: appConfig.cardSizeAnimationDuration.value,
                      enableAnimation:
                          appConfig.enablePageTransitionAnimation.value &&
                          !nativeDockActive,
                      axis: showRail ? Axis.vertical : Axis.horizontal,
                      pageBuilder: (id) => campusItemConfigById(id).page(),
                    );
                  },
                );
                return ListenableBuilder(
                  listenable: Listenable.merge([
                    appConfig.immersiveDockEnabled,
                    appConfig.immersiveDockStyle,
                    appConfig.immersiveDockColorInvert,
                    appConfig.immersiveDockInteractive,
                  ]),
                  builder: (context, _) {
                    // HarmonyOS 原生沉浸光感底栏：窄屏且启用时接管底部导航
                    final useNativeDock =
                        ImmersiveDockService.isOhos &&
                        showBar &&
                        appConfig.immersiveDockEnabled.value;
                    _syncNativeDock(
                      appConfig,
                      visibleIds,
                      hasUpdate,
                      l10n,
                      showBar,
                    );
                    return Scaffold(
                      // 让页面内容延伸到悬浮底栏下方，滚动时透出光感模糊
                      extendBody: true,
                      body: Row(
                        children: [
                          // Rail placeholder: always present, hidden via Offstage
                          Offstage(
                            offstage: !showRail,
                            child: NavigationRail(
                              selectedIndex: _currentIndex,
                              onDestinationSelected: (index) {
                                setState(() => _currentIndex = index);
                              },
                              labelType: NavigationRailLabelType.all,
                              destinations: visibleIds
                                  .map(
                                    (id) =>
                                        _buildRailDestination(id, hasUpdate, l10n),
                                  )
                                  .toList(),
                            ),
                          ),
                          Offstage(
                            offstage: !showRail,
                            child: const VerticalDivider(thickness: 1, width: 1),
                          ),
                          // Page content: always at index 2
                          // 原生底栏悬浮时取消底部安全区，让内容延伸到底栏下方
                          Expanded(
                            child: SafeArea(
                              bottom: !useNativeDock,
                              child: pageContent,
                            ),
                          ),
                        ],
                      ),
                      bottomNavigationBar: useNativeDock
                          ? null
                          : showBar
                              ? ImmersiveDockBar(
                                  selectedIndex: _currentIndex,
                                  onDestinationSelected: (index) {
                                    setState(() => _currentIndex = index);
                                  },
                                  destinations: visibleIds
                                      .map(
                                        (id) => _buildBarDestination(
                                          id,
                                          hasUpdate,
                                          l10n,
                                        ),
                                      )
                                      .toList(),
                                )
                              : null,
                    );
                  },
                );
              },
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

  NavigationRailDestination _buildRailDestination(
    String id,
    bool hasUpdate,
    AppLocalizations l10n,
  ) {
    final config = campusItemConfigById(id);
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
      label: Text(config.dockLabel(l10n)),
    );
  }

  NavigationDestination _buildBarDestination(
    String id,
    bool hasUpdate,
    AppLocalizations l10n,
  ) {
    final config = campusItemConfigById(id);
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
      label: config.dockLabel(l10n),
      tooltip: '',
    );
  }
}
