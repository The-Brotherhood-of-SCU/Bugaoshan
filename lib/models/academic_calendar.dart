import 'dart:convert';

import 'package:json_annotation/json_annotation.dart';

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
  DateTime? fromJson(String? json) => json != null ? DateTime.parse(json) : null;

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
    return (targetDay.isAtSameMomentAs(startDay) || targetDay.isAfter(startDay)) &&
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
        jsonDecode(content) as Map<String, dynamic>);
  }
}
