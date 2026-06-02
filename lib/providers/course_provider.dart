import 'package:flutter/foundation.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/models/holiday_override.dart';
import 'package:bugaoshan/services/database_service.dart';
import 'package:bugaoshan/utils/holiday_utils.dart';

class CourseProvider {
  final DatabaseService _db;

  /// Called after any data mutation that affects displayed courses.
  /// Set this from outside (e.g., WidgetUpdateService) to avoid circular DI.
  VoidCallback? onCoursesChanged;

  CourseProvider(this._db) {
    _loadData();
    _loadHolidayOverrides();
  }

  final ValueNotifier<List<Course>> courses = ValueNotifier<List<Course>>([]);
  final ValueNotifier<ScheduleConfig> scheduleConfig =
      ValueNotifier<ScheduleConfig>(_defaultConfig());
  final ValueNotifier<List<ScheduleConfig>> allSchedules =
      ValueNotifier<List<ScheduleConfig>>([]);
  final ValueNotifier<int> currentWeek = ValueNotifier<int>(1);
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);

  /// 调休记录，key 为 "YYYY-MM-DD"，value 为 HolidayOverride
  final ValueNotifier<Map<String, HolidayOverride>> holidayOverrides =
      ValueNotifier<Map<String, HolidayOverride>>({});

  /// 当前数据库中是否存在课表。UI 据此在「暂无课表」空状态和 grid 之间切换。
  bool get hasSchedule => allSchedules.value.isNotEmpty;

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
      // 无课表时 currentWeek 兜底为 1，避免占位 config 算出意外的周数
      if (allSchedules.value.isEmpty) {
        currentWeek.value = 1;
      } else {
        currentWeek.value = config.getCurrentWeek();
      }
    } catch (e) {
      debugPrint('CourseProvider: failed to load data: $e');
    } finally {
      isLoading.value = false;
      onCoursesChanged?.call();
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
    onCoursesChanged?.call();
  }

  Future<void> updateCourse(Course course) async {
    await _db.updateCourse(course);
    courses.value = _db.getCourses();
    onCoursesChanged?.call();
  }

  Future<void> deleteCourse(String courseId) async {
    await _db.deleteCourse(courseId);
    courses.value = _db.getCourses();
    onCoursesChanged?.call();
  }

  Future<void> updateScheduleConfig(ScheduleConfig config) async {
    await _db.saveScheduleConfig(config);
    scheduleConfig.value = config;
    allSchedules.value = _db.getAllSchedules();
    currentWeek.value = config.getCurrentWeek();
    onCoursesChanged?.call();
  }

  void updateCurrentWeek(int week) {
    final totalWeeks = scheduleConfig.value.totalWeeks;
    currentWeek.value = week.clamp(1, totalWeeks);
  }

  // ==================== Holiday Overrides ====================

  Future<void> _loadHolidayOverrides() async {
    try {
      final raw = await _db.getHolidayOverrides();
      final map = <String, HolidayOverride>{};
      for (final entry in raw.entries) {
        map[entry.key] = HolidayOverride.fromJson(entry.value);
      }
      holidayOverrides.value = map;
    } catch (e) {
      debugPrint('CourseProvider: failed to load holiday overrides: $e');
    }
  }

  /// 设置某天为放假
  Future<void> setHoliday(DateTime date) async {
    final key = _dateKey(date);
    final current = Map<String, HolidayOverride>.from(holidayOverrides.value);
    current[key] = HolidayOverride(date: date, active: true);
    holidayOverrides.value = current;
    await _db.saveHolidayOverride(current[key]!.toJson());
    onCoursesChanged?.call();
  }

  /// 设置放假并调休：[holidayDate] 放假，课程调到 [makeupDate]
  Future<void> setHolidayWithMakeup(
    DateTime holidayDate,
    DateTime makeupDate,
  ) async {
    final key = _dateKey(holidayDate);
    final current = Map<String, HolidayOverride>.from(holidayOverrides.value);
    current[key] = HolidayOverride(
      date: holidayDate,
      makeupDate: makeupDate,
      active: true,
    );
    holidayOverrides.value = current;
    await _db.saveHolidayOverride(current[key]!.toJson());
    onCoursesChanged?.call();
  }

  /// 取消某天的放假设置（同时清除调休）。
  ///
  /// - 法定节假日 → 存入 `active: false`，一次性取消放假和调休
  /// - 手动设置的放假 → 删除记录
  Future<void> cancelHoliday(DateTime date) async {
    final key = _dateKey(date);
    final current = Map<String, HolidayOverride>.from(holidayOverrides.value);

    if (HolidayUtils.isStatutoryHoliday(date)) {
      // 法定节假日 → 存入 active: false，清除调休
      current[key] = HolidayOverride(date: date, active: false);
      holidayOverrides.value = current;
      await _db.saveHolidayOverride(current[key]!.toJson());
    } else {
      // 手动设置的放假 → 删除记录
      current.remove(key);
      holidayOverrides.value = current;
      await _db.removeHolidayOverride(date);
    }
    onCoursesChanged?.call();
  }

  /// 仅取消调休，保留放假设置。
  Future<void> cancelMakeup(DateTime date) async {
    final key = _dateKey(date);
    final current = Map<String, HolidayOverride>.from(holidayOverrides.value);
    final existing = current[key];

    if (existing != null) {
      current[key] = HolidayOverride(date: date, active: existing.active);
      holidayOverrides.value = current;
      await _db.saveHolidayOverride(current[key]!.toJson());
    }
    onCoursesChanged?.call();
  }

  String _dateKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> clearAllData() async {
    await _db.clearAllCourseData();
    await _loadData();
  }
}
