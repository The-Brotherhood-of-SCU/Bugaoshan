import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/providers/export_schedule_provider.dart';
import 'package:bugaoshan/services/database_service.dart';
import 'package:flutter_test/flutter_test.dart';

/// 仿 test/course_display_settings_test.dart 的 mock 套路：
/// implements + noSuchMethod 兜底，只显式覆盖用到的读接口。
class _FakeDatabaseService implements DatabaseService {
  final ScheduleConfig current;
  final List<Course> currentCourses;

  _FakeDatabaseService({required this.current, this.currentCourses = const []});

  @override
  List<ScheduleConfig> getAllSchedules() => [current];

  @override
  ScheduleConfig? getScheduleConfig() => current;

  @override
  List<Course> getCourses({String? scheduleId}) => currentCourses;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Course _course(String name) => Course(
  name: name,
  teacher: '老师',
  location: '一教101',
  startWeek: 1,
  endWeek: 16,
  dayOfWeek: 1,
  startSection: 1,
  endSection: 2,
  colorValue: 0xFF2196F3,
);

ScheduleConfig _config(String id, String name) => ScheduleConfig(
  id: id,
  semesterName: name,
  semesterStartDate: DateTime(2026, 9, 1),
  totalWeeks: 20,
);

void main() {
  setUp(() async {
    await getIt.reset();
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('ExportScheduleProvider resolved snapshot', () {
    test('forSchedule 快照 B：resolvedConfig/resolvedCourses 全部来自 B', () {
      final configA = _config('A', '当前课表A');
      final coursesA = [_course('数学A'), _course('英语A')];
      getIt.registerSingleton<CourseProvider>(
        CourseProvider(
          _FakeDatabaseService(current: configA, currentCourses: coursesA),
        ),
      );

      final configB = _config('B', '课表B');
      final coursesB = [_course('物理B'), _course('化学B')];
      final provider = ExportScheduleProvider.forSchedule(configB, coursesB);

      expect(provider.resolvedConfig, same(configB));
      expect(provider.resolvedConfig!.id, 'B');
      // 全部来自 B：与传入的 coursesB 同一列表，且不含 A 的课程。
      expect(provider.resolvedCourses, same(coursesB));
      expect(provider.resolvedCourses.map((c) => c.name).toList(), [
        '物理B',
        '化学B',
      ]);
    });

    test('create() 的 resolvedConfig 仍是当前课表 A', () {
      final configA = _config('A', '当前课表A');
      final coursesA = [_course('数学A')];
      getIt.registerSingleton<CourseProvider>(
        CourseProvider(
          _FakeDatabaseService(current: configA, currentCourses: coursesA),
        ),
      );

      final provider = ExportScheduleProvider.create();

      expect(provider.resolvedConfig, same(configA));
      expect(provider.resolvedConfig!.id, 'A');
      expect(provider.resolvedCourses, same(coursesA));
    });
  });
}
