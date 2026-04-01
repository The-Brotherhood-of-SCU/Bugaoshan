import 'dart:convert';

import 'package:hive_ce/hive.dart';
import 'package:rubbish_plan/models/course.dart';

const String _boxCourses = 'courses';
const String _keyScheduleConfig = 'scheduleConfig';

class DatabaseService {
  Box? _coursesBox;

  Future<void> init() async {
    await Hive.openBox(_boxCourses);
    _coursesBox = Hive.box(_boxCourses);
  }

  // ==================== Courses ====================

  List<Course> getCourses() {
    return _coursesBox!.values
        .where((e) => e is Map)
        .map((e) => Course.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> addCourse(Course course) async {
    await _coursesBox!.put(course.id, course.toJson());
  }

  Future<void> updateCourse(Course course) async {
    await _coursesBox!.put(course.id, course.toJson());
  }

  Future<void> deleteCourse(String courseId) async {
    await _coursesBox!.delete(courseId);
  }

  Future<bool> hasConflict(Course course, {String? excludeId}) async {
    return getCourses().any((c) => c.conflictsWith(course, excludeId: excludeId));
  }

  // ==================== Schedule Config ====================

  ScheduleConfig getScheduleConfig() {
    final jsonStr = _coursesBox!.get(_keyScheduleConfig) as String?;
    if (jsonStr == null || jsonStr.isEmpty) {
      return _defaultScheduleConfig();
    }
    try {
      final map = _decodeJson(jsonStr);
      return ScheduleConfig.fromJson(map);
    } catch (_) {
      return _defaultScheduleConfig();
    }
  }

  Future<void> saveScheduleConfig(ScheduleConfig config) async {
    final jsonStr = _encodeJson(config.toJson());
    await _coursesBox!.put(_keyScheduleConfig, jsonStr);
  }

  // ==================== Clear All ====================

  Future<void> clearAllCourseData() async {
    await _coursesBox!.clear();
  }

  // ==================== Helpers ====================

  ScheduleConfig _defaultScheduleConfig() {
    final now = DateTime.now();
    return ScheduleConfig(
      semesterStartDate: DateTime(now.year, now.month, now.day),
      totalWeeks: 20,
    );
  }

  Map<String, dynamic> _decodeJson(String str) =>
      Map<String, dynamic>.from(json.decode(str) as Map);

  String _encodeJson(Map<String, dynamic> map) => json.encode(map);
}
