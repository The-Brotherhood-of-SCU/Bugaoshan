import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_app_group_directory/flutter_app_group_directory.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:bugaoshan/utils/app_log.dart';

import 'package:sqflite/sqflite.dart';
import 'package:bugaoshan/models/balance_record.dart';
import 'package:bugaoshan/models/course.dart';

const String _keyCurrentScheduleId = 'currentScheduleId';

class DatabaseService {
  static const String _tag = 'DatabaseService';
  static const int _schemaVersion = 3;

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

  /// 按实际表结构补齐当前所需字段，不依赖旧版本号推断字段是否存在。
  ///
  /// 基础表由 [_createSchema] 先幂等创建，此处只添加缺失列，保留已有数据。
  static Future<void> _ensureCourseColumns(DatabaseExecutor db) async {
    const definitions = {
      // v2: courses 增加 campus 列（教务处 campusName 字段）
      'campus': "TEXT NOT NULL DEFAULT ''",
      // v3: courses 增加 custom_weeks 列（支持离散周次）
      'custom_weeks': 'TEXT',
    };
    final rows = await db.rawQuery('PRAGMA table_info(courses)');
    final existing = rows.map((row) => row['name']).toSet();
    for (final column in definitions.entries) {
      if (!existing.contains(column.key)) {
        await db.execute(
          'ALTER TABLE courses ADD COLUMN ${column.key} ${column.value}',
        );
      }
    }
  }

  /// 版本不低于当前支持版本时信任已有结构，更高版本同时记录告警。
  static bool _canSkipSchemaRepair(int version) {
    if (version < _schemaVersion) return false;
    if (version > _schemaVersion) {
      AppLog.w(
        _tag,
        '数据库版本高于当前程序支持的版本：当前=$version，支持=$_schemaVersion；'
        '保留现有版本和结构继续打开',
      );
    }
    return true;
  }

  /// 打开数据库，仅对版本低于3的旧库检查并修复结构。
  ///
  /// 版本3及以上视为已具备当前结构，跳过补列、补表和迁移事务。
  /// 不向 sqflite 传 version，避免它回写更低的版本号。
  /// 打开或修复失败时记录原始异常和堆栈，并继续向上传播。
  Future<Database> openDatabaseAtPath(String path) {
    return AppLog.guard<Database>(
      _tag,
      '打开或修复数据库',
      () => openDatabase(
        path,
        onConfigure: (db) async {
          // 为 Widget 等并发连接产生的短时锁冲突预留5秒等待。
          await db.rawQuery('PRAGMA busy_timeout = 5000');
        },
        onOpen: (db) async {
          final version = await db.getVersion();
          if (_canSkipSchemaRepair(version)) return;

          await db.transaction((txn) async {
            // 加锁后重新读取，避免其他进程已升级数据库仍按旧版本执行修复。
            final rows = await txn.rawQuery('PRAGMA user_version');
            final currentVersion = rows.single['user_version'] as int;
            if (_canSkipSchemaRepair(currentVersion)) return;

            // 旧库可能保留了表却丢失版本号，也可能只缺少部分基础表。
            await _createSchema(txn);
            await _ensureCourseColumns(txn);
            await _createBalanceRecordsTable(txn);
            await txn.execute('PRAGMA user_version = $_schemaVersion');
          }, exclusive: true);
        },
      ),
    );
  }

