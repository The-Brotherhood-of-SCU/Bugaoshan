import 'package:flutter/material.dart';
import 'package:bugaoshan/models/course.dart';

class IcsService {
  const IcsService._();

  static String genIcs({
    required ScheduleConfig config,
    required List<Course> courses,
    required String teacherLabel,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//Bugaoshan//Course Schedule//EN');
    buffer.writeln('CALSCALE:GREGORIAN');
    buffer.writeln('METHOD:PUBLISH');

    for (final course in courses) {
      for (int week = course.startWeek; week <= course.endWeek; week++) {
        if (!_isWeekActive(course, week)) continue;

        final courseDate = _getCourseDate(
          config.semesterStartDate,
          week,
          course.dayOfWeek,
        );
        final startTime = config.timeSlots[course.startSection - 1].startTime;
        final endTime = config.timeSlots[course.endSection - 1].endTime;

        final dtStart = _combineDateTime(courseDate, startTime);
        final dtEnd = _combineDateTime(courseDate, endTime);

        buffer.writeln('BEGIN:VEVENT');
        buffer.writeln('DTSTART:${_formatIcsDate(dtStart)}');
        buffer.writeln('DTEND:${_formatIcsDate(dtEnd)}');
        buffer.writeln('SUMMARY:${_escapeIcsText(course.name)}');
        buffer.writeln('LOCATION:${_escapeIcsText(course.location)}');
        buffer.writeln(
          'DESCRIPTION:${_escapeIcsText('$teacherLabel: ${course.teacher}')}',
        );
        buffer.writeln('UID:${course.id}_$week@bugaoshan');
        buffer.writeln('END:VEVENT');
      }
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  static bool _isWeekActive(Course course, int week) {
    if (course.weekType == WeekType.odd && week.isEven) return false;
    if (course.weekType == WeekType.even && week.isOdd) return false;
    return true;
  }

  static DateTime _getCourseDate(
    DateTime semesterStart,
    int week,
    int dayOfWeek,
  ) {
    // force monday alignment
    final monday = semesterStart.toMonday();
    final targetDate = monday.add(
      Duration(days: (week - 1) * 7 + (dayOfWeek - 1)),
    );
    return DateTime(targetDate.year, targetDate.month, targetDate.day);
  }

  static DateTime _combineDateTime(DateTime date, TimeOfDay time) {
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  static String _formatIcsDate(DateTime dt) {
    return '${dt.year}${dt.month.toString().padLeft(2, '0')}${dt.day.toString().padLeft(2, '0')}'
        'T${dt.hour.toString().padLeft(2, '0')}${dt.minute.toString().padLeft(2, '0')}00';
  }

  static String _escapeIcsText(String text) {
    return text
        .replaceAll('\\', '\\\\')
        .replaceAll('\n', '\\n')
        .replaceAll(',', '\\,')
        .replaceAll(';', '\\;');
  }
}
