import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/widgets/course/course_card.dart';

List<Course> selectVisibleCoursesForDay(
  List<Course> courses,
  int displayWeek, {
  bool showNonCurrentWeekCourses = true,
}) {
  final visibleCourses =
      courses.where((course) => course.isInWeekRange(displayWeek)).toList()
        ..sort(_compareCoursesForLayout);

  if (!showNonCurrentWeekCourses) {
    return visibleCourses
        .where((course) => course.isActiveInWeek(displayWeek))
        .toList();
  }

  final futureCourses =
      courses.where((course) => displayWeek < course.startWeek).toList()
        ..sort((a, b) {
          final weekCompare = a.startWeek.compareTo(b.startWeek);
          if (weekCompare != 0) return weekCompare;
          return _compareCoursesForLayout(a, b);
        });

  for (final course in futureCourses) {
    final overlapsVisible = visibleCourses.any(
      (visibleCourse) => _coursesOverlapInSections(visibleCourse, course),
    );
    if (!overlapsVisible) {
      visibleCourses.add(course);
    }
  }

  visibleCourses.sort(_compareCoursesForLayout);
  return visibleCourses;
}

int _compareCoursesForLayout(Course a, Course b) {
  final sectionCompare = a.startSection.compareTo(b.startSection);
  if (sectionCompare != 0) return sectionCompare;

  final durationCompare = (b.endSection - b.startSection).compareTo(
    a.endSection - a.startSection,
  );
  if (durationCompare != 0) return durationCompare;

  return a.startWeek.compareTo(b.startWeek);
}

bool _coursesOverlapInSections(Course a, Course b) {
  return !(a.endSection < b.startSection || a.startSection > b.endSection);
}

/// Displays a weekly course schedule grid with time slots and course cards.
class CourseGrid extends StatefulWidget {
  final List<Course> courses;
  final ScheduleConfig config;
  final int displayWeek;
  final int totalWeeks;
  final void Function(Course course)? onCourseTap;
  final void Function(Course course)? onCourseLongPress;
  final void Function(int dayOfWeek, int section)? onEmptyTap;

  const CourseGrid({
    super.key,
    required this.courses,
    required this.config,
    required this.displayWeek,
    required this.totalWeeks,
    this.onCourseTap,
    this.onCourseLongPress,
    this.onEmptyTap,
  });

  @override
  State<CourseGrid> createState() => _CourseGridState();
}

class _CourseGridState extends State<CourseGrid> {
  // Store the currently selected empty cell (dayOfWeek, section)
  int? _selectedEmptyDay;
  int? _selectedEmptySection;
  final appConfig = getIt<AppConfigProvider>();

