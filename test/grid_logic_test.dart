import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/widgets/course/grid_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Course track assignment', () {
    test('uses one coordinate system for an overlap-connected component', () {
      final courses = [
        _buildCourse('A', 1, 2),
        _buildCourse('B', 2, 5),
        _buildCourse('C', 3, 4),
        _buildCourse('D', 4, 5),
      ];

      final tracks = assignCourseTracks(courses);

      expect(tracks.map((track) => track.totalTracks), everyElement(3));
      for (var i = 0; i < courses.length; i++) {
        for (var j = i + 1; j < courses.length; j++) {
          if (!coursesOverlapInSections(courses[i], courses[j])) continue;

          expect(
            _horizontalIntervalsAreDisjoint(tracks[i], tracks[j]),
            isTrue,
            reason: '${courses[i].name} and ${courses[j].name} overlap in time',
          );
        }
      }
    });

    test('sizes disconnected overlap components independently', () {
      final tracks = assignCourseTracks([
        _buildCourse('A', 1, 2),
        _buildCourse('B', 2, 3),
        _buildCourse('C', 5, 6),
        _buildCourse('D', 5, 7),
        _buildCourse('E', 6, 6),
      ]);

      expect(tracks.take(2).map((track) => track.totalTracks), everyElement(2));
      expect(tracks.skip(2).map((track) => track.totalTracks), everyElement(3));
    });
  });
}

Course _buildCourse(String name, int startSection, int endSection) {
  return Course(
    name: name,
    teacher: '老师',
    location: '教室',
    startWeek: 1,
    endWeek: 16,
    dayOfWeek: 1,
    startSection: startSection,
    endSection: endSection,
    colorValue: 0xFF2196F3,
    weekType: WeekType.every,
  );
}

bool _horizontalIntervalsAreDisjoint(TrackInfo a, TrackInfo b) {
  final aLeft = a.track / a.totalTracks;
  final aRight = (a.track + 1) / a.totalTracks;
  final bLeft = b.track / b.totalTracks;
  final bRight = (b.track + 1) / b.totalTracks;
  return aRight <= bLeft || bRight <= aLeft;
}
