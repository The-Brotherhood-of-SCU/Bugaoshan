import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/providers/riverpod/settings/app_config_pods.dart';
import 'package:bugaoshan/providers/riverpod/course/course_pods.dart';
import 'package:bugaoshan/pages/course/widgets/course_grid.dart';
import 'package:bugaoshan/utils/holiday_utils.dart';
import 'package:bugaoshan/widgets/common/background_image_view.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

class CoursePage extends ConsumerStatefulWidget {
  const CoursePage({super.key, this.demoMode = false});

  final bool demoMode;

  @override
  ConsumerState<CoursePage> createState() => _CoursePageState();
}

class _CoursePageState extends ConsumerState<CoursePage> with WidgetsBindingObserver {
  static const String _tag = 'CoursePageState';

  final courseProvider = getIt<CourseProvider>();
  final appConfig = getIt<AppConfigProvider>();

  /// 页面级控制器（demo 模式或无课表时为 null）。
  /// 不进 GetIt —— demo/真实两个 CoursePage 实例共存时单例语义错误。
  CoursePageController? _controller;

  bool _promptedNextSemester = false;
  bool _hasScheduleListenerAdded = false;

  @override
  void initState() {
    super.initState();

    if (!widget.demoMode) {
      // 非 demo 模式：始终监听 hasSchedule 空↔非空翻转，覆盖「无→有」与「有→无」两个方向。
      // 这样初始有课表时也能在删除最后一条课表时及时回到空状态，避免只在空状态才监听导致的失联。
      courseProvider.allSchedules.addListener(_onHasScheduleChanged);
      courseProvider.scheduleConfig.addListener(_onHasScheduleChanged);
      _hasScheduleListenerAdded = true;

      if (courseProvider.hasSchedule) {
        _createController();
      }
    }
  }

