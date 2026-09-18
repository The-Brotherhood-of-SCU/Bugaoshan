import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('Course.duplicate', () {
    test('生成全新 id，并保留除名称外的全部字段', () {
      final original = _course();
      final copy = original.duplicate(nameSuffix: ' (副本)');

      expect(copy.id, isNotEmpty);
      expect(copy.id, isNot(original.id));
      expect(copy.name, '${original.name} (副本)');
      expect(copy.teacher, original.teacher);
      expect(copy.location, original.location);
      expect(copy.campus, original.campus);
      expect(copy.startWeek, original.startWeek);
      expect(copy.endWeek, original.endWeek);
      expect(copy.dayOfWeek, original.dayOfWeek);
      expect(copy.startSection, original.startSection);
      expect(copy.endSection, original.endSection);
      expect(copy.colorValue, original.colorValue);
      expect(copy.weekType, original.weekType);
    });

    test('不传后缀时名称保持不变', () {
      final original = _course();

      expect(original.duplicate().name, original.name);
    });

    test('copyWith 不传 id 时沿用原 id，因此复制必须另生成 id', () {
      final original = _course();

      expect(original.copyWith().id, original.id);
      expect(original.duplicate().id, isNot(original.id));
    });
  });

  group('复制课程落库', () {
    test('副本按新增写入，课程总数 +1 且原课程不被覆盖', () async {
      final harness = await _openService();
      addTearDown(harness.dispose);
      final service = harness.service;
      final original = _course();
      await service.addCourse(original);

      await service.addCourse(original.duplicate(nameSuffix: ' (副本)'));

      final courses = await service.getCoursesAsync();
      expect(courses.length, 2, reason: '复制应产生一门新课程');
      final preserved = courses.singleWhere(
        (course) => course.id == original.id,
      );
      expect(preserved.name, original.name, reason: '原课程不应被改名');
      final copy = courses.singleWhere((course) => course.id != original.id);
      expect(copy.name, '${original.name} (副本)');
      expect(copy.campus, original.campus);
      expect(copy.startSection, original.startSection);
    });
  });
}

Course _course() => Course(
  id: 'course-original',
  name: '高等数学',
  teacher: '张三',
  location: '江安一教 A101',
  campus: '江安校区',
  startWeek: 1,
  endWeek: 16,
  dayOfWeek: 1,
  startSection: 1,
  endSection: 2,
  colorValue: 0xFF2196F3,
);

/// 打开一个内存数据库，并把 [DatabaseService] 切到其中的课表 S1。
Future<_ServiceHarness> _openService() async {
  final db = await openDatabase(inMemoryDatabasePath, version: 1);
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
      campus TEXT NOT NULL DEFAULT '',
      start_week INTEGER,
      end_week INTEGER,
      day_of_week INTEGER,
      start_section INTEGER,
      end_section INTEGER,
      color_value INTEGER,
      week_type INTEGER
    )
  ''');

  final service = DatabaseService.forTesting(db);
  final config = ScheduleConfig(
    id: 'S1',
    semesterName: '测试课表',
    semesterStartDate: DateTime(2026, 9, 1),
  );
  await service.addSchedule(config);
  await service.switchSchedule(config.id);

  return _ServiceHarness(db, service);
}

class _ServiceHarness {
  const _ServiceHarness(this.db, this.service);

  final Database db;
  final DatabaseService service;

  Future<void> dispose() => db.close();
}
