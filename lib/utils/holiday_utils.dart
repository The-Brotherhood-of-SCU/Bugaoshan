import 'package:tyme/tyme.dart';

/// 特殊日类型
enum SpecialDayType { ordinary, festival, holiday, solarTerm }

/// 特殊日信息
class SpecialDayInfo {
  final SpecialDayType type;
  final String? name;
  final String? subtitle;

  SpecialDayInfo({required this.type, this.name, this.subtitle});
}

/// 中国法定节假日检测工具
///
/// 基于 [tyme](https://pub.dev/packages/tyme) 库计算：
/// - 法定假日数据来自国务院官方安排（自 2001-12-29 起）
/// - 节气采用寿星天文算法精确计算
/// - 公历节日和农历传统节日依据国家标准
class HolidayUtils {
  HolidayUtils._();

  /// 缓存 {year: {holidayName: totalDays}}
  static final Map<int, Map<String, int>> _totalDaysCache = {};

  /// 获取 [date] 对应的法定节假日名称，如 '国庆节'
  /// 调休上班日返回 null
  static String? getHolidayName(DateTime date) {
    try {
      final legalHoliday = SolarDay(
        date.year,
        date.month,
        date.day,
      ).getLegalHoliday();
      if (legalHoliday != null && !legalHoliday.isWork()) {
        return legalHoliday.getName();
      }
    } catch (_) {}
    return null;
  }

  /// 判断 [date] 是否为法定节假日（放假）
  static bool isStatutoryHoliday(DateTime date) {
    return getHolidayName(date) != null;
  }

  /// 获取 [holidayName] 在 [year] 的总放假天数
  static int getHolidayTotalDays(String holidayName, int year) {
    return _totalDaysCache
        .putIfAbsent(year, () => {})
        .putIfAbsent(
          holidayName,
          () => _computeHolidayTotalDays(holidayName, year),
        );
  }

  static int _computeHolidayTotalDays(String holidayName, int year) {
    int count = 0;
    for (var month = 1; month <= 12; month++) {
      final daysInMonth = DateTime(year, month + 1, 0).day;
      for (var day = 1; day <= daysInMonth; day++) {
        try {
          final legalHoliday = SolarDay(year, month, day).getLegalHoliday();
          if (legalHoliday != null &&
              !legalHoliday.isWork() &&
              legalHoliday.getName() == holidayName) {
            count++;
          }
        } catch (_) {}
      }
    }
    return count;
  }

  /// 获取 [date] 对应的节日名称，如 '元宵节'、'教师节'
  /// 已归入法定假日的春节、清明节不再重复
  static String? getFestivalName(DateTime date) {
    try {
      final solarDay = SolarDay(date.year, date.month, date.day);
      // 公历现代节日
      final sf = solarDay.getFestival();
      if (sf != null) return sf.getName();
      // 农历传统节日（跳过已归入法定假日的春节、清明）
      final lf = solarDay.getLunarDay().getFestival();
      if (lf != null) {
        final name = lf.getName();
        if (name != '春节' && name != '清明节') return name;
      }
    } catch (_) {}
    return null;
  }

  /// 判断 [date] 是否为标记节日
  static bool isFestival(DateTime date) => getFestivalName(date) != null;

  /// 获取 [date] 对应的节气名称，如 '立春'
  /// 仅当天返回名称（节气开始日），非持续期间
  static String? getSolarTermName(DateTime date) {
    try {
      final termDay = SolarDay(date.year, date.month, date.day).getTermDay();
      if (termDay.dayIndex == 0) {
        return termDay.getSolarTerm().getName();
      }
    } catch (_) {}
    return null;
  }

  /// 判断 [date] 是否为节气
  static bool isSolarTerm(DateTime date) => getSolarTermName(date) != null;

  /// 获取 [date] 对应的特殊日信息（含类型、名称、备注等）
  ///
  /// 优先级：假 > 节 > 气 > 普通日
  static SpecialDayInfo getSpecialDay(DateTime date) {
    try {
      final solarDay = SolarDay(date.year, date.month, date.day);

      // 1. 法定假日（放假）
      final legalHoliday = solarDay.getLegalHoliday();
      if (legalHoliday != null && !legalHoliday.isWork()) {
        final totalDays = getHolidayTotalDays(
          legalHoliday.getName(),
          date.year,
        );
        return SpecialDayInfo(
          type: SpecialDayType.holiday,
          name: legalHoliday.getName(),
          subtitle: '共$totalDays天假',
        );
      }

      // 2. 节日（公历 + 农历，跳过春节清明）
      final sf = solarDay.getFestival();
      if (sf != null) {
        return SpecialDayInfo(
          type: SpecialDayType.festival,
          name: sf.getName(),
        );
      }
      final lf = solarDay.getLunarDay().getFestival();
      if (lf != null) {
        final name = lf.getName();
        if (name != '春节' && name != '清明节') {
          return SpecialDayInfo(type: SpecialDayType.festival, name: name);
        }
      }

      // 3. 节气（仅当天）
      final termDay = solarDay.getTermDay();
      if (termDay.dayIndex == 0) {
        return SpecialDayInfo(
          type: SpecialDayType.solarTerm,
          name: termDay.getSolarTerm().getName(),
        );
      }
    } catch (_) {}

    return SpecialDayInfo(type: SpecialDayType.ordinary);
  }
}
