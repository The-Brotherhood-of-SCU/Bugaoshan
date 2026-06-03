import 'package:tyme/tyme.dart';

/// 特殊日类型
enum SpecialDayType { ordinary, festival, holiday, solarTerm }

/// 特殊日信息
class SpecialDayInfo {
  final SpecialDayType type;
  final String? name;
  final int? holidayTotalDays;

  SpecialDayInfo({required this.type, this.name, this.holidayTotalDays});
}

/// 兜底用固定日期节假日映射。
///
/// 当 tyme 无某年数据时，这些日期必定放假，可直接做降级显示。
/// 其余依赖农历的法定假日（春节、清明、端午、中秋）天数不定，不在此列。
const Map<int, Map<int, String>> _kFixedHolidays = {
  1: {1: '元旦'},
  5: {1: '劳动节'},
  10: {1: '国庆节'},
};

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

  /// tyme 无数据时降级：返回固定日期假日的名称
  static String? _getFixedHolidayFallback(DateTime date) {
    return _kFixedHolidays[date.month]?[date.day];
  }

  /// 获取 [date] 对应的法定节假日名称，如 '国庆节'
  /// 调休上班日返回 null
  static String? getHolidayName(DateTime date) {
    try {
      final legalHoliday = SolarDay(
        date.year,
        date.month,
        date.day,
      ).getLegalHoliday();
      if (legalHoliday != null) {
        return legalHoliday.isWork() ? null : legalHoliday.getName();
      }
    } catch (_) {}
    // tyme 无此日数据 → 固定日期放假兜底
    return _getFixedHolidayFallback(date);
  }

  /// 判断 [date] 是否为法定节假日（放假）
  static bool isStatutoryHoliday(DateTime date) {
    return getHolidayName(date) != null;
  }

  /// 获取 [holidayName] 在 [year] 的总放假天数
  ///
  /// 若提供 [near] 日期，则仅在该日期前后 30 天内搜索，避免遍历全年。
  static int getHolidayTotalDays(
    String holidayName,
    int year, {
    DateTime? near,
  }) {
    return _totalDaysCache
        .putIfAbsent(year, () => {})
        .putIfAbsent(
          holidayName,
          () => _computeHolidayTotalDays(holidayName, year, near: near),
        );
  }

  static int _computeHolidayTotalDays(
    String holidayName,
    int year, {
    DateTime? near,
  }) {
    int count = 0;

    if (near != null) {
      // date 本身必定是节假日，向前往后遍历直到非节假日或不同假日名称
      count = 1;
      // 向前遍历
      var d = near.subtract(const Duration(days: 1));
      while (d.year == year) {
        try {
          final legalHoliday = SolarDay(
            d.year,
            d.month,
            d.day,
          ).getLegalHoliday();
          if (legalHoliday == null ||
              legalHoliday.isWork() ||
              legalHoliday.getName() != holidayName) {
            break;
          }
          count++;
        } catch (_) {
          break;
        }
        d = d.subtract(const Duration(days: 1));
      }
      // 向后遍历
      d = near.add(const Duration(days: 1));
      while (d.year == year) {
        try {
          final legalHoliday = SolarDay(
            d.year,
            d.month,
            d.day,
          ).getLegalHoliday();
          if (legalHoliday == null ||
              legalHoliday.isWork() ||
              legalHoliday.getName() != holidayName) {
            break;
          }
          count++;
        } catch (_) {
          break;
        }
        d = d.add(const Duration(days: 1));
      }
    } else {
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
    // 1. 法定假日（tyme）
    try {
      final solarDay = SolarDay(date.year, date.month, date.day);
      final legalHoliday = solarDay.getLegalHoliday();
      if (legalHoliday != null) {
        if (!legalHoliday.isWork()) {
          final totalDays = getHolidayTotalDays(
            legalHoliday.getName(),
            date.year,
            near: date,
          );
          return SpecialDayInfo(
            type: SpecialDayType.holiday,
            name: legalHoliday.getName(),
            holidayTotalDays: totalDays,
          );
        }
        // tyme 标记为上班 → 不放假，不继续降级
      } else {
        // 1b. 兜底：固定日期法定假日（tyme 无数据）
        final fallback = _getFixedHolidayFallback(date);
        if (fallback != null) {
          return SpecialDayInfo(type: SpecialDayType.holiday, name: fallback);
        }
      }
    } catch (_) {
      // tyme 异常 → 尝试固定日期兜底
      final fallback = _getFixedHolidayFallback(date);
      if (fallback != null) {
        return SpecialDayInfo(type: SpecialDayType.holiday, name: fallback);
      }
    }

    // 2. 节日 + 节气
    try {
      final solarDay = SolarDay(date.year, date.month, date.day);

      // 2a. 节日（公历 + 农历，跳过春节清明）
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

      // 2b. 节气（仅当天）
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
