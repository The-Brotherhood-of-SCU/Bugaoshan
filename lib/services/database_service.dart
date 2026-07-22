import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:app_group_directory/app_group_directory.dart';
import 'package:sqflite/sqflite.dart';
import 'package:bugaoshan/models/balance_record.dart';
import 'package:bugaoshan/models/course.dart';

const String _keyCurrentScheduleId = 'currentScheduleId';

class DatabaseService {
  late Database _db;

  // In-memory cache to support synchronous read methods
  String _currentScheduleId = '';
  List<ScheduleConfig> _schedulesCache = [];
  List<Course> _coursesCache = [];

  bool get hasSchedule => _schedulesCache.isNotEmpty;

  DatabaseService();

  /// 测试用:跳过 [init] 中的路径解析与磁盘 IO,直接注入已初始化的 [Database]。
  /// 自动创建 `balance_records` 表;其余表(courses/schedules/metadata)按需自建。
  @visibleForTesting
  DatabaseService.forTesting(Database db) : _db = db;

  /// 测试用:确保 balance_records 表存在(供 [forTesting] 后调用)。
  @visibleForTesting
  Future<void> ensureBalanceRecordsTableForTesting() async {
    await _createBalanceRecordsTable(_db);
  }

  Future<void> init() async {
    debugPrint('BugaoShan Database: Initializing database...');
    
    Directory dir;
    // iOS/macOS 使用 App Group 共享目录，让 Widget Extension 也能访问数据库
    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      const appGroupId = 'group.io.github.the-brotherhood-of-scu.bugaoshan';
      try {
        final appGroupDir = await AppGroupDirectory.getAppGroupDirectory(appGroupId);
        if (appGroupDir != null) {
          dir = appGroupDir;
          debugPrint('BugaoShan Database: Using App Group directory: ${appGroupDir.path}');
        } else {
          debugPrint('BugaoShan Database: App Group directory is null, using application support directory');
          dir = await getApplicationSupportDirectory();
        }
      } catch (e) {
        debugPrint('BugaoShan Database: Failed to get App Group directory: $e');
        dir = await getApplicationSupportDirectory();
      }
    } else {
      dir = await getApplicationSupportDirectory();
    }
    final dbPath = p.join(dir.path, 'bugaoshan.db');
    debugPrint('BugaoShan Database: Database path: $dbPath');
    
    // 如果在 iOS/macOS 上，检查是否需要从旧位置迁移数据库
    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      try {
        final oldDir = await getApplicationSupportDirectory();
        final oldDbPath = p.join(oldDir.path, 'bugaoshan.db');
        final oldFile = File(oldDbPath);
        final newFile = File(dbPath);
        
        if (await oldFile.exists() && !await newFile.exists()) {
          debugPrint('BugaoShan Database: Migrating database from old location to App Group directory...');
          await oldFile.copy(dbPath);
          debugPrint('BugaoShan Database: Database migrated successfully to new location');
        } else if (!await oldFile.exists() && !await newFile.exists()) {
          debugPrint('BugaoShan Database: No existing database found at either location, will create new one');
        } else if (await newFile.exists()) {
          debugPrint('BugaoShan Database: Database already exists at App Group directory');
        }
      } catch (e) {
        debugPrint('BugaoShan Database: Error during database migration: $e');
      }
    }

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
        await _createBalanceRecordsTable(db);
      },
    );

    // 老用户(db 已存在)通过此处确保新表创建
    await _ensureBalanceRecordsTable();

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

  /// 替换指定课表的所有课程（先删后插）。用于「更新课表」场景。
  Future<void> replaceScheduleCourses(
    String scheduleId,
    List<Course> courses,
  ) async {
    await _db.transaction((txn) async {
      await txn.delete(
        'courses',
        where: 'schedule_id = ?',
        whereArgs: [scheduleId],
      );
      for (final course in courses) {
        await txn.insert('courses', _courseToRow(course, scheduleId));
      }
    });
    if (_currentScheduleId == scheduleId) {
      await _loadCoursesCache();
    }
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

  // ==================== Balance Records ====================

  Future<void> _createBalanceRecordsTable(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS balance_records (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        room_key TEXT NOT NULL,
        balance_type INTEGER NOT NULL,
        timestamp INTEGER NOT NULL,
        balance REAL NOT NULL,
        price REAL NOT NULL
      )
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_balance_records_lookup
      ON balance_records(room_key, balance_type, timestamp)
    ''');
  }

  Future<void> _ensureBalanceRecordsTable() async {
    await _createBalanceRecordsTable(_db);
  }

  Future<int> insertBalanceRecord(BalanceRecord record) async {
    return await _db.insert('balance_records', record.toRow());
  }

  Future<List<BalanceRecord>> getBalanceRecords({
    required String roomKey,
    required int balanceType,
    DateTime? since,
    DateTime? until,
  }) async {
    final where = StringBuffer('room_key = ? AND balance_type = ?');
    final whereArgs = <dynamic>[roomKey, balanceType];
    if (since != null) {
      where.write(' AND timestamp >= ?');
      whereArgs.add(since.millisecondsSinceEpoch);
    }
    if (until != null) {
      where.write(' AND timestamp <= ?');
      whereArgs.add(until.millisecondsSinceEpoch);
    }
    final rows = await _db.query(
      'balance_records',
      where: where.toString(),
      whereArgs: whereArgs,
      orderBy: 'timestamp ASC',
    );
    return rows.map(BalanceRecord.fromRow).toList();
  }

  Future<int> deleteBalanceRecordsBefore(DateTime threshold) async {
    return await _db.delete(
      'balance_records',
      where: 'timestamp < ?',
      whereArgs: [threshold.millisecondsSinceEpoch],
    );
  }

  Future<int> deleteBalanceRecordsByRoom(String roomKey) async {
    return await _db.delete(
      'balance_records',
      where: 'room_key = ?',
      whereArgs: [roomKey],
    );
  }
}
