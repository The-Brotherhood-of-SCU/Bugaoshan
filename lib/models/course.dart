/// 课程领域模型与日历扩展的汇总出口。
///
/// 为避免破坏既有 import（`import course.dart` 用于访问 [Course] /
/// [ScheduleConfig] / [TimeSlot]），此文件保留全部公共符号面：
/// - [Course] / [WeekType] / [DateTimeExtension] 定义在此文件；
/// - [ScheduleConfig] / [TimeSlot] 定义在 `schedule_config.dart`，
///   通过本文件 re-export，保持 `import course.dart` 即可使用。
library;

import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';

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

  /// 自定义离散周次列表（升序排列，例如 [1, 2, 4, 6]）。
  /// 为 null 时表示使用 [startWeek]..[endWeek] 结合 [weekType] 的连续/单双周规则。
  List<int>? customWeeks;

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
    this.customWeeks,
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
    final customWeeksRaw = json['customWeeks'] as List<dynamic>?;
    List<int>? customWeeks;
    if (customWeeksRaw != null) {
      customWeeks =
          customWeeksRaw
              .map((e) => (e is num) ? e.toInt() : int.tryParse(e.toString()))
              .whereType<int>()
              .where((w) => w >= 1)
              .toSet()
              .toList()
            ..sort();
      if (customWeeks.isEmpty) customWeeks = null;
    }
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
      customWeeks: customWeeks,
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
    if (customWeeks != null) 'customWeeks': customWeeks,
  };

  Color get color => Color(colorValue);

  set color(Color c) => colorValue = c.toARGB32();

  bool isInWeekRange(int week) {
    return week >= startWeek && week <= endWeek;
  }

  /// Check if this course is active in the given week
  bool isActiveInWeek(int week) {
    if (customWeeks != null && customWeeks!.isNotEmpty) {
      return customWeeks!.contains(week);
    }
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
    // Week overlap check
    final overlapStart = startWeek > other.startWeek
        ? startWeek
        : other.startWeek;
    final overlapEnd = endWeek < other.endWeek ? endWeek : other.endWeek;
    if (overlapStart > overlapEnd) return false;

    for (int w = overlapStart; w <= overlapEnd; w++) {
      if (isActiveInWeek(w) && other.isActiveInWeek(w)) {
        return true;
      }
    }
    return false;
  }

  /// 将一组周数格式化为紧凑的区间描述，例如 `1-3, 5, 8-10`
  static String formatSegments(List<int> weeks) {
    if (weeks.isEmpty) return '';
    final sorted = weeks.where((w) => w >= 1).toSet().toList()..sort();
    if (sorted.isEmpty) return '';
    final segments = <String>[];
    int start = sorted.first;
    int end = start;

    for (int i = 1; i < sorted.length; i++) {
      final current = sorted[i];
      if (current == end + 1) {
        end = current;
      } else {
        segments.add(start == end ? '$start' : '$start-$end');
        start = current;
        end = current;
      }
    }
    segments.add(start == end ? '$start' : '$start-$end');
    return segments.join(', ');
  }

  /// 本地化周次显示文本。若为自定义离散周则返回离散区间，否则返回标准起止周及单双周标识。
  String formatWeeks(AppLocalizations l10n) {
    if (customWeeks != null && customWeeks!.isNotEmpty) {
      final segs = formatSegments(customWeeks!);
      final isZh = l10n.localeName.startsWith('zh');
      return isZh ? '$segs 周' : 'Weeks $segs';
    }
    final range = l10n.weekRange(startWeek, endWeek);
    return switch (weekType) {
      WeekType.odd => '$range ${l10n.oddWeek}',
      WeekType.even => '$range ${l10n.evenWeek}',
      WeekType.every => range,
    };
  }

  /// 复制并可选覆盖字段。[id] 传 `null` 时保留原 ID；需要重新生成 ID 时
  /// 显式传入 [Course.generateId]()，或直接使用 [duplicate] 复制整门课程。
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
    List<int>? customWeeks,
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
      customWeeks: customWeeks ?? this.customWeeks,
    );
  }

  /// 复制一门课程：字段与原课程完全一致，但使用全新的 [id]，名称追加 [nameSuffix]。
  ///
  /// 复制结果在语义上是「新课程」，必须通过新增落库；若沿用原 id，
  /// 数据层会按 id 执行 UPDATE，从而覆盖原课程而不是产生副本。
  Course duplicate({String nameSuffix = ''}) =>
      copyWith(id: generateId(), name: '$name$nameSuffix');
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