  void _handleEmptyTap(int day, int section) {
    if (_selectedEmptyDay == day && _selectedEmptySection == section) {
      // Second tap: trigger the actual add action
      widget.onEmptyTap?.call(day, section);
      setState(() {
        _selectedEmptyDay = null;
        _selectedEmptySection = null;
      });
    } else {
      // First tap: select the cell
      setState(() {
        _selectedEmptyDay = day;
        _selectedEmptySection = section;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dayNames = [
      l10n.monday,
      l10n.tuesday,
      l10n.wednesday,
      l10n.thursday,
      l10n.friday,
      l10n.saturday,
      l10n.sunday,
    ];
    final sections = widget.config.sectionsPerDay;
    final timeSlots = widget.config.timeSlots;
    final dayCount = widget.config.showWeekend ? 7 : 5;

    return ListenableBuilder(
      listenable: Listenable.merge([
        appConfig.showCourseGrid,
        appConfig.courseRowHeight,
      ]),
      builder: (context, _) {
        return Column(
          children: [
            // Header row: empty corner + day names
            _buildHeaderRow(context, dayNames),
            // Grid body
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Section number + time column (fixed width)
                    _buildSectionColumn(sections, timeSlots, context),
                    // 7 or 5 day columns
                    Expanded(
                      child: Row(
                        children: List.generate(dayCount, (dayIndex) {
                          final day = dayIndex + 1; // 1=Mon ... 7=Sun
                          final dayCourses = selectVisibleCoursesForDay(
                            widget.courses
                                .where((c) => c.dayOfWeek == day)
                                .toList(),
                            widget.displayWeek,
                            showNonCurrentWeekCourses:
                                widget.config.showNonCurrentWeekCourses,
                          );
                          return _buildDayColumn(
                            context,
                            day,
                            sections,
                            dayCourses,
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

  Widget _buildHeaderRow(BuildContext context, List<String> dayNames) {
    final theme = Theme.of(context);
    final visibleDays = widget.config.showWeekend
        ? dayNames
        : dayNames.sublist(0, 5);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final semesterStart = widget.config.semesterStartDate;

    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          // Empty corner for section column alignment
          Container(
            width: _sectionWidth,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: List.generate(visibleDays.length, (index) {
                final name = visibleDays[index];
                final date = semesterStart.add(
                  Duration(days: (widget.displayWeek - 1) * 7 + index),
                );
                final isToday = date.isAtSameMomentAs(today);

                return Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: isToday
                          ? theme.colorScheme.primaryContainer.withAlpha(180)
                          : null,
                      border: Border(
                        right: BorderSide(
                          color: theme.colorScheme.outlineVariant,
                          width: 0.5,
                        ),
                      ),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                              color: isToday
                                  ? theme.colorScheme.primary
                                  : theme.colorScheme.onSurface,
                            ),
                          ),
                          Text(
                            '${date.month}-${date.day}',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isToday
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                              color: isToday
                                  ? theme.colorScheme.primary.withAlpha(200)
                                  : theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  static const double _sectionWidth = 35;

  Widget _buildSectionColumn(
    int sections,
    List<TimeSlot> timeSlots,
    BuildContext context,
  ) {
    final theme = Theme.of(context);

    // Calculate boundaries
    final morningEnd = widget.config.morningSections;
    final afternoonEnd =
        widget.config.morningSections + widget.config.afternoonSections;

    return SizedBox(
      width: _sectionWidth,
      child: Column(
        children: List.generate(sections, (i) {
          final slot = i < timeSlots.length ? timeSlots[i] : null;
          final startStr = slot != null
              ? '${slot.startTime.hour.toString().padLeft(2, '0')}:${slot.startTime.minute.toString().padLeft(2, '0')}'
              : '';

          final isBoundary = (i + 1 == morningEnd) || (i + 1 == afternoonEnd);

          return Container(
            height: appConfig.courseRowHeight.value,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: isBoundary
                      ? theme.colorScheme.primary.withAlpha(150)
                      : theme.colorScheme.outlineVariant,
                  width: isBoundary ? 1.5 : 0.5,
                ),
                right: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${i + 1}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (startStr.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        startStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildDayColumn(
    BuildContext context,
    int day,
    int sections,
    List<Course> dayCourses,
  ) {
    final theme = Theme.of(context);
    final appConfig = getIt<AppConfigProvider>();
    final rowHeight = appConfig.courseRowHeight.value;

    // Calculate boundaries
    final morningEnd = widget.config.morningSections;
    final afternoonEnd =
        widget.config.morningSections + widget.config.afternoonSections;

    return Expanded(
      child: SizedBox(
        height: rowHeight * sections,
        child: Stack(
          children: [
            // Grid lines (conditionally rendered)
            if (appConfig.showCourseGrid.value)
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
            // Course cards
            ...dayCourses.map((course) {
              final top = (course.startSection - 1) * rowHeight;
              final courseHeight =
                  (course.endSection - course.startSection + 1) * rowHeight - 2;
              return Positioned(
                top: top + 1,
                left: 1,
                right: 1,
                height: courseHeight,
                child: SizedBox(
                  child: CourseCard(
                    course: course,
                    config: widget.config,
                    displayWeek: widget.displayWeek,
                    onTap: widget.onCourseTap != null
                        ? () => widget.onCourseTap!(course)
                        : null,
                    onLongPress: widget.onCourseLongPress != null
                        ? () => widget.onCourseLongPress!(course)
                        : null,
                  ),
                ),
              );
            }),
            // Invisible tap targets for empty cells, and Add icon for selected empty cell
            ...List.generate(sections, (i) {
              final section = i + 1;
              // Skip sections that are covered by a course card
              final hasCourse = dayCourses.any(
                (c) => section >= c.startSection && section <= c.endSection,
              );
              if (hasCourse) return const SizedBox.shrink();

              final isSelected =
                  _selectedEmptyDay == day && _selectedEmptySection == section;

              return Positioned(
                top: i * rowHeight,
                left: 0,
                right: 0,
                height: rowHeight,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: widget.onEmptyTap != null
                      ? () => _handleEmptyTap(day, section)
                      : null,
                  child: isSelected
                      ? Container(
                          margin: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withAlpha(
                              100,
                            ), // e.g. pinkish/primary with opacity
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: theme.colorScheme.primary.withAlpha(150),
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
        ),
      ),
    );
  }
}
