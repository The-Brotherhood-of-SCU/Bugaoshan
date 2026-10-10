/// 教学周与自然日的唯一锚定口径（校历口径）。
///
/// 校历的教学周以**周日**为首日成行，**第 1 周是包含学期起点的那一周**：
///
/// - 学期起点为周日（校历多数学期）→ 第 1 周即起点当周，块首日 = 起点本身；
/// - 学期起点为周一（如 2026-2027 秋季学期 2026-08-31）→ 第 1 周为 8/30(日)~9/5(六)，
///   因此 9/20(日) 属第 4 周。
///
/// 第 W 周 = `[块首日 + (W-1)*7, 块首日 + (W-1)*7 + 6]`，学期最后一天 =
/// `块首日 + 总周数*7 - 1`。
///
/// 课表页 `ScheduleConfig.dateForCourseDay`、桌面小组件（Android `weekAnchor` /
/// iOS `courseWeekAnchor`）、顶栏与校历徽标、课表设置页「当前周」都取自本文件的口径，
/// 禁止各自演化——历史上正是两侧口径不一致，导致周一起点学期里小组件把周日的课
/// 查早一周（2026-09-19 修复）。
library;

/// 教学周块首日，即第 1 周的周日 = **学期起点所在周的周日**。
///
/// 教务系统以周日为每周第一天（与 `course.dart` 里 `DateTimeExtension.toSunday` 同义）。
/// 起点本身是周日时块首日即起点；起点是周一时为起点前一天（2026-08-31 → 2026-08-30）。
DateTime courseWeekAnchor(DateTime semesterStartDate) {
  final start = DateTime(
    semesterStartDate.year,
    semesterStartDate.month,
    semesterStartDate.day,
  );
  return start.subtract(Duration(days: start.weekday % 7));
}

/// [date] 落在第几教学周（自 1 起，不按总周数裁剪）。
///
/// 早于块首日的一律算第 1 周；调用方若需要「未开学 / 已放假」的判定，请自行比较
/// 学期起点与学期最后一天（[courseSemesterEnd]）。
int courseWeekOf(DateTime semesterStartDate, DateTime date) {
  final anchor = courseWeekAnchor(semesterStartDate);
  final target = DateTime(date.year, date.month, date.day);
  final days = target.difference(anchor).inDays;
  final week = days ~/ 7 + 1;
  return week < 1 ? 1 : week;
}

/// 学期最后一天，即第 [totalWeeks] 周的周六。
DateTime courseSemesterEnd(DateTime semesterStartDate, int totalWeeks) {
  final anchor = courseWeekAnchor(semesterStartDate);
  return anchor.add(Duration(days: totalWeeks * 7 - 1));
}
