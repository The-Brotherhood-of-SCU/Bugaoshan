import 'dart:convert';
import 'dart:io';

import 'package:bugaoshan/widgets/common/third_center.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/course/course_edit_page.dart';
import 'package:bugaoshan/pages/course/import_schedule_page.dart';
import 'package:bugaoshan/pages/course/schedule_management_page.dart';
import 'package:bugaoshan/services/api/academic_calendar_service.dart';
import 'package:bugaoshan/models/academic_calendar.dart';
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
part 'course_page_vacation_view.dart';

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
  bool _isViewingVacation = false;
  bool _promptedNextSemester = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final config = courseProvider.scheduleConfig.value;
    final actualWeek = config.getCurrentWeek();
    final totalWeeks = config.totalWeeks;
    _isViewingVacation = actualWeek > totalWeeks;
    _visibleWeek = _isViewingVacation
        ? totalWeeks
        : courseProvider.currentWeek.value;
    _pageController = PageController(
      initialPage: _isViewingVacation ? totalWeeks : _visibleWeek - 1,
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
        duration: appConfig.cardSizeAnimationDuration.value,
        curve: AppCurves.quick,
      );
    } else if (_visibleWeek != courseProvider.currentWeek.value) {
      setState(() {
        _visibleWeek = courseProvider.currentWeek.value;
      });
    }
  }

  void _syncToCurrentWeek() {
    final config = courseProvider.scheduleConfig.value;
    final actualWeek = config.getCurrentWeek();
    final totalWeeks = config.totalWeeks;
    if (actualWeek > totalWeeks) {
      _navigateToVacation();
    } else {
      courseProvider.updateCurrentWeek(actualWeek);
    }
    _checkAndPromptNextSemester();
  }

  void _navigateToVacation() {
    if (!_isViewingVacation && _pageController.hasClients) {
      _isViewingVacation = true;
      _pageController.animateToPage(
        courseProvider.scheduleConfig.value.totalWeeks,
        duration: appConfig.cardSizeAnimationDuration.value,
        curve: AppCurves.quick,
      );
      setState(() {});
    }
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
              isViewingVacation: _isViewingVacation,
              onPreviousWeek: () => _isViewingVacation
                  ? _changeWeek(courseProvider.scheduleConfig.value.totalWeeks)
                  : _changeWeek(courseProvider.currentWeek.value - 1),
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
        ? _kDemoCourses
        : courseProvider.courses.value;
    final totalWeeks = config.totalWeeks;

    if (widget.demoMode) {
      // 预览模式：固定显示第 1 周，不滑动、不跟随当前课表周数
      return CourseGrid(
        courses: allCourses,
        config: config,
        displayWeek: 1,
        totalWeeks: totalWeeks,
      );
    }

    return _SwipePageView(
      controller: _pageController,
      itemCount: totalWeeks + 1,
      onPageChanged: _onPageChanged,
      itemBuilder: (context, index) {
        if (index >= totalWeeks) {
          return _VacationView(
            scheduleConfig: config,
            allSchedules: courseProvider.allSchedules.value,
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
    final totalWeeks = courseProvider.scheduleConfig.value.totalWeeks;
    if (index >= totalWeeks) {
      if (!_isViewingVacation) {
        setState(() => _isViewingVacation = true);
      }
      return;
    }
    if (_isViewingVacation) {
      setState(() => _isViewingVacation = false);
    }
    final displayWeek = index + 1;
    if (_visibleWeek != displayWeek) {
      setState(() {
        _visibleWeek = displayWeek;
      });
    }
    courseProvider.updateCurrentWeek(displayWeek);
  }

  void _changeWeek(int newWeek) {
    final totalWeeks = courseProvider.scheduleConfig.value.totalWeeks;
    if (newWeek > totalWeeks) {
      _navigateToVacation();
      return;
    }
    if (newWeek < 1) newWeek = 1;
    if (_isViewingVacation) {
      setState(() => _isViewingVacation = false);
    }
    courseProvider.updateCurrentWeek(newWeek);
  }

  void _goToCurrentWeek() {
    _syncToCurrentWeek();
  }

  Future<void> _checkAndPromptNextSemester() async {
    if (_promptedNextSemester) return;
    _promptedNextSemester = true;

    try {
      final assetContent = await rootBundle.loadString(
        'assets/academic_calendar.json',
      );
      final decoded = jsonDecode(assetContent) as Map<String, dynamic>;
      final expanded = AcademicCalendarService.expandCalendarJson(decoded);
      final data = AcademicCalendarData.fromJson(expanded);
      final nextSemester = data.findNextSemester(
        courseProvider.scheduleConfig.value.semesterEndDate,
      );
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
    } catch (_) {}
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
}

/// 课程表样式预览中使用的示例课程。
/// 覆盖周一至周五，分布在上午和下午时段，便于在 [SetCourseStylePage] 中预览样式变化。
final List<Course> _kDemoCourses = [
  Course(
    name: '高等数学',
    teacher: '张教授',
    location: '综C407',
    startWeek: 1,
    endWeek: 20,
    dayOfWeek: 1,
    startSection: 1,
    endSection: 2,
    colorValue: 0xFF1976D2,
  ),
  Course(
    name: '大学英语（三）',
    teacher: '李老师',
    location: '综B207',
    startWeek: 1,
    endWeek: 20,
    dayOfWeek: 2,
    startSection: 3,
    endSection: 4,
    colorValue: 0xFF388E3C,
  ),
  Course(
    name: '程序设计基础',
    teacher: '王老师',
    location: '二基楼B501',
    startWeek: 1,
    endWeek: 20,
    dayOfWeek: 3,
    startSection: 6,
    endSection: 8,
    colorValue: 0xFFE64A19,
  ),
  Course(
    name: '线性代数',
    teacher: '赵教授',
    location: '综C103',
    startWeek: 1,
    endWeek: 20,
    dayOfWeek: 4,
    startSection: 1,
    endSection: 2,
    colorValue: 0xFF7B1FA2,
  ),
  Course(
    name: '大学物理（下）',
    teacher: '陈老师',
    location: '综B307',
    startWeek: 1,
    endWeek: 20,
    dayOfWeek: 5,
    startSection: 3,
    endSection: 4,
    colorValue: 0xFF00838F,
  ),
  // 第15周才开始的课程，用于展示「显示非本周课程」开关效果
  Course(
    name: '体育',
    teacher: '刘老师',
    location: '江安体育馆',
    startWeek: 15,
    endWeek: 20,
    dayOfWeek: 1,
    startSection: 5,
    endSection: 6,
    colorValue: 0xFFF9A825,
  ),
];
