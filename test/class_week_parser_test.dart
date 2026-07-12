import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/services/ics_service.dart';
import 'package:bugaoshan/utils/class_week_parser.dart';
import 'package:bugaoshan/widgets/course/grid_logic.dart';

void main() {
  group('classWeek parsing', () {
    test('splits sparse weeks without filling gaps', () {
      final segments = parseClassWeekSegments('110100');

      expect(segments, [
        (startWeek: 1, endWeek: 2, weekType: WeekType.every),
        (startWeek: 4, endWeek: 4, weekType: WeekType.every),
      ]);
    });

    test('keeps a complete alternating sequence compact', () {
      expect(parseClassWeekSegments('101010'), [
        (startWeek: 1, endWeek: 5, weekType: WeekType.odd),
      ]);
      expect(parseClassWeekSegments('010101'), [
        (startWeek: 2, endWeek: 6, weekType: WeekType.even),
      ]);
    });

    test('preserves active-week semantics in the grid and ICS export', () {
      final segments = parseClassWeekSegments('110100');
      final courses = segments.indexed.map((entry) {
        final (index, segment) = entry;
        return Course(
          id: 'segment-$index',
          name: '稀疏周课程',
          teacher: '老师',
          location: '教室',
          startWeek: segment.startWeek,
          endWeek: segment.endWeek,
          dayOfWeek: DateTime.monday,
          startSection: 1,
          endSection: 1,
          colorValue: 0xff2196f3,
          weekType: segment.weekType,
        );
      }).toList();

      final visibleByWeek = [
        for (var week = 1; week <= 6; week++)
          selectVisibleCoursesForDay(
            courses,
            week,
            showNonCurrentWeekCourses: false,
          ).isNotEmpty,
      ];
      expect(visibleByWeek, [true, true, false, true, false, false]);

      final config = ScheduleConfig(
        semesterStartDate: DateTime(2026, 1, 5),
        timeSlots: const [
          TimeSlot(
            startTime: TimeOfDay(hour: 8, minute: 15),
            endTime: TimeOfDay(hour: 9, minute: 0),
          ),
        ],
      );
      final eventDates = IcsService.genCourseCalendarEvents(
        config: config,
        courses: courses,
        teacherLabel: '教师',
      ).map((event) => event.start).toList();

      expect(eventDates, [
        DateTime(2026, 1, 5, 8, 15),
        DateTime(2026, 1, 12, 8, 15),
        DateTime(2026, 1, 26, 8, 15),
      ]);
    });
  });
}
