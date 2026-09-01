import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/models/course.dart';

Course _course(String location, {String campus = '', String name = '课程'}) =>
    Course(
      name: name,
      teacher: '',
      location: location,
      campus: campus,
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
  group('ScheduleConfig.dominantCampusOfCourses', () {
    test('空列表返回 null', () {
      expect(ScheduleConfig.dominantCampusOfCourses(const []), isNull);
    });

    test('全部无校区关键词返回 null', () {
      expect(
        ScheduleConfig.dominantCampusOfCourses([
          _course('线上'),
          _course('综楼C203'),
          _course(''),
        ]),
        isNull,
      );
    });

    test('占多数的校区为主导', () {
      final campus = ScheduleConfig.dominantCampusOfCourses([
        _course('江安一教A101', name: '课A'),
        _course('江安综楼C203', name: '课B'),
        _course('望江基础教学楼B101', name: '课C'),
      ]);
      expect(campus, '江安');
    });

    test('数量并列返回 null', () {
      final campus = ScheduleConfig.dominantCampusOfCourses([
        _course('江安一教A101', name: '课A'),
        _course('望江一教101', name: '课B'),
      ]);
      expect(campus, isNull);
    });

    test('同一课程按周段/节次展开的多条记录只计一次', () {
      // 1 门望江课拆成 12 条记录 vs 3 门江安课各 1 条：
      // 逐条计数会得出望江主导；按课程名去重后应为江安。
      final campus = ScheduleConfig.dominantCampusOfCourses([
        for (var i = 0; i < 12; i++) _course('望江一教101', name: '望江课'),
        _course('江安一教A101', name: '江安课1'),
        _course('江安综楼C203', name: '江安课2'),
        _course('江安一教B201', name: '江安课3'),
      ]);
      expect(campus, '江安');
    });

    test('同一课程名多条记录取第一条命中的校区', () {
      final campus = ScheduleConfig.dominantCampusOfCourses([
        _course('望江一教101', name: '跨校区课'),
        _course('江安一教A101', name: '跨校区课'),
        _course('望江一教102', name: '望江课'),
        _course('江安一教B201', name: '江安课'),
      ]);
      expect(campus, '望江');
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
        _course('江安一教A101', name: '江安课'),
        _course('望江一教101', name: '望江课'),
        _course('线上', name: '线上课'),
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

  group('ScheduleConfig.campusKeywordOfCourse', () {
    test('优先使用 campus 字段', () {
      expect(
        ScheduleConfig.campusKeywordOfCourse(_course('一教A101', campus: '江安校区')),
        '江安',
      );
    });

    test('campus 字段无关键词时回退到地点推断', () {
      expect(
        ScheduleConfig.campusKeywordOfCourse(
          _course('华西五教302', campus: '其它校区'),
        ),
        '华西',
      );
    });

    test('campus 与地点均无关键词返回 null', () {
      expect(
        ScheduleConfig.campusKeywordOfCourse(_course('综楼C203', campus: '')),
        isNull,
      );
    });
  });

  group('ScheduleConfig.applyCampusTimeSlotsForCourses (campus 字段)', () {
    test('地点无校区关键词时由 campus 字段主导', () {
      final config = _config();
      final applied = ScheduleConfig.applyCampusTimeSlotsForCourses(config, [
        _course('一教A101', campus: '望江校区'),
        _course('综楼C203', campus: '望江校区'),
      ]);
      expect(applied, isTrue);
      expect(config.timeSlots, ScheduleConfig.wangJiangHuaXiTimeSlots);
    });

    test('campus 与地点关键词混合时合并计数', () {
      final config = _config();
      final applied = ScheduleConfig.applyCampusTimeSlotsForCourses(config, [
        _course('一教A101', campus: '望江校区'),
        _course('基础教学楼B101', campus: '望江校区'),
        _course('江安综楼C203'),
      ]);
      expect(applied, isTrue);
      expect(config.timeSlots, ScheduleConfig.wangJiangHuaXiTimeSlots);
    });

    test('campus 字段并列时保持原时间表', () {
      final config = _config();
      final original = List.of(config.timeSlots);
      final applied = ScheduleConfig.applyCampusTimeSlotsForCourses(config, [
        _course('一教A101', campus: '望江校区', name: '望江课'),
        _course('一教A101', campus: '江安校区', name: '江安课'),
      ]);
      expect(applied, isFalse);
      expect(config.timeSlots, original);
    });

    test('无任何校区信息时保持原时间表', () {
      final config = _config();
      final original = List.of(config.timeSlots);
      final applied = ScheduleConfig.applyCampusTimeSlotsForCourses(config, [
        _course('综楼C203'),
        _course('线上'),
      ]);
      expect(applied, isFalse);
      expect(config.timeSlots, original);
    });
  });

  group('ScheduleConfig 非 4-5-3 配置守卫与预置检测', () {
    test('非 4-5-3 配置不应用预设（避免节数与时间表错位）', () {
      final config = ScheduleConfig(
        semesterStartDate: DateTime(2026, 3, 2),
        morningSections: 3,
        afternoonSections: 4,
        eveningSections: 3,
        // 模拟分享 JSON 携带的 10 节时间表
        timeSlots: List.generate(
          10,
          (_) => const TimeSlot(
            startTime: TimeOfDay(hour: 8, minute: 0),
            endTime: TimeOfDay(hour: 8, minute: 45),
          ),
        ),
      );
      final original = List.of(config.timeSlots);
      final applied = ScheduleConfig.applyCampusTimeSlotsForCourses(config, [
        _course('望江一教101'),
      ]);
      expect(applied, isFalse);
      expect(config.timeSlots, original);
      expect(config.sectionsPerDay, 10);
      expect(config.timeSlots.length, isNot(12));
    });

    test('campusTimeSlotsForCourses 返回主导校区预置', () {
      expect(
        ScheduleConfig.campusTimeSlotsForCourses([_course('华西五教302')]),
        ScheduleConfig.wangJiangHuaXiTimeSlots,
      );
      expect(ScheduleConfig.campusTimeSlotsForCourses([_course('线上')]), isNull);
    });

    test('isPresetTimeSlots 识别两种预置', () {
      expect(
        ScheduleConfig.isPresetTimeSlots(
          List.of(ScheduleConfig.jiangAnTimeSlots),
        ),
        isTrue,
      );
      expect(
        ScheduleConfig.isPresetTimeSlots(
          List.of(ScheduleConfig.wangJiangHuaXiTimeSlots),
        ),
        isTrue,
      );
    });

    test('自定义时间表不被识别为预置', () {
      final custom = List.of(ScheduleConfig.jiangAnTimeSlots);
      custom[0] = custom[0].copyWith(
        startTime: const TimeOfDay(hour: 9, minute: 0),
      );
      expect(ScheduleConfig.isPresetTimeSlots(custom), isFalse);
      expect(ScheduleConfig.isPresetTimeSlots(<TimeSlot>[]), isFalse);
    });
  });

  group('Course campus 字段序列化', () {
    test('toJson/fromJson 保留 campus', () {
      final course = _course('一教A101', campus: '江安校区');
      final restored = Course.fromJson(course.toJson());
      expect(restored.campus, '江安校区');
    });

    test('旧 JSON 无 campus 字段时兼容为空串', () {
      final json = _course('一教A101').toJson()..remove('campus');
      final restored = Course.fromJson(json);
      expect(restored.campus, '');
    });
  });
}
