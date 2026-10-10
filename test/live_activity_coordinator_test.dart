import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/services/reminder/live_activity_coordinator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// [LiveCourseResolver] 课程解析逻辑单元测试。
///
/// 覆盖进行中课程匹配、会话标识生成与后续课程推导。周次判定遵循校历周日成行
/// 口径及 [Course.isActiveInWeek] 约定，与 [ReminderPlanBuilder] 保持一致。
void main() {
  /// 测试基准时间：学期起点 2026-08-31（周一，第 1 教学周）；2026-09-01（周二，第 1 教学周）。
  ScheduleConfig schedule({int totalWeeks = 20}) => ScheduleConfig(
    id: 's1',
    semesterStartDate: DateTime(2026, 8, 31),
    totalWeeks: totalWeeks,
    timeSlots: const [
      TimeSlot(
        startTime: TimeOfDay(hour: 8, minute: 0),
        endTime: TimeOfDay(hour: 8, minute: 45),
      ),
      TimeSlot(
        startTime: TimeOfDay(hour: 9, minute: 0),
        endTime: TimeOfDay(hour: 9, minute: 45),
      ),
      TimeSlot(
        startTime: TimeOfDay(hour: 10, minute: 0),
        endTime: TimeOfDay(hour: 10, minute: 45),
      ),
    ],
  );

  Course course({
    String name = '高等数学',
    int dayOfWeek = 2,
    int startSection = 1,
    int endSection = 1,
    List<int>? customWeeks,
  }) => Course(
    name: name,
    teacher: '张老师',
    location: '综C407',
    dayOfWeek: dayOfWeek,
    startWeek: 1,
    endWeek: 20,
    startSection: startSection,
    endSection: endSection,
    colorValue: 0xFF2196F3,
    customWeeks: customWeeks,
  );

  LiveCourseSnapshot resolve({
    required List<Course> courses,
    required DateTime now,
    ScheduleConfig? config,
  }) => LiveCourseResolver.resolve(
    courses: courses,
    config: config ?? schedule(),
    now: now,
  );
  group('当前课程判定', () {
    test('课中：返回当前课程与下课时刻', () {
      final snapshot = resolve(
        courses: [course()],
        now: DateTime(2026, 9, 1, 8, 20),
      );

      expect(snapshot.current?.name, '高等数学');
      expect(snapshot.endAt, DateTime(2026, 9, 1, 8, 45));
    });

    test('上课瞬间即为「在上课」，下课瞬间即为「已下课」', () {
      final courses = [course()];

      expect(
        resolve(courses: courses, now: DateTime(2026, 9, 1, 8, 0)).hasCurrent,
        isTrue,
      );
      // 左闭右开区间 [start, end)：到达下课时刻即视为已结束。
      expect(
        resolve(courses: courses, now: DateTime(2026, 9, 1, 8, 45)).hasCurrent,
        isFalse,
      );
    });

    test('连堂课按结束节次取下课时刻', () {
      final snapshot = resolve(
        courses: [course(startSection: 1, endSection: 3)],
        now: DateTime(2026, 9, 1, 8, 30),
      );

      expect(snapshot.current?.name, '高等数学');
      expect(snapshot.endAt, DateTime(2026, 9, 1, 10, 45));
    });

    test('课间：没有当前课程，但能拿到下一节', () {
      final snapshot = resolve(
        courses: [
          course(startSection: 1),
          course(name: '线性代数', startSection: 2),
        ],
        now: DateTime(2026, 9, 1, 8, 50),
      );

      expect(snapshot.hasCurrent, isFalse);
      expect(snapshot.next?.name, '线性代数');
      expect(snapshot.nextStartAt, DateTime(2026, 9, 1, 9, 0));
    });

    test('别的星期与本周不上课的课程都不算数', () {
      expect(
        resolve(
          courses: [course(dayOfWeek: 3)],
          now: DateTime(2026, 9, 1, 8, 20),
        ).hasCurrent,
        isFalse,
      );
      // 离散周次 customWeeks：当前周次未命中时不处于活跃状态。
      expect(
        resolve(
          courses: [
            course(customWeeks: const [2, 3]),
          ],
          now: DateTime(2026, 9, 1, 8, 20),
        ).hasCurrent,
        isFalse,
      );
    });

    test('学期开始前与放假后都不判定', () {
      expect(
        resolve(
          courses: [course(dayOfWeek: 1)],
          now: DateTime(2026, 8, 24, 8, 20),
        ).hasCurrent,
        isFalse,
      );
      // 教学周超出 totalWeeks 时不匹配任何课程。
      expect(
        resolve(
          courses: [course(dayOfWeek: 1)],
          now: DateTime(2027, 1, 25, 8, 20),
        ).hasCurrent,
        isFalse,
      );
    });

    test('无课表或无课程时返回空快照而不是抛异常', () {
      // 空课程列表与 null 配置均返回空快照，不抛异常。
      expect(
        LiveCourseResolver.resolve(
          courses: const [],
          config: schedule(),
          now: DateTime(2026, 9, 1, 8, 20),
        ).hasCurrent,
        isFalse,
      );
      expect(
        LiveCourseResolver.resolve(
          courses: [course()],
          config: null,
          now: DateTime(2026, 9, 1, 8, 20),
        ).hasCurrent,
        isFalse,
      );
    });

    test('节次超出时间表长度时跳过该课', () {
      expect(
        resolve(
          courses: [course(startSection: 9, endSection: 9)],
          now: DateTime(2026, 9, 1, 8, 20),
        ).hasCurrent,
        isFalse,
      );
    });
  });

  group('会话标识', () {
    test('同名连堂课属于不同会话', () {
      // 两节同名的课，起止节次不同（8:00-8:45 与 9:00-9:45）。
      final courses = [
        course(startSection: 1, endSection: 1),
        course(startSection: 2, endSection: 2),
      ];

      final first = resolve(courses: courses, now: DateTime(2026, 9, 1, 8, 20));
      final second = resolve(
        courses: courses,
        now: DateTime(2026, 9, 1, 9, 20),
      );

      // 标识须能区分这两节，否则第二节不下发新状态，倒计时停留在第一节的终点。
      expect(first.sessionKey, isNot(second.sessionKey));
      expect(first.sessionKey, isNotNull);
    });

    test('同一节课在不同时刻的会话标识稳定', () {
      final courses = [course()];

      expect(
        resolve(courses: courses, now: DateTime(2026, 9, 1, 8, 5)).sessionKey,
        resolve(courses: courses, now: DateTime(2026, 9, 1, 8, 40)).sessionKey,
      );
    });

    test('没有进行中课程时没有会话标识', () {
      expect(
        resolve(
          courses: [course()],
          now: DateTime(2026, 9, 1, 12, 0),
        ).sessionKey,
        isNull,
      );
    });
  });

  group('下节课程推导', () {
    test('课间时给出下一节', () {
      final snapshot = resolve(
        courses: [
          course(startSection: 1, endSection: 1),
          course(name: '线性代数', startSection: 2, endSection: 2),
        ],
        now: DateTime(2026, 9, 1, 8, 50),
      );

      expect(snapshot.hasCurrent, isFalse);
      expect(snapshot.next?.name, '线性代数');
    });

    test('连堂课时不把落在当前课程区间内的课当作「下节」', () {
      // 当前为第 1~3 节连堂（8:00-10:45）；另一门课于第 2 节（9:00）开始，
      // 虽晚于 now，但落在当前课程的区间内，与下课倒计时矛盾。
      final snapshot = resolve(
        courses: [
          course(startSection: 1, endSection: 3),
          course(name: '线性代数', startSection: 2, endSection: 2),
        ],
        now: DateTime(2026, 9, 1, 8, 30),
      );

      expect(snapshot.current?.name, '高等数学');
      expect(snapshot.endAt, DateTime(2026, 9, 1, 10, 45));
      expect(snapshot.next, isNull);
    });

    test('课间里紧接着的那节课仍算「下节」', () {
      // 第 1 节 8:00-8:45 已下课，第 2 节 9:00 开始：两者区间不重叠。
      final snapshot = resolve(
        courses: [
          course(startSection: 1, endSection: 1),
          course(name: '线性代数', startSection: 2, endSection: 2),
        ],
        now: DateTime(2026, 9, 1, 8, 20),
      );

      expect(snapshot.current?.name, '高等数学');
      expect(snapshot.next?.name, '线性代数');
      expect(snapshot.nextStartAt, DateTime(2026, 9, 1, 9, 0));
    });

    test('当前课程结束后才开始的课仍算「下节」', () {
      // 当前课 8:00-9:45（第 1~2 节连堂），下一门 10:00 开始（第 3 节）。
      final snapshot = resolve(
        courses: [
          course(startSection: 1, endSection: 2),
          course(name: '线性代数', startSection: 3, endSection: 3),
        ],
        now: DateTime(2026, 9, 1, 8, 20),
      );

      expect(snapshot.endAt, DateTime(2026, 9, 1, 9, 45));
      expect(snapshot.next?.name, '线性代数');
    });
  });
}
