import 'package:flutter/material.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/utils/app_shapes.dart';
import 'package:bugaoshan/widgets/course/course_card.dart';
import 'grid_logic.dart';

/// 课程网格日期列，显示单天的课程卡片、网格线和空白单元格点击区域。
class GridDayColumn extends StatelessWidget {
  final List<Course> courses;
  final ScheduleConfig config;
  final int displayWeek;
  final bool showAllWeeks;
  final int sections;
  final double rowHeight;
  final bool showCourseGrid;
  final int? selectedEmptySection;
  final void Function(Course course)? onCourseTap;
  final void Function(Course course)? onCourseLongPress;
  final void Function(int section)? onEmptyCellTap;

  const GridDayColumn({
    super.key,
    required this.courses,
    required this.config,
    required this.displayWeek,
    required this.showAllWeeks,
    required this.sections,
    required this.rowHeight,
    required this.showCourseGrid,
    this.selectedEmptySection,
    this.onCourseTap,
    this.onCourseLongPress,
    this.onEmptyCellTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // 计算边界位置
    final morningEnd = config.morningSections;
    final afternoonEnd = config.morningSections + config.afternoonSections;

    // 全周视图下计算轨道分配
    final trackInfos = showAllWeeks && courses.length > 1
        ? assignCourseTracks(courses)
        : null;

    return Expanded(
      child: SizedBox(
        height: rowHeight * sections,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columnWidth = constraints.maxWidth;
            return Stack(
              children: [
                // 网格线（条件渲染）
                if (showCourseGrid)
                  ...List.generate(sections, (i) {
                    final isBoundary =
                        (i + 1 == morningEnd) || (i + 1 == afternoonEnd);

                    return Positioned(
                      top: i * rowHeight,
                      left: 0,
                      right: 0,
                      height: rowHeight,
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(
                              color: isBoundary
                                  ? theme.colorScheme.primary.withAlpha(150)
                                  : theme.colorScheme.outlineVariant,
                              width: isBoundary ? 1.5 : 0.5,
                            ),
                            right: BorderSide(
                              color: theme.colorScheme.outlineVariant,
                              width: 0.5,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                // 课程卡片
                ...courses.asMap().entries.map((entry) {
                  final index = entry.key;
                  final course = entry.value;
                  final top = (course.startSection - 1) * rowHeight;
                  final courseHeight =
                      (course.endSection - course.startSection + 1) *
                          rowHeight -
                      2;

                  final cardWidget = SizedBox(
                    child: CourseCard(
                      course: course,
                      config: config,
                      displayWeek: displayWeek,
                      showAllWeeks: showAllWeeks,
                      onTap: onCourseTap != null
                          ? () => onCourseTap!(course)
                          : null,
                      onLongPress: onCourseLongPress != null
                          ? () => onCourseLongPress!(course)
                          : null,
                    ),
                  );

                  if (showAllWeeks && trackInfos != null) {
                    final info = trackInfos[index];
                    final trackWidth = columnWidth / info.totalTracks;
                    return Positioned(
                      top: top + 1,
                      left: info.track * trackWidth + 1,
                      width: trackWidth - 2,
                      height: courseHeight,
                      child: cardWidget,
                    );
                  }

                  return Positioned(
                    top: top + 1,
                    left: 1,
                    right: 1,
                    height: courseHeight,
                    child: cardWidget,
                  );
                }),
                // 空白单元格的不可见点击区域，以及选中状态的添加图标
                if (!showAllWeeks)
                  ...List.generate(sections, (i) {
                    final section = i + 1;
                    // 跳过被课程卡片覆盖的节次
                    final hasCourse = courses.any(
                      (c) =>
                          section >= c.startSection && section <= c.endSection,
                    );
                    if (hasCourse) return const SizedBox.shrink();

                    final isSelected = selectedEmptySection == section;

                    return Positioned(
                      top: i * rowHeight,
                      left: 0,
                      right: 0,
                      height: rowHeight,
                      child: GestureDetector(
                        behavior: HitTestBehavior.translucent,
                        onTap: onEmptyCellTap != null
                            ? () => onEmptyCellTap!(section)
                            : null,
                        child: isSelected
                            ? Container(
                                margin: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary.withAlpha(
                                    100,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                    AppShapes.small,
                                  ),
                                  border: Border.all(
                                    color: theme.colorScheme.primary.withAlpha(
                                      150,
                                    ),
                                    width: 1,
                                  ),
                                ),
                                child: Center(
                                  child: Icon(
                                    Icons.add,
                                    color: theme.colorScheme.onPrimaryContainer,
                                    size: 32,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}
