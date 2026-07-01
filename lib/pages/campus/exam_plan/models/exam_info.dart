/// 单门考试信息模型，从教务系统考表 HTML 解析。
class ExamInfo {
  final String courseName;
  final String week;
  final String date;
  final String weekday;
  final String timeRange;
  final String location;
  final String seatNumber;
  final String ticketNumber;
  final String tip;

  const ExamInfo({
    required this.courseName,
    required this.week,
    required this.date,
    required this.weekday,
    required this.timeRange,
    required this.location,
    required this.seatNumber,
    required this.ticketNumber,
    required this.tip,
  });

  /// 考试是否已结束（按日期 + 结束时间判断）
  bool get isPast {
    final now = DateTime.now();
    try {
      final dateParsed = DateTime.parse(date);
      final timeParts = timeRange.split('-');
      if (timeParts.length == 2) {
        final endParts = timeParts.last.split(':');
        if (endParts.length == 2) {
          final endHour = int.parse(endParts[0]);
          final endMin = int.parse(endParts[1]);
          final examEnd = DateTime(
            dateParsed.year,
            dateParsed.month,
            dateParsed.day,
            endHour,
            endMin,
          );
          return now.isAfter(examEnd);
        }
      }
      return now.isAfter(dateParsed.add(const Duration(days: 1)));
    } catch (_) {
      return false;
    }
  }
}
