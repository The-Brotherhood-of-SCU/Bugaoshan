import 'package:flutter_test/flutter_test.dart';
import 'package:Bugaoshan/models/course.dart';
import 'package:Bugaoshan/widgets/course/course_grid.dart';

void main() {
  group('Course week visibility', () {
    final course = Course(
      name: '高数',
      teacher: '老师',
      location: '教室',
      startWeek: 1,
      endWeek: 16,
      dayOfWeek: 1,
      startSection: 1,
      endSection: 2,
      colorValue: 0xFF2196F3,
      weekType: WeekType.odd,
    );

    test('keeps odd-week ghost card within configured week range', () {
      expect(course.isInWeekRange(2), isTrue);
      expect(course.isActiveInWeek(2), isFalse);
    });

    test('hides course outside configured week range', () {
      expect(course.isInWeekRange(17), isFalse);
      expect(course.isActiveInWeek(17), isFalse);
    });
  });

  group('Visible course selection', () {
    Course buildCourse({
      required String name,
      required int startWeek,
      required int endWeek,
      required int startSection,
      required int endSection,
      WeekType weekType = WeekType.every,
    }) {
      return Course(
        name: name,
        teacher: '老师',
        location: '教室',
        startWeek: startWeek,
        endWeek: endWeek,
        dayOfWeek: 1,
        startSection: startSection,
        endSection: endSection,
        colorValue: 0xFF2196F3,
        weekType: weekType,
      );
    }

    test('shows future course ghost when slot is empty', () {
      final visibleCourses = selectVisibleCoursesForDay([
        buildCourse(
          name: '第三周开始的课',
          startWeek: 3,
          endWeek: 16,
          startSection: 1,
          endSection: 2,
        ),
      ], 1);

      expect(visibleCourses.map((course) => course.name), ['第三周开始的课']);
    });

    test('hides future course ghost when current week slot is occupied', () {
      final visibleCourses = selectVisibleCoursesForDay([
        buildCourse(
          name: '第三周开始的课',
          startWeek: 3,
          endWeek: 16,
          startSection: 1,
          endSection: 2,
        ),
        buildCourse(
          name: '当前已有课',
          startWeek: 1,
          endWeek: 16,
          startSection: 1,
          endSection: 2,
        ),
      ], 1);

      expect(visibleCourses.map((course) => course.name), ['当前已有课']);
    });

    test(
      'keeps future course ghost when occupied course is on another slot',
      () {
        final visibleCourses = selectVisibleCoursesForDay([
          buildCourse(
            name: '第三周开始的课',
            startWeek: 3,
            endWeek: 16,
            startSection: 1,
            endSection: 2,
          ),
          buildCourse(
            name: '当前已有课',
            startWeek: 1,
            endWeek: 16,
            startSection: 3,
            endSection: 4,
          ),
        ], 1);

        expect(visibleCourses.map((course) => course.name), [
          '第三周开始的课',
          '当前已有课',
        ]);
      },
    );
  });
}
