import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/course_edit_page.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/widgets/dialog/dialog.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';

class CourseDetailSheet extends StatelessWidget {
  final Course course;
  final CourseProvider courseProvider;

  const CourseDetailSheet({
    super.key,
    required this.course,
    required this.courseProvider,
  });

  String _formatTimeOfDay(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final config = courseProvider.scheduleConfig.value;

    String timeRange = '';
    if (course.startSection > 0 &&
        course.endSection <= config.timeSlots.length) {
      final startSlot = config.timeSlots[course.startSection - 1];
      final endSlot = config.timeSlots[course.endSection - 1];
      timeRange =
          '${_formatTimeOfDay(startSlot.startTime)} - ${_formatTimeOfDay(endSlot.endTime)}';
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title + Actions
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      course.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.delete_outline,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    onPressed: () async {
                      final confirm = await showYesNoDialog(
                        title: l10n.deleteCourse,
                        content: l10n.deleteCourseConfirm,
                      );
                      if (confirm == true) {
                        await courseProvider.deleteCourse(course.id);
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      }
                    },
                  ),
                  // Duplicate
                  IconButton(
                    icon: Icon(
                      Icons.copy,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      final newCourse = course.copyWith(); // Create a new copy
                      newCourse.name = '${course.name}${l10n.copySuffix}';
                      popupOrNavigate(
                        context,
                        CourseEditPage(course: newCourse),
                      );
                    },
                  ),
                  // Edit
                  IconButton(
                    icon: Icon(
                      Icons.edit_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      popupOrNavigate(context, CourseEditPage(course: course));
                    },
                  ),
                ],
              ),
            ),
            const Divider(),
            // Info List
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  _InfoItem(
                    icon: Icons.calendar_today_outlined,
                    iconColor: Colors.teal,
                    text: l10n.weekRange(course.startWeek, course.endWeek),
                  ),
                  _InfoItem(
                    icon: Icons.access_time_outlined,
                    iconColor: Colors.orange,
                    text:
                        '第 ${course.startSection} - ${course.endSection} ${l10n.section}   $timeRange',
                  ),
                  if (course.teacher.isNotEmpty)
                    _InfoItem(
                      icon: Icons.person_outline,
                      iconColor: Colors.blue,
                      text: course.teacher,
                    ),
                  if (course.location.isNotEmpty)
                    _InfoItem(
                      icon: Icons.location_on_outlined,
                      iconColor: Colors.redAccent,
                      text: course.location,
                    ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String text;

  const _InfoItem({
    required this.icon,
    required this.iconColor,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(text, style: const TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
