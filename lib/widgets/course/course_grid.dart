import 'package:flutter/material.dart';
import 'package:rubbish_plan/injection/injector.dart';
import 'package:rubbish_plan/l10n/app_localizations.dart';
import 'package:rubbish_plan/models/course.dart';
import 'package:rubbish_plan/providers/app_config_provider.dart';

/// Displays a weekly course schedule grid with time slots and course cards.
class CourseGrid extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dayNames = [
      l10n.monday, l10n.tuesday, l10n.wednesday,
      l10n.thursday, l10n.friday, l10n.saturday, l10n.sunday,
    ];
    final sections = config.sectionsPerDay;
    final timeSlots = config.timeSlots;
    final dayCount = config.showWeekend ? 7 : 5;

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
                      final dayCourses = courses
                          .where((c) => c.dayOfWeek == day)
                          .toList();
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
  }

  Widget _buildHeaderRow(BuildContext context, List<String> dayNames) {
    final theme = Theme.of(context);
    final visibleDays = config.showWeekend ? dayNames : dayNames.sublist(0, 5);
    return Container(
      height: 32,
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
            width: 52,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
          ),
          Expanded(
            child: Row(
              children: visibleDays.map((name) {
                return Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        right: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionColumn(int sections, List<TimeSlot> timeSlots, BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: 52,
      child: Column(
        children: List.generate(sections, (i) {
          final slot = i < timeSlots.length ? timeSlots[i] : null;
          final startStr = slot != null
              ? '${slot.startTime.hour.toString().padLeft(2, '0')}:${slot.startTime.minute.toString().padLeft(2, '0')}'
              : '';
          return Container(
            height: 72,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
                right: BorderSide(color: theme.colorScheme.outlineVariant),
              ),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${i + 1}${l10n.section}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  if (startStr.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        startStr,
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.onSurfaceVariant),
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
    final rowHeight = 72.0;

    return Expanded(
      child: SizedBox(
        height: rowHeight * sections,
        child: Stack(
          children: [
            // Grid lines
            ...List.generate(sections, (i) {
              return Positioned(
                top: i * rowHeight,
                left: 0,
                right: 0,
                height: rowHeight,
                child: Container(
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
                      right: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
                    ),
                  ),
                ),
              );
            }),
            // Course cards
            ...dayCourses.map((course) {
              final top = (course.startSection - 1) * rowHeight;
              // 不再设置固定 height，让内容自然撑开。最小高度仍然是课程占据的节数高度。
              final minHeight = (course.endSection - course.startSection + 1) * rowHeight - 2;
              return Positioned(
                top: top + 1,
                left: 1,
                right: 1,
                child: Container(
                  constraints: BoxConstraints(minHeight: minHeight),
                  child: _CourseCard(
                    course: course,
                    config: config,
                    displayWeek: displayWeek,
                    onTap: onCourseTap != null ? () => onCourseTap!(course) : null,
                    onLongPress: onCourseLongPress != null ? () => onCourseLongPress!(course) : null,
                  ),
                ),
              );
            }),
            // Invisible tap targets for empty cells
            ...List.generate(sections, (i) {
              // Skip sections that are covered by a course card
              final hasCourse = dayCourses.any(
                (c) => i + 1 >= c.startSection && i + 1 <= c.endSection,
              );
              if (hasCourse) return const SizedBox.shrink();
              return Positioned(
                top: i * rowHeight,
                left: 0,
                right: 0,
                height: rowHeight,
                child: GestureDetector(
                  behavior: HitTestBehavior.translucent,
                  onTap: onEmptyTap != null ? () => onEmptyTap!(day, i + 1) : null,
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _CourseCard extends StatelessWidget {
  final Course course;
  final ScheduleConfig config;
  final int displayWeek;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _CourseCard({
    required this.course,
    required this.config,
    required this.displayWeek,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final appConfig = getIt<AppConfigProvider>();
    final l10n = AppLocalizations.of(context)!;

    return ListenableBuilder(
      listenable: Listenable.merge([
        appConfig.colorOpacity,
        appConfig.courseCardFontSize,
      ]),
      builder: (context, _) {
        final isActive = course.isActiveInWeek(displayWeek);
        final color = course.color.withValues(
            alpha: isActive
                ? appConfig.colorOpacity.value
                : appConfig.colorOpacity.value * 0.35);
        final textColor = Colors.white;
        final fontSize = appConfig.courseCardFontSize.value;
        final smallFontSize = fontSize - 2;

        return GestureDetector(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Container(
            // 移除 clipBehavior: Clip.hardEdge,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(6),
              border: isActive ? null : Border.all(color: textColor.withAlpha(50), width: 0.5),
            ),
            padding: const EdgeInsets.all(4),
            // 移除 SingleChildScrollView，让 Column 直接撑开 Container
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  course.name,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                    height: 1.1,
                  ),
                  // 不再限制行数，或者可以保留较大的值如 5
                ),
                if (config.showLocation && course.location.isNotEmpty)
                  _buildIconText(
                    Icons.location_on_outlined,
                    course.location,
                    smallFontSize,
                    textColor,
                  ),
                if (config.showTeacherName && course.teacher.isNotEmpty)
                  _buildIconText(
                    Icons.person_outline,
                    course.teacher,
                    smallFontSize,
                    textColor,
                  ),
                _buildIconText(
                  Icons.calendar_today_outlined,
                  '${course.startWeek}-${course.endWeek}${l10n.week}',
                  smallFontSize,
                  textColor,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildIconText(IconData icon, String text, double fontSize, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: fontSize, color: color.withAlpha(200)),
          const SizedBox(width: 2),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: fontSize,
                color: color.withAlpha(230),
                height: 1.1,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}
