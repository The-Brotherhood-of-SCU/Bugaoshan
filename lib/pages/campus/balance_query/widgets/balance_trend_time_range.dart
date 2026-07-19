/// 电费趋势页时间范围筛选枚举。
///
/// [custom] 表示用户切换到"自定义"模式,真正的起止日期由
/// [BalanceTrendCustomRangeCard] 维护。
enum BalanceTrendTimeRange { days7, days30, days90, custom }

/// 将本地日期(用户选的"开始"/"结束")转换为 UTC 范围
/// (本地 00:00:00 ~ 本地 23:59:59.999),用于数据库查询。
///
/// [start]/[end] 均为本地日期,仅日期部分有效。
({DateTime since, DateTime until}) localDatesToUtc({
  required DateTime start,
  required DateTime end,
}) {
  final since = DateTime(start.year, start.month, start.day, 0, 0, 0).toUtc();
  final until = DateTime(end.year, end.month, end.day, 23, 59, 59, 999).toUtc();
  return (since: since, until: until);
}
