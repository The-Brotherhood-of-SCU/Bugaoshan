import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/services/database_service.dart';
import 'package:bugaoshan/services/hook_registry.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'editing a non-current schedule only refreshes the schedule list',
    () async {
      final current = _schedule(id: 'A', name: '当前课表', weeksAgo: 1);
      final other = _schedule(id: 'B', name: '其他课表', weeksAgo: 2);
      final database = _FakeDatabaseService(
        currentScheduleId: current.id,
        schedules: [current, other],
      );
      final registry = HookRegistry();
      final provider = CourseProvider(database, registry: registry);
      var coursesChangedCount = 0;
      registry.on(
        provider,
        CourseProvider.courseChanged,
        (_) => coursesChangedCount++,
      );
      final updatedOther = other.copyWith(
        semesterName: '已重命名的其他课表',
        semesterStartDate: _weeksAgo(5),
      );

      await provider.updateScheduleConfig(updatedOther);

      expect(provider.scheduleConfig.value, same(current));
      expect(
        provider.allSchedules.value.singleWhere((item) => item.id == other.id),
        same(updatedOther),
      );
      expect(coursesChangedCount, 0);
    },
  );

  test(
    'editing the current schedule refreshes current config and week',
    () async {
      final current = _schedule(id: 'A', name: '当前课表', weeksAgo: 1);
      final other = _schedule(id: 'B', name: '其他课表', weeksAgo: 2);
      final database = _FakeDatabaseService(
        currentScheduleId: current.id,
        schedules: [current, other],
      );
      final registry = HookRegistry();
      final provider = CourseProvider(database, registry: registry);
      var coursesChangedCount = 0;
      registry.on(
        provider,
        CourseProvider.courseChanged,
        (_) => coursesChangedCount++,
      );
      final updatedCurrent = current.copyWith(
        semesterName: '已更新的当前课表',
        semesterStartDate: _weeksAgo(4),
      );

      await provider.updateScheduleConfig(updatedCurrent);

      expect(provider.scheduleConfig.value, same(updatedCurrent));
      expect(
        provider.allSchedules.value.singleWhere(
          (item) => item.id == current.id,
        ),
        same(updatedCurrent),
      );
      expect(coursesChangedCount, 1);
    },
  );

  test('addSchedule 从空状态导入时不出现 hasSchedule=true 而 config 未就位的中间态', () async {
    final database = _EmptyStartDatabaseService();
    final provider = CourseProvider(database);
    var sawInconsistentState = false;
    provider.allSchedules.addListener(() {
      if (provider.allSchedules.value.isNotEmpty &&
          provider.scheduleConfig.value == null) {
        sawInconsistentState = true;
      }
    });

    await provider.addSchedule(_schedule(id: 'A', name: '首次导入', weeksAgo: 0));

    expect(sawInconsistentState, isFalse);
    expect(provider.hasSchedule, isTrue);
    expect(provider.scheduleConfig.value?.id, 'A');
    expect(provider.allSchedules.value.single.id, 'A');
  });

  test('runBatch 合并多个写操作只递增一次 courseDataVersion', () async {
    final current = _schedule(id: 'A', name: '当前课表', weeksAgo: 1);
    final database = _FakeDatabaseService(
      currentScheduleId: current.id,
      schedules: [current],
    );
    final provider = CourseProvider(database);

    expect(provider.courseDataVersion.value, 0);

    await provider.runBatch(() async {
      await provider.addCourse(
        Course(
          id: 'c1',
          name: '课程1',
          teacher: '教师1',
          location: '',
          startWeek: 1,
          endWeek: 16,
          dayOfWeek: 1,
          startSection: 1,
          endSection: 2,
          colorValue: 0,
        ),
      );
      await provider.updateScheduleConfig(
        current.copyWith(semesterName: '新课表名称'),
      );
      expect(provider.courseDataVersion.value, 0);
    });

    expect(provider.courseDataVersion.value, 1);
  });

  test('updateScheduleConfig 仅在学期元数据改变时递增 courseDataVersion', () async {
    final current = _schedule(id: 'A', name: '当前课表', weeksAgo: 1);
    final database = _FakeDatabaseService(
      currentScheduleId: current.id,
      schedules: [current],
    );
    final provider = CourseProvider(database);

    expect(provider.courseDataVersion.value, 0);

    // 修改非学期设置（周数、起始日期）不递增
    await provider.updateScheduleConfig(
      current.copyWith(totalWeeks: 18, semesterStartDate: _weeksAgo(3)),
    );
    expect(provider.courseDataVersion.value, 0);

    // 修改学期名称递增
    await provider.updateScheduleConfig(
      current.copyWith(semesterName: '改名后的课表'),
    );
    expect(provider.courseDataVersion.value, 1);
  });

  test('课表变更可以同时通知多个订阅者', () async {
    final current = _schedule(id: 'A', name: '当前课表', weeksAgo: 1);
    final database = _FakeDatabaseService(
      currentScheduleId: current.id,
      schedules: [current],
    );
    final registry = HookRegistry();
    final provider = CourseProvider(database, registry: registry);
    var firstCount = 0;
    var secondCount = 0;
    List<Course>? secondPayload;
    registry.on(provider, CourseProvider.courseChanged, (_) => firstCount++);
    registry.on(provider, CourseProvider.courseChanged, (courses) {
      secondCount++;
      secondPayload = courses;
    });

    await provider.updateScheduleConfig(current.copyWith(semesterName: '改名'));

    // 单一回调字段时代，第二个订阅会覆盖第一个；经注册中心分发后两者都应收到。
    expect(firstCount, 1);
    expect(secondCount, 1);
    // 时机携带变更后的课表数据，订阅者不需要再去读 ValueNotifier。
    expect(secondPayload, same(provider.courses.value));
  });

  test('取消订阅只移除对应的订阅者', () async {
    final current = _schedule(id: 'A', name: '当前课表', weeksAgo: 1);
    final database = _FakeDatabaseService(
      currentScheduleId: current.id,
      schedules: [current],
    );
    final registry = HookRegistry();
    final provider = CourseProvider(database, registry: registry);
    var firstCount = 0;
    var secondCount = 0;
    final cancelFirst = registry.on(
      provider,
      CourseProvider.courseChanged,
      (_) => firstCount++,
    );
    registry.on(provider, CourseProvider.courseChanged, (_) => secondCount++);

    cancelFirst();
    await provider.updateScheduleConfig(current.copyWith(semesterName: '改名'));

    expect(firstCount, 0);
    expect(secondCount, 1);
  });

  test('单个订阅者抛错不影响其它订阅者', () async {
    final current = _schedule(id: 'A', name: '当前课表', weeksAgo: 1);
    final database = _FakeDatabaseService(
      currentScheduleId: current.id,
      schedules: [current],
    );
    final registry = HookRegistry();
    final provider = CourseProvider(database, registry: registry);
    var laterCount = 0;
    registry.on(
      provider,
      CourseProvider.courseChanged,
      (_) => throw StateError('订阅者异常'),
    );
    registry.on(provider, CourseProvider.courseChanged, (_) => laterCount++);

    await provider.updateScheduleConfig(current.copyWith(semesterName: '改名'));

    expect(laterCount, 1);
  });

  test('订阅未注册的时机立即抛错，而不是静默收不到通知', () {
    final current = _schedule(id: 'A', name: '当前课表', weeksAgo: 1);
    final database = _FakeDatabaseService(
      currentScheduleId: current.id,
      schedules: [current],
    );
    final registry = HookRegistry();
    final provider = CourseProvider(database, registry: registry);
    final unknownHook = Hook<void>('typoHook');

    expect(
      () => registry.on(provider, unknownHook, (_) {}),
      throwsA(isA<StateError>()),
    );
  });

  test('debugSnapshot 反映每个时机的订阅者数量', () {
    final current = _schedule(id: 'A', name: '当前课表', weeksAgo: 1);
    final database = _FakeDatabaseService(
      currentScheduleId: current.id,
      schedules: [current],
    );
    final registry = HookRegistry();
    final provider = CourseProvider(database, registry: registry);
    registry.on(provider, CourseProvider.courseChanged, (_) {});
    registry.on(provider, CourseProvider.courseChanged, (_) {});

    expect(registry.debugSnapshot()['CourseProvider.courseChanged'], 2);
  });
}

