import 'package:flutter/foundation.dart';
import 'package:Bugaoshan/models/course.dart';
import 'package:Bugaoshan/serivces/database_service.dart';

class CourseProvider {
  final DatabaseService _db;

  CourseProvider(this._db) {
    _loadData();
  }

  final ValueNotifier<List<Course>> courses = ValueNotifier<List<Course>>([]);
  final ValueNotifier<ScheduleConfig> scheduleConfig =
      ValueNotifier<ScheduleConfig>(_defaultConfig());
  final ValueNotifier<List<ScheduleConfig>> allSchedules =
      ValueNotifier<List<ScheduleConfig>>([]);
  final ValueNotifier<int> currentWeek = ValueNotifier<int>(1);
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);

  static ScheduleConfig _defaultConfig() {
    final now = DateTime.now();
    return ScheduleConfig(
      id: 'default',
      semesterName: '默认课表',
      semesterStartDate: now.toMonday(),
      totalWeeks: 20,
    );
  }

  Future<void> _loadData() async {
    isLoading.value = true;
    try {
      courses.value = _db.getCourses();
      allSchedules.value = _db.getAllSchedules();
      final config = _db.getScheduleConfig();
      scheduleConfig.value = config;
      currentWeek.value = config.getCurrentWeek();
    } catch (e) {
      debugPrint('CourseProvider: failed to load data: $e');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> switchSchedule(String scheduleId) async {
    isLoading.value = true;
    try {
      await _db.switchSchedule(scheduleId);
      await _loadData();
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> addSchedule(ScheduleConfig config) async {
    await _db.addSchedule(config);
    allSchedules.value = _db.getAllSchedules();
    await switchSchedule(config.id);
  }

  Future<void> deleteSchedule(String scheduleId) async {
    await _db.deleteSchedule(scheduleId);
    // Reload everything as current schedule might have changed
    await _loadData();
  }

  Future<List<Course>> getCoursesForSchedule(String scheduleId) async {
    return await _db.getCoursesAsync(scheduleId: scheduleId);
  }

  bool isScheduleNameTaken(String name, {String? excludeId}) {
    return allSchedules.value.any(
      (s) => s.semesterName.trim() == name.trim() && s.id != excludeId,
    );
  }

  List<Course> getCoursesForWeek(int week) {
    return courses.value.where((c) => c.isActiveInWeek(week)).toList();
  }

  /// Check if a course conflicts with existing courses (excluding a specific course by id)
  bool hasConflictSync(Course course, {String? excludeId}) {
    return courses.value.any(
      (c) => c.conflictsWith(course, excludeId: excludeId),
    );
  }

  /// Async conflict check using database query
  Future<bool> hasConflict(Course course, {String? excludeId}) {
    return _db.hasConflict(course, excludeId: excludeId);
  }

  Future<void> addCourse(Course course) async {
    await _db.addCourse(course);
    courses.value = _db.getCourses();
  }

  Future<void> updateCourse(Course course) async {
    await _db.updateCourse(course);
    courses.value = _db.getCourses();
  }

  Future<void> deleteCourse(String courseId) async {
    await _db.deleteCourse(courseId);
    courses.value = _db.getCourses();
  }

  Future<void> updateScheduleConfig(ScheduleConfig config) async {
    await _db.saveScheduleConfig(config);
    scheduleConfig.value = config;
    allSchedules.value = _db.getAllSchedules();
    currentWeek.value = config.getCurrentWeek();
  }

  void updateCurrentWeek(int week) {
    final totalWeeks = scheduleConfig.value.totalWeeks;
    currentWeek.value = week.clamp(1, totalWeeks);
  }

  Future<void> clearAllData() async {
    await _db.clearAllCourseData();
    await _loadData();
  }
}
