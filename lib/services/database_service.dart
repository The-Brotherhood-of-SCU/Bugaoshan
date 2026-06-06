import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:bugaoshan/models/course.dart';

const String _keyCurrentScheduleId = 'currentScheduleId';

class DatabaseService {
  late Database _db;

  // In-memory cache to support synchronous read methods
  String _currentScheduleId = '';
  List<ScheduleConfig> _schedulesCache = [];
  List<Course> _coursesCache = [];

  bool get hasSchedule => _schedulesCache.isNotEmpty;

  Future<void> init() async {
    final dir = await getApplicationSupportDirectory();
    final dbPath = p.join(dir.path, 'bugaoshan.db');

    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE metadata (
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE schedules (
            id TEXT PRIMARY KEY,
            config_json TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE courses (
            id TEXT PRIMARY KEY,
            schedule_id TEXT NOT NULL,
            name TEXT,
            teacher TEXT,
            location TEXT,
            start_week INTEGER,
            end_week INTEGER,
            day_of_week INTEGER,
            start_section INTEGER,
            end_section INTEGER,
            color_value INTEGER,
            week_type INTEGER,
            FOREIGN KEY (schedule_id) REFERENCES schedules(id) ON DELETE CASCADE
          )
        ''');
      },
    );

    // Load current schedule ID from metadata
    final metaRows = await _db.query(
      'metadata',
      where: 'key = ?',
      whereArgs: [_keyCurrentScheduleId],
    );
    if (metaRows.isNotEmpty) {
      _currentScheduleId = metaRows.first['value'] as String;
    }

    // 不再自动创建默认课表。新安装的 schedules 表为空，
    // _currentScheduleId 保持 '' 直到用户切换到一个真实课表。
    // 老用户：schedules 表非空，上面加载的 _currentScheduleId 继续生效。

    // Load caches
    await _loadSchedulesCache();
    await _loadCoursesCache();
  }

  // ==================== Cache Helpers ====================

  Future<void> _loadSchedulesCache() async {
    final rows = await _db.query('schedules');
    _schedulesCache = rows.map((row) {
      return ScheduleConfig.fromJson(_decodeJson(row['config_json'] as String));
    }).toList();
  }

  Future<void> _loadCoursesCache() async {
    final rows = await _db.query(
      'courses',
      where: 'schedule_id = ?',
      whereArgs: [_currentScheduleId],
    );
    _coursesCache = rows.map(_rowToCourse).toList();
  }

  Map<String, dynamic> _courseToRow(Course course, String scheduleId) => {
    'id': course.id,
    'schedule_id': scheduleId,
    'name': course.name,
    'teacher': course.teacher,
    'location': course.location,
    'start_week': course.startWeek,
    'end_week': course.endWeek,
    'day_of_week': course.dayOfWeek,
    'start_section': course.startSection,
    'end_section': course.endSection,
    'color_value': course.colorValue,
    'week_type': course.weekType.index,
  };

  Course _rowToCourse(Map<String, dynamic> row) {
    final weekTypeIndex = row['week_type'] as int? ?? 0;
    return Course(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      teacher: row['teacher'] as String? ?? '',
      location: row['location'] as String? ?? '',
      startWeek: row['start_week'] as int,
      endWeek: row['end_week'] as int,
      dayOfWeek: row['day_of_week'] as int,
      startSection: row['start_section'] as int,
      endSection: row['end_section'] as int,
      colorValue: row['color_value'] as int,
      weekType: weekTypeIndex < WeekType.values.length
          ? WeekType.values[weekTypeIndex]
          : WeekType.every,
    );
  }

  // ==================== Schedule Management ====================

  String getCurrentScheduleId() => _currentScheduleId;

  Future<void> switchSchedule(String scheduleId) async {
    // 未知 id 早返回，避免把空 '' 写进 metadata 并触发 courses 缓存重载。
    if (_schedulesCache.indexWhere((s) => s.id == scheduleId) < 0) {
      debugPrint('DatabaseService.switchSchedule: unknown id $scheduleId');
      return;
    }
    _currentScheduleId = scheduleId;
    await _db.insert('metadata', {
      'key': _keyCurrentScheduleId,
      'value': scheduleId,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
    await _loadCoursesCache();
  }

  List<ScheduleConfig> getAllSchedules() => List.unmodifiable(_schedulesCache);

  ScheduleConfig getScheduleConfig() {
    if (_schedulesCache.isEmpty) return _placeholderScheduleConfig();
    return _schedulesCache.firstWhere(
      (s) => s.id == _currentScheduleId,
      orElse: () => _schedulesCache.first,
    );
  }

  Future<void> saveScheduleConfig(ScheduleConfig config) async {
    final existing = await _db.query(
      'schedules',
      where: 'id = ?',
      whereArgs: [config.id],
    );
    final json = _encodeJson(config.toJson());
    if (existing.isNotEmpty) {
      await _db.update(
        'schedules',
        {'config_json': json},
        where: 'id = ?',
        whereArgs: [config.id],
      );
    } else {
      await _db.insert('schedules', {'id': config.id, 'config_json': json});
    }
    await _loadSchedulesCache();
  }

  Future<void> addSchedule(ScheduleConfig config) async {
    await _db.insert('schedules', {
      'id': config.id,
      'config_json': _encodeJson(config.toJson()),
    });
    await _loadSchedulesCache();
  }

  Future<void> deleteSchedule(String scheduleId) async {
    await _db.transaction((txn) async {
      await txn.delete(
        'courses',
        where: 'schedule_id = ?',
        whereArgs: [scheduleId],
      );
      await txn.delete('schedules', where: 'id = ?', whereArgs: [scheduleId]);
    });

    await _loadSchedulesCache();

    // 如果删的是当前课表：剩余 → 切到第一个；不剩 → 清空 currentScheduleId
    if (_currentScheduleId == scheduleId) {
      if (_schedulesCache.isNotEmpty) {
        await switchSchedule(_schedulesCache.first.id);
      } else {
        _currentScheduleId = '';
        await _db.insert('metadata', {
          'key': _keyCurrentScheduleId,
          'value': '',
        }, conflictAlgorithm: ConflictAlgorithm.replace);
        await _loadCoursesCache();
      }
    }
  }

  // ==================== Courses ====================

  List<Course> getCourses({String? scheduleId}) {
    if (scheduleId != null && scheduleId != _currentScheduleId) {
      // For cross-schedule reads, query directly (synchronous fallback)
      // In practice, getCoursesAsync should be used for cross-schedule
      return [];
    }
    return List.unmodifiable(_coursesCache);
  }

  Future<void> addCourse(Course course) async {
    if (_currentScheduleId.isEmpty) {
      debugPrint('DatabaseService.addCourse: no current schedule');
      return;
    }
    await _db.insert('courses', _courseToRow(course, _currentScheduleId));
    await _loadCoursesCache();
  }

  Future<void> updateCourse(Course course) async {
    if (_currentScheduleId.isEmpty) {
      debugPrint('DatabaseService.updateCourse: no current schedule');
      return;
    }
    await _db.update(
      'courses',
      _courseToRow(course, _currentScheduleId),
      where: 'id = ?',
      whereArgs: [course.id],
    );
    await _loadCoursesCache();
  }

  Future<void> deleteCourse(String courseId) async {
    await _db.delete('courses', where: 'id = ?', whereArgs: [courseId]);
    await _loadCoursesCache();
  }

  Future<List<Course>> getCoursesAsync({String? scheduleId}) async {
    final sid = scheduleId ?? _currentScheduleId;
    final rows = await _db.query(
      'courses',
      where: 'schedule_id = ?',
      whereArgs: [sid],
    );
    return rows.map(_rowToCourse).toList();
  }

  Future<bool> hasConflict(Course course, {String? excludeId}) async {
    return _coursesCache.any(
      (c) => c.conflictsWith(course, excludeId: excludeId),
    );
  }

  // ==================== Clear ====================

  Future<void> clearAllCourseData() async {
    await _db.transaction((txn) async {
      await txn.delete('courses');
      await txn.delete('schedules');
      await txn.delete('metadata');
    });
    _currentScheduleId = '';
    _schedulesCache = [];
    _coursesCache = [];
  }

  // ==================== Helpers ====================

  /// 占位用 ScheduleConfig，仅在 _schedulesCache 为空时返回，
  /// 用于周次/总周数等算术保护，**不会**被持久化。
  ScheduleConfig _placeholderScheduleConfig() {
    final now = DateTime.now();
    return ScheduleConfig(
      id: '',
      semesterName: '',
      semesterStartDate: now.toMonday(),
      totalWeeks: 20,
    );
  }

  Map<String, dynamic> _decodeJson(String str) =>
      Map<String, dynamic>.from(json.decode(str) as Map);

  String _encodeJson(Map<String, dynamic> map) => json.encode(map);
}
