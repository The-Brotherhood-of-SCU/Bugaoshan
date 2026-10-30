import 'package:bugaoshan/widgets/navigation/home_dock_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/providers/riverpod/settings/app_config_pods.dart';
import 'package:bugaoshan/utils/holiday_utils.dart';
import 'course_grid_body.dart';

/// 显示周课程表的网格，包含时间槽和课程卡片。
///
/// 本组件只负责三件事：读 AppConfig、订阅视觉设置、提供滚动容器与底部留白。
/// 表头选型在 [CourseGridHeader]，网格本体在 [CourseGridBody] —— 两者与导出
/// 视图（`ScheduleExportView`）共用；导出时不要滚动容器与 viewport 裁剪。
class CourseGrid extends ConsumerWidget {
  final List<Course> courses;
  final ScheduleConfig config;
  final int displayWeek;
  final int totalWeeks;

  /// 是否聚合显示全部周次的课程（查询类课表用，无“当前周”概念）。
  /// 聚合模式下日期同样无意义，会与 [showHeaderDates] = false 一起
  /// 落到最小周几表头，两个开关语义独立、表头选型收敛到同一处。
  final bool showAllWeeks;

  /// 表头是否显示日期（今天高亮、节假日标记）。查询类课表涉及历年学期，
  /// 日期无意义，可关掉以换用仅周几的最小表头。
  final bool showHeaderDates;
  final bool? showWeekendOverride;
  final void Function(Course course)? onCourseTap;
  final void Function(Course course)? onCourseLongPress;
  final void Function(int dayOfWeek, int section)? onEmptyTap;
  final void Function(DateTime date, SpecialDayInfo info)? onSpecialDayTap;

  const CourseGrid({
    super.key,
    required this.courses,
    required this.config,
    required this.displayWeek,
    this.totalWeeks = 20,
    this.showAllWeeks = false,
    this.showHeaderDates = true,
    this.showWeekendOverride,
    this.onCourseTap,
    this.onCourseLongPress,
    this.onEmptyTap,
    this.onSpecialDayTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showWeekendVal = ref.watch(showWeekendSettingProvider);
    final showWeekend = showWeekendOverride ?? showWeekendVal;
    final backgroundImagePath = ref.watch(backgroundImagePathSettingProvider);
    final hasBackground = backgroundImagePath != null;
    final rowHeight = ref.watch(courseRowHeightSettingProvider);
    final showCourseGrid = ref.watch(showCourseGridSettingProvider);
    final showNonCurrentWeekCourses =
        ref.watch(showNonCurrentWeekCoursesSettingProvider);

    return Column(
      children: [
        CourseGridHeader(
          config: config,
          displayWeek: displayWeek,
          hasBackground: hasBackground,
          showWeekend: showWeekend,
          showAllWeeks: showAllWeeks,
          showHeaderDates: showHeaderDates,
          onSpecialDayTap: onSpecialDayTap,
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.vertical,
            padding: EdgeInsets.only(
              bottom: HomeDockInsets.bottomOf(context),
            ),
            child: CourseGridBody(
              courses: courses,
              config: config,
              displayWeek: displayWeek,
              showWeekend: showWeekend,
              showNonCurrentWeekCourses: showNonCurrentWeekCourses,
              rowHeight: rowHeight,
              showCourseGrid: showCourseGrid,
              showAllWeeks: showAllWeeks,
              onCourseTap: onCourseTap,
              onCourseLongPress: onCourseLongPress,
              onEmptyTap: onEmptyTap,
            ),
          ),
        ),
      ],
    );
  }
}
