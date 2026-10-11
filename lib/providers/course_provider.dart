import 'package:flutter/foundation.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/services/database_service.dart';
import 'package:bugaoshan/utils/app_log.dart';

class CourseProvider {
  final DatabaseService _db;

  /// Called after any data mutation that affects displayed courses.
  /// Set this from outside (e.g., WidgetUpdateService) to avoid circular DI.
  VoidCallback? onCoursesChanged;

  CourseProvider(this._db) {
    _loadData();
  }

  final ValueNotifier<List<Course>> courses = ValueNotifier<List<Course>>([]);
  final ValueNotifier<ScheduleConfig?> scheduleConfig =
      ValueNotifier<ScheduleConfig?>(null);
  final ValueNotifier<List<ScheduleConfig>> allSchedules =
      ValueNotifier<List<ScheduleConfig>>([]);
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);

  /// 当前数据库中是否存在课表。UI 据此在「暂无课表」空状态和 grid 之间切换。
  bool get hasSchedule => allSchedules.value.isNotEmpty;

  Future<void> _loadData() async {
    isLoading.value = true;
    try {
      courses.value = _db.getCourses();
      // 顺序约束：scheduleConfig 必须先于 allSchedules 发布。课表页的
      // 「无→有」监听要求两者同时就位才创建控制器；allSchedules 先行会让
      // 监听在 config 仍为 null 时触发而错过创建时机。
      final config = _db.getScheduleConfig();
      scheduleConfig.value = config;
      allSchedules.value = _db.getAllSchedules();
    } catch (e, logStackTrace) {
      AppLog.e(
        'CourseProvider',
        '_loadData 失败',
        error: e,
        stackTrace: logStackTrace,
      );
    } finally {
      isLoading.value = false;
      onCoursesChanged?.call();
    }
  }

  Future<void> switchSchedule(String scheduleId) async {
    return AppLog.guard('CourseProvider', '切换课表', () async {
      isLoading.value = true;
      try {
        await _db.switchSchedule(scheduleId);
        await _loadData();
      } finally {
        isLoading.value = false;
      }
    });
  }

  Future<void> addSchedule(ScheduleConfig config) async {
    return AppLog.guard('CourseProvider', '新增课表', () async {
      // 落库后直接 switchSchedule，由 _loadData 统一发布 scheduleConfig 与
      // allSchedules。若这里先单独发布 allSchedules，switchSchedule 的异步
      // 间隙里会出现「hasSchedule=true 而 scheduleConfig 未就位」的中间态，
      // 空库首次导入时课表页网格会以未创建的控制器构建并抛空指针。
      await _db.addSchedule(config);
      await switchSchedule(config.id);
    });
  }

  Future<void> deleteSchedule(String scheduleId) async {
    return AppLog.guard('CourseProvider', '删除课表', () async {
      await _db.deleteSchedule(scheduleId);
      // Reload everything as current schedule might have changed
      await _loadData();
    });
  }

  Future<List<Course>> getCoursesForSchedule(String scheduleId) async {
    return AppLog.guard('CourseProvider', '读取课表课程', () async {
      return await _db.getCoursesAsync(scheduleId: scheduleId);
    });
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
    return AppLog.guard('CourseProvider', '新增课程', () async {
      await _db.addCourse(course);
      courses.value = _db.getCourses();
      onCoursesChanged?.call();
    });
  }

  Future<void> updateCourse(Course course) async {
    return AppLog.guard('CourseProvider', '修改课程', () async {
      await _db.updateCourse(course);
      courses.value = _db.getCourses();
      onCoursesChanged?.call();
    });
  }

  Future<void> deleteCourse(String courseId) async {
    return AppLog.guard('CourseProvider', '删除课程', () async {
      await _db.deleteCourse(courseId);
      courses.value = _db.getCourses();
      onCoursesChanged?.call();
    });
  }

  Future<void> updateScheduleConfig(ScheduleConfig config) async {
    return AppLog.guard('CourseProvider', '保存课表设置', () async {
      await _db.saveScheduleConfig(config);
      allSchedules.value = _db.getAllSchedules();
      if (config.id == _db.getCurrentScheduleId()) {
        scheduleConfig.value = config;
        // 非当前课表不影响当前课程展示，也无需刷新桌面组件。
        onCoursesChanged?.call();
      }
    });
  }

  /// 替换指定课表的所有课程（先删后插）。用于「更新课表」场景。
  Future<void> replaceScheduleCourses(
    String scheduleId,
    List<Course> newCourses,
  ) async {
    return AppLog.guard('CourseProvider', '替换课表课程', () async {
      await _db.replaceScheduleCourses(scheduleId, newCourses);
      if (scheduleId == _db.getCurrentScheduleId()) {
        courses.value = _db.getCourses();
      }
      onCoursesChanged?.call();
    });
  }

  /// 根据课表名查找已存在的课表 ID，用于冲突时更新。
  String? findScheduleIdByName(String name) {
    final match = allSchedules.value.where(
      (s) => s.semesterName.trim() == name.trim(),
    );
    return match.isNotEmpty ? match.first.id : null;
  }

  Future<void> clearAllData() async {
    return AppLog.guard('CourseProvider', '清空课表', () async {
      await _db.clearAllCourseData();
      await _loadData();
    });
  }
}
