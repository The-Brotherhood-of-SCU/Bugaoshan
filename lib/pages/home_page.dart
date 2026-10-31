import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/campus_item_config.dart';
import 'package:bugaoshan/models/student_type.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/providers/update_provider.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/scu_backend/core/auth_coordinator.dart';
import 'package:bugaoshan/services/widget_update_service.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/widgets/common/auth_scoped_indexed_stack.dart';
import 'package:bugaoshan/widgets/navigation/adaptive_home_dock.dart';
import 'package:bugaoshan/widgets/navigation/home_dock_symbols.dart';
import 'package:bugaoshan/widgets/navigation/home_dock_insets.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
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
      await getIt.isReady<ScuAuthProvider>();
      final authProvider = getIt<ScuAuthProvider>();
      if (authProvider.isLoggedIn) {
        unawaited(getIt<AuthCoordinator>().warmUpAll());
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
    final appConfig = getIt<AppConfigProvider>();
    final authProvider = getIt<ScuAuthProvider>();
    final l10n = AppLocalizations.of(context)!;

    return ValueListenableBuilder<List<String>>(
      valueListenable: appConfig.visibleDockIds,
      builder: (context, savedIds, _) {
        // dock 中不属于当前学生身份的功能项临时隐藏，
        // 不改动 visibleDockIds 里保存的配置，切回身份后恢复。
        return ValueListenableBuilder<StudentType>(
          valueListenable: appConfig.studentType,
          builder: (context, studentType, _) {
            final visibleIds = [
              for (final id in savedIds)
                if (campusItemVisibleForStudentType(
                  campusItemConfigById(id),
                  studentType,
                ))
                  id,
            ];
            _clampCurrentIndex(visibleIds);

            return ValueListenableBuilder<bool>(
              valueListenable: appConfig.hasUpdateNotification,
              builder: (context, hasUpdate, _) {
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
                    final pageContent = ListenableBuilder(
                      listenable: Listenable.merge([
                        appConfig.cardSizeAnimationDuration,
                        appConfig.enableDockSwitchAnimation,
                      ]),
                      builder: (context, _) {
                        return AuthScopedIndexedStack(
                          authListenable: authProvider,
                          isAuthenticated: () => authProvider.isLoggedIn,
                          visibleIds: visibleIds,
                          selectedIndex: _currentIndex,
                          duration: appConfig.cardSizeAnimationDuration.value,
                          enableAnimation:
                              appConfig.enableDockSwitchAnimation.value,
                          axis: showRail ? Axis.vertical : Axis.horizontal,
                          pageBuilder: _buildDockPage,
                        );
                      },
                    );
                    return Scaffold(
                      extendBody: extendBehindDock,
                      body: Row(
                        children: [
                          // Rail placeholder: always present, hidden via Offstage
                          Offstage(
                            offstage: !showRail,
                            child: showRail
                                ? ValueListenableBuilder<bool>(
                                    valueListenable:
                                        appConfig.enableDockSwitchAnimation,
                                    builder: (context, enableAnimation, _) =>
                                        AdaptiveHomeDock(
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
                                        ),
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
                          ? ValueListenableBuilder<bool>(
                              valueListenable:
                                  appConfig.enableDockSwitchAnimation,
                              builder: (context, enableAnimation, _) =>
                                  AdaptiveHomeDock(
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
                                  ),
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
