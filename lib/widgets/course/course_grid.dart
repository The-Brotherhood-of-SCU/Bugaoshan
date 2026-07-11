import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/utils/holiday_utils.dart';
import 'grid_header.dart';
import 'grid_section_column.dart';
import 'grid_day_column.dart';
import 'grid_logic.dart';

/// 显示周课程表的网格，包含时间槽和课程卡片。
class CourseGrid extends StatefulWidget {
  final List<Course> courses;
  final ScheduleConfig config;
  final int displayWeek;
  final int totalWeeks;
  final bool showAllWeeks;
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
  // 存储当前选中的空白单元格（dayOfWeek, section）
  int? _selectedEmptyDay;
  int? _selectedEmptySection;
  final appConfig = getIt<AppConfigProvider>();

  static const double _sectionWidth = 35;

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

    return ListenableBuilder(
      listenable: Listenable.merge([
        appConfig.showCourseGrid,
        appConfig.courseRowHeight,
        appConfig.showWeekend,
        appConfig.showNonCurrentWeekCourses,
      ]),
      builder: (context, _) {
        final showWeekend =
            widget.showWeekendOverride ?? appConfig.showWeekend.value;
        final dayCount = showWeekend ? 7 : 5;
        final hasBackground = appConfig.backgroundImagePath.value != null;
        final rowHeight = appConfig.courseRowHeight.value;
        final showCourseGrid = appConfig.showCourseGrid.value;

        return Column(
          children: [
            GridHeaderRow(
              config: widget.config,
              displayWeek: widget.displayWeek,
              showAllWeeks: widget.showAllWeeks,
              hasBackground: hasBackground,
              sectionWidth: _sectionWidth,
              showWeekend: showWeekend,
              onSpecialDayTap: widget.onSpecialDayTap,
            ),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GridSectionColumn(
                      config: widget.config,
                      rowHeight: rowHeight,
                      width: _sectionWidth,
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
                              widget.courses
                                  .where((c) => c.dayOfWeek == day)
                                  .toList(),
                              widget.displayWeek,
                              showNonCurrentWeekCourses:
                                  appConfig.showNonCurrentWeekCourses.value,
                            );
                          }

                          final isSelectedDay = _selectedEmptyDay == day;

                          return GridDayColumn(
                            courses: dayCourses,
                            config: widget.config,
                            displayWeek: widget.displayWeek,
                            showAllWeeks: widget.showAllWeeks,
                            sections: sections,
                            rowHeight: rowHeight,
                            showCourseGrid: showCourseGrid,
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
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
