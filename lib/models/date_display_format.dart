/// 日期显示的组成部分。
enum _DatePart { day, month, year }

/// 课表日期格式：一个完整的「年-月-日」排列方式。
///
/// 由用户在「软件设置 → 日期格式」下拉中挑选，全局生效并持久化在
/// `AppConfigProvider.dateDisplayFormat`。
///
/// 两种消费方式，共用同一份排列与分隔符，保证两处看起来是一套格式：
/// - [formatFull]：课表左上角顶栏，显示完整日期；
/// - [formatMonthDay]：课表表头每一列，只保留月与日。
///
/// 之所以不再按语言输出「10月19日」：低分辨率屏上 5~7 列平摊后每列只有
/// 60px 上下，中文长日期会被压缩到难以辨认，定宽数字则不受文案长度影响。
enum DateDisplayFormat {
  /// `19/8/26`
  dayMonthShortYearSlash(
    [_DatePart.day, _DatePart.month, _DatePart.year],
    '/',
    padded: false,
    shortYear: true,
  ),

  /// `19/08/2026`
  dayMonthYearSlash([_DatePart.day, _DatePart.month, _DatePart.year], '/'),

  /// `8/19/26`
  monthDayShortYearSlash(
    [_DatePart.month, _DatePart.day, _DatePart.year],
    '/',
    padded: false,
    shortYear: true,
  ),

  /// `8/19/2026`
  monthDayYearSlash(
    [_DatePart.month, _DatePart.day, _DatePart.year],
    '/',
    padded: false,
  ),

  /// `19.08.2026`
  dayMonthYearDot([_DatePart.day, _DatePart.month, _DatePart.year], '.'),

  /// `19-08-2026`
  dayMonthYearDash([_DatePart.day, _DatePart.month, _DatePart.year], '-'),

  /// `2026/8/19`
  yearMonthDaySlash(
    [_DatePart.year, _DatePart.month, _DatePart.day],
    '/',
    padded: false,
  ),

  /// `2026.08.19`
  yearMonthDayDot([_DatePart.year, _DatePart.month, _DatePart.day], '.'),

  /// `2026-08-19`
  yearMonthDayDash([_DatePart.year, _DatePart.month, _DatePart.day], '-');

  const DateDisplayFormat(
    this._order,
    this._separator, {
    this.padded = true,
    this.shortYear = false,
  });

  final List<_DatePart> _order;
  final String _separator;

  /// 月与日是否补零到两位。年份恒为四位，或用 [shortYear] 缩成两位。
  final bool padded;

  /// 年份是否缩写为两位（如 `26`）。
  final bool shortYear;

  /// 完整日期，供课表顶栏使用。
  String formatFull(DateTime date) =>
      _order.map((part) => _part(part, date)).join(_separator);

  /// 只含月与日的片段，供课表表头窄列使用。
  ///
  /// 顺序与分隔符沿用当前格式，只是丢掉年份：选 `19.08.2026` 时表头是
  /// `19.08`，选 `2026-08-19` 时是 `08-19`。
  String formatMonthDay(DateTime date) {
    const kept = {_DatePart.day, _DatePart.month};
    return _order
        .where((part) => kept.contains(part))
        .map((part) => _part(part, date))
        .join(_separator);
  }

  String _part(_DatePart part, DateTime date) {
    switch (part) {
      case _DatePart.day:
        return padded ? _two(date.day) : '${date.day}';
      case _DatePart.month:
        return padded ? _two(date.month) : '${date.month}';
      case _DatePart.year:
        final year = '${date.year}';
        return shortYear ? year.substring(year.length - 2) : year;
    }
  }

  static String _two(int value) => value.toString().padLeft(2, '0');
}
