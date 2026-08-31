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
  static const int kDefaultTotalWeeks = 20;

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

  int get sectionsPerDay =>
      morningSections + afternoonSections + eveningSections;

  /// The last day of this semester (end of the last teaching week).
  DateTime get semesterEndDate {
    final start = DateTime(
      semesterStartDate.year,
      semesterStartDate.month,
      semesterStartDate.day,
    );
    return start.add(Duration(days: totalWeeks * 7 - 1));
  }

  ScheduleConfig({
    this.id = 'default',
    this.semesterName = '',
    required this.semesterStartDate,
    this.totalWeeks = kDefaultTotalWeeks,
    this.morningSections = 4,
    this.afternoonSections = 5,
    this.eveningSections = 3,
    this.courseDuration = 45,
    this.breakDuration = 10,
    this.autoSyncTime = true,
    List<TimeSlot>? timeSlots,
  }) : timeSlots = timeSlots ?? _defaultTimeSlots(4, 5, 3, 45, 10);

  factory ScheduleConfig.fromJson(Map<String, dynamic> json) {
    int totalWeeks;
    if (json.containsKey('totalWeeks')) {
      totalWeeks = json['totalWeeks'] as int;
    } else if (json.containsKey('semesterEndDate')) {
      final startDate =
          DateTime.tryParse(json['semesterStartDate'] as String? ?? '') ??
          DateTime.now();
      final endDate =
          DateTime.tryParse(json['semesterEndDate'] as String? ?? '') ??
          DateTime.now();
      totalWeeks = (endDate.difference(startDate).inDays / 7).ceil();
    } else {
      totalWeeks = kDefaultTotalWeeks;
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
      semesterStartDate:
          DateTime.tryParse(json['semesterStartDate'] as String? ?? '') ??
          DateTime.now(),
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
  };

  /// 四川大学江安校区时间表预设（4-5-3）
  static List<TimeSlot> get jiangAnTimeSlots => const [
    // Morning
    TimeSlot(
      startTime: TimeOfDay(hour: 8, minute: 15),
      endTime: TimeOfDay(hour: 9, minute: 0),
    ),
    TimeSlot(
      startTime: TimeOfDay(hour: 9, minute: 10),
      endTime: TimeOfDay(hour: 9, minute: 55),
    ),
    TimeSlot(
      startTime: TimeOfDay(hour: 10, minute: 15),
      endTime: TimeOfDay(hour: 11, minute: 0),
    ),
    TimeSlot(
      startTime: TimeOfDay(hour: 11, minute: 10),
      endTime: TimeOfDay(hour: 11, minute: 55),
    ),
    // Afternoon
    TimeSlot(
      startTime: TimeOfDay(hour: 13, minute: 50),
      endTime: TimeOfDay(hour: 14, minute: 35),
    ),
    TimeSlot(
      startTime: TimeOfDay(hour: 14, minute: 45),
      endTime: TimeOfDay(hour: 15, minute: 30),
    ),
    TimeSlot(
      startTime: TimeOfDay(hour: 15, minute: 40),
      endTime: TimeOfDay(hour: 16, minute: 25),
    ),
    TimeSlot(
      startTime: TimeOfDay(hour: 16, minute: 45),
      endTime: TimeOfDay(hour: 17, minute: 30),
    ),
    TimeSlot(
      startTime: TimeOfDay(hour: 17, minute: 40),
      endTime: TimeOfDay(hour: 18, minute: 25),
    ),
    // Evening
    TimeSlot(
      startTime: TimeOfDay(hour: 19, minute: 20),
      endTime: TimeOfDay(hour: 20, minute: 5),
    ),
    TimeSlot(
      startTime: TimeOfDay(hour: 20, minute: 15),
      endTime: TimeOfDay(hour: 21, minute: 0),
    ),
    TimeSlot(
      startTime: TimeOfDay(hour: 21, minute: 10),
      endTime: TimeOfDay(hour: 21, minute: 55),
    ),
  ];

  /// 四川大学望江/华西校区时间表预设（4-5-3）
  static List<TimeSlot> get wangJiangHuaXiTimeSlots => const [
    TimeSlot(
      startTime: TimeOfDay(hour: 8, minute: 0),
      endTime: TimeOfDay(hour: 8, minute: 45),
    ),
    TimeSlot(
      startTime: TimeOfDay(hour: 8, minute: 55),
      endTime: TimeOfDay(hour: 9, minute: 40),
    ),
    TimeSlot(
      startTime: TimeOfDay(hour: 10, minute: 0),
      endTime: TimeOfDay(hour: 10, minute: 45),
    ),
    TimeSlot(
      startTime: TimeOfDay(hour: 10, minute: 55),
      endTime: TimeOfDay(hour: 11, minute: 40),
    ),
    TimeSlot(
      startTime: TimeOfDay(hour: 14, minute: 0),
      endTime: TimeOfDay(hour: 14, minute: 45),
    ),
    TimeSlot(
      startTime: TimeOfDay(hour: 14, minute: 55),
      endTime: TimeOfDay(hour: 15, minute: 40),
    ),
    TimeSlot(
      startTime: TimeOfDay(hour: 15, minute: 50),
      endTime: TimeOfDay(hour: 16, minute: 35),
    ),
    TimeSlot(
      startTime: TimeOfDay(hour: 16, minute: 55),
      endTime: TimeOfDay(hour: 17, minute: 40),
    ),
    TimeSlot(
      startTime: TimeOfDay(hour: 17, minute: 50),
      endTime: TimeOfDay(hour: 18, minute: 35),
    ),
    TimeSlot(
      startTime: TimeOfDay(hour: 19, minute: 30),
      endTime: TimeOfDay(hour: 20, minute: 15),
    ),
    TimeSlot(
      startTime: TimeOfDay(hour: 20, minute: 25),
      endTime: TimeOfDay(hour: 21, minute: 10),
    ),
    TimeSlot(
      startTime: TimeOfDay(hour: 21, minute: 20),
      endTime: TimeOfDay(hour: 22, minute: 5),
    ),
  ];

  /// 根据校区名称返回对应的时间表预设。
  ///
  /// 匹配逻辑：校区名包含"江安" → 江安时间表；
  /// 包含"望江"或"华西" → 望江/华西时间表；
  /// 否则返回 null，调用方应使用全局配置作为兜底。
  static List<TimeSlot>? timeSlotsForCampusName(String campusName) {
    if (campusName.contains('江安')) return jiangAnTimeSlots;
    if (campusName.contains('望江') || campusName.contains('华西')) {
      return wangJiangHuaXiTimeSlots;
    }
    return null;
  }

  /// 从上课地点推断校区时使用的关键词，顺序即匹配优先级。
  static const List<String> campusKeywords = ['江安', '望江', '华西'];

  /// 从一批上课地点统计主导校区。
  ///
  /// 每个地点按 [campusKeywords] 顺序取第一个命中的关键词计数一次；
  /// 返回出现次数严格最多的校区名。无任何命中或存在并列时返回 null。
  static String? dominantCampusOfLocations(Iterable<String> locations) {
    final counts = <String, int>{};
    for (final location in locations) {
      for (final keyword in campusKeywords) {
        if (location.contains(keyword)) {
          counts[keyword] = (counts[keyword] ?? 0) + 1;
          break;
        }
      }
    }
    return _majorityCampus(counts);
  }

  /// 单门课程的校区关键词。
  ///
  /// 优先取教务处 `campusName` 字段命中的校区关键词；未命中时回退到
  /// 从上课地点字符串推断。
  static String? campusKeywordOfCourse(Course course) {
    for (final keyword in campusKeywords) {
      if (course.campus.contains(keyword)) return keyword;
    }
    for (final keyword in campusKeywords) {
      if (course.location.contains(keyword)) return keyword;
    }
    return null;
  }

  /// 从一批课程统计主导校区（依据 [campusKeywordOfCourse]）。
  static String? dominantCampusOfCourses(List<Course> courses) {
    final counts = <String, int>{};
    for (final course in courses) {
      final keyword = campusKeywordOfCourse(course);
      if (keyword != null) {
        counts[keyword] = (counts[keyword] ?? 0) + 1;
      }
    }
    return _majorityCampus(counts);
  }

  /// 取计数表中严格最多的校区；空表或并列时返回 null。
  static String? _majorityCampus(Map<String, int> counts) {
    if (counts.isEmpty) return null;
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (sorted.length > 1 && sorted.first.value == sorted[1].value) {
      return null; // 并列，无法确定主导校区
    }
    return sorted.first.key;
  }

  /// 若 [courses] 存在主导校区，则将 [config] 的时间表替换为该校区的
  /// 预置时间表（会新建列表，不共享预设常量）。
  ///
  /// 校区判定优先使用课程的 `campus` 字段（教务处 campusName），其次
  /// 从地点字符串推断。返回是否发生了修改；无主导校区时保持 [config]
  /// 不变并返回 false。
  static bool applyCampusTimeSlotsForCourses(
    ScheduleConfig config,
    List<Course> courses,
  ) {
    final campus = dominantCampusOfCourses(courses);
    if (campus == null) return false;
    final slots = timeSlotsForCampusName(campus);
    if (slots == null) return false;
    config.timeSlots = List.of(slots);
    return true;
  }

  static List<TimeSlot> _defaultTimeSlots(
    int morning,
    int afternoon,
    int evening,
    int courseDuration,
    int breakDuration,
  ) {
    final slots = <TimeSlot>[];

    // Standard 4-5-3 → use the 江安 preset (most common SCU schedule)
    if (morning == 4 && afternoon == 5 && evening == 3) {
      return List.of(jiangAnTimeSlots);
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
    return week;
  }

  /// 返回指定教学周、星期对应的自然日。
  ///
  /// 课表允许将学期起点保存为周日；该周日属于第一教学周，随后一天
  /// 才是第一周周一。因此不能直接用 [DateTimeExtension.toMonday]，否则
  /// 周日起点会被归到前一周。
  DateTime dateForCourseDay(int week, int dayOfWeek) {
    final start = DateTime(
      semesterStartDate.year,
      semesterStartDate.month,
      semesterStartDate.day,
    );
    final mondayOffset = (DateTime.monday - start.weekday) % 7;
    final daysFromMonday = dayOfWeek == DateTime.sunday
        ? -1
        : dayOfWeek - DateTime.monday;
    return start.add(
      Duration(days: (week - 1) * 7 + mondayOffset + daysFromMonday),
    );
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
      timeSlots: timeSlots ?? List.of(this.timeSlots),
    );
  }
}

