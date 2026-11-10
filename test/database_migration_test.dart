import 'dart:io';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/services/database_service.dart';
import 'package:bugaoshan/utils/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

const _metadata = {'key': 'currentScheduleId', 'value': 'schedule-1'};
const _schedule = {
  'id': 'schedule-1',
  'config_json': '{"id":"schedule-1","semesterName":"legacy"}',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfiNoIsolate;

  late Directory directory;
  late String path;
  Database? database;
  late AppLogger logger;

  setUp(() async {
    await getIt.reset();
    logger = AppLogger();
    getIt.registerSingleton<AppLogger>(logger);
    directory = await Directory.systemTemp.createTemp('bugaoshan-migration-');
    path = p.join(directory.path, 'legacy.db');
    database = null;
  });

  tearDown(() async {
    await database?.close();
    await directory.delete(recursive: true);
    await getIt.reset();
    logger.dispose();
  });

  test('missing required columns are added without losing data', () async {
    final course = await _createDatabaseFixture(
      path,
      version: 1,
      missingColumns: {'campus', 'custom_weeks'},
    );

    final db = await DatabaseService().openDatabaseAtPath(path);
    database = db;
    expect(await db.getVersion(), 3);
    expect(await db.query('metadata'), [_metadata]);
    expect(await db.query('schedules'), [_schedule]);
    expect(await db.query('courses'), [
      {...course, 'campus': '', 'custom_weeks': null},
    ]);
  });

  test('version zero preserves existing tables and records', () async {
    final course = await _createDatabaseFixture(
      path,
      version: 2,
      missingColumns: {'custom_weeks'},
    );
    var db = await openDatabase(path);
    database = db;
    await db.setVersion(0);
    await db.close();
    database = null;

    db = await DatabaseService().openDatabaseAtPath(path);
    database = db;
    expect(await db.getVersion(), 3);
    expect(await db.query('metadata'), [_metadata]);
    expect(await db.query('schedules'), [_schedule]);
    expect(await db.query('courses'), [
      {...course, 'custom_weeks': null},
    ]);
    expect(logger.entries, isEmpty);
  });

  test('a missing courses table preserves existing schedules', () async {
    await _createDatabaseFixture(path, version: 2);
    var db = await openDatabase(path);
    database = db;
    await db.execute('DROP TABLE courses');
    await db.close();
    database = null;

    db = await DatabaseService().openDatabaseAtPath(path);
    database = db;
    expect(await db.getVersion(), 3);
    expect(await db.query('metadata'), [_metadata]);
    expect(await db.query('schedules'), [_schedule]);
    expect(await db.query('courses'), isEmpty);
    final columns = await db.rawQuery('PRAGMA table_info(courses)');
    expect(
      columns.map((column) => column['name']),
      containsAll(['id', 'schedule_id', 'campus', 'custom_weeks']),
    );
    expect(await db.query('balance_records'), isEmpty);
    expect(logger.entries, isEmpty);
  });

  test('existing columns and values survive repeated opens', () async {
    final course = await _createDatabaseFixture(path, version: 2);

    for (var attempt = 0; attempt < 2; attempt++) {
      final db = await DatabaseService().openDatabaseAtPath(path);
      database = db;
      expect(await db.getVersion(), 3);
      expect(await db.query('courses'), [course]);
      final columns = await db.rawQuery('PRAGMA table_info(courses)');
      for (final name in ['campus', 'custom_weeks']) {
        expect(
          columns.where((column) => column['name'] == name),
          hasLength(1),
        );
      }
      await db.close();
      database = null;
    }
  });

  test('v3 to v2 to v3 preserves data and existing columns', () async {
    final course = await _createDatabaseFixture(
      path,
      version: 2,
      missingColumns: {'custom_weeks'},
    );

    var db = await DatabaseService().openDatabaseAtPath(path);
    database = db;
    await db.update('courses', {'custom_weeks': '1,3,5'});
    final expectedCourse = {...course, 'custom_weeks': '1,3,5'};
    expect(await db.getVersion(), 3);
    await db.close();
    database = null;

    // 模拟旧版：没有 onDowngrade，只回写版本号，仍保留新版字段和数据。
    db = await openDatabase(path, version: 2);
    database = db;
    expect(await db.getVersion(), 2);
    expect(await db.query('courses'), [expectedCourse]);
    await db.close();
    database = null;

    // 再次升级时不能重复加列，也不能丢失新版已保存的离散周次。
    db = await DatabaseService().openDatabaseAtPath(path);
    database = db;
    expect(await db.getVersion(), 3);
    expect(await db.query('courses'), [expectedCourse]);
    expect(await db.query('metadata'), [_metadata]);
    expect(await db.query('schedules'), [_schedule]);
  });

  test('fresh databases create the current schema and start empty', () async {
    final db = await DatabaseService().openDatabaseAtPath(path);
    database = db;

    expect(await db.getVersion(), 3);
    final timeout = await db.rawQuery('PRAGMA busy_timeout');
    expect(timeout.single.values.single, 5000);
    for (final table in ['metadata', 'schedules', 'courses', 'balance_records']) {
      expect(await db.query(table), isEmpty);
    }
    expect(logger.entries, isEmpty);
  });

  test('current versions trust the marker and leave schema untouched', () async {
    final course = await _createDatabaseFixture(
      path,
      version: 3,
      missingColumns: {'campus'},
    );
    var db = await openDatabase(path);
    database = db;
    final schema = await db.rawQuery(
      'SELECT type, name, tbl_name, sql FROM sqlite_master ORDER BY type, name',
    );
    await db.close();
    database = null;

    db = await DatabaseService().openDatabaseAtPath(path);
    database = db;
    expect(await db.getVersion(), 3);
    expect(await db.query('courses'), [course]);
    expect(
      await db.rawQuery(
        'SELECT type, name, tbl_name, sql FROM sqlite_master ORDER BY type, name',
      ),
      schema,
    );
    expect(logger.entries, isEmpty);
  });

  test('higher versions warn and stay writable without downgrading', () async {
    final course = await _createDatabaseFixture(path, version: 4);
    var db = await openDatabase(path);
    database = db;
    await db.execute('ALTER TABLE courses ADD COLUMN future_note TEXT');
    await db.update('courses', {'future_note': 'preserve-v4'});
    await db.execute('CREATE TABLE future_data (value TEXT)');
    await db.insert('future_data', {'value': 'future payload'});
    final schema = await db.rawQuery(
      'SELECT type, name, tbl_name, sql FROM sqlite_master ORDER BY type, name',
    );
    await db.close();
    database = null;

    db = await DatabaseService().openDatabaseAtPath(path);
    database = db;
    expect(await db.getVersion(), 4);
    expect(await db.query('courses'), [
      {...course, 'future_note': 'preserve-v4'},
    ]);
    expect(await db.query('future_data'), [
      {'value': 'future payload'},
    ]);
    expect(await db.query('metadata'), [_metadata]);
    expect(await db.query('schedules'), [_schedule]);
    expect(
      await db.rawQuery(
        'SELECT type, name, tbl_name, sql FROM sqlite_master ORDER BY type, name',
      ),
      schema,
    );
    expect(logger.entries, hasLength(1));
    final entry = logger.entries.single;
    expect(entry.level, LogLevel.warn);
    expect(entry.tag, 'DatabaseService');
    expect(entry.category, LogCategory.business);
    expect(entry.message, contains('当前=4'));
    expect(entry.message, contains('支持=3'));
    expect(entry.message, contains('保留现有版本和结构继续打开'));

    await db.update('courses', {'name': 'still writable'});
    expect((await db.query('courses')).single['name'], 'still writable');
    expect(await db.getVersion(), 4);
  });

  test('failed repair logs and rolls back changes', () async {
    final course = await _createDatabaseFixture(
      path,
      version: 1,
      missingColumns: {'campus', 'custom_weeks'},
    );
    var db = await openDatabase(path);
    database = db;
    // 索引创建前已补过列，验证失败时这些结构修改也会一并回滚。
    await db.execute('CREATE TABLE balance_records (legacy_value TEXT)');
    await db.insert('balance_records', {'legacy_value': 'keep balance data'});
    final schema = await db.rawQuery(
      'SELECT type, name, tbl_name, sql FROM sqlite_master ORDER BY type, name',
    );
    await db.close();
    database = null;

    await expectLater(
      DatabaseService().openDatabaseAtPath(path),
      throwsA(isA<DatabaseException>()),
    );

    final entry = logger.entries.single;
    expect(entry.level, LogLevel.error);
    expect(entry.tag, 'DatabaseService');
    expect(entry.message, '打开或修复数据库 失败');
    expect(entry.error, isNotEmpty);
    expect(entry.stackTrace, isNotEmpty);

    db = await openDatabase(path);
    database = db;
    expect(await db.getVersion(), 1);
    expect(await db.query('courses'), [course]);
    expect(await db.query('metadata'), [_metadata]);
    expect(await db.query('schedules'), [_schedule]);
    expect(await db.query('balance_records'), [
      {'legacy_value': 'keep balance data'},
    ]);
    expect(
      await db.rawQuery(
        'SELECT type, name, tbl_name, sql FROM sqlite_master ORDER BY type, name',
      ),
      schema,
    );
  });
}

