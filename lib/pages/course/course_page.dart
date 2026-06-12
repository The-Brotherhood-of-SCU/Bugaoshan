import 'dart:io';

import 'package:bugaoshan/widgets/common/third_center.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/course/course_edit_page.dart';
import 'package:bugaoshan/pages/course/import_schedule_page.dart';
import 'package:bugaoshan/pages/course/schedule_management_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/widgets/course/course_detail_sheet.dart';
import 'package:bugaoshan/widgets/course/course_grid.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:bugaoshan/utils/export_schedule_utils.dart';
import 'package:bugaoshan/utils/holiday_utils.dart';
import 'package:bugaoshan/widgets/course/special_day_sheet.dart';
import 'package:bugaoshan/utils/app_shapes.dart';

part 'course_page_swipe_page_view.dart';
part 'course_page_top_bar.dart';
part 'course_page_actions.dart';
part 'course_page_no_schedule_view.dart';

class CoursePage extends StatefulWidget {
  const CoursePage({super.key, this.demoMode = false});

  final bool demoMode;

  @override
  State<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> with WidgetsBindingObserver {
  final courseProvider = getIt<CourseProvider>();
  final appConfig = getIt<AppConfigProvider>();
  late PageController _pageController;
  late int _visibleWeek;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _visibleWeek = courseProvider.currentWeek.value;
    _pageController = PageController(
      initialPage: courseProvider.currentWeek.value - 1,
    );
    courseProvider.currentWeek.addListener(_onCurrentWeekChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncToCurrentWeek();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    courseProvider.currentWeek.removeListener(_onCurrentWeekChanged);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _syncToCurrentWeek();
    }
  }

  void _onCurrentWeekChanged() {
    final targetPage = courseProvider.currentWeek.value - 1;
    if (_pageController.hasClients &&
        _pageController.page?.round() != targetPage) {
      _pageController.animateToPage(
        targetPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else if (_visibleWeek != courseProvider.currentWeek.value) {
      setState(() {
        _visibleWeek = courseProvider.currentWeek.value;
      });
    }
  }

  void _syncToCurrentWeek() {
    final currentWeek = courseProvider.scheduleConfig.value.getCurrentWeek();
    courseProvider.updateCurrentWeek(currentWeek);
  }

  @override
  Widget build(BuildContext context) {
    final courseDataListenable = Listenable.merge([
      courseProvider.courses,
      courseProvider.scheduleConfig,
      courseProvider.currentWeek,
      courseProvider.allSchedules,
    ]);
    final bgImageListenable = Listenable.merge([
      appConfig.backgroundImagePath,
      appConfig.backgroundImageOpacity,
    ]);

    return Column(
      children: [
        if (!widget.demoMode)
          ListenableBuilder(
            listenable: courseDataListenable,
            builder: (context, _) => _TopBar(
              week: courseProvider.currentWeek.value,
              totalWeeks: courseProvider.scheduleConfig.value.totalWeeks,
              visibleWeek: _visibleWeek,
              onPreviousWeek: () =>
                  _changeWeek(courseProvider.currentWeek.value - 1),
              onNextWeek: () =>
                  _changeWeek(courseProvider.currentWeek.value + 1),
              onGoToCurrentWeek: _goToCurrentWeek,
              onImport: _onImport,
              onExport: _onExport,
              onAddCourse: _onAddCourse,
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              ListenableBuilder(
                listenable: bgImageListenable,
                builder: _buildBackgroundImage,
              ),
              ListenableBuilder(
                listenable: courseDataListenable,
                builder: (context, _) => courseProvider.hasSchedule
                    ? _buildCourseGrid(context, null)
                    : _buildNoScheduleView(context, null),
              ),
              ValueListenableBuilder<bool>(
                valueListenable: courseProvider.isLoading,
                builder: _buildLoadingIndicator,
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _openScheduleManagement(BuildContext context) {
    popupOrNavigate(context, const ScheduleManagementPage());
  }

  void _openAddScheduleDialog(BuildContext context) {
    promptForNewScheduleConfig(context, courseProvider);
  }

  Widget _buildBackgroundImage(BuildContext context, Widget? _) {
    final path = appConfig.backgroundImagePath.value;
    if (path == null) return const SizedBox.shrink();
    return Positioned.fill(
      child: Image(
        image: FileImage(File(path)),
        fit: BoxFit.cover,
        // 使用 frameBuilder 监听第一帧完成并做淡入动画，避免白屏突变
        frameBuilder:
            (BuildContext ctx, Widget child, int? frame, bool wasSync) {
              final visible = frame != null || wasSync;
              return AnimatedOpacity(
                opacity: visible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: child,
              );
            },
        color: Colors.white.withAlpha(
          (appConfig.backgroundImageOpacity.value * 255).round(),
        ),
        colorBlendMode: BlendMode.modulate,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }

  Widget _buildCourseGrid(BuildContext context, Widget? _) {
    final config = courseProvider.scheduleConfig.value;
    final allCourses = courseProvider.courses.value;
    final totalWeeks = config.totalWeeks;
    return _SwipePageView(
      controller: _pageController,
      itemCount: totalWeeks,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        return CourseGrid(
          courses: allCourses,
          config: config,
          displayWeek: index + 1,
          totalWeeks: totalWeeks,
          onCourseTap: widget.demoMode ? null : _onCourseTap,
          onCourseLongPress: widget.demoMode ? null : _onCourseLongPress,
          onEmptyTap: widget.demoMode ? null : _onEmptyTap,
          onSpecialDayTap: widget.demoMode ? null : _onSpecialDayTap,
        );
      },
    );
  }

  Widget _buildNoScheduleView(BuildContext context, Widget? _) {
    return _NoScheduleView(
      onOpenManagement: () => _openScheduleManagement(context),
      onImport: _onImport,
      onAddSchedule: () => _openAddScheduleDialog(context),
    );
  }

  Widget _buildLoadingIndicator(
    BuildContext context,
    bool isLoading,
    Widget? _,
  ) {
    if (!isLoading) return const SizedBox.shrink();
    return const Center(child: CircularProgressIndicator());
  }

  void _onPageChanged(int index) {
    final displayWeek = index + 1;
    if (_visibleWeek != displayWeek) {
      setState(() {
        _visibleWeek = displayWeek;
      });
    }
    courseProvider.updateCurrentWeek(displayWeek);
  }

  void _changeWeek(int newWeek) {
    courseProvider.updateCurrentWeek(newWeek);
  }

  void _goToCurrentWeek() {
    _syncToCurrentWeek();
  }
}
