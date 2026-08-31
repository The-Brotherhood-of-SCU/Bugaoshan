import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/models/course.dart';

Course _course(String location) => Course(
  name: '课程',
  teacher: '',
  location: location,
  startWeek: 1,
  endWeek: 16,
  dayOfWeek: 1,
  startSection: 1,
  endSection: 2,
  colorValue: 0xFF2196F3,
);

ScheduleConfig _config() =>
    ScheduleConfig(semesterStartDate: DateTime(2026, 3, 2));

void main() {
  group('ScheduleConfig.dominantCampusOfLocations', () {
    test('空列表返回 null', () {
      expect(ScheduleConfig.dominantCampusOfLocations(const []), isNull);
    });

    test('全部无校区关键词返回 null', () {
      expect(
        ScheduleConfig.dominantCampusOfLocations(['线上', '综楼C203', '']),
        isNull,
      );
    });

    test('占多数的校区为主导', () {
      final campus = ScheduleConfig.dominantCampusOfLocations([
        '江安一教A101',
        '江安综楼C203',
        '望江基础教学楼B101',
      ]);
      expect(campus, '江安');
    });

    test('数量并列返回 null', () {
      final campus = ScheduleConfig.dominantCampusOfLocations([
        '江安一教A101',
        '望江一教101',
      ]);
      expect(campus, isNull);
    });

    test('地点同时包含多个关键词时按优先级只计一次', () {
      final campus = ScheduleConfig.dominantCampusOfLocations([
        '江安望江楼101',
        '江安一教A101',
      ]);
      expect(campus, '江安');
    });
  });

  group('ScheduleConfig.applyCampusTimeSlotsForCourses', () {
    test('江安主导 → 应用江安预置时间表', () {
      final config = _config();
      final applied = ScheduleConfig.applyCampusTimeSlotsForCourses(config, [
        _course('江安一教A101'),
        _course('江安综楼C203'),
      ]);
      expect(applied, isTrue);
      expect(config.timeSlots, ScheduleConfig.jiangAnTimeSlots);
    });

    test('望江主导 → 应用望江/华西预置时间表', () {
      final config = _config();
      final applied = ScheduleConfig.applyCampusTimeSlotsForCourses(config, [
        _course('望江基础教学楼B101'),
        _course('望江一教101'),
        _course('江安一教A101'),
      ]);
      expect(applied, isTrue);
      expect(config.timeSlots, ScheduleConfig.wangJiangHuaXiTimeSlots);
    });

    test('华西主导 → 应用望江/华西预置时间表', () {
      final config = _config();
      final applied = ScheduleConfig.applyCampusTimeSlotsForCourses(config, [
        _course('华西五教302'),
      ]);
      expect(applied, isTrue);
      expect(config.timeSlots, ScheduleConfig.wangJiangHuaXiTimeSlots);
    });

    test('无主导校区时保持原时间表不变', () {
      final config = _config();
      final original = List.of(config.timeSlots);
      final applied = ScheduleConfig.applyCampusTimeSlotsForCourses(config, [
        _course('江安一教A101'),
        _course('望江一教101'),
        _course('线上'),
      ]);
      expect(applied, isFalse);
      expect(config.timeSlots, original);
    });

    test('应用后使用的是预设副本，不共享常量列表', () {
      final config = _config();
      ScheduleConfig.applyCampusTimeSlotsForCourses(config, [
        _course('江安一教A101'),
      ]);
      expect(
        identical(config.timeSlots, ScheduleConfig.jiangAnTimeSlots),
        isFalse,
      );
      config.timeSlots.removeAt(0);
      expect(ScheduleConfig.jiangAnTimeSlots.length, 12);
    });
  });
}
