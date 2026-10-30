import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/campus_item_config.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/providers/riverpod/settings/app_config_pods.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/services/widget_update_service.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/widgets/common/auth_scoped_indexed_stack.dart';
import 'package:bugaoshan/widgets/navigation/adaptive_home_dock.dart';
import 'package:bugaoshan/widgets/navigation/home_dock_symbols.dart';
import 'package:bugaoshan/widgets/navigation/home_dock_insets.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});

  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage> with WidgetsBindingObserver {
  static const String _tag = 'HomePageState';

  int _currentIndex = 0;
  bool _nativeDock = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkForUpdateInBackground();
    _attemptAutoLogin();
  }

  Future<void> _attemptAutoLogin() async {
    try {
      final authProvider = ref.read(scuAuthProviderBridge);
      if (authProvider.isLoggedIn) {
        unawaited(ref.read(authCoordinatorBridge).warmUpAll());
        return;
      }
      await authProvider.autoLogin();
    } catch (e, logStackTrace) {
      AppLog.e(
        _tag,
        '_attemptAutoLogin 失败',
        error: e,
        stackTrace: logStackTrace,
      );
    }
  }

  Future<void> _checkForUpdateInBackground() async {
    try {
      final updateProvider = ref.read(updateProviderBridge);
      final result = await updateProvider.checkForUpdate();
      if (result.hasUpdate) {
        ref.read(hasUpdateNotificationSettingProvider.notifier).update(true);
      }
    } catch (e, logStackTrace) {
      AppLog.e(
        _tag,
        '_checkForUpdateInBackground 失败',
        error: e,
        stackTrace: logStackTrace,
      );
    }
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

  Future<void> _updateWidget() async {
    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS || Platform.isMacOS)) {
      try {
        await getIt<WidgetUpdateService>().updateWidgetData();
      } catch (e, logStackTrace) {
        AppLog.e(_tag, '_updateWidget 失败', error: e, stackTrace: logStackTrace);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildMainScreen();
  }

  Widget _buildMainScreen() {
    final authProvider = ref.watch(scuAuthProviderBridge);
    final l10n = AppLocalizations.of(context)!;

    final savedIds = ref.watch(visibleDockIdsSettingProvider);
    final studentType = ref.watch(studentTypeSettingProvider);
    final hasUpdate = ref.watch(hasUpdateNotificationSettingProvider);
    final duration = ref.watch(cardSizeAnimationDurationSettingProvider);
    final enableAnimation = ref.watch(enableDockSwitchAnimationSettingProvider);

    final visibleIds = [
      for (final id in savedIds)
        if (campusItemVisibleForStudentType(
          campusItemConfigById(id),
          studentType,
        ))
          id,
    ];
    _clampCurrentIndex(visibleIds);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 600;
        final showRail = isWide && visibleIds.length >= 2;
        final showBar =
            !isWide &&
            visibleIds.length >= 2 &&
            (!_nativeDock ||
                MediaQuery.viewInsetsOf(context).bottom == 0);
        final extendBehindDock = showBar && _nativeDock;
        final pageContent = AuthScopedIndexedStack(
          authListenable: authProvider,
          isAuthenticated: () => authProvider.isLoggedIn,
          visibleIds: visibleIds,
          selectedIndex: _currentIndex,
          duration: duration,
          enableAnimation: enableAnimation,
          axis: showRail ? Axis.vertical : Axis.horizontal,
          pageBuilder: _buildDockPage,
        );
        return Scaffold(
          extendBody: extendBehindDock,
          body: Row(
            children: [
              // Rail placeholder: always present, hidden via Offstage
              Offstage(
                offstage: !showRail,
                child: showRail
                    ? AdaptiveHomeDock(
                        axis: Axis.vertical,
                        reduceMotion: !enableAnimation,
                        selectedIndex: _currentIndex,
                        onDestinationSelected: (index) {
                          setState(
                            () => _currentIndex = index,
                          );
                        },
                        destinations: visibleIds
                            .map(
                              (id) => _buildDockDestination(
                                id,
                                hasUpdate,
                                l10n,
                              ),
                            )
                            .toList(),
                      )
                    : const SizedBox.shrink(),
              ),
              Offstage(
                offstage: !showRail,
                child: const VerticalDivider(
                  thickness: 1,
                  width: 1,
                ),
              ),
              // Page content: always at index 2
              Expanded(
                child: HomeDockBody(
                  extended: extendBehindDock,
                  child: pageContent,
                ),
              ),
            ],
          ),
          bottomNavigationBar: showBar
              ? AdaptiveHomeDock(
                  selectedIndex: _currentIndex,
                  reduceMotion: !enableAnimation,
                  moreLabel: l10n.moreFeaturesTitle,
                  cancelLabel: l10n.cancel,
                  onNativeModeChanged: (native) {
                    if (_nativeDock != native) {
                      setState(() => _nativeDock = native);
                    }
                  },
                  onDestinationSelected: (index) {
                    setState(() => _currentIndex = index);
                  },
                  destinations: visibleIds
                      .map(
                        (id) => _buildDockDestination(
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
  }

  Widget _buildDockPage(String id) {
    final page = campusItemConfigById(id).page();
    if (id == dockIdCourse || id == dockIdCampus || id == dockIdProfile) {
      return page;
    }
    // 其余自定义业务入口由外层整页抬起一块 Dock 高度的空间，保留表单与 FAB
    // 的可操作区域，同时屏蔽被 extendBody 注入的底部 padding：若页面自带底栏
    // （如改造前第二课堂的 NavigationBar）或内层滚动组件再消费一次，就会多留出
    // 一整个 Dock 高度的空白 (#376)。已适配的三张主页不走这里，它们把这段
    // 空间放到滚动内容末尾，而非裁短 viewport。
    return Builder(
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: HomeDockInsets.bottomOf(context)),
        child: HomeDockInsets.consumed(context: context, child: page),
      ),
    );
  }

  void _clampCurrentIndex(List<String> ids) {
    if (ids.isEmpty) {
      _currentIndex = 0;
    } else if (_currentIndex >= ids.length) {
      _currentIndex = ids.length - 1;
    }
  }

  HomeDockDestination _buildDockDestination(
    String id,
    bool hasUpdate,
    AppLocalizations l10n,
  ) {
    final config = campusItemConfigById(id);
    final symbols = homeDockSymbols(id);
    return HomeDockDestination(
      id: id,
      icon: config.icon,
      selectedIcon: config.selectedIcon,
      label: config.dockLabel(l10n),
      symbol: symbols.normal,
      selectedSymbol: symbols.selected,
      showBadge: id == dockIdProfile && hasUpdate,
      badgeLabel: l10n.newVersionAvailable,
    );
  }
}