enum WeekType { every, odd, even }

class Course {
  final String id;
  String name;
  String teacher;
  String location;

  /// 上课校区（来自教务处 `campusName` 字段，如"江安校区"）。
  /// 旧数据 / 分享 JSON 无此字段时为空串，此时从 [location] 推断。
  String campus;
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
    this.campus = '',
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
    final weekTypeIndex = json['weekType'] as int?;
    return Course(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      teacher: json['teacher'] as String? ?? '',
      location: json['location'] as String? ?? '',
      campus: json['campus'] as String? ?? '',
      startWeek: json['startWeek'] as int? ?? 1,
      endWeek: json['endWeek'] as int? ?? ScheduleConfig.kDefaultTotalWeeks,
      dayOfWeek: json['dayOfWeek'] as int? ?? 1,
      startSection: json['startSection'] as int? ?? 1,
      endSection: json['endSection'] as int? ?? 1,
      colorValue: json['colorValue'] as int? ?? 0xFF2196F3,
      weekType: weekTypeIndex != null && weekTypeIndex < WeekType.values.length
          ? WeekType.values[weekTypeIndex]
          : WeekType.every,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'teacher': teacher,
    'location': location,
    'campus': campus,
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
    // Section overlap check (O(1) interval intersection)
    if (endSection < other.startSection || startSection > other.endSection) {
      return false;
    }
    // Week overlap check considering WeekType (O(1))
    final overlapStart = startWeek > other.startWeek
        ? startWeek
        : other.startWeek;
    final overlapEnd = endWeek < other.endWeek ? endWeek : other.endWeek;
    if (overlapStart > overlapEnd) return false;
    return _hasSharedWeek(overlapStart, overlapEnd, weekType, other.weekType);
  }

  static bool _hasSharedWeek(int start, int end, WeekType a, WeekType b) {
    if (a == WeekType.even && b == WeekType.odd) return false;
    if (a == WeekType.odd && b == WeekType.even) return false;
    if (a == WeekType.every && b == WeekType.every) return true;
    final needOdd = a == WeekType.odd || b == WeekType.odd;
    int first;
    if (needOdd) {
      first = start.isOdd ? start : start + 1;
    } else {
      first = start.isEven ? start : start + 1;
    }
    return first <= end;
  }

  Course copyWith({
    String? name,
    String? teacher,
    String? location,
    String? campus,
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
      campus: campus ?? this.campus,
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

  /// 教务系统以周日为每周第一天，返回本周周日
  DateTime toSunday() {
    return subtract(Duration(days: weekday % 7));
  }
}
