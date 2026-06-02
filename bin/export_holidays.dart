import 'dart:io';
import 'package:bugaoshan/utils/holiday_utils.dart';

/// 将 HolidayUtils 中所有节假日/节气/节日数据导出为 CSV
void main() {
  final file = File('holidays_export.csv');
  final buf = StringBuffer();

  // CSV header with BOM for Excel UTF-8 compatibility
  buf.write('\uFEFF');
  buf.writeln('年份,月-日,类型,名称,备注');

  final allDates = <DateTime>{};

  // 遍历所有年份的所有日期，收集非普通日
  for (final year in [2024, 2025, 2026]) {
    for (var month = 1; month <= 12; month++) {
      final daysInMonth = DateTime(year, month + 1, 0).day;
      for (var day = 1; day <= daysInMonth; day++) {
        try {
          final date = DateTime(year, month, day);
          final info = HolidayUtils.getSpecialDay(date);
          if (info.type.name != 'ordinary') {
            allDates.add(date);
          }
        } catch (_) {}
      }
    }
  }

  // 排序输出
  final sorted = allDates.toList()..sort();
  for (final date in sorted) {
    final info = HolidayUtils.getSpecialDay(date);
    final mmdd =
        '${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
    final typeLabel = switch (info.type) {
      SpecialDayType.holiday => '法定假日',
      SpecialDayType.festival => '传统/纪念日',
      SpecialDayType.solarTerm => '节气',
      SpecialDayType.ordinary => '普通日',
    };
    buf.writeln(
      '${date.year},$mmdd,$typeLabel,${info.name ?? ''},${info.subtitle ?? ''}',
    );
  }

  file.writeAsStringSync(buf.toString());
  print('✅ CSV 已导出: ${file.absolute.path}');
  print('共 ${sorted.length} 条记录');
}
