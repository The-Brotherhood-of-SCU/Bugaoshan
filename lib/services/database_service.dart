import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hive_ce/hive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'package:bugaoshan/models/course.dart';

const String _keyCurrentScheduleId = 'currentScheduleId';
const String _keySchedules = 'schedules';
const String _keyScheduleConfig = 'scheduleConfig'; // Legacy Hive key

class DatabaseService {
  late Database _db;

  // In-memory cache to support synchronous read methods
  String _currentScheduleId = 'default';
  List<ScheduleConfig> _schedulesCache = [];
  List<Course> _coursesCache = [];

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

    // Try migrating from Hive if old data exists
    await _migrateFromHiveIfNeeded(dir.path);

    // Load current schedule ID from metadata
    final metaRows = await _db.query(
      'metadata',
      where: 'key = ?',
      whereArgs: [_keyCurrentScheduleId],
    );
    if (metaRows.isNotEmpty) {
      _currentScheduleId = metaRows.first['value'] as String;
    }

    // Ensure a default schedule exists
    final scheduleRows = await _db.query('schedules');
    if (scheduleRows.isEmpty) {
      final defaultConfig = _defaultScheduleConfig();
      await _db.insert('schedules', {
        'id': defaultConfig.id,
        'config_json': _encodeJson(defaultConfig.toJson()),
      });
      await _db.insert('metadata', {
        'key': _keyCurrentScheduleId,
        'value': 'default',
      });
    }

    // Load caches
    await _loadSchedulesCache();
    await _loadCoursesCache();
  }

  // ==================== Hive Migration ====================

  Future<void> _migrateFromHiveIfNeeded(String appDirPath) async {
    // Check if Hive metadata box file exists
    final hiveMetaFile = File(p.join(appDirPath, 'metadata.hive'));
    if (!hiveMetaFile.existsSync()) return;

    // Check if SQLite already has data (don't re-migrate)
    final existingSchedules = await _db.query('schedules');
    if (existingSchedules.isNotEmpty) return;

    debugPrint('Migrating data from Hive to SQLite...');

    try {
      Hive.init(appDirPath);

      // Open metadata box
      await Hive.openBox('metadata');
      final metadataBox = Hive.box('metadata');

      // Read schedules list
      final schedulesRaw = metadataBox.get(_keySchedules) as List<dynamic>?;
      final currentId = metadataBox.get(_keyCurrentScheduleId) as String? ??
          'default';

      List<ScheduleConfig> schedules = [];
      if (schedulesRaw != null) {
        for (final item in schedulesRaw) {
          try {
            final map = Map<String, dynamic>.from(
              json.decode(item as String) as Map,
            );
            schedules.add(ScheduleConfig.fromJson(map));
          } catch (_) {}
        }
      }

      // If no schedules found, try legacy single-schedule format
      if (schedules.isEmpty) {
        final legacyJson = metadataBox.get(_keyScheduleConfig) as String?;
        if (legacyJson != null && legacyJson.isNotEmpty) {
          try {
            final config = ScheduleConfig.fromJson(
              Map<String, dynamic>.from(json.decode(legacyJson) as Map),
            );
            config.id = 'default';
            if (config.semesterName.isEmpty) {
              config.semesterName = '默认课表';
            }
            schedules.add(config);
          } catch (_) {
            schedules.add(_defaultScheduleConfig());
          }
        } else {
          schedules.add(_defaultScheduleConfig());
        }
      }

      // Insert schedules into SQLite
      for (final s in schedules) {
        await _db.insert('schedules', {
          'id': s.id,
          'config_json': _encodeJson(s.toJson()),
        });
      }

      // Insert current schedule ID
      await _db.insert('metadata', {
        'key': _keyCurrentScheduleId,
        'value': currentId,
      });

      // Migrate courses from each Hive box
      for (final s in schedules) {
        final boxName = s.id == 'default' ? 'courses' : 'courses_${s.id}';
        try {
          await Hive.openBox(boxName);
          final box = Hive.box(boxName);
          for (final value in box.values) {
            if (value is Map) {
              final courseMap = Map<String, dynamic>.from(value);
              final course = Course.fromJson(courseMap);
              await _db.insert('courses', _courseToRow(course, s.id));
            }
          }
          await box.close();
        } catch (e) {
          debugPrint('Failed to migrate courses for schedule ${s.id}: $e');
        }
      }

      await metadataBox.close();

      // Delete old Hive files
      _deleteHiveFiles(appDirPath);

      debugPrint('Hive migration completed successfully.');
    } catch (e) {
      debugPrint('Hive migration failed: $e');
    }
  }

  void _deleteHiveFiles(String dirPath) {
    try {
      final dir = Directory(dirPath);
      for (final file in dir.listSync()) {
        if (file is File) {
          final name = p.basename(file.path);
          if (name.endsWith('.hive') ||
              name.endsWith('.lock') ||
              name.endsWith('.hive.crc')) {
            file.deleteSync();
          }
        }
      }
    } catch (e) {
      debugPrint('Failed to delete Hive files: $e');
    }
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
    return Course(
      id: row['id'] as String,
      name: row['name'] as String,
      teacher: row['teacher'] as String,
      location: row['location'] as String,
      startWeek: row['start_week'] as int,
      endWeek: row['end_week'] as int,
      dayOfWeek: row['day_of_week'] as int,
      startSection: row['start_section'] as int,
      endSection: row['end_section'] as int,
      colorValue: row['color_value'] as int,
      weekType: WeekType.values[row['week_type'] as int],
    );
  }

  // ==================== Schedule Management ====================

  String getCurrentScheduleId() => _currentScheduleId;

  Future<void> switchSchedule(String scheduleId) async {
    _currentScheduleId = scheduleId;
    await _db.update(
      'metadata',
      {'value': scheduleId},
      where: 'key = ?',
      whereArgs: [_keyCurrentScheduleId],
    );
    await _loadCoursesCache();
  }

  List<ScheduleConfig> getAllSchedules() => List.unmodifiable(_schedulesCache);

  ScheduleConfig getScheduleConfig() {
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
      await _db.insert('schedules', {
        'id': config.id,
        'config_json': json,
      });
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
    // Delete courses for this schedule
    await _db.delete(
      'courses',
      where: 'schedule_id = ?',
      whereArgs: [scheduleId],
    );
    // Delete schedule config
    await _db.delete(
      'schedules',
      where: 'id = ?',
      whereArgs: [scheduleId],
    );

    await _loadSchedulesCache();

    // If we deleted the current one, switch to the first available
    if (_currentScheduleId == scheduleId && _schedulesCache.isNotEmpty) {
      await switchSchedule(_schedulesCache.first.id);
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
    await _db.insert('courses', _courseToRow(course, _currentScheduleId));
    await _loadCoursesCache();
  }

  Future<void> updateCourse(Course course) async {
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
    await _db.delete('courses');
    await _db.delete('schedules');
    await _db.delete('metadata');

    // Re-create default schedule
    final defaultConfig = _defaultScheduleConfig();
    await _db.insert('schedules', {
      'id': defaultConfig.id,
      'config_json': _encodeJson(defaultConfig.toJson()),
    });
    await _db.insert('metadata', {
      'key': _keyCurrentScheduleId,
      'value': 'default',
    });
    _currentScheduleId = 'default';

    await _loadSchedulesCache();
    await _loadCoursesCache();
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
