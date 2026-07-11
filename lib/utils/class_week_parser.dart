import 'package:bugaoshan/models/course.dart';

typedef ClassWeekSegment = ({int startWeek, int endWeek, WeekType weekType});

/// 将教务系统的周次位串拆成 [Course] 可精确表达的若干区间。
///
/// 连续周合并为 `every` 区间，完整且无缺口的单双周序列合并为一个
/// `odd` / `even` 区间。其余稀疏模式按连续段拆分，保证不会凭空增加周次。
List<ClassWeekSegment> parseClassWeekSegments(String classWeek) {
  final activeWeeks = <int>[
    for (var index = 0; index < classWeek.length; index++)
      if (classWeek[index] == '1') index + 1,
  ];
  if (activeWeeks.isEmpty) return const [];

  final isCompleteAlternating =
      activeWeeks.length > 1 &&
      activeWeeks.indexed.skip(1).every((entry) {
        final (index, week) = entry;
        return week - activeWeeks[index - 1] == 2;
      });
  if (isCompleteAlternating) {
    return [
      (
        startWeek: activeWeeks.first,
        endWeek: activeWeeks.last,
        weekType: activeWeeks.first.isOdd ? WeekType.odd : WeekType.even,
      ),
    ];
  }

  final segments = <ClassWeekSegment>[];
  var start = activeWeeks.first;
  var end = start;
  for (final week in activeWeeks.skip(1)) {
    if (week == end + 1) {
      end = week;
      continue;
    }
    segments.add((startWeek: start, endWeek: end, weekType: WeekType.every));
    start = week;
    end = week;
  }
  segments.add((startWeek: start, endWeek: end, weekType: WeekType.every));
  return segments;
}
