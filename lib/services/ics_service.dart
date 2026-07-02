import 'package:flutter/material.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/pages/campus/exam_plan/models/exam_info.dart';
import 'package:bugaoshan/utils/calendar_event_utils.dart';

export 'package:bugaoshan/utils/calendar_event_utils.dart'
    show
        CalendarEventPayload,
        CalendarExportPayload,
        CalendarStructuredLocation;

class IcsService {
  const IcsService._();

  static String genIcs({
    required ScheduleConfig config,
    required List<Course> courses,
    required String teacherLabel,
  }) {
    return _genCalendarIcs(
      productName: 'Course Schedule',
      events: genCourseCalendarEvents(
        config: config,
        courses: courses,
        teacherLabel: teacherLabel,
      ),
    );
  }

  static CalendarExportPayload genCourseExportPayload({
    required ScheduleConfig config,
    required List<Course> courses,
    required String teacherLabel,
  }) {
    final events = genCourseCalendarEvents(
      config: config,
      courses: courses,
      teacherLabel: teacherLabel,
    );
    return CalendarExportPayload(
      fileName: '${safeFileName(config.semesterName)}.ics',
      icsContent: _genCalendarIcs(
        productName: 'Course Schedule',
        events: events,
      ),
      events: events.map((event) => event.toPlatformJson()).toList(),
    );
  }

