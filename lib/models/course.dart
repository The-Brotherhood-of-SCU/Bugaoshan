import 'package:flutter/material.dart';

class TimeSlot {
  final TimeOfDay startTime;
  final TimeOfDay endTime;

  const TimeSlot({required this.startTime, required this.endTime});

  factory TimeSlot.fromJson(Map<String, dynamic> json) {
    return TimeSlot(
      startTime: _timeOfDayFromJson(json['startTime'] as Map<String, dynamic>),
      endTime: _timeOfDayFromJson(json['endTime'] as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() => {
    'startTime': _timeOfDayToJson(startTime),
    'endTime': _timeOfDayToJson(endTime),
  };

  static TimeOfDay _timeOfDayFromJson(Map<String, dynamic> json) {
    return TimeOfDay(hour: json['hour'] as int, minute: json['minute'] as int);
  }

  static Map<String, dynamic> _timeOfDayToJson(TimeOfDay time) {
    return {'hour': time.hour, 'minute': time.minute};
  }

  TimeSlot copyWith({TimeOfDay? startTime, TimeOfDay? endTime}) {
    return TimeSlot(
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
    );
  }
}

class ScheduleConfig {
  String id;
  String semesterName;
  DateTime semesterStartDate;
  int totalWeeks;
  int morningSections;
  int afternoonSections;
  int eveningSections;
  int courseDuration;
  int breakDuration;
  bool autoSyncTime;
  List<TimeSlot> timeSlots;
  bool showTeacherName;
  bool showLocation;
  bool showWeekend;
  bool showNonCurrentWeekCourses;

  int get sectionsPerDay =>
      morningSections + afternoonSections + eveningSections;

  ScheduleConfig({
    this.id = 'default',
    this.semesterName = '',
    required this.semesterStartDate,
    this.totalWeeks = 16,
    this.morningSections = 4,
    this.afternoonSections = 5,
    this.eveningSections = 3,
    this.courseDuration = 45,
    this.breakDuration = 10,
    this.autoSyncTime = true,
    List<TimeSlot>? timeSlots,
    this.showTeacherName = true,
    this.showLocation = true,
    this.showWeekend = false,
    this.showNonCurrentWeekCourses = true,
  }) : timeSlots = timeSlots ?? _defaultTimeSlots(4, 5, 3, 45, 10);

  factory ScheduleConfig.fromJson(Map<String, dynamic> json) {
    int totalWeeks;
    if (json.containsKey('totalWeeks')) {
      totalWeeks = json['totalWeeks'] as int;
    } else if (json.containsKey('semesterEndDate')) {
      final startDate = DateTime.parse(json['semesterStartDate'] as String);
      final endDate = DateTime.parse(json['semesterEndDate'] as String);
      totalWeeks = (endDate.difference(startDate).inDays / 7).ceil();
    } else {
      totalWeeks = 16;
    }

    int morning = json['morningSections'] as int? ?? 4;
    int afternoon = json['afternoonSections'] as int? ?? 5;
    int evening = json['eveningSections'] as int? ?? 3;

    // Fallback for old configurations using `sectionsPerDay`
    if (!json.containsKey('morningSections') &&
        json.containsKey('sectionsPerDay')) {
      int total = json['sectionsPerDay'] as int;
      morning = (total >= 4) ? 4 : total;
      afternoon = (total >= 9) ? 5 : (total > 4 ? total - 4 : 0);
      evening = (total > 9) ? total - 9 : 0;
    }

    final courseDuration = json['courseDuration'] as int? ?? 45;
    final breakDuration = json['breakDuration'] as int? ?? 10;

    return ScheduleConfig(
      id: json['id'] as String? ?? 'default',
      semesterName: json['semesterName'] as String? ?? '',
      semesterStartDate: DateTime.parse(json['semesterStartDate'] as String),
      totalWeeks: totalWeeks,
      morningSections: morning,
      afternoonSections: afternoon,
      eveningSections: evening,
      courseDuration: courseDuration,
      breakDuration: breakDuration,
      autoSyncTime: json['autoSyncTime'] as bool? ?? true,
      timeSlots:
          (json['timeSlots'] as List<dynamic>?)
              ?.map((e) => TimeSlot.fromJson(e as Map<String, dynamic>))
              .toList() ??
          _defaultTimeSlots(
            morning,
            afternoon,
            evening,
            courseDuration,
            breakDuration,
          ),
      showTeacherName: json['showTeacherName'] as bool? ?? true,
      showLocation: json['showLocation'] as bool? ?? true,
      showWeekend: json['showWeekend'] as bool? ?? true,
      showNonCurrentWeekCourses:
          json['showNonCurrentWeekCourses'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'semesterName': semesterName,
    'semesterStartDate':
        '${semesterStartDate.year}-${semesterStartDate.month.toString().padLeft(2, '0')}-${semesterStartDate.day.toString().padLeft(2, '0')}',
    'totalWeeks': totalWeeks,
    'morningSections': morningSections,
    'afternoonSections': afternoonSections,
    'eveningSections': eveningSections,
    'courseDuration': courseDuration,
    'breakDuration': breakDuration,
    'autoSyncTime': autoSyncTime,
    'timeSlots': timeSlots.map((e) => e.toJson()).toList(),
    'showTeacherName': showTeacherName,
    'showLocation': showLocation,
    'showWeekend': showWeekend,
    'showNonCurrentWeekCourses': showNonCurrentWeekCourses,
  };

  static List<TimeSlot> _defaultTimeSlots(
    int morning,
    int afternoon,
    int evening,
    int courseDuration,
    int breakDuration,
  ) {
    final slots = <TimeSlot>[];

    // Check if it matches the standard 4-5-3 config to provide specific times
    if (morning == 4 && afternoon == 5 && evening == 3) {
      return [
        // Morning
        TimeSlot(
          startTime: const TimeOfDay(hour: 8, minute: 15),
          endTime: const TimeOfDay(hour: 9, minute: 0),
        ),
        TimeSlot(
          startTime: const TimeOfDay(hour: 9, minute: 10),
          endTime: const TimeOfDay(hour: 9, minute: 55),
        ),
        TimeSlot(
          startTime: const TimeOfDay(hour: 10, minute: 15),
          endTime: const TimeOfDay(hour: 11, minute: 0),
        ),
        TimeSlot(
          startTime: const TimeOfDay(hour: 11, minute: 10),
          endTime: const TimeOfDay(hour: 11, minute: 55),
        ),
        // Afternoon
        TimeSlot(
          startTime: const TimeOfDay(hour: 13, minute: 50),
          endTime: const TimeOfDay(hour: 14, minute: 35),
        ),
        TimeSlot(
          startTime: const TimeOfDay(hour: 14, minute: 45),
          endTime: const TimeOfDay(hour: 15, minute: 30),
        ),
        TimeSlot(
          startTime: const TimeOfDay(hour: 15, minute: 40),
          endTime: const TimeOfDay(hour: 16, minute: 25),
        ),
        TimeSlot(
          startTime: const TimeOfDay(hour: 16, minute: 45),
          endTime: const TimeOfDay(hour: 17, minute: 30),
        ),
        TimeSlot(
          startTime: const TimeOfDay(hour: 17, minute: 40),
          endTime: const TimeOfDay(hour: 18, minute: 25),
        ),
        // Evening
        TimeSlot(
          startTime: const TimeOfDay(hour: 19, minute: 20),
          endTime: const TimeOfDay(hour: 20, minute: 5),
        ),
        TimeSlot(
          startTime: const TimeOfDay(hour: 20, minute: 15),
          endTime: const TimeOfDay(hour: 21, minute: 0),
        ),
        TimeSlot(
          startTime: const TimeOfDay(hour: 21, minute: 10),
          endTime: const TimeOfDay(hour: 21, minute: 55),
        ),
      ];
    }

    // Default generic logic if config is different
    // Morning (starts at 8:00)
    int currentHour = 8;
    int currentMin = 0;
    for (int i = 0; i < morning; i++) {
      int endMin = currentMin + courseDuration;
      int endHour = currentHour + (endMin ~/ 60);
      endMin = endMin % 60;
      slots.add(
        TimeSlot(
          startTime: TimeOfDay(hour: currentHour, minute: currentMin),
          endTime: TimeOfDay(hour: endHour, minute: endMin),
        ),
      );
      // Add break
      currentMin = endMin + breakDuration;
      currentHour = endHour + (currentMin ~/ 60);
      currentMin = currentMin % 60;
    }

    // Afternoon (starts at 14:00)
    currentHour = 14;
    currentMin = 0;
    for (int i = 0; i < afternoon; i++) {
      int endMin = currentMin + courseDuration;
      int endHour = currentHour + (endMin ~/ 60);
      endMin = endMin % 60;
      slots.add(
        TimeSlot(
          startTime: TimeOfDay(hour: currentHour, minute: currentMin),
          endTime: TimeOfDay(hour: endHour, minute: endMin),
        ),
      );
      // Add break
      currentMin = endMin + breakDuration;
      currentHour = endHour + (currentMin ~/ 60);
      currentMin = currentMin % 60;
    }

    // Evening (starts at 19:00)
    currentHour = 19;
    currentMin = 0;
    for (int i = 0; i < evening; i++) {
      int endMin = currentMin + courseDuration;
      int endHour = currentHour + (endMin ~/ 60);
      endMin = endMin % 60;
      slots.add(
        TimeSlot(
          startTime: TimeOfDay(hour: currentHour, minute: currentMin),
          endTime: TimeOfDay(hour: endHour, minute: endMin),
        ),
      );
      // Add break
      currentMin = endMin + breakDuration;
      currentHour = endHour + (currentMin ~/ 60);
      currentMin = currentMin % 60;
    }

    return slots;
  }

  int getCurrentWeek() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(
      semesterStartDate.year,
      semesterStartDate.month,
      semesterStartDate.day,
    );
    if (today.isBefore(start)) return 1;
    final days = today.difference(start).inDays;
    final week = (days / 7).floor() + 1;
    return week.clamp(1, totalWeeks);
  }

  ScheduleConfig copyWith({
    String? id,
    String? semesterName,
    DateTime? semesterStartDate,
    int? totalWeeks,
    int? morningSections,
    int? afternoonSections,
    int? eveningSections,
    int? courseDuration,
    int? breakDuration,
    bool? autoSyncTime,
    List<TimeSlot>? timeSlots,
    bool? showTeacherName,
    bool? showLocation,
    bool? showWeekend,
    bool? showNonCurrentWeekCourses,
  }) {
    return ScheduleConfig(
      id: id ?? this.id,
      semesterName: semesterName ?? this.semesterName,
      semesterStartDate: semesterStartDate ?? this.semesterStartDate,
      totalWeeks: totalWeeks ?? this.totalWeeks,
      morningSections: morningSections ?? this.morningSections,
      afternoonSections: afternoonSections ?? this.afternoonSections,
      eveningSections: eveningSections ?? this.eveningSections,
      courseDuration: courseDuration ?? this.courseDuration,
      breakDuration: breakDuration ?? this.breakDuration,
      autoSyncTime: autoSyncTime ?? this.autoSyncTime,
      timeSlots: timeSlots ?? this.timeSlots,
      showTeacherName: showTeacherName ?? this.showTeacherName,
      showLocation: showLocation ?? this.showLocation,
      showWeekend: showWeekend ?? this.showWeekend,
      showNonCurrentWeekCourses:
          showNonCurrentWeekCourses ?? this.showNonCurrentWeekCourses,
    );
  }
}

enum WeekType { every, odd, even }

class Course {
  final String id;
  String name;
  String teacher;
  String location;
  int startWeek;
  int endWeek;
  int dayOfWeek; // 1=Mon ... 7=Sun
  int startSection;
  int endSection;
  int colorValue; // ARGB
  WeekType weekType;

  Course({
    String? id,
    required this.name,
    required this.teacher,
    required this.location,
    required this.startWeek,
    required this.endWeek,
    required this.dayOfWeek,
    required this.startSection,
    required this.endSection,
    required this.colorValue,
    this.weekType = WeekType.every,
  }) : id = id ?? _generateId();

  static int _idCounter = 0;
  static String _generateId() {
    final now = DateTime.now();
    _idCounter++;
    return '${now.microsecondsSinceEpoch}_$_idCounter';
  }

  factory Course.fromJson(Map<String, dynamic> json) {
    return Course(
      id: json['id'] as String,
      name: json['name'] as String,
      teacher: json['teacher'] as String,
      location: json['location'] as String,
      startWeek: json['startWeek'] as int,
      endWeek: json['endWeek'] as int,
      dayOfWeek: json['dayOfWeek'] as int,
      startSection: json['startSection'] as int,
      endSection: json['endSection'] as int,
      colorValue: json['colorValue'] as int,
      weekType: json['weekType'] != null
          ? WeekType.values[json['weekType'] as int]
          : WeekType.every,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'teacher': teacher,
    'location': location,
    'startWeek': startWeek,
    'endWeek': endWeek,
    'dayOfWeek': dayOfWeek,
    'startSection': startSection,
    'endSection': endSection,
    'colorValue': colorValue,
    'weekType': weekType.index,
  };

  Color get color => Color(colorValue);

  set color(Color c) => colorValue = c.toARGB32();

  bool isInWeekRange(int week) {
    return week >= startWeek && week <= endWeek;
  }

  /// Check if this course is active in the given week
  bool isActiveInWeek(int week) {
    if (!isInWeekRange(week)) return false;
    if (weekType == WeekType.odd && week.isEven) return false;
    if (weekType == WeekType.even && week.isOdd) return false;
    return true;
  }

  /// Check if this course conflicts with another course
  bool conflictsWith(Course other, {String? excludeId}) {
    if (excludeId != null && id == excludeId) return false;
    if (dayOfWeek != other.dayOfWeek) return false;
    // Check week overlap considering week types
    for (int w = startWeek; w <= endWeek; w++) {
      if (isActiveInWeek(w) && other.isActiveInWeek(w)) {
        // Same week, check section overlap
        if (!(endSection < other.startSection ||
            startSection > other.endSection)) {
          return true;
        }
      }
    }
    return false;
  }

  Course copyWith({
    String? name,
    String? teacher,
    String? location,
    int? startWeek,
    int? endWeek,
    int? dayOfWeek,
    int? startSection,
    int? endSection,
    int? colorValue,
    WeekType? weekType,
  }) {
    return Course(
      id: id,
      name: name ?? this.name,
      teacher: teacher ?? this.teacher,
      location: location ?? this.location,
      startWeek: startWeek ?? this.startWeek,
      endWeek: endWeek ?? this.endWeek,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startSection: startSection ?? this.startSection,
      endSection: endSection ?? this.endSection,
      colorValue: colorValue ?? this.colorValue,
      weekType: weekType ?? this.weekType,
    );
  }
}

extension DateTimeExtension on DateTime {
  DateTime toMonday() {
    return subtract(Duration(days: weekday - 1));
  }
}
