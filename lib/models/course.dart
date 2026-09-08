/// 课程领域模型与日历扩展的汇总出口。
///
/// 为避免破坏既有 import（`import course.dart` 用于访问 [Course] /
/// [ScheduleConfig] / [TimeSlot]），此文件保留全部公共符号面：
/// - [Course] / [WeekType] / [DateTimeExtension] 定义在此文件；
/// - [ScheduleConfig] / [TimeSlot] 定义在 `schedule_config.dart`，
///   通过本文件 re-export，保持 `import course.dart` 即可使用。
library;

import 'package:flutter/material.dart';

export 'schedule_config.dart' show ScheduleConfig, TimeSlot;

/// 默认学期总周数（教务系统标准 20 周）。
const int kDefaultTotalWeeks = 20;

/// 周类型：每周 / 单周 / 双周。
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
  }) : id = id ?? generateId();

  static int _idCounter = 0;

  /// 生成唯一课程 ID（微秒时间戳 + 自增序号）。
  static String generateId() {
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
      endWeek: json['endWeek'] as int? ?? kDefaultTotalWeeks,
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

  /// 复制并可选覆盖字段。[id] 传 `null` 时保留原 ID；需要重新生成 ID 时
  /// 显式传入 [Course.generateId]()。
  Course copyWith({
    String? id,
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
      id: id ?? this.id,
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
