import 'package:flutter/material.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/utils/holiday_utils.dart';
import 'grid_day_column.dart';
import 'grid_header.dart';
import 'grid_logic.dart';
import 'grid_section_column.dart';
import 'minimal_weekday_header.dart';

/// 节次列宽度。表头与网格主体共用同一常量，保证左右列严格对齐。
///
/// 从原 `_CourseGridState._sectionWidth` 提升为公共常量：导出视图
/// （`ScheduleExportView`）需要以固定逻辑宽度复刻同一套网格比例。
const double kCourseGridSectionWidth = 35;

/// 单周表头高度（`GridHeaderRow` 为 `40 * textScale`）。
///
/// 仅供需要预先推算网格逻辑高度的调用方使用；网格本身的高度由内容
/// 自然布局决定，不依赖该常量。
const double kCourseGridHeaderHeight = 40;

/// 课程网格表头：按「是否聚合全部周次 / 是否显示日期」二选一。
///
/// 收口原本内联在 `CourseGrid.build` 里的表头选型，使正常页面与导出视图
/// 共用同一套判断，避免两处各写一份 `if`：
/// - `showAllWeeks`（聚合各周，无“当前周”概念）
/// - `!showHeaderDates`（历史学期，日期无意义）
/// 两条路径统一落到仅周几的 [MinimalWeekdayHeader]；其余情况走 [GridHeaderRow]。
class CourseGridHeader extends StatelessWidget {
  final ScheduleConfig config;
  final int displayWeek;
  final bool hasBackground;
  final bool showWeekend;
  final bool showAllWeeks;
  final bool showHeaderDates;
  final void Function(DateTime date, SpecialDayInfo info)? onSpecialDayTap;

  const CourseGridHeader({
    super.key,
    required this.config,
    required this.displayWeek,
    required this.hasBackground,
    required this.showWeekend,
    this.showAllWeeks = false,
    this.showHeaderDates = true,
    this.onSpecialDayTap,
  });

  @override
  Widget build(BuildContext context) {
    if (showAllWeeks || !showHeaderDates) {
      return MinimalWeekdayHeader(
        showWeekend: showWeekend,
        sectionWidth: kCourseGridSectionWidth,
      );
    }
    return GridHeaderRow(
      config: config,
      displayWeek: displayWeek,
      hasBackground: hasBackground,
      sectionWidth: kCourseGridSectionWidth,
      showWeekend: showWeekend,
      onSpecialDayTap: onSpecialDayTap,
    );
  }
}

/// 课程网格主体：左侧节次列 + 各天课程列。
///
/// 拆出本组件的目的：正常页面（[CourseGrid]）把主体放进
/// `SingleChildScrollView` 以获得滚动与 viewport 裁剪，导出视图则直接以
/// 自然高度使用它（无滚动、无裁剪）——两者共用同一份布局代码。
///
/// 契约（勿破坏）：
/// - 完全参数化：不 import injector / AppConfigProvider，不订阅任何 Listenable；
/// - 高度只由内容决定，即 `rowHeight * config.sectionsPerDay`；
/// - 自身不产生滚动容器；
/// - “空白单元格两段点击选中”状态由本组件持有（原 `_CourseGridState` 搬入），
///   [onEmptyTap] 为 null 时不会产生任何可交互区域。
class CourseGridBody extends StatefulWidget {
  final List<Course> courses;
  final ScheduleConfig config;
  final int displayWeek;
  final bool showWeekend;
  final bool showNonCurrentWeekCourses;
  final double rowHeight;
  final bool showCourseGrid;
  final bool showAllWeeks;
  final void Function(Course course)? onCourseTap;
  final void Function(Course course)? onCourseLongPress;
  final void Function(int dayOfWeek, int section)? onEmptyTap;

  const CourseGridBody({
    super.key,
    required this.courses,
    required this.config,
    required this.displayWeek,
    required this.showWeekend,
    required this.showNonCurrentWeekCourses,
    required this.rowHeight,
    required this.showCourseGrid,
    this.showAllWeeks = false,
    this.onCourseTap,
    this.onCourseLongPress,
    this.onEmptyTap,
  });

  @override
  State<CourseGridBody> createState() => _CourseGridBodyState();
}

class _CourseGridBodyState extends State<CourseGridBody> {
  // 存储当前选中的空白单元格（dayOfWeek, section）
  int? _selectedEmptyDay;
  int? _selectedEmptySection;

  void _handleEmptyTap(int day, int section) {
    if (_selectedEmptyDay == day && _selectedEmptySection == section) {
      // 第二次点击：触发实际的添加操作
      widget.onEmptyTap?.call(day, section);
      setState(() {
        _selectedEmptyDay = null;
        _selectedEmptySection = null;
      });
    } else if (_selectedEmptyDay == null && _selectedEmptySection == null) {
      // 第一次点击：选中单元格（之前没有选中任何内容）
      setState(() {
        _selectedEmptyDay = day;
        _selectedEmptySection = section;
      });
    } else {
      // 点击不同的单元格（之前已有选中）：取消选中
      setState(() {
        _selectedEmptyDay = null;
        _selectedEmptySection = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final sections = widget.config.sectionsPerDay;
    final showWeekend = widget.showWeekend;
    final dayCount = showWeekend ? 7 : 5;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        GridSectionColumn(
          config: widget.config,
          rowHeight: widget.rowHeight,
          width: kCourseGridSectionWidth,
        ),
        Expanded(
          child: Row(
            children: List.generate(dayCount, (dayIndex) {
              final day = showWeekend
                  ? (dayIndex == 0 ? 7 : dayIndex)
                  : dayIndex + 1;
              List<Course> dayCourses;
              if (widget.showAllWeeks) {
                dayCourses = widget.courses
                    .where((c) => c.dayOfWeek == day)
                    .toList();
                dayCourses.sort(compareCoursesForLayout);
                dayCourses = mergeSameSlotCourses(dayCourses);
              } else {
                dayCourses = selectVisibleCoursesForDay(
                  widget.courses.where((c) => c.dayOfWeek == day).toList(),
                  widget.displayWeek,
                  showNonCurrentWeekCourses: widget.showNonCurrentWeekCourses,
                );
              }

              final isSelectedDay = _selectedEmptyDay == day;

              return GridDayColumn(
                courses: dayCourses,
                config: widget.config,
                displayWeek: widget.displayWeek,
                showAllWeeks: widget.showAllWeeks,
                sections: sections,
                rowHeight: widget.rowHeight,
                showCourseGrid: widget.showCourseGrid,
                selectedEmptySection: isSelectedDay
                    ? _selectedEmptySection
                    : null,
                onCourseTap: widget.onCourseTap,
                onCourseLongPress: widget.onCourseLongPress,
                onEmptyCellTap: widget.onEmptyTap != null
                    ? (section) => _handleEmptyTap(day, section)
                    : null,
              );
            }),
          ),
        ),
      ],
    );
  }
}
