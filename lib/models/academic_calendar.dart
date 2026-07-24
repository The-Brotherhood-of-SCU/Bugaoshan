import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

import 'course.dart';

part 'academic_calendar.g.dart';

class _DateConverter extends JsonConverter<DateTime, String> {
  const _DateConverter();

  @override
  DateTime fromJson(String json) => DateTime.parse(json);

  @override
  String toJson(DateTime object) =>
      '${object.year}-${object.month.toString().padLeft(2, '0')}-${object.day.toString().padLeft(2, '0')}';
}

class _NullableDateConverter extends JsonConverter<DateTime?, String?> {
  const _NullableDateConverter();

  @override
  DateTime? fromJson(String? json) =>
      json != null ? DateTime.parse(json) : null;

  @override
  String? toJson(DateTime? object) => object != null
      ? '${object.year}-${object.month.toString().padLeft(2, '0')}-${object.day.toString().padLeft(2, '0')}'
      : null;
}

@JsonSerializable()
class AcademicCalendarEvent {
  @_DateConverter()
  final DateTime date;
  @_NullableDateConverter()
  final DateTime? endDate;
  @JsonKey(defaultValue: '')
  final String label;
  @JsonKey(defaultValue: 'event')
  final String tag; // e.g. 'holiday', 'exam', 'start', 'course', 'event'

  AcademicCalendarEvent({
    required this.date,
    this.endDate,
    required this.label,
    required this.tag,
  });

  factory AcademicCalendarEvent.fromJson(Map<String, dynamic> json) =>
      _$AcademicCalendarEventFromJson(json);

  Map<String, dynamic> toJson() => _$AcademicCalendarEventToJson(this);

  /// Check if a given date falls inside this event
  bool isActive(DateTime target) {
    final targetDay = DateTime(target.year, target.month, target.day);
    final startDay = DateTime(date.year, date.month, date.day);
    if (endDate == null) {
      return targetDay.isAtSameMomentAs(startDay);
    }
    final endDay = DateTime(endDate!.year, endDate!.month, endDate!.day);
    return (targetDay.isAtSameMomentAs(startDay) ||
            targetDay.isAfter(startDay)) &&
        (targetDay.isAtSameMomentAs(endDay) || targetDay.isBefore(endDay));
  }

  /// Check if the event is already finished compared to target date
  bool isFinished(DateTime target) {
    final targetDay = DateTime(target.year, target.month, target.day);
    final lastDay = endDate ?? date;
    final endDay = DateTime(lastDay.year, lastDay.month, lastDay.day);
    return targetDay.isAfter(endDay);
  }

  /// Get days remaining or days elapsed
  int getDaysDifference(DateTime target) {
    final targetDay = DateTime(target.year, target.month, target.day);
    final startDay = DateTime(date.year, date.month, date.day);
    return startDay.difference(targetDay).inDays;
  }
}

@JsonSerializable()
class AcademicCalendarSemester {
  final String name;
  @_DateConverter()
  final DateTime startDate;
  @JsonKey(defaultValue: 20)
  final int totalWeeks;
  @JsonKey(defaultValue: [])
  final List<AcademicCalendarEvent> events;

  AcademicCalendarSemester({
    required this.name,
    required this.startDate,
    required this.totalWeeks,
    required this.events,
  });

  factory AcademicCalendarSemester.fromJson(Map<String, dynamic> json) =>
      _$AcademicCalendarSemesterFromJson(json);

  Map<String, dynamic> toJson() => _$AcademicCalendarSemesterToJson(this);

  /// Calculate the teaching week of a target date.
  /// Returns null if date is before semester starts or after semester totalWeeks.
  int? getCurrentWeek(DateTime target) {
    final today = DateTime(target.year, target.month, target.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    if (today.isBefore(start)) return null;
    final days = today.difference(start).inDays;
    final week = (days / 7).floor() + 1;
    if (week > totalWeeks) return null;
    return week;
  }

  /// Check if target date falls within this semester's timeline
  bool isDateInSemester(DateTime target) {
    final today = DateTime(target.year, target.month, target.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    final end = start.add(Duration(days: totalWeeks * 7 - 1));
    return (today.isAtSameMomentAs(start) || today.isAfter(start)) &&
        (today.isAtSameMomentAs(end) || today.isBefore(end));
  }

  /// The date when this semester ends (last day of the last teaching week).
  DateTime get endDate => DateTime(
    startDate.year,
    startDate.month,
    startDate.day,
  ).add(Duration(days: totalWeeks * 7 - 1));

  /// The registration event (报到), if any.
  AcademicCalendarEvent? get registrationEvent {
    for (final event in events) {
      if (event.label.contains('报到')) return event;
    }
    return null;
  }

  /// Find a matching [ScheduleConfig] from [schedules].
  ///
  /// Priority:
  /// 1. Exact semester name match.
  /// 2. Academic year + season marker (春/秋/夏/冬) both present → match on both.
  /// 3. Semester start date (year + month) match.
  /// 4. Fallback: academic year only.
  String? findMatchingScheduleId(List<ScheduleConfig> schedules) {
    // Priority 1: exact match
    for (final s in schedules) {
      if (s.semesterName == name) return s.id;
    }

    final yearPattern = RegExp(r'(\d{4})-(\d{4})');
    final yearMatch = yearPattern.firstMatch(name);
    if (yearMatch == null) {
      // No year pattern in calendar semester name, try start date only
      for (final s in schedules) {
        if (s.semesterStartDate.year == startDate.year &&
            s.semesterStartDate.month == startDate.month) {
          return s.id;
        }
      }
      return null;
    }

    final yearKey = '${yearMatch.group(1)}-${yearMatch.group(2)}';

    // Extract season marker (春/秋/夏/冬) from calendar semester name
    String? season;
    final seasonMatch = RegExp(r'[春秋夏冬]').firstMatch(name);
    if (seasonMatch != null) season = seasonMatch.group(0);

    // Priority 2: year + season match
    if (season != null) {
      for (final s in schedules) {
        if (s.semesterName.contains(yearKey) &&
            s.semesterName.contains(season)) {
          return s.id;
        }
      }
    }

    // Priority 3: start date year + month match
    for (final s in schedules) {
      if (s.semesterStartDate.year == startDate.year &&
          s.semesterStartDate.month == startDate.month) {
        return s.id;
      }
    }

    // Priority 4: fallback — academic year only
    for (final s in schedules) {
      if (s.semesterName.contains(yearKey)) return s.id;
    }

    return null;
  }
}

@JsonSerializable()
class AcademicCalendarData {
  @JsonKey(defaultValue: [])
  final List<AcademicCalendarSemester> semesters;

  AcademicCalendarData({required this.semesters});

  factory AcademicCalendarData.fromJson(Map<String, dynamic> json) =>
      _$AcademicCalendarDataFromJson(json);

  factory AcademicCalendarData.fromJsonString(String content) {
    return AcademicCalendarData.fromJson(
      jsonDecode(content) as Map<String, dynamic>,
    );
  }

  /// Find the first semester that starts after [date].
  /// Semesters are assumed to be sorted by startDate.
  AcademicCalendarSemester? findNextSemester(DateTime date) {
    for (final semester in semesters) {
      if (semester.startDate.isAfter(date)) return semester;
    }
    return null;
  }
}
