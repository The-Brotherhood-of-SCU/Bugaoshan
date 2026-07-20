import 'package:intl/intl.dart';

/// SCU 用户都在中国,余额趋势相关时间统一按北京时区(UTC+8)解释,
/// 不依赖设备本地时区。数据库存储仍为 UTC 毫秒,仅展示/聚合/日界判定
/// 固定 +8h 偏移,这样境外旅行/留学的用户看到的也是北京日历日。
const Duration kBeijingUtcOffset = Duration(hours: 8);

/// 将 [utcTime] 按北京时区格式化为字符串。
/// [utcTime] 可以是 UTC 或本地 DateTime,内部先 toUtc() 再加 8h。
String formatBeijing(DateTime utcTime, String pattern) {
  final beijing = utcTime.toUtc().add(kBeijingUtcOffset);
  return DateFormat(pattern).format(beijing);
}

/// 返回 [utcTime] 所在的北京日历日(UTC 标记,仅作 bucket key)。
/// 同一北京日内的所有 UTC 时刻都会得到相同的 key。
DateTime beijingDayBucket(DateTime utcTime) {
  final b = utcTime.toUtc().add(kBeijingUtcOffset);
  return DateTime.utc(b.year, b.month, b.day);
}

/// 返回 [utcTime] 所在北京日 00:00 对应的 UTC 即时。
/// 用于"今日已采样否"等以北京日界为基准的查询下界。
DateTime beijingStartOfDayUtc(DateTime utcTime) {
  final b = utcTime.toUtc().add(kBeijingUtcOffset);
  return DateTime.utc(b.year, b.month, b.day).subtract(kBeijingUtcOffset);
}

/// 当前北京日的 00:00 对应的 UTC 即时。
DateTime beijingStartOfTodayUtc() =>
    beijingStartOfDayUtc(DateTime.now().toUtc());

/// 将"北京日历日"的 year/month/day 转为 UTC 即时。
/// 用于把 DatePicker 选出的日期(仅日期分量有意义)按北京日解释。
DateTime beijingDateToUtc(
  int year,
  int month,
  int day, {
  int hour = 0,
  int minute = 0,
  int second = 0,
  int millisecond = 0,
}) {
  return DateTime.utc(
    year,
    month,
    day,
    hour,
    minute,
    second,
    millisecond,
  ).subtract(kBeijingUtcOffset);
}
