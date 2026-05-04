import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus_page.dart';
import 'package:bugaoshan/pages/campus/academic_calendar/academic_calendar_page.dart';
import 'package:bugaoshan/pages/campus/balance_query/balance_query_page.dart';
import 'package:bugaoshan/pages/campus/classroom/classroom_page.dart';
import 'package:bugaoshan/pages/campus/ccyl/ccyl_page.dart';
import 'package:bugaoshan/pages/campus/grades/grades_page.dart';
import 'package:bugaoshan/pages/campus/network_device/network_device_page.dart';
import 'package:bugaoshan/pages/campus/plan_completion/plan_completion_page.dart';
import 'package:bugaoshan/pages/campus/train_program/train_program_page.dart';
import 'package:bugaoshan/pages/course/course_page.dart';
import 'package:bugaoshan/pages/profile_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/app_info_provider.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/update_service.dart';
import 'package:bugaoshan/services/widget_update_service.dart';
import 'package:bugaoshan/utils/constants.dart';

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

  // Lightweight dock item: icon + label only, no page widget.
  static const _dockMeta = <String, ({IconData icon, IconData selectedIcon})>{
    dockIdCourse: (
      icon: Icons.menu_book_outlined,
      selectedIcon: Icons.menu_book,
    ),
    dockIdCampus: (icon: Icons.school_outlined, selectedIcon: Icons.school),
    dockIdProfile: (icon: Icons.person_outlined, selectedIcon: Icons.person),
    dockIdGrades: (
      icon: Icons.bar_chart_outlined,
      selectedIcon: Icons.bar_chart,
    ),
    dockIdCcyl: (icon: Icons.event_outlined, selectedIcon: Icons.event),
    dockIdPlanCompletion: (
      icon: Icons.assignment_turned_in_outlined,
      selectedIcon: Icons.assignment_turned_in,
    ),
    dockIdTrainProgram: (
      icon: Icons.school_outlined,
      selectedIcon: Icons.school,
    ),
    dockIdClassroom: (
      icon: Icons.meeting_room_outlined,
      selectedIcon: Icons.meeting_room,
    ),
    dockIdNetworkDevice: (
      icon: Icons.router_outlined,
      selectedIcon: Icons.router,
    ),
    dockIdBalanceQuery: (
      icon: Icons.account_balance_wallet_outlined,
      selectedIcon: Icons.account_balance_wallet,
    ),
    dockIdAcademicCalendar: (
      icon: Icons.calendar_month_outlined,
      selectedIcon: Icons.calendar_month,
    ),
  };

  String _dockLabel(String id, AppLocalizations l10n) => switch (id) {
    dockIdCourse => l10n.dockLabelCourse,
    dockIdCampus => l10n.dockLabelCampus,
    dockIdProfile => l10n.dockLabelProfile,
    dockIdGrades => l10n.dockLabelGrades,
    dockIdCcyl => l10n.dockLabelCcyl,
    dockIdPlanCompletion => l10n.dockLabelPlanCompletion,
    dockIdTrainProgram => l10n.dockLabelTrainProgram,
    dockIdClassroom => l10n.dockLabelClassroom,
    dockIdNetworkDevice => l10n.dockLabelNetworkDevice,
    dockIdBalanceQuery => l10n.dockLabelBalanceQuery,
    dockIdAcademicCalendar => l10n.dockLabelAcademicCalendar,
    _ => id,
  };

  // Only builds the page widget when actually selected.
  Widget _buildPage(String id) => switch (id) {
    dockIdCourse => CoursePage(),
    dockIdCampus => const CampusPage(),
    dockIdProfile => ProfilePage(),
    dockIdGrades => const GradesPage(),
    dockIdCcyl => const CcylPage(),
    dockIdPlanCompletion => const PlanCompletionPage(),
    dockIdTrainProgram => const TrainProgramPage(),
    dockIdClassroom => const ClassroomPage(),
    dockIdNetworkDevice => const NetworkDevicePage(),
    dockIdBalanceQuery => const BalanceQueryPage(),
    dockIdAcademicCalendar => const AcademicCalendarPage(),
    _ => ProfilePage(),
  };

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
        final currentPage = _buildPage(currentId);

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
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
          _onTabSelected(visibleIds[index]);
        },
        destinations: visibleIds
            .map((id) => _buildBarDestination(id, hasUpdate, l10n))
            .toList(),
      ),
    );
  }

  NavigationRailDestination _buildRailDestination(
    String id,
    bool hasUpdate,
    AppLocalizations l10n,
  ) {
    final meta = _dockMeta[id]!;
    final isProfile = id == dockIdProfile;
    return NavigationRailDestination(
      icon: isProfile
          ? _buildUpdateBadge(showBadge: hasUpdate, child: Icon(meta.icon))
          : Icon(meta.icon),
      selectedIcon: isProfile
          ? _buildUpdateBadge(
              showBadge: hasUpdate,
              child: Icon(meta.selectedIcon),
            )
          : Icon(meta.selectedIcon),
      label: Text(_dockLabel(id, l10n)),
    );
  }

  NavigationDestination _buildBarDestination(
    String id,
    bool hasUpdate,
    AppLocalizations l10n,
  ) {
    final meta = _dockMeta[id]!;
    final isProfile = id == dockIdProfile;
    return NavigationDestination(
      icon: isProfile
          ? _buildUpdateBadge(showBadge: hasUpdate, child: Icon(meta.icon))
          : Icon(meta.icon),
      selectedIcon: isProfile
          ? _buildUpdateBadge(
              showBadge: hasUpdate,
              child: Icon(meta.selectedIcon),
            )
          : Icon(meta.selectedIcon),
      label: _dockLabel(id, l10n),
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
