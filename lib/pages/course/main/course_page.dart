import 'dart:io';

import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/academic_calendar.dart';
import 'package:bugaoshan/models/course.dart';
import 'course_page_actions.dart';
import 'course_page_controller.dart';
import 'course_page_no_schedule_view.dart';
import 'course_page_swipe_page_view.dart';
import 'course_page_top_bar.dart';
import 'course_page_vacation_view.dart';
import 'course_preview_data.dart';
import '../management/schedule_management_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/pages/course/widgets/course_grid.dart';
import 'package:bugaoshan/utils/holiday_utils.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

class CoursePage extends StatefulWidget {
  const CoursePage({super.key, this.demoMode = false});

  final bool demoMode;

  @override
  State<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends State<CoursePage> with WidgetsBindingObserver {
  final courseProvider = getIt<CourseProvider>();
  final appConfig = getIt<AppConfigProvider>();

  /// 页面级控制器（demo 模式为 null）。
  /// 不进 GetIt —— demo/真实两个 CoursePage 实例共存时单例语义错误。
  CoursePageController? _controller;

  bool _promptedNextSemester = false;

  /// 课表网格的 listenable。demo 模式下只需 scheduleConfig；非 demo 模式下
  /// 还需 courses、allSchedules 和 controller.showVacationPage（pageCount 变化时
  /// PageView 需重建）。grid 不监听 controller 本身 —— 翻页由 PageController
  /// 直接驱动，不需要整 PageView 重建。
  late final Listenable _gridListenable;

  late final Listenable _bgImageListenable = Listenable.merge([
    appConfig.backgroundImagePath,
    appConfig.backgroundImageOpacity,
  ]);

  @override
  void initState() {
    super.initState();

    if (widget.demoMode) {
      // 预览模式：固定第 1 周，不建控制器、不挂监听、不注册 observer、不弹提示
      // —— 修 demoMode 干扰真实课表页的 bug（以前 postFrame 写全局 currentWeek
      // 把 IndexedStack 里的真实页顶回当前周，甚至弹「切换学期」对话框）。
      _gridListenable = courseProvider.scheduleConfig;
      return;
    }

    WidgetsBinding.instance.addObserver(this);
    _controller = CoursePageController(
      scheduleConfig: courseProvider.scheduleConfig,
      allSchedules: courseProvider.allSchedules,
      animationDuration: appConfig.cardSizeAnimationDuration,
    );
    _gridListenable = Listenable.merge([
      courseProvider.courses,
      courseProvider.scheduleConfig,
      courseProvider.allSchedules,
      _controller!.showVacationPage,
    ]);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkAndPromptNextSemester();
    });
  }

  @override
  void dispose() {
    if (!widget.demoMode) {
      WidgetsBinding.instance.removeObserver(this);
      _controller?.dispose();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // 跨天或长时间后台后回前台：刷新放假页可用性 + 顶栏徽章。
    // 刻意不跳周 —— 回前台不自动跳当前周。
    // 裸 setState 必须保留：CourseGrid 的今天列高亮/节假日角标读 DateTime.now()，
    // 删了会破坏跨夜刷新。
    _controller?.refreshToday();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (!widget.demoMode)
          ListenableBuilder(
            listenable: _controller!,
            builder: (context, _) => CoursePageTopBar(
              visibleWeek: _controller!.visibleWeek,
              totalWeeks: _controller!.totalWeeks,
              actualWeek: _controller!.actualWeek,
              isViewingVacation: _controller!.isViewingVacation,
              isTodayOnVacation: _controller!.isTodayOnVacation,
              isNotStarted: _controller!.isNotStarted,
              canGoPrevious: _controller!.canGoPrevious,
              canGoNext: _controller!.canGoNext,
              animationDuration: appConfig.cardSizeAnimationDuration.value,
              onPreviousWeek: _controller!.goToPreviousPage,
              onNextWeek: _controller!.goToNextPage,
              onGoToCurrentWeek: _controller!.goToToday,
              onImport: _onImport,
              onExport: _onExport,
              onAddCourse: _onAddCourse,
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              ListenableBuilder(
                listenable: _bgImageListenable,
                builder: _buildBackgroundImage,
              ),
              ListenableBuilder(
                listenable: _gridListenable,
                builder: (context, _) =>
                    widget.demoMode || courseProvider.hasSchedule
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
    final allCourses = widget.demoMode
        ? kDemoCourses
        : courseProvider.courses.value;

    if (widget.demoMode) {
      // 预览模式：固定显示第 1 周，不滑动、不跟随当前课表周数
      return CourseGrid(
        courses: allCourses,
        config: config,
        displayWeek: 1,
        totalWeeks: config.totalWeeks,
      );
    }

    final controller = _controller!;
    final totalWeeks = controller.totalWeeks;
    // build 内每次重读 controller.pageController —— detach 期间可能被换实例，
    // 缓存到局部之外会导致 CourseSwipePageView 持有失效的旧控制器。
    return CourseSwipePageView(
      controller: controller.pageController,
      itemCount: controller.pageCount,
      animationDuration: appConfig.cardSizeAnimationDuration.value,
      onPageChanged: controller.onPageSettled,
      itemBuilder: (context, index) {
        if (controller.showVacationPage.value && index >= totalWeeks) {
          return VacationView(
            controller: controller,
            onViewNextSemester: _onViewNextSemester,
          );
        }
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
    return NoScheduleView(
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

  Future<void> _checkAndPromptNextSemester() async {
    if (_promptedNextSemester) return;
    _promptedNextSemester = true;

    try {
      final controller = _controller;
      if (controller == null) return;
      final nextSemester = await controller.ensureCalendarNextSemester();
      if (nextSemester == null) return;

      final registrationDate =
          nextSemester.registrationEvent?.date ?? nextSemester.startDate;
      final today = DateTime.now();
      if (today.isBefore(registrationDate)) return;

      // Check if already viewing next semester
      final currentSchedule = courseProvider.scheduleConfig.value;
      if (currentSchedule.semesterStartDate.year == registrationDate.year &&
          currentSchedule.semesterStartDate.month == registrationDate.month) {
        return;
      }

      final matchId = nextSemester.findMatchingScheduleId(
        courseProvider.allSchedules.value,
      );
      if (matchId == null) return;

      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(l10n.promptSwitchSemesterTitle),
          content: Text(l10n.promptSwitchSemester),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: Text(l10n.switchSchedule),
            ),
          ],
        ),
      );
      if (confirmed == true) {
        courseProvider.switchSchedule(matchId);
      }
    } catch (e) {
      debugPrint('CoursePage: failed to check next semester: $e');
    }
  }

  void _onViewNextSemester(AcademicCalendarSemester semester) {
    final l10n = AppLocalizations.of(context)!;
    final matchId = semester.findMatchingScheduleId(
      courseProvider.allSchedules.value,
    );
    if (matchId != null) {
      courseProvider.switchSchedule(matchId);
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.noNextSemesterSchedule)));
    }
  }

  // ---- Delegates to CoursePageActions (解耦 extension) ----

  void _onImport() =>
      CoursePageActions.showImportSheet(context, courseProvider);

  void _onExport() => CoursePageActions.showExportSheet(context);

  void _onAddCourse() => CoursePageActions.navigateToAddCourse(context);

  void _onCourseTap(Course course) =>
      CoursePageActions.showCourseDetailSheet(context, course, courseProvider);

  void _onCourseLongPress(Course course) =>
      CoursePageActions.handleCourseLongPress(context, course, courseProvider);

  void _onEmptyTap(int dayOfWeek, int section) =>
      CoursePageActions.handleEmptyTap(context, dayOfWeek, section);

  void _onSpecialDayTap(DateTime date, SpecialDayInfo info) =>
      CoursePageActions.handleSpecialDayTap(context, date, info);
}
