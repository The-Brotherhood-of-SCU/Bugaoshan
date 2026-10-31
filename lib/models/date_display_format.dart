import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

/// 课表日期格式：顺序与分隔符都取自当前语言环境的 CLDR 数据。
///
/// 顺序（月在前还是日在前）和分隔符（`/`、`.`、`-`）都是地区习惯，不是
/// 产品偏好，因此不写死在 ARB 里，而是直接向 `intl` 要当前 locale 的
/// `DateFormat.Md` 模式：
///
/// | locale | CLDR 模式 | 表头 |
/// |---|---|---|
/// | en_US | `M/d` | 8/19 |
/// | en_GB | `dd/MM` | 19/08 |
/// | zh_CN | `M/d` | 8/19 |
/// | de_DE | `d.M.` | 19.8. |
///
/// 顶栏显示完整日期（带年份），网格表头只保留月与日；两者共用同一份
/// 顺序与分隔符，保证同屏看起来是一套格式。
///
/// 之所以不用「10月19日」：低分辨率屏上 5~7 列平摊后每列只有 60px 上下，
/// 中文长日期会被压缩到难以辨认，数字则不受语言文案长度影响。
@immutable
class DateDisplayFormat {
  /// 直接指定顺序与分隔符，主要用于测试与默认值。
  const DateDisplayFormat({
    required this.monthFirst,
    required this.separator,
  });

  /// 从语言环境解析。CLDR 数据缺失时回落到 `M/d`（绝大多数语言的写法）。
  factory DateDisplayFormat.of(Locale locale) {
    final pattern = _patternFor(locale);
    return DateDisplayFormat(
      monthFirst: _isMonthFirst(pattern),
      separator: _separatorOf(pattern),
    );
  }

  /// 月是否排在日前。
  final bool monthFirst;

  /// 月与日之间的分隔符，取自同一份 CLDR 模式。
  final String separator;

  /// 完整日期，供课表顶栏使用：`10/26/2026` 或 `26.10.2026`。
  String formatFull(DateTime date) {
    final year = '${date.year}';
    final month = _two(date.month);
    final day = _two(date.day);
    return monthFirst
        ? [month, day, year].join(separator)
        : [day, month, year].join(separator);
  }

  /// 只含月与日的片段，供课表表头窄列使用：`10/26` 或 `26.10`。
  String formatMonthDay(DateTime date) {
    final month = _two(date.month);
    final day = _two(date.day);
    return monthFirst ? '$month$separator$day' : '$day$separator$month';
  }

  static String _two(int value) => value.toString().padLeft(2, '0');

  static const String _fallbackPattern = 'M/d';

  static String _patternFor(Locale locale) {
    final candidates = <String>[
      locale.toString(),
      if (locale.countryCode != null) locale.languageCode,
      'en_US',
    ];
    for (final candidate in candidates) {
      try {
        return DateFormat.Md(candidate).pattern ?? _fallbackPattern;
      } on Exception {
        // 该 locale 的 intl 数据未加载，换下一个候选。
      }
    }
    return _fallbackPattern;
  }

  /// 模式里月份在日之前即「月在前」。
  static bool _isMonthFirst(String pattern) {
    final month = pattern.indexOf('M');
    final day = pattern.indexOf('d');
    if (month < 0 || day < 0) return true;
    return month < day;
  }

  /// 取模式里第一个分隔字符（`/`、`.` 或 `-`）；空白与非 ASCII 标点
  /// （如韩语的 `. ` 与阿拉伯语的 RTL 标记）一律归到主分隔符。
  static String _separatorOf(String pattern) {
    for (final char in pattern.split('')) {
      if ('/.-'.contains(char)) return char;
    }
    return '/';
  }

  @override
  bool operator ==(Object other) =>
      other is DateDisplayFormat &&
      other.monthFirst == monthFirst &&
      other.separator == separator;

  @override
  int get hashCode => Object.hash(monthFirst, separator);

  @override
  String toString() =>
      'DateDisplayFormat(monthFirst: $monthFirst, separator: "$separator")';
}
