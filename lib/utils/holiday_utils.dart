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
/// 包含常见法定节假日列表，由于国务院每年公布具体安排，
/// 这里仅包含近年的主要节日日期。用户可在 UI 中自行增删。
class HolidayUtils {
  HolidayUtils._();

  /// 法定节假日名称 → 日期集合（月-日，跨年通用）
  ///
  /// 农历节日（春节、清明、端午、中秋）的公历日期每年变化，
  /// 请在 [byYear] 中按年补充具体日期。
  static const Map<String, Set<String>> _fixedHolidays = {
    '元旦': {'01-01'},
    '劳动节': {'05-01'},
    '国庆节': {'10-01', '10-02', '10-03'},
    '清明节': {'04-04', '04-05'},
  };

  /// 按年份补充的农历节日具体日期（公历）
  static const Map<int, Map<String, Set<String>>> byYear = {
    2024: {
      '春节': {'02-10', '02-11', '02-12', '02-13', '02-14', '02-15', '02-16'},
      '清明节': {'04-04'},
      '端午节': {'06-08', '06-09', '06-10'},
      '中秋节': {'09-15', '09-16', '09-17'},
      '国庆节': {'10-01', '10-02', '10-03', '10-04', '10-05', '10-06', '10-07'},
    },
    2025: {
      '元旦': {'01-01'},
      '春节': {
        '01-28',
        '01-29',
        '01-30',
        '01-31',
        '02-01',
        '02-02',
        '02-03',
        '02-04',
      },
      '清明节': {'04-04', '04-05', '04-06'},
      '劳动节': {'05-01', '05-02', '05-03', '05-04', '05-05'},
      '端午节': {'05-31', '06-01', '06-02'},
      '中秋节': {'10-06'},
      '国庆节': {
        '10-01',
        '10-02',
        '10-03',
        '10-04',
        '10-05',
        '10-06',
        '10-07',
        '10-08',
      },
    },
    2026: {
      '春节': {'02-15', '02-16', '02-17', '02-18', '02-19', '02-20', '02-21'},
      '清明节': {'04-04', '04-05', '04-06'},
      '劳动节': {'05-01', '05-02', '05-03', '05-04', '05-05'},
      '端午节': {'06-19', '06-20', '06-21'},
      '中秋节': {'10-04'},
      '国庆节': {'10-01', '10-02', '10-03', '10-04', '10-05', '10-06', '10-07'},
    },
  };

  /// 判断 [date] 是否是法定节假日
  static bool isStatutoryHoliday(DateTime date) {
    return getHolidayName(date) != null;
  }

  /// 获取 [date] 对应的法定节假日名称，如 '国庆节'
  /// 如果不是法定节假日则返回 null
  static String? getHolidayName(DateTime date) {
    final mmdd = _mmdd(date);
    final year = date.year;

    // 先查当年按年补充的
    final yearMap = byYear[year];
    if (yearMap != null) {
      for (final entry in yearMap.entries) {
        if (entry.value.contains(mmdd)) return entry.key;
      }
    }

    // 再查固定节假日
    for (final entry in _fixedHolidays.entries) {
      if (entry.value.contains(mmdd)) return entry.key;
    }

    return null;
  }

  /// 获取 [holidayName] 在 [year] 的总假期天数
  static int getHolidayTotalDays(String holidayName, int year) {
    final yearMap = byYear[year];
    if (yearMap != null && yearMap.containsKey(holidayName)) {
      return yearMap[holidayName]!.length;
    }
    return _fixedHolidays[holidayName]?.length ?? 0;
  }

  /// 不放假但值得标记的传统节日（按年）
  static const Map<int, Map<String, Set<String>>> festivalsByYear = {
    2024: {
      '元宵节': {'02-24'},
      '七夕节': {'08-10'},
      '重阳节': {'10-11'},
    },
    2025: {
      '元宵节': {'02-12'},
      '七夕节': {'08-29'},
      '重阳节': {'10-29'},
    },
    2026: {
      '元宵节': {'03-03'},
      '七夕节': {'08-19'},
      '重阳节': {'10-18'},
    },
  };

  /// 固定日期节日（不放假）
  static const Map<String, Set<String>> _fixedFestivals = {
    '植树节': {'03-12'},
    '儿童节': {'06-01'},
    '建党节': {'07-01'},
    '建军节': {'08-01'},
    '教师节': {'09-10'},
  };

  /// 二十四节气（近似日期，月-日）
  static const Map<String, String> _solarTerms = {
    '立春': '02-04',
    '雨水': '02-19',
    '惊蛰': '03-06',
    '春分': '03-21',
    '清明': '04-05',
    '谷雨': '04-20',
    '立夏': '05-06',
    '小满': '05-21',
    '芒种': '06-06',
    '夏至': '06-21',
    '小暑': '07-07',
    '大暑': '07-23',
    '立秋': '08-07',
    '处暑': '08-23',
    '白露': '09-08',
    '秋分': '09-23',
    '寒露': '10-08',
    '霜降': '10-23',
    '立冬': '11-07',
    '小雪': '11-22',
    '大雪': '12-07',
    '冬至': '12-22',
    '小寒': '01-06',
    '大寒': '01-20',
  };

  /// 判断 [date] 是否为标记节日（不放假）
  static bool isFestival(DateTime date) {
    return getFestivalName(date) != null;
  }

  /// 获取 [date] 对应的节日名称，如 '元宵节'
  static String? getFestivalName(DateTime date) {
    final mmdd = _mmdd(date);
    // 先查按年补充的传统节日
    final yearMap = festivalsByYear[date.year];
    if (yearMap != null) {
      for (final entry in yearMap.entries) {
        if (entry.value.contains(mmdd)) return entry.key;
      }
    }
    // 再查固定日期节日
    for (final entry in _fixedFestivals.entries) {
      if (entry.value.contains(mmdd)) return entry.key;
    }
    return null;
  }

  /// 判断 [date] 是否为节气
  static bool isSolarTerm(DateTime date) {
    return getSolarTermName(date) != null;
  }

  /// 获取 [date] 对应的节气名称，如 '立春'
  static String? getSolarTermName(DateTime date) {
    final mmdd = _mmdd(date);
    for (final entry in _solarTerms.entries) {
      if (entry.value == mmdd) return entry.key;
    }
    return null;
  }

  /// 获取 [date] 对应的特殊日信息（含类型、名称、备注等）
  ///
  /// 优先级：假 > 节 > 气 > 普通日
  static SpecialDayInfo getSpecialDay(DateTime date) {
    final holidayName = getHolidayName(date);
    if (holidayName != null) {
      final totalDays = getHolidayTotalDays(holidayName, date.year);
      return SpecialDayInfo(
        type: SpecialDayType.holiday,
        name: holidayName,
        subtitle: '共$totalDays天假',
      );
    }

    final festivalName = getFestivalName(date);
    if (festivalName != null) {
      return SpecialDayInfo(type: SpecialDayType.festival, name: festivalName);
    }

    final termName = getSolarTermName(date);
    if (termName != null) {
      return SpecialDayInfo(type: SpecialDayType.solarTerm, name: termName);
    }

    return SpecialDayInfo(type: SpecialDayType.ordinary);
  }

  /// 格式化日期为 MM-DD 字符串
  static String _mmdd(DateTime d) =>
      '${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