ScheduleConfig _schedule({
  required String id,
  required String name,
  required int weeksAgo,
}) {
  return ScheduleConfig(
    id: id,
    semesterName: name,
    semesterStartDate: _weeksAgo(weeksAgo),
    totalWeeks: 20,
  );
}

DateTime _weeksAgo(int weeks) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  return today.subtract(Duration(days: weeks * 7));
}

class _FakeDatabaseService extends DatabaseService {
  _FakeDatabaseService({
    required String currentScheduleId,
    required List<ScheduleConfig> schedules,
  }) : _currentScheduleId = currentScheduleId,
       _schedules = List.of(schedules);

  final String _currentScheduleId;
  List<ScheduleConfig> _schedules;

  @override
  List<Course> getCourses({String? scheduleId}) => const [];

  @override
  List<ScheduleConfig> getAllSchedules() => List.unmodifiable(_schedules);

  @override
  ScheduleConfig getScheduleConfig() =>
      _schedules.singleWhere((schedule) => schedule.id == _currentScheduleId);

  @override
  String getCurrentScheduleId() => _currentScheduleId;

  @override
  Future<void> saveScheduleConfig(ScheduleConfig config) async {
    _schedules = [
      for (final schedule in _schedules)
        if (schedule.id == config.id) config else schedule,
    ];
  }

  @override
  Future<void> addCourse(Course course) async {}
}

/// 模拟空库首次 addSchedule：初始无任何课表，落库与切换才有数据。
class _EmptyStartDatabaseService extends DatabaseService {
  List<ScheduleConfig> _schedules = [];
  String _currentScheduleId = '';

  @override
  List<Course> getCourses({String? scheduleId}) => const [];

  @override
  List<ScheduleConfig> getAllSchedules() => List.unmodifiable(_schedules);

  @override
  ScheduleConfig? getScheduleConfig() {
    if (_schedules.isEmpty) return null;
    return _schedules.firstWhere(
      (schedule) => schedule.id == _currentScheduleId,
      orElse: () => _schedules.first,
    );
  }

  @override
  String getCurrentScheduleId() => _currentScheduleId;

  @override
  Future<void> addSchedule(ScheduleConfig config) async {
    _schedules = [..._schedules, config];
  }

  @override
  Future<void> switchSchedule(String scheduleId) async {
    _currentScheduleId = scheduleId;
  }
}