  Future<void> _createSchema(DatabaseExecutor db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS metadata (
        key TEXT PRIMARY KEY,
        value TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS schedules (
        id TEXT PRIMARY KEY,
        config_json TEXT NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS courses (
        id TEXT PRIMARY KEY,
        schedule_id TEXT NOT NULL,
        name TEXT,
        teacher TEXT,
        location TEXT,
        campus TEXT NOT NULL DEFAULT '',
        start_week INTEGER,
        end_week INTEGER,
        day_of_week INTEGER,
        start_section INTEGER,
        end_section INTEGER,
        color_value INTEGER,
        week_type INTEGER,
        custom_weeks TEXT,
        FOREIGN KEY (schedule_id) REFERENCES schedules(id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> init() async {
    debugPrint('BugaoShan Database: Initializing database...');

    Directory dir;
    // iOS 与 macOS 使用 App Group 共享目录，让 Widget Extension 也能访问数据库。
    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      const appGroupId = 'group.io.github.thebrotherhoodofscu.bugaoshan.ios';
      try {
        final appGroupDir = await FlutterAppGroupDirectory.getAppGroupDirectory(
          appGroupId,
        );
        if (appGroupDir != null) {
          dir = appGroupDir;
          debugPrint(
            'BugaoShan Database: Using App Group directory: ${appGroupDir.path}',
          );
        } else {
          debugPrint(
            'BugaoShan Database: App Group directory is null, using application support directory',
          );
          dir = await getApplicationSupportDirectory();
        }
      } catch (e, logStackTrace) {
        AppLog.e(_tag, 'init 失败', error: e, stackTrace: logStackTrace);

        dir = await getApplicationSupportDirectory();
      }
    } else {
      dir = await getApplicationSupportDirectory();
    }
    final dbPath = p.join(dir.path, 'bugaoshan.db');
    debugPrint('BugaoShan Database: Database path: $dbPath');

    // iOS 与 macOS 检查是否需要从旧位置迁移数据库到 App Group。
    if (!kIsWeb && (Platform.isIOS || Platform.isMacOS)) {
      try {
        final oldDir = await getApplicationSupportDirectory();
        final oldDbPath = p.join(oldDir.path, 'bugaoshan.db');
        final oldFile = File(oldDbPath);
        final newFile = File(dbPath);

        if (await oldFile.exists() && !await newFile.exists()) {
          debugPrint(
            'BugaoShan Database: Migrating database from old location to App Group directory...',
          );
          await oldFile.copy(dbPath);
          debugPrint(
            'BugaoShan Database: Database migrated successfully to new location',
          );
        } else if (!await oldFile.exists() && !await newFile.exists()) {
          debugPrint(
            'BugaoShan Database: No existing database found at either location, will create new one',
          );
        } else if (await newFile.exists()) {
          debugPrint(
            'BugaoShan Database: Database already exists at App Group directory',
          );
        }
      } catch (e, logStackTrace) {
        AppLog.e(_tag, 'init 失败', error: e, stackTrace: logStackTrace);
      }
    }

    _db = await openDatabaseAtPath(dbPath);

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
    'campus': course.campus,
    'start_week': course.startWeek,
    'end_week': course.endWeek,
    'day_of_week': course.dayOfWeek,
    'start_section': course.startSection,
    'end_section': course.endSection,
    'color_value': course.colorValue,
    'week_type': course.weekType.index,
    'custom_weeks':
        (course.customWeeks != null && course.customWeeks!.isNotEmpty)
        ? (course.customWeeks!.where((w) => w >= 1).toSet().toList()..sort())
              .join(',')
        : null,
  };

  Course _rowToCourse(Map<String, dynamic> row) {
    final weekTypeIndex = row['week_type'] as int? ?? 0;
    // 与 Course.fromJson 共用同一套解析与边界归一，避免两处口径漂移。
    final customWeeks = Course.parseCustomWeeks(row['custom_weeks']);
    return Course(
      id: row['id'] as String,
      name: row['name'] as String? ?? '',
      teacher: row['teacher'] as String? ?? '',
      location: row['location'] as String? ?? '',
      campus: row['campus'] as String? ?? '',
      // 离散周是权威：起止周收敛到其 min/max（见 Course.fromJson 注释）。
      startWeek: customWeeks?.first ?? row['start_week'] as int,
      endWeek: customWeeks?.last ?? row['end_week'] as int,
      dayOfWeek: row['day_of_week'] as int,
      startSection: row['start_section'] as int,
      endSection: row['end_section'] as int,
      colorValue: row['color_value'] as int,
      weekType: weekTypeIndex < WeekType.values.length
          ? WeekType.values[weekTypeIndex]
          : WeekType.every,
      customWeeks: customWeeks,
    );
  }

  // ==================== Schedule Management ====================

  String getCurrentScheduleId() => _currentScheduleId;

  Future<void> switchSchedule(String scheduleId) async {
    // 未知 id 早返回，避免把空 '' 写进 metadata 并触发 courses 缓存重载。
    if (_schedulesCache.indexWhere((s) => s.id == scheduleId) < 0) {
      AppLog.e(_tag, '切换课表失败：课表不存在 id=$scheduleId');
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

  ScheduleConfig? getScheduleConfig() {
    if (_schedulesCache.isEmpty) return null;
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
      AppLog.e(_tag, '新增课程失败：未选择课表');
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
      AppLog.e(_tag, '修改课程失败：未选择课表');
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
