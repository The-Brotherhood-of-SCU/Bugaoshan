import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/models/holiday_override.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/utils/holiday_utils.dart';
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

  /// 调休记录映射，key = "YYYY-MM-DD"
  final Map<String, HolidayOverride> holidayOverrides;

  /// 点击表头特殊日回调
  final void Function(DateTime date, SpecialDayInfo info)? onSpecialDayTap;

  const CourseGrid({
    super.key,
    required this.courses,
    required this.config,
    required this.displayWeek,
    required this.totalWeeks,
    this.onCourseTap,
    this.onCourseLongPress,
    this.onEmptyTap,
    this.holidayOverrides = const {},
    this.onSpecialDayTap,
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
    } else if (_selectedEmptyDay == null && _selectedEmptySection == null) {
      // First tap: select the cell (nothing was selected before)
      setState(() {
        _selectedEmptyDay = day;
        _selectedEmptySection = section;
      });
    } else {
      // Tap different cell while something was selected: dismiss
      setState(() {
        _selectedEmptyDay = null;
        _selectedEmptySection = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dayNames = [
      l10n.sunday,
      l10n.monday,
      l10n.tuesday,
      l10n.wednesday,
      l10n.thursday,
      l10n.friday,
      l10n.saturday,
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
            _buildHeaderRow(context, dayNames),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionColumn(sections, timeSlots, context),
                    Expanded(
                      child: Row(
                        children: List.generate(dayCount, (dayIndex) {
                          final day = widget.config.showWeekend
                              ? (dayIndex == 0 ? 7 : dayIndex)
                              : dayIndex + 1;
                          final date = _getDateForDayColumn(day);
                          final dateKey = _dateKey(date);
                          final shouldHide = _shouldApplyHoliday(date);

                          // 放假且 active 的日期不显示课程
                          if (shouldHide) {
                            final hasMakeup =
                                widget.holidayOverrides[dateKey]?.makeupDate !=
                                null;
                            return _buildDayColumn(
                              context,
                              day,
                              sections,
                              [],
                              isHoliday: true,
                              hasMakeup: hasMakeup,
                            );
                          }

                          // 正常课程
                          var dayCourses = selectVisibleCoursesForDay(
                            widget.courses
                                .where((c) => c.dayOfWeek == day)
                                .toList(),
                            widget.displayWeek,
                            showNonCurrentWeekCourses:
                                widget.config.showNonCurrentWeekCourses,
                          );

                          // 检查是否有其他调休日把课程调到了今天
                          for (final override
                              in widget.holidayOverrides.values) {
                            if (override.makeupDate != null &&
                                _dateKey(override.makeupDate!) == dateKey) {
                              // 调休日：显示被调休那天的课程
                              final makeupDayOfWeek = override.date.weekday == 7
                                  ? 7
                                  : override.date.weekday;
                              final makeupCourses = selectVisibleCoursesForDay(
                                widget.courses
                                    .where(
                                      (c) => c.dayOfWeek == makeupDayOfWeek,
                                    )
                                    .toList(),
                                widget.displayWeek,
                                showNonCurrentWeekCourses:
                                    widget.config.showNonCurrentWeekCourses,
                              );
                              // 合并课程，去重（按 id）
                              final existingIds = dayCourses
                                  .map((c) => c.id)
                                  .toSet();
                              for (final mc in makeupCourses) {
                                if (!existingIds.contains(mc.id)) {
                                  dayCourses = [...dayCourses, mc];
                                  existingIds.add(mc.id);
                                }
                              }
                              dayCourses.sort(_compareCoursesForLayout);
                            }
                          }

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

  /// 计算某一列对应的实际日期
  DateTime _getDateForDayColumn(int dayOfWeek) {
    final semesterStart = widget.config.semesterStartDate;
    final daysFromMonday = dayOfWeek == 7 ? -1 : dayOfWeek - 1;
    final mondayOffset = (1 - semesterStart.weekday) % 7;
    return semesterStart.add(
      Duration(
        days: (widget.displayWeek - 1) * 7 + mondayOffset + daysFromMonday,
      ),
    );
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// 判断放假效果是否应对某天生效（受 override.active 影响）。
  /// 内置法定假默认生效，用户取消后失效。
  bool _shouldApplyHoliday(DateTime date) {
    final key = _dateKey(date);
    final override = widget.holidayOverrides[key];
    return override?.active ?? HolidayUtils.isStatutoryHoliday(date);
  }

  /// 获取某天的有效特殊日信息（考虑内置数据 + 用户调休记录）
  ///
  /// 用户手动设置的放假优先于内置的节/气，但不覆盖内置的法定假。
  SpecialDayInfo _getSpecialDay(DateTime date) {
    final builtIn = HolidayUtils.getSpecialDay(date);
    final key = _dateKey(date);
    final override = widget.holidayOverrides[key];

    if (override != null) {
      // 用户有调休记录 → 该天视为放假，active 跟随用户设置
      final name = builtIn.type == SpecialDayType.holiday ? builtIn.name : null;
      final subtitle = builtIn.type == SpecialDayType.holiday
          ? builtIn.subtitle
          : null;
      return SpecialDayInfo(
        type: SpecialDayType.holiday,
        name: name,
        subtitle: subtitle,
      );
    }

    return builtIn;
  }

  Widget _buildHeaderRow(BuildContext context, List<String> dayNames) {
    final theme = Theme.of(context);
    final visibleDays = widget.config.showWeekend
        ? dayNames
        : dayNames.sublist(1, 6);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final hasBackground = appConfig.backgroundImagePath.value != null;
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: hasBackground ? null : theme.colorScheme.surfaceContainerHighest,
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
                // 周日为index 0，计算当前列对应的星期几
                final dayOfWeek = widget.config.showWeekend
                    ? (index == 0 ? 7 : index)
                    : index + 1;
                final date = _getDateForDayColumn(dayOfWeek);
                final isToday = date.isAtSameMomentAs(today);
                final specialDay = _getSpecialDay(date);
                final isHoliday = specialDay.type == SpecialDayType.holiday;
                final isFestival = specialDay.type == SpecialDayType.festival;
                final isSolarTerm = specialDay.type == SpecialDayType.solarTerm;
                final isSpecial = isHoliday || isFestival || isSolarTerm;
                // 检查当天是否为某个调休日的上课日
                final dateKey = _dateKey(date);
                final isMakeupDay = widget.holidayOverrides.values.any(
                  (o) =>
                      o.makeupDate != null &&
                      _dateKey(o.makeupDate!) == dateKey &&
                      o.active,
                );

                return Expanded(
                  child: GestureDetector(
                    onTap: isSpecial && widget.onSpecialDayTap != null
                        ? () => widget.onSpecialDayTap!(date, specialDay)
                        : null,
                    child: Container(
                      decoration: BoxDecoration(
                        color: isHoliday
                            ? Colors.red.withAlpha(15)
                            : isFestival
                            ? Colors.orange.withAlpha(15)
                            : isSolarTerm
                            ? Colors.green.withAlpha(15)
                            : isToday
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
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${date.month}-${date.day}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: isToday
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    color: isHoliday
                                        ? Colors.red
                                        : isFestival
                                        ? Colors.orange
                                        : isSolarTerm
                                        ? Colors.green
                                        : isToday
                                        ? theme.colorScheme.primary.withAlpha(
                                            200,
                                          )
                                        : theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                                if (isHoliday)
                                  Text(
                                    ' 假',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                if (isMakeupDay)
                                  Text(
                                    ' 调',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.red,
                                    ),
                                  ),
                                if (isFestival)
                                  Text(
                                    ' 节',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                if (isSolarTerm)
                                  Text(
                                    ' 气',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.green,
                                    ),
                                  ),
                              ],
                            ),
                          ],
                        ),
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
          final endStr = slot != null
              ? '${slot.endTime.hour.toString().padLeft(2, '0')}:${slot.endTime.minute.toString().padLeft(2, '0')}'
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
                  if (startStr.isNotEmpty) ...[
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
                    if (endStr.isNotEmpty &&
                        appConfig.courseRowHeight.value >= 60)
                      Text(
                        endStr,
                        style: TextStyle(
                          fontSize: 11,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  /// 生成上午/下午/晚上三段的放假覆盖层
  List<Widget> _buildHolidayOverlay(
    BuildContext context,
    bool hasMakeup,
    double rowHeight,
  ) {
    final morningEnd = widget.config.morningSections;
    final afternoonEnd =
        widget.config.morningSections + widget.config.afternoonSections;
    final total =
        morningEnd +
        widget.config.afternoonSections +
        widget.config.eveningSections;

    final l10n = AppLocalizations.of(context)!;
    final label = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.holidayOverlay,
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.red.withAlpha(80),
          ),
        ),
        if (hasMakeup)
          Text(
            l10n.makeupOverlay,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange.withAlpha(120),
            ),
          ),
      ],
    );

    final sections = [
      (start: 0, end: morningEnd), // 上午
      (start: morningEnd, end: afternoonEnd), // 下午
      (start: afternoonEnd, end: total), // 晚上
    ];

    return [
      for (final sec in sections)
        Positioned(
          top: sec.start * rowHeight,
          left: 0,
          right: 0,
          height: (sec.end - sec.start) * rowHeight,
          child: Container(
            decoration: BoxDecoration(color: Colors.red.withAlpha(8)),
            child: Center(child: Transform.rotate(angle: -0.3, child: label)),
          ),
        ),
    ];
  }

  Widget _buildDayColumn(
    BuildContext context,
    int day,
    int sections,
    List<Course> dayCourses, {
    bool isHoliday = false,
    bool hasMakeup = false,
  }) {
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
            // 放假覆盖层（上午/下午/晚上各一块）
            if (isHoliday)
              ..._buildHolidayOverlay(context, hasMakeup, rowHeight),
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
