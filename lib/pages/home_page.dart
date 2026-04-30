import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus_page.dart';
import 'package:bugaoshan/pages/course_page.dart';
import 'package:bugaoshan/pages/profile_page.dart';
import 'package:bugaoshan/providers/course_provider.dart';
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
  late List<NavigationItemData> _navigationItems;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _localizations = AppLocalizations.of(context)!;
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

  @override
  Widget build(BuildContext context) {
    return _buildMainScreen();
  }

  Widget _buildMainScreen() {
    return OrientationBuilder(
      builder: (context, orientation) {
        if (orientation == Orientation.landscape) {
          // Landscape mode: use left navigation rail
          return Scaffold(
            body: Row(
              children: [
                NavigationRail(
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
                  destinations: _navigationItems
                      .map(
                        (item) => NavigationRailDestination(
                          icon: Icon(item.icon),
                          selectedIcon: Icon(item.selectedIcon),
                          label: Text(item.label),
                        ),
                      )
                      .toList(),
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
            bottomNavigationBar: NavigationBar(
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
              destinations: _navigationItems
                  .map(
                    (item) => NavigationDestination(
                      icon: Icon(item.icon),
                      selectedIcon: Icon(item.selectedIcon),
                      label: item.label,
                    ),
                  )
                  .toList(),
            ),
          );
        }
      },
    );
  }
}
