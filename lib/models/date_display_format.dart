import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// 课表日期格式：年、月、日的排列方式。
///
/// 只保留四种常见写法，统一用 `/` 分隔、年份四位、月日补零：
///
/// ```
/// MM/DD/YYYY   10/26/2026
/// DD/MM/YYYY   26/10/2026
/// YYYY/MM/DD   2026/10/26
/// YYYY/DD/MM   2026/26/10
/// ```
///
/// 默认值由系统语言映射而来（[fromLocale]），用户可以覆盖。
/// 顶栏显示完整日期，网格表头只保留月与日；两者共用同一份顺序。
///
/// 之所以不用「10月19日」：低分辨率屏上 5~7 列平摊后每列只有 60px 上下，
/// 中文长日期会被压缩到难以辨认，数字则不受语言文案长度影响。
enum DateDisplayFormat {
  /// `10/26/2026`
  monthDayYear,

  /// `26/10/2026`
  dayMonthYear,

  /// `2026/10/26`
  yearMonthDay,

  /// `2026/26/10`
  yearDayMonth;

  bool get _yearFirst =>
      this == DateDisplayFormat.yearMonthDay ||
      this == DateDisplayFormat.yearDayMonth;

  bool get _monthFirst =>
      this == DateDisplayFormat.monthDayYear ||
      this == DateDisplayFormat.yearMonthDay;

  /// 完整日期，供课表顶栏使用。
  String formatFull(DateTime date) {
    final year = '${date.year}';
    final month = _two(date.month);
    final day = _two(date.day);
    final monthDay = _monthFirst ? [month, day] : [day, month];
    return (_yearFirst ? [year, ...monthDay] : [...monthDay, year]).join('/');
  }

  /// 只含月与日的片段，供课表表头窄列使用。
  String formatMonthDay(DateTime date) {
    final month = _two(date.month);
    final day = _two(date.day);
    return _monthFirst ? '$month/$day' : '$day/$month';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  /// 按系统语言映射出默认格式。
  ///
  /// 读取 `intl` 的 `DateFormat.yMd(locale).pattern`，看 `y`、`M`、`d` 谁先出现。
  /// intl 数据尚未初始化（如纯 Dart 单测）时回落到 [monthDayYear]。
  static DateDisplayFormat fromLocale(Locale locale) {
    for (final candidate in <String>[
      locale.toString(),
      locale.languageCode,
      'en_US',
    ]) {
      try {
        final pattern = DateFormat.yMd(candidate).pattern;
        if (pattern != null) return _fromPattern(pattern);
      } on Exception {
        // 该 locale 的 intl 数据未加载，换下一个候选。
      }
    }
    return DateDisplayFormat.monthDayYear;
  }

  /// 按模式里 `y`、`M`、`d` 的先后判定排列。
  static DateDisplayFormat _fromPattern(String pattern) {
    final year = pattern.indexOf('y');
    final month = pattern.indexOf('M');
    final day = pattern.indexOf('d');
    if (year < 0 || month < 0 || day < 0) {
      return DateDisplayFormat.monthDayYear;
    }
    if (year < month && year < day) {
      return month < day
          ? DateDisplayFormat.yearMonthDay
          : DateDisplayFormat.yearDayMonth;
    }
    return month < day
        ? DateDisplayFormat.monthDayYear
        : DateDisplayFormat.dayMonthYear;
  }

  /// 取用户设置；未设置时回落到系统语言映射。
  static DateDisplayFormat resolve(
    BuildContext context,
    DateDisplayFormat? override,
  ) => override ?? fromLocale(Localizations.localeOf(context));
}
