import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/providers/course_provider.dart';
import 'package:bugaoshan/services/database_service.dart';
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
      final provider = CourseProvider(database);
      var coursesChangedCount = 0;
      provider.onCoursesChanged = () => coursesChangedCount++;
      final initialWeek = provider.currentWeek.value;
      final updatedOther = other.copyWith(
        semesterName: '已重命名的其他课表',
        semesterStartDate: _weeksAgo(5),
      );

      await provider.updateScheduleConfig(updatedOther);

      expect(provider.scheduleConfig.value, same(current));
      expect(provider.currentWeek.value, initialWeek);
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
      final provider = CourseProvider(database);
      var coursesChangedCount = 0;
      provider.onCoursesChanged = () => coursesChangedCount++;
      final updatedCurrent = current.copyWith(
        semesterName: '已更新的当前课表',
        semesterStartDate: _weeksAgo(4),
      );

      await provider.updateScheduleConfig(updatedCurrent);

      expect(provider.scheduleConfig.value, same(updatedCurrent));
      expect(provider.currentWeek.value, updatedCurrent.getCurrentWeek());
      expect(
        provider.allSchedules.value.singleWhere(
          (item) => item.id == current.id,
        ),
        same(updatedCurrent),
      );
      expect(coursesChangedCount, 1);
    },
  );
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
}
