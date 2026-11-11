import 'package:flutter/foundation.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/services/database_service.dart';
import 'package:bugaoshan/services/hook_registry.dart';
import 'package:bugaoshan/utils/app_log.dart';

class CourseProvider {
  static const String _tag = 'CourseProvider';

  /// 「课表数据已变更」时机。
  ///
  /// 语义：课程增删改、当前课表切换、课表配置保存等会影响课表展示的写操作完成后触发，
  /// 携带变更后的完整课程列表。订阅者通过 [HookRegistry] 按 (本对象, 该时机) 订阅，
  /// 因此同一时机可以有任意多个订阅者（桌面小组件同步、缓存刷新、埋点……），
  /// 后订阅者不会覆盖先订阅者。
  static final Hook<List<Course>> courseChanged = Hook<List<Course>>(
    'courseChanged',
  );

  /// 本类对外声明的全部时机，构造时注册进 [HookRegistry]。
  static final List<Hook<dynamic>> hooks = <Hook<dynamic>>[courseChanged];

  final DatabaseService _db;
  final HookRegistry _hooks;

  CourseProvider(this._db, {HookRegistry? registry})
    : _hooks = registry ?? HookRegistry.instance {
    _hooks.register(this, CourseProvider.hooks);
    _loadData();
  }

  final ValueNotifier<List<Course>> courses = ValueNotifier<List<Course>>([]);
  final ValueNotifier<ScheduleConfig?> scheduleConfig =
      ValueNotifier<ScheduleConfig?>(null);
  final ValueNotifier<List<ScheduleConfig>> allSchedules =
      ValueNotifier<List<ScheduleConfig>>([]);
  final ValueNotifier<bool> isLoading = ValueNotifier<bool>(false);

  /// 广播 [courseChanged]：由注册中心分发给全部订阅者，单个订阅者异常不影响其余订阅者。
  void _notifyCoursesChanged() {
    _hooks.fire(this, courseChanged, courses.value);
  }

  /// 课表或课程数据变更版本号。
  ///
  /// 仅在实际增删改课表、课程、清空数据，或修改课表学期元数据（[ScheduleConfig.semesterName]、
  /// [ScheduleConfig.academicYearCode]、[ScheduleConfig.termName]）时递增；单纯切换当前激活课表或修改
  /// 非学期设置（如节次时间、总周数、作息设置等）不递增。
  /// 支持通过 [runBatch] 在同一批次内合并多次写操作，仅在最外层批次执行完毕时递增一次。
  final ValueNotifier<int> courseDataVersion = ValueNotifier<int>(0);

  int _batchDepth = 0;
  bool _pendingCourseDataVersionBump = false;

  void _bumpCourseDataVersion() {
    if (_batchDepth > 0) {
      _pendingCourseDataVersionBump = true;
      return;
    }
    courseDataVersion.value++;
  }

  /// 在同一批次内执行多次课表/课程写操作，仅在最外层批次结束时合并发布一次
  /// [courseDataVersion] 变更，避免批量导入跨多个 await 触发重复的派生索引重建。
  /// 若中途抛出异常但已有部分写操作落库，`finally` 仍会发布一次版本递增以保持一致性。
  Future<T> runBatch<T>(Future<T> Function() action) async {
    _batchDepth++;
    try {
      return await action();
    } finally {
      _batchDepth--;
      if (_batchDepth == 0 && _pendingCourseDataVersionBump) {
        _pendingCourseDataVersionBump = false;
        courseDataVersion.value++;
      }
    }
  }

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
      AppLog.e(_tag, '_loadData 失败', error: e, stackTrace: logStackTrace);
    } finally {
      isLoading.value = false;
      _notifyCoursesChanged();
    }
  }

  Future<void> switchSchedule(String scheduleId) async {
    return AppLog.guard(_tag, '切换课表', () async {
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
    return AppLog.guard(_tag, '新增课表', () async {
      // 落库后直接 switchSchedule，由 _loadData 统一发布 scheduleConfig 与
      // allSchedules。若这里先单独发布 allSchedules，switchSchedule 的异步
      // 间隙里会出现「hasSchedule=true 而 scheduleConfig 未就位」的中间态，
      // 空库首次导入时课表页网格会以未创建的控制器构建并抛空指针。
      await _db.addSchedule(config);
      await switchSchedule(config.id);
      _bumpCourseDataVersion();
    });
  }

  Future<void> deleteSchedule(String scheduleId) async {
    return AppLog.guard(_tag, '删除课表', () async {
      await _db.deleteSchedule(scheduleId);
      // Reload everything as current schedule might have changed
      await _loadData();
      _bumpCourseDataVersion();
    });
  }

  Future<List<Course>> getCoursesForSchedule(String scheduleId) async {
    return AppLog.guard(_tag, '读取课表课程', () async {
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
    return AppLog.guard(_tag, '新增课程', () async {
      await _db.addCourse(course);
      courses.value = _db.getCourses();
      _bumpCourseDataVersion();
      _notifyCoursesChanged();
    });
  }

  Future<void> updateCourse(Course course) async {
    return AppLog.guard(_tag, '修改课程', () async {
      await _db.updateCourse(course);
      courses.value = _db.getCourses();
      _bumpCourseDataVersion();
      _notifyCoursesChanged();
    });
  }

  Future<void> deleteCourse(String courseId) async {
    return AppLog.guard(_tag, '删除课程', () async {
      await _db.deleteCourse(courseId);
      courses.value = _db.getCourses();
      _bumpCourseDataVersion();
      _notifyCoursesChanged();
    });
  }

  Future<void> updateScheduleConfig(ScheduleConfig config) async {
    return AppLog.guard(_tag, '保存课表设置', () async {
      final previous = _db
          .getAllSchedules()
          .where((s) => s.id == config.id)
          .firstOrNull;
      final semesterMetadataChanged =
          previous == null ||
          identical(previous, config) ||
          previous.semesterName != config.semesterName ||
          previous.academicYearCode != config.academicYearCode ||
          previous.termName != config.termName;

      await _db.saveScheduleConfig(config);
      allSchedules.value = _db.getAllSchedules();
      if (config.id == _db.getCurrentScheduleId()) {
        scheduleConfig.value = config;
        // 非当前课表不影响当前课程展示，也无需刷新桌面组件。
        _notifyCoursesChanged();
      }
      if (semesterMetadataChanged) {
        _bumpCourseDataVersion();
      }
    });
  }

  /// 替换指定课表的所有课程（先删后插）。用于「更新课表」场景。
  Future<void> replaceScheduleCourses(
    String scheduleId,
    List<Course> newCourses,
  ) async {
    return AppLog.guard(_tag, '替换课表课程', () async {
      await _db.replaceScheduleCourses(scheduleId, newCourses);
      if (scheduleId == _db.getCurrentScheduleId()) {
        courses.value = _db.getCourses();
      }
      _bumpCourseDataVersion();
      _notifyCoursesChanged();
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
    return AppLog.guard(_tag, '清空课表', () async {
      await _db.clearAllCourseData();
      await _loadData();
      _bumpCourseDataVersion();
    });
  }
}
