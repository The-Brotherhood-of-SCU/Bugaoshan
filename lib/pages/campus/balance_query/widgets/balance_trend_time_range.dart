import 'package:bugaoshan/utils/beijing_time.dart';

/// 电费趋势页时间范围筛选枚举。
///
/// [custom] 表示用户切换到"自定义"模式,真正的起止日期由
/// [BalanceTrendCustomRangeCard] 维护。
enum BalanceTrendTimeRange { days7, days30, days90, custom }

/// 将用户选的"开始"/"结束"日期按北京日历日解释,转为 UTC 范围
/// (北京日 00:00:00 ~ 北京日 23:59:59.999),用于数据库查询。
///
/// [start]/[end] 仅日期分量(year/month/day)有效。SCU 用户都在中国,
/// 固定按 UTC+8 解释,不依赖设备本地时区。
({DateTime since, DateTime until}) localDatesToUtc({
  required DateTime start,
  required DateTime end,
}) {
  final since = beijingDateToUtc(start.year, start.month, start.day);
  final until = beijingDateToUtc(
    end.year,
    end.month,
    end.day,
    hour: 23,
    minute: 59,
    second: 59,
    millisecond: 999,
  );
  return (since: since, until: until);
}