  void _createController() {
    WidgetsBinding.instance.addObserver(this);
    _controller = CoursePageController(
      scheduleConfig: courseProvider.scheduleConfig,
      allSchedules: courseProvider.allSchedules,
      animationDuration: appConfig.cardSizeAnimationDuration,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkAndPromptNextSemester();
    });
  }

  void _onHasScheduleChanged() {
    final hasSchedule = courseProvider.hasSchedule;
    final hasConfig = courseProvider.scheduleConfig.value != null;
    if (hasSchedule && hasConfig && _controller == null && !widget.demoMode) {
      // 无→有：创建控制器并重建。保持监听以便后续还能感知「有→无」。
      if (!mounted) return;
      setState(() {
        _createController();
      });
    } else if (!hasSchedule && _controller != null) {
      // 有→无：销毁控制器，回到空状态。保持监听以便再次「无→有」。
      WidgetsBinding.instance.removeObserver(this);
      _controller?.dispose();
      _controller = null;
      if (!mounted) return;
      setState(() {});
    }
  }

  @override
  void dispose() {
    if (!widget.demoMode) {
      if (_hasScheduleListenerAdded) {
        courseProvider.allSchedules.removeListener(_onHasScheduleChanged);
        courseProvider.scheduleConfig.removeListener(_onHasScheduleChanged);
      }
      if (_controller != null) {
        WidgetsBinding.instance.removeObserver(this);
        _controller?.dispose();
      }
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_controller == null) return;
    // 跨天或长时间后台后回前台：刷新放假页可用性 + 顶栏徽章。
    // 刻意不跳周 —— 回前台不自动跳当前周。
    // 裸 setState 必须保留：CourseGrid 的今天列高亮/节假日角标读 DateTime.now()，
    // 删了会破坏跨夜刷新。
    _controller?.refreshToday();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final hasSchedule = ref.watch(hasScheduleProvider);
    final isLoading = ref.watch(courseIsLoadingProvider);
    final schedules = ref.watch(allSchedulesProvider);
    final currentConfig = ref.watch(currentScheduleConfigProvider);
    final animDuration =
        ref.watch(cardSizeAnimationDurationSettingProvider);

    return Column(
      children: [
        if (!widget.demoMode && _controller != null)
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
              animationDuration: animDuration,
              onPreviousWeek: _controller!.goToPreviousPage,
              onNextWeek: _controller!.goToNextPage,
              onGoToCurrentWeek: _controller!.goToToday,
              onImport: _onImport,
              onExport: _onExport,
              onAddCourse: _onAddCourse,
              schedules: schedules,
              currentScheduleId: currentConfig?.id,
              onSwitchSchedule: (id) => courseProvider.switchSchedule(id),
              onOpenScheduleManagement: () =>
                  _openScheduleManagement(logicRootContext),
            ),
          ),
        Expanded(
          child: Stack(
            children: [
              _buildBackgroundImage(context),
              widget.demoMode || hasSchedule
                  ? _buildCourseGrid(context, null)
                  : _buildNoScheduleView(context, null),
              if (isLoading)
                const Center(child: CircularProgressIndicator()),
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

  Widget _buildBackgroundImage(BuildContext context) {
    final path = ref.watch(backgroundImagePathSettingProvider);
    if (path == null) return const SizedBox.shrink();
    final crop = ref.watch(backgroundImageCropSettingProvider);
    final opacity = ref.watch(backgroundImageOpacitySettingProvider);
    return Positioned.fill(
      child: BackgroundImageView(
        path: path,
        crop: crop,
        overlayOpacity: opacity,
      ),
    );
  }

  Widget _buildCourseGrid(BuildContext context, Widget? _) {
    // demo 模式：若 provider 暂无 schedule，用本地占位 config 保证预览可渲染
    final config =
        ref.watch(currentScheduleConfigProvider) ??
        ScheduleConfig(
          semesterStartDate: DateTime.now().toMonday(),
          totalWeeks: kDefaultTotalWeeks,
        );
    final allCourses = widget.demoMode
        ? kDemoCourses
        : ref.watch(coursesListProvider);

    if (widget.demoMode) {
      // 预览模式：固定显示第 1 周，不滑动、不跟随当前课表周数
      return CourseGrid(
        courses: allCourses,
        config: config,
        displayWeek: 1,
        totalWeeks: config.totalWeeks,
      );
    }

    // 保险丝：非 demo 模式下网格只应在控制器就绪后构建。导入落库的瞬态
    // 间隙里控制器可能尚未创建（scheduleConfig 尚未就位），空占位一帧即可，
    // 不能让 _controller! 的空指针崩溃打断渲染。
    final controller = _controller;
    if (controller == null) return const SizedBox.shrink();
    final totalWeeks = controller.totalWeeks;
    final animDuration =
        ref.watch(cardSizeAnimationDurationSettingProvider);
    // build 内每次重读 controller.pageController —— detach 期间可能被换实例，
    // 缓存到局部之外会导致 CourseSwipePageView 持有失效的旧控制器。
    return ListenableBuilder(
      listenable: controller.showVacationPage,
      builder: (context, _) => CourseSwipePageView(
        controller: controller.pageController,
        itemCount: controller.pageCount,
        animationDuration: animDuration,
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
    ),
  );
}

  Widget _buildNoScheduleView(BuildContext context, Widget? _) {
    return NoScheduleView(
      onOpenManagement: () => _openScheduleManagement(context),
      onImport: _onImport,
      onAddSchedule: () => _openAddScheduleDialog(context),
    );
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
      if (currentSchedule == null) return;
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
        unawaited(courseProvider.switchSchedule(matchId));
      }
    } catch (e, logStackTrace) {
      AppLog.e(
        _tag,
        '_checkAndPromptNextSemester 失败',
        error: e,
        stackTrace: logStackTrace,
      );
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

  void _onExport() => CoursePageActions.showExportSheet(
    context,
    visibleWeek: _controller?.visibleWeek,
  );

  void _onAddCourse() {
    final cfg = courseProvider.scheduleConfig.value;
    if (cfg == null) return;
    CoursePageActions.navigateToAddCourse(context, cfg);
  }

  void _onCourseTap(Course course) =>
      CoursePageActions.showCourseDetailSheet(context, course, courseProvider);

  void _onCourseLongPress(Course course) =>
      CoursePageActions.handleCourseLongPress(context, course, courseProvider);

  void _onEmptyTap(int dayOfWeek, int section) {
    final cfg = courseProvider.scheduleConfig.value;
    if (cfg == null) return;
    CoursePageActions.handleEmptyTap(context, dayOfWeek, section, cfg);
  }

  void _onSpecialDayTap(DateTime date, SpecialDayInfo info) =>
      CoursePageActions.handleSpecialDayTap(context, date, info);
}
