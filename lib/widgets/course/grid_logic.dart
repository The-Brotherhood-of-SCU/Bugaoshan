import 'package:bugaoshan/models/course.dart';

/// 筛选指定周次可见的课程列表。
///
/// [showNonCurrentWeekCourses] 为 false 时仅返回当前活跃课程；
/// 为 true 时还会包含未来周次但不与当前课程时间冲突的课程。
List<Course> selectVisibleCoursesForDay(
  List<Course> courses,
  int displayWeek, {
  bool showNonCurrentWeekCourses = true,
}) {
  final visibleCourses =
      courses.where((course) => course.isInWeekRange(displayWeek)).toList()
        ..sort(compareCoursesForLayout);

  if (!showNonCurrentWeekCourses) {
    return visibleCourses
        .where((course) => course.isActiveInWeek(displayWeek))
        .toList();
  }

  final futureCourses =
      courses.where((course) => displayWeek < course.startWeek).toList()
        ..sort((a, b) {
          final weekCompare = a.startWeek.compareTo(b.startWeek);
          if (weekCompare != 0) return weekCompare;
          return compareCoursesForLayout(a, b);
        });

  for (final course in futureCourses) {
    final overlapsVisible = visibleCourses.any(
      (visibleCourse) => coursesOverlapInSections(visibleCourse, course),
    );
    if (!overlapsVisible) {
      visibleCourses.add(course);
    }
  }

  visibleCourses.sort(compareCoursesForLayout);
  return visibleCourses;
}

/// 课程排序：按开始节次升序，相同则按持续时长降序，再相同则按开始周升序。
int compareCoursesForLayout(Course a, Course b) {
  final sectionCompare = a.startSection.compareTo(b.startSection);
  if (sectionCompare != 0) return sectionCompare;

  final durationCompare = (b.endSection - b.startSection).compareTo(
    a.endSection - a.startSection,
  );
  if (durationCompare != 0) return durationCompare;

  return a.startWeek.compareTo(b.startWeek);
}

/// 判断两门课程在节次上是否重叠。
bool coursesOverlapInSections(Course a, Course b) {
  return !(a.endSection < b.startSection || a.startSection > b.endSection);
}

/// 轨道分配信息，用于全周视图下课程的并排显示。
class TrackInfo {
  final int track;
  final int totalTracks;
  const TrackInfo({required this.track, required this.totalTracks});
}

/// 为重叠课程分配垂直轨道，用于并排显示。
List<TrackInfo> assignCourseTracks(List<Course> courses) {
  if (courses.isEmpty) return [];
  if (courses.length == 1) {
    return [const TrackInfo(track: 0, totalTracks: 1)];
  }

  // 按开始节次排序，相同则按持续时长降序以保证稳定性
  final indexed = courses.asMap().entries.toList()
    ..sort((a, b) {
      final cmp = a.value.startSection.compareTo(b.value.startSection);
      if (cmp != 0) return cmp;
      final aDuration = a.value.endSection - a.value.startSection;
      final bDuration = b.value.endSection - b.value.startSection;
      return bDuration.compareTo(aDuration);
    });

  final trackEnds = <int>[];
  final assignments = List<int>.filled(courses.length, -1);

  for (final entry in indexed) {
    final originalIndex = entry.key;
    final course = entry.value;

    int assignedTrack = -1;
    for (int t = 0; t < trackEnds.length; t++) {
      if (trackEnds[t] < course.startSection) {
        assignedTrack = t;
        break;
      }
    }
    if (assignedTrack == -1) {
      assignedTrack = trackEnds.length;
      trackEnds.add(0);
    }
    trackEnds[assignedTrack] = course.endSection;
    assignments[originalIndex] = assignedTrack;
  }

  // 重新映射：对于每门课程，仅基于其时间段内实际重叠的课程计算 track/totalTracks
  return List.generate(courses.length, (i) {
    final course = courses[i];
    final overlapping = <int>[];
    for (int j = 0; j < courses.length; j++) {
      if (coursesOverlapInSections(courses[j], course)) {
        overlapping.add(j);
      }
    }
    overlapping.sort((a, b) => assignments[a].compareTo(assignments[b]));
    final localTrack = overlapping.indexOf(i);
    return TrackInfo(track: localTrack, totalTracks: overlapping.length);
  });
}

/// 合并同名、同星期、同节次范围的课程为一张卡片。
/// 减少轨道数量并以紧凑格式显示合并信息。
List<Course> mergeSameSlotCourses(List<Course> courses) {
  if (courses.length <= 1) return courses;

  final groups = <String, List<Course>>{};
  for (final course in courses) {
    final key =
        '${course.name}|${course.dayOfWeek}|${course.startSection}|${course.endSection}';
    groups.putIfAbsent(key, () => []).add(course);
  }

  if (groups.length == courses.length) return courses;

  final result = <Course>[];
  for (final group in groups.values) {
    if (group.length == 1) {
      result.add(group[0]);
    } else {
      // 仅当位置相同时合并；位置不同则保留并排轨道
      final uniqueLocations = group.map((c) => c.location).toSet();
      if (uniqueLocations.length == 1) {
        result.add(mergeCourseGroup(group));
      } else {
        result.addAll(group);
      }
    }
  }
  return result;
}

/// 合并一组课程（同名、同星期、同节次）为单个 Course。
Course mergeCourseGroup(List<Course> group) {
  final first = group.first;

  // 教师：去重后的姓名（部分字段已包含逗号分隔的姓名）
  final teacher = group
      .expand((c) => c.teacher.split(RegExp(r'[,，、]')))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toSet()
      .join('\u3001');

  // 地点：去重后的值，不含周次注释
  final location = group.map((c) => c.location).toSet().join(' \u00b7 ');

  final minWeek = group.map((c) => c.startWeek).reduce((a, b) => a < b ? a : b);
  final maxWeek = group.map((c) => c.endWeek).reduce((a, b) => a > b ? a : b);

  return Course(
    name: first.name,
    teacher: teacher,
    location: location,
    startWeek: minWeek,
    endWeek: maxWeek,
    dayOfWeek: first.dayOfWeek,
    startSection: first.startSection,
    endSection: first.endSection,
    colorValue: first.colorValue,
    weekType: group.map((c) => c.weekType).toSet().length == 1
        ? first.weekType
        : WeekType.every,
  );
}
