import 'dart:convert';

class AcademicCalendarEvent {
  final DateTime date;
  final DateTime? endDate;
  final String label;
  final String tag; // e.g. 'holiday', 'exam', 'start', 'course', 'event'

  AcademicCalendarEvent({
    required this.date,
    this.endDate,
    required this.label,
    required this.tag,
  });

  factory AcademicCalendarEvent.fromJson(Map<String, dynamic> json) {
    final dateStr = json['date'] as String;
    final endDateStr = json['endDate'] as String?;
    return AcademicCalendarEvent(
      date: DateTime.parse(dateStr),
      endDate: endDateStr != null ? DateTime.parse(endDateStr) : null,
      label: json['label'] as String? ?? '',
      tag: json['tag'] as String? ?? 'event',
    );
  }

  Map<String, dynamic> toJson() => {
    'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
    if (endDate != null)
      'endDate': '${endDate!.year}-${endDate!.month.toString().padLeft(2, '0')}-${endDate!.day.toString().padLeft(2, '0')}',
    'label': label,
    'tag': tag,
  };

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

class AcademicCalendarSemester {
  final String name;
  final DateTime startDate;
  final int totalWeeks;
  final List<AcademicCalendarEvent> events;

  AcademicCalendarSemester({
    required this.name,
    required this.startDate,
    required this.totalWeeks,
    required this.events,
  });

  factory AcademicCalendarSemester.fromJson(Map<String, dynamic> json) {
    final startDateStr = json['startDate'] as String;
    final eventsList = json['events'] as List<dynamic>? ?? [];
    return AcademicCalendarSemester(
      name: json['name'] as String? ?? '',
      startDate: DateTime.parse(startDateStr),
      totalWeeks: json['totalWeeks'] as int? ?? 20,
      events: eventsList
          .map((e) => AcademicCalendarEvent.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'startDate': '${startDate.year}-${startDate.month.toString().padLeft(2, '0')}-${startDate.day.toString().padLeft(2, '0')}',
    'totalWeeks': totalWeeks,
    'events': events.map((e) => e.toJson()).toList(),
  };

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

class AcademicCalendarData {
  final List<AcademicCalendarSemester> semesters;

  AcademicCalendarData({required this.semesters});

  factory AcademicCalendarData.fromJson(Map<String, dynamic> json) {
    final semestersList = json['semesters'] as List<dynamic>? ?? [];
    return AcademicCalendarData(
      semesters: semestersList
          .map((e) => AcademicCalendarSemester.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  factory AcademicCalendarData.fromJsonString(String content) {
    return AcademicCalendarData.fromJson(jsonDecode(content) as Map<String, dynamic>);
  }
}
