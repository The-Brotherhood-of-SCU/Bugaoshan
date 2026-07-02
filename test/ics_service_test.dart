import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/services/ics_service.dart';

void main() {
  group('Course calendar export', () {
    test('keeps course title unchanged while mapping location', () {
      final config = ScheduleConfig(
        semesterStartDate: DateTime(2026, 2, 23),
        semesterName: '2025-2026-2',
        timeSlots: const [
          TimeSlot(
            startTime: TimeOfDay(hour: 8, minute: 15),
            endTime: TimeOfDay(hour: 9, minute: 0),
          ),
        ],
      );

      final events = IcsService.genCourseCalendarEvents(
        config: config,
        courses: [
          Course(
            name: '(107447030-31) 高等数学A',
            teacher: '张三',
            location: '江安一教A101',
            startWeek: 1,
            endWeek: 1,
            dayOfWeek: 1,
            startSection: 1,
            endSection: 1,
            colorValue: 0xff2196f3,
          ),
        ],
        teacherLabel: '教师',
      );

      expect(events, hasLength(1));
      final payload = events.single.toPlatformJson();
      expect(payload['title'], '(107447030-31) 高等数学A');
      expect(payload['location'], '四川大学江安校区 · 江安一教A101');
      expect(payload['structuredLocation'], {
        'title': '四川大学江安校区 · 江安一教A101',
        'latitude': 30.5601863,
        'longitude': 103.9973029,
        'radius': 250.0,
      });
    });

    test('exports mapped campus coordinates to ICS GEO', () {
      final config = ScheduleConfig(
        semesterStartDate: DateTime(2026, 2, 23),
        semesterName: '2025-2026-2',
        timeSlots: const [
          TimeSlot(
            startTime: TimeOfDay(hour: 8, minute: 15),
            endTime: TimeOfDay(hour: 9, minute: 0),
          ),
        ],
      );

      final ics = IcsService.genIcs(
        config: config,
        courses: [
          Course(
            name: '课序号 02 大学英语',
            teacher: '李四',
            location: '华西十教201',
            startWeek: 1,
            endWeek: 1,
            dayOfWeek: 1,
            startSection: 1,
            endSection: 1,
            colorValue: 0xff2196f3,
          ),
        ],
        teacherLabel: '教师',
      );

      expect(ics, contains('SUMMARY:课序号 02 大学英语'));
      expect(ics, contains('LOCATION:四川大学华西校区 · 华西十教201'));
      expect(ics, contains('GEO:30.6425541;104.0673888'));
    });

    test('builds course calendar export payload in one place', () {
      final config = ScheduleConfig(
        semesterStartDate: DateTime(2026, 2, 23),
        semesterName: '2025-2026-2',
        timeSlots: const [
          TimeSlot(
            startTime: TimeOfDay(hour: 8, minute: 15),
            endTime: TimeOfDay(hour: 9, minute: 0),
          ),
        ],
      );

      final payload = IcsService.genCourseExportPayload(
        config: config,
        courses: [
          Course(
            name: '大学英语',
            teacher: '李四',
            location: '望江一教101',
            startWeek: 1,
            endWeek: 1,
            dayOfWeek: 1,
            startSection: 1,
            endSection: 1,
            colorValue: 0xff2196f3,
          ),
        ],
        teacherLabel: '教师',
      );

      expect(payload.fileName, '2025_2026_2.ics');
      expect(payload.icsContent, contains('SUMMARY:大学英语'));
      expect(payload.events, hasLength(1));
      expect(payload.events.single['location'], '四川大学望江校区 · 望江一教101');
    });
  });
}
