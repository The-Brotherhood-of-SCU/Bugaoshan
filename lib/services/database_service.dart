import 'dart:convert';
import 'dart:io';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart';
import 'package:bugaoshan/models/course.dart';

const String _keyCurrentScheduleId = 'currentScheduleId';

class DatabaseService {
  late Database _db;

  // In-memory cache to keep synchronous getters working
  String _currentScheduleId = 'default';
  List<ScheduleConfig> _schedules = [];
  final Map<String, Course> _coursesCache = {}; // ID to Course mapping for the current schedule

  Future<void> init() async {
    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }

    final databasesPath = await getDatabasesPath();
    final path = join(databasesPath, 'bugaoshan.db');

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE metadata (
            key TEXT PRIMARY KEY,
            value TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE schedules (
            id TEXT PRIMARY KEY,
            data_json TEXT
          )
        ''');
        await db.execute('''
          CREATE TABLE courses (
            id TEXT PRIMARY KEY,
            schedule_id TEXT,
            data_json TEXT
          )
        ''');
      },
    );

    // Initialize Metadata
    final metaResult = await _db.query('metadata', where: 'key = ?', whereArgs: [_keyCurrentScheduleId]);
    if (metaResult.isNotEmpty) {
      _currentScheduleId = metaResult.first['value'] as String;
    } else {
      await _db.insert('metadata', {'key': _keyCurrentScheduleId, 'value': 'default'});
      _currentScheduleId = 'default';
    }

    // Load Schedules
    final schedulesResult = await _db.query('schedules');
    if (schedulesResult.isNotEmpty) {
      _schedules = schedulesResult.map((e) => ScheduleConfig.fromJson(_decodeJson(e['data_json'] as String))).toList();
    } else {
      // Create default
      final defaultConfig = _defaultScheduleConfig();
      _schedules = [defaultConfig];
      await _db.insert('schedules', {'id': defaultConfig.id, 'data_json': _encodeJson(defaultConfig.toJson())});
    }

    // Load Courses for current schedule
    await _loadCoursesCache(_currentScheduleId);
  }

  Future<void> _loadCoursesCache(String scheduleId) async {
    _coursesCache.clear();
    final coursesResult = await _db.query('courses', where: 'schedule_id = ?', whereArgs: [scheduleId]);
    for (var row in coursesResult) {
      final course = Course.fromJson(_decodeJson(row['data_json'] as String));
      _coursesCache[course.id] = course;
    }
  }

  // ==================== Schedules Management ====================

  String getCurrentScheduleId() {
    return _currentScheduleId;
  }

  Future<void> switchSchedule(String scheduleId) async {
    _currentScheduleId = scheduleId;
    await _db.update('metadata', {'value': scheduleId}, where: 'key = ?', whereArgs: [_keyCurrentScheduleId]);
    await _loadCoursesCache(scheduleId);
  }

  List<ScheduleConfig> getAllSchedules() {
    return List.unmodifiable(_schedules);
  }

  ScheduleConfig getScheduleConfig() {
    return _schedules.firstWhere(
      (s) => s.id == _currentScheduleId,
      orElse: () => _schedules.first,
    );
  }

  Future<void> saveScheduleConfig(ScheduleConfig config) async {
    final index = _schedules.indexWhere((s) => s.id == config.id);
    if (index >= 0) {
      _schedules[index] = config;
      await _db.update('schedules', {'data_json': _encodeJson(config.toJson())}, where: 'id = ?', whereArgs: [config.id]);
    } else {
      _schedules.add(config);
      await _db.insert('schedules', {'id': config.id, 'data_json': _encodeJson(config.toJson())});
    }
  }

  Future<void> addSchedule(ScheduleConfig config) async {
    await saveScheduleConfig(config);
  }

  Future<void> deleteSchedule(String scheduleId) async {
    _schedules.removeWhere((s) => s.id == scheduleId);
    await _db.delete('schedules', where: 'id = ?', whereArgs: [scheduleId]);
    await _db.delete('courses', where: 'schedule_id = ?', whereArgs: [scheduleId]);

    // If we deleted the current one, switch to the first available
    if (_currentScheduleId == scheduleId && _schedules.isNotEmpty) {
      await switchSchedule(_schedules.first.id);
    }
  }

  // ==================== Courses ====================

  List<Course> getCourses({String? scheduleId}) {
    // Synchronous call requires cache. We only cache the current schedule.
    if (scheduleId == null || scheduleId == _currentScheduleId) {
      return _coursesCache.values.toList();
    }
    // If they asked for a different schedule synchronously, we can't fetch it instantly.
    // In practice, this codebase only fetches the current one synchronously.
    return [];
  }

  Future<void> addCourse(Course course) async {
    _coursesCache[course.id] = course;
    await _db.insert('courses', {'id': course.id, 'schedule_id': _currentScheduleId, 'data_json': _encodeJson(course.toJson())});
  }

  Future<void> updateCourse(Course course) async {
    _coursesCache[course.id] = course;
    await _db.update('courses', {'data_json': _encodeJson(course.toJson())}, where: 'id = ?', whereArgs: [course.id]);
  }

  Future<void> deleteCourse(String courseId) async {
    _coursesCache.remove(courseId);
    await _db.delete('courses', where: 'id = ?', whereArgs: [courseId]);
  }

  Future<List<Course>> getCoursesAsync({String? scheduleId}) async {
    if (scheduleId == null || scheduleId == _currentScheduleId) {
      return _coursesCache.values.toList();
    }

    final coursesResult = await _db.query('courses', where: 'schedule_id = ?', whereArgs: [scheduleId]);
    return coursesResult.map((row) => Course.fromJson(_decodeJson(row['data_json'] as String))).toList();
  }

  Future<bool> hasConflict(Course course, {String? excludeId}) async {
    return getCourses().any(
      (c) => c.conflictsWith(course, excludeId: excludeId),
    );
  }

  // ==================== Clear All ====================

  Future<void> clearAllCourseData() async {
    _coursesCache.clear();
    await _db.delete('courses', where: 'schedule_id = ?', whereArgs: [_currentScheduleId]);
  }

  // ==================== Helpers ====================

  ScheduleConfig _defaultScheduleConfig() {
    final now = DateTime.now();
    return ScheduleConfig(
      id: 'default',
      semesterName: '默认课表',
      semesterStartDate: now.toMonday(),
      totalWeeks: 20,
    );
  }

  Map<String, dynamic> _decodeJson(String str) =>
      Map<String, dynamic>.from(json.decode(str) as Map);

  String _encodeJson(Map<String, dynamic> map) => json.encode(map);
}