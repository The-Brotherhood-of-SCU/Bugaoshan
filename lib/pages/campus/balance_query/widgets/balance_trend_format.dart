import 'dart:math' show pow, log, ln10;

import 'package:intl/intl.dart';

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

/// UTC 时间戳 → 本地 `yyyy-MM-dd`。
String formatDate(DateTime t) {
  return DateFormat('yyyy-MM-dd').format(t.toLocal());
}

/// UTC 时间戳 → 本地 `yyyy-MM-dd HH:mm`。
String formatDateTime(DateTime t) {
  return DateFormat('yyyy-MM-dd HH:mm').format(t.toLocal());
}

/// 计算"好看"的 Y 轴刻度间隔(1/2/5 × 10^n)。
double niceInterval(double min, double max) {
  final range = max - min;
  if (range <= 0) return 1;
  final raw = range / 4;
  final mag = pow(10, (log(raw) / ln10).floor()).toDouble();
  final norm = raw / mag;
  double nice;
  if (norm < 1.5) {
    nice = 1;
  } else if (norm < 3) {
    nice = 2;
  } else if (norm < 7) {
    nice = 5;
  } else {
    nice = 10;
  }
  return nice * mag;
}

/// X 轴(时间)间隔:至少 4 段。
double niceTimeInterval(double minX, double maxX) {
  final range = maxX - minX;
  if (range <= 0) return 1;
  return range / 4;
}
