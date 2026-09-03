import 'dart:math' show pow, log, ln10;

import 'package:bugaoshan/utils/beijing_time.dart';

/// 电费趋势页通用的数值/日期格式化与图表轴间隔工具。
///
/// 全部为纯函数,无实例状态,便于在多个子 widget 中复用。

/// `¥1.50`。
String formatMoney(double v) {
  final s = formatNumber(v, decimals: 2);
  return '¥$s';
}

/// 按指定小数位四舍五入转字符串。
String formatNumber(double v, {int decimals = 2}) {
  return v.toStringAsFixed(decimals);
}

/// UTC 时间戳 → 北京时区 `yyyy-MM-dd`。
String formatDate(DateTime t) => formatBeijing(t, 'yyyy-MM-dd');

/// UTC 时间戳 → 北京时区 `yyyy-MM-dd HH:mm`。
String formatDateTime(DateTime t) => formatBeijing(t, 'yyyy-MM-dd HH:mm');

/// 计算"好看"的 Y 轴刻度间隔(1/2/5 × 10^n)。
///
/// [chartHeight] 为图表像素高度,[minPixelSpacing] 为相邻刻度标签的
/// 最小像素间距。数据范围很窄时(如照明电量在 272.x 附近波动)原始
/// `range / 4` 可能算出过小的间隔,导致刻度标签互相重叠;这里在间隔
/// 过小时会向上取整到更大的 1/2/5 间隔,保证像素间距不小于
/// [minPixelSpacing]。
double niceInterval(
  double min,
  double max, {
  double chartHeight = 240,
  double minPixelSpacing = 40,
}) {
  final range = max - min;
  if (range <= 0) return 1;
  var interval = _niceIntervalOf(range / 4);
  // 间隔对应的像素间距 = chartHeight * interval / range,
  // 若小于 minPixelSpacing 则向上取整到更大的 1/2/5 间隔。
  final minInterval = minPixelSpacing * range / chartHeight;
  while (interval < minInterval) {
    interval = _nextNiceUp(interval);
  }
  return interval;
}

double _niceIntervalOf(double raw) {
  final mag = pow(10, (log(raw) / ln10).floor()).toDouble();
  final norm = raw / mag;
  if (norm < 1.5) return 1 * mag;
  if (norm < 3) return 2 * mag;
  if (norm < 7) return 5 * mag;
  return 10 * mag;
}

/// 向上取整到下一个 1/2/5 × 10^n 间隔。
double _nextNiceUp(double interval) {
  final mag = pow(10, (log(interval) / ln10).floor()).toDouble();
  final norm = interval / mag;
  if (norm < 2) return 2 * mag;
  if (norm < 5) return 5 * mag;
  return 10 * mag;
}

/// X 轴(时间)间隔:至少 4 段。
double niceTimeInterval(double minX, double maxX) {
  final range = maxX - minX;
  if (range <= 0) return 1;
  return range / 4;
}