  static List<CalendarEventPayload> genCourseCalendarEvents({
    required ScheduleConfig config,
    required List<Course> courses,
    required String teacherLabel,
  }) {
    final events = <CalendarEventPayload>[];

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
        final start = _combineDateTime(courseDate, startTime);
        final end = _combineDateTime(courseDate, endTime);
        final location = CalendarLocationMapper.resolve(course.location);

        events.add(
          CalendarEventPayload(
            start: start,
            end: end,
            title: course.name,
            location: location.title,
            description: '$teacherLabel: ${course.teacher}',
            uid: CalendarEventIdentity.courseUid(
              courseId: course.id,
              week: week,
            ),
            structuredLocation: location.structuredLocation,
          ),
        );
      }
    }

    return events;
  }

  static String genExamIcs({required List<ExamInfo> exams}) {
    return _genCalendarIcs(
      productName: 'Exam Schedule',
      events: genExamCalendarEvents(exams: exams),
    );
  }

  static CalendarExportPayload genExamExportPayload({
    required List<ExamInfo> exams,
    required String fileName,
  }) {
    final events = genExamCalendarEvents(exams: exams);
    return CalendarExportPayload(
      fileName: safeFileName(fileName, allowHyphen: true),
      icsContent: _genCalendarIcs(productName: 'Exam Schedule', events: events),
      events: events.map((event) => event.toPlatformJson()).toList(),
    );
  }

  static String safeFileName(String value, {bool allowHyphen = false}) {
    final sanitized = value.replaceAll(
      RegExp(allowHyphen ? r'[^\w\u4e00-\u9fff.-]' : r'[^\w\u4e00-\u9fff.]'),
      '_',
    );
    return sanitized.isEmpty ? 'calendar' : sanitized;
  }

  static String _genCalendarIcs({
    required String productName,
    required Iterable<CalendarEventPayload> events,
  }) {
    final buffer = StringBuffer();
    _writeCalendarHeader(buffer, productName);

    for (final event in events) {
      _writeCalendarEvent(buffer, event);
    }

    buffer.writeln('END:VCALENDAR');
    return buffer.toString();
  }

  static List<CalendarEventPayload> genExamCalendarEvents({
    required List<ExamInfo> exams,
  }) {
    final events = <CalendarEventPayload>[];

    for (final exam in exams) {
      final range = _parseExamDateTimeRange(exam);
      if (range == null) continue;
      final courseName = CalendarEventIdentity.normalizeName(exam.courseName);
      final location = CalendarLocationMapper.resolve(exam.location);

      final description = [
        exam.week,
        '座位号: ${exam.seatNumber}',
        if (exam.ticketNumber.isNotEmpty) '准考证号: ${exam.ticketNumber}',
        if (exam.tip != '无') '提示: ${exam.tip}',
      ].join('\n');

      events.add(
        CalendarEventPayload(
          start: range.start,
          end: range.end,
          title: courseName.endsWith('考试') ? courseName : '$courseName考试',
          location: location.title,
          description: description,
          uid: CalendarEventIdentity.examUid(name: courseName),
          structuredLocation: location.structuredLocation,
        ),
      );
    }

    return events;
  }

  static void _writeCalendarHeader(StringBuffer buffer, String productName) {
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//Bugaoshan//$productName//EN');
    buffer.writeln('CALSCALE:GREGORIAN');
    buffer.writeln('METHOD:PUBLISH');
    buffer.writeln('X-WR-TIMEZONE:Asia/Shanghai');
    buffer.writeln('BEGIN:VTIMEZONE');
    buffer.writeln('TZID:Asia/Shanghai');
    buffer.writeln('BEGIN:STANDARD');
    buffer.writeln('TZOFFSETFROM:+0800');
    buffer.writeln('TZOFFSETTO:+0800');
    buffer.writeln('TZNAME:CST');
    buffer.writeln('DTSTART:19700101T000000');
    buffer.writeln('RRULE:FREQ=YEARLY;BYDAY=1SU;BYMONTH=3');
    buffer.writeln('END:STANDARD');
    buffer.writeln('BEGIN:DAYLIGHT');
    buffer.writeln('TZOFFSETFROM:+0800');
    buffer.writeln('TZOFFSETTO:+0800');
    buffer.writeln('TZNAME:CST');
    buffer.writeln('DTSTART:19700101T000000');
    buffer.writeln('RRULE:FREQ=YEARLY;BYDAY=1SU;BYMONTH=11');
    buffer.writeln('END:DAYLIGHT');
    buffer.writeln('END:VTIMEZONE');
  }

  static void _writeCalendarEvent(
    StringBuffer buffer,
    CalendarEventPayload event,
  ) {
    buffer.writeln('BEGIN:VEVENT');
    buffer.writeln(
      'DTSTART;TZID=${event.timeZone}:${_formatIcsDate(event.start)}',
    );
    buffer.writeln('DTEND;TZID=${event.timeZone}:${_formatIcsDate(event.end)}');
    buffer.writeln('SUMMARY:${_escapeIcsText(event.title)}');
    buffer.writeln('LOCATION:${_escapeIcsText(event.location)}');
    final structuredLocation = event.structuredLocation;
    if (structuredLocation != null) {
      buffer.writeln(
        'GEO:${structuredLocation.latitude};${structuredLocation.longitude}',
      );
    }
    buffer.writeln('DESCRIPTION:${_escapeIcsText(event.description)}');
    buffer.writeln('UID:${event.uid}');
    buffer.writeln('END:VEVENT');
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

  static ({DateTime start, DateTime end})? _parseExamDateTimeRange(
    ExamInfo exam,
  ) {
    final dateMatch = RegExp(
      r'^(\d{4})-(\d{2})-(\d{2})$',
    ).firstMatch(exam.date);
    final timeMatch = RegExp(
      r'^(\d{2}):(\d{2})-(\d{2}):(\d{2})$',
    ).firstMatch(exam.timeRange);
    if (dateMatch == null || timeMatch == null) return null;

    final year = int.parse(dateMatch.group(1)!);
    final month = int.parse(dateMatch.group(2)!);
    final day = int.parse(dateMatch.group(3)!);
    final start = DateTime(
      year,
      month,
      day,
      int.parse(timeMatch.group(1)!),
      int.parse(timeMatch.group(2)!),
    );
    final end = DateTime(
      year,
      month,
      day,
      int.parse(timeMatch.group(3)!),
      int.parse(timeMatch.group(4)!),
    );
    return (start: start, end: end);
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
