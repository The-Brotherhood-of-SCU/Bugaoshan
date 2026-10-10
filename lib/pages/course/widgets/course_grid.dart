import 'package:bugaoshan/widgets/navigation/home_dock_insets.dart';
import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/utils/holiday_utils.dart';
import 'course_grid_body.dart';

/// 显示周课程表的网格，包含时间槽和课程卡片。
///
/// 本组件只负责三件事：读 AppConfig、订阅视觉设置、提供滚动容器与底部留白。
/// 表头选型在 [CourseGridHeader]，网格本体在 [CourseGridBody] —— 两者与导出
/// 视图（`ScheduleExportView`）共用；导出时不要滚动容器与 viewport 裁剪。
class CourseGrid extends StatefulWidget {
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
  State<CourseGrid> createState() => _CourseGridState();
}

class _CourseGridState extends State<CourseGrid> {
  final appConfig = getIt<AppConfigProvider>();

  /// build 里读到的所有 AppConfig 字段。提成字段避免每帧新建 merge 导致
  /// ListenableBuilder 反复解绑重绑订阅。
  late final Listenable _configListenable = Listenable.merge([
    appConfig.showCourseGrid,
    appConfig.courseRowHeight,
    appConfig.showWeekend,
    appConfig.showNonCurrentWeekCourses,
    // build 里读了 backgroundImagePath（hasBackground），必须一并订阅，
    // 否则设置/清除背景图后网格样式不会刷新。
    appConfig.backgroundImagePath,
  ]);

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _configListenable,
      builder: (context, _) {
        final showWeekend =
            widget.showWeekendOverride ?? appConfig.showWeekend.value;
        final hasBackground = appConfig.backgroundImagePath.value != null;
        final rowHeight = appConfig.courseRowHeight.value;
        final showCourseGrid = appConfig.showCourseGrid.value;

        return Column(
          children: [
            CourseGridHeader(
              config: widget.config,
              displayWeek: widget.displayWeek,
              hasBackground: hasBackground,
              showWeekend: showWeekend,
              showAllWeeks: widget.showAllWeeks,
              showHeaderDates: widget.showHeaderDates,
              onSpecialDayTap: widget.onSpecialDayTap,
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                padding: EdgeInsets.only(
                  bottom: HomeDockInsets.bottomOf(context),
                ),
                child: CourseGridBody(
                  courses: widget.courses,
                  config: widget.config,
                  displayWeek: widget.displayWeek,
                  showWeekend: showWeekend,
                  showNonCurrentWeekCourses:
                      appConfig.showNonCurrentWeekCourses.value,
                  rowHeight: rowHeight,
                  showCourseGrid: showCourseGrid,
                  showAllWeeks: widget.showAllWeeks,
                  onCourseTap: widget.onCourseTap,
                  onCourseLongPress: widget.onCourseLongPress,
                  onEmptyTap: widget.onEmptyTap,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