Future<Map<String, Object?>> _createDatabaseFixture(
  String path, {
  required int version,
  Set<String> missingColumns = const <String>{},
}) async {
  final course = <String, Object?>{
    'id': 'course-1',
    'schedule_id': 'schedule-1',
    'name': 'Legacy course',
    'teacher': 'Teacher',
    'location': 'Room 101',
    'campus': '江安校区',
    'start_week': 1,
    'end_week': 16,
    'day_of_week': 1,
    'start_section': 1,
    'end_section': 2,
    'color_value': 0xFF2196F3,
    'week_type': 0,
    'custom_weeks': '1,3,5',
  }..removeWhere((name, _) => missingColumns.contains(name));
  final db = await openDatabase(
    path,
    version: version,
    onCreate: (db, _) async {
      await db.execute('''
        CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL)
      ''');
      await db.insert('metadata', _metadata);
      await db.execute('''
        CREATE TABLE schedules (
          id TEXT PRIMARY KEY,
          config_json TEXT NOT NULL
        )
      ''');
      await db.insert('schedules', _schedule);
      final columns = {
        'id': 'TEXT PRIMARY KEY',
        'schedule_id': 'TEXT NOT NULL',
        'name': 'TEXT',
        'teacher': 'TEXT',
        'location': 'TEXT',
        'campus': "TEXT NOT NULL DEFAULT ''",
        'start_week': 'INTEGER',
        'end_week': 'INTEGER',
        'day_of_week': 'INTEGER',
        'start_section': 'INTEGER',
        'end_section': 'INTEGER',
        'color_value': 'INTEGER',
        'week_type': 'INTEGER',
        'custom_weeks': 'TEXT',
      }..removeWhere((name, _) => missingColumns.contains(name));
      final definitions = [
        for (final column in columns.entries) '${column.key} ${column.value}',
        'FOREIGN KEY (schedule_id) REFERENCES schedules(id) ON DELETE CASCADE',
      ];
      await db.execute('CREATE TABLE courses (${definitions.join(', ')})');
      await db.insert('courses', course);
    },
  );
  await db.close();
  return course;
}
