import 'package:bugaoshan/models/date_display_format.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('DateDisplayFormat', () {
    final date = DateTime(2026, 8, 19);

    test('完整日期的排列与分隔符', () {
      const expected = {
        DateDisplayFormat.dayMonthShortYearSlash: '19/8/26',
        DateDisplayFormat.dayMonthYearSlash: '19/08/2026',
        DateDisplayFormat.monthDayShortYearSlash: '8/19/26',
        DateDisplayFormat.monthDayYearSlash: '8/19/2026',
        DateDisplayFormat.dayMonthYearDot: '19.08.2026',
        DateDisplayFormat.dayMonthYearDash: '19-08-2026',
        DateDisplayFormat.yearMonthDaySlash: '2026/8/19',
        DateDisplayFormat.yearMonthDayDot: '2026.08.19',
        DateDisplayFormat.yearMonthDayDash: '2026-08-19',
      };
      // 枚举顺序即下拉顺序，新增格式时必须同步这里。
      expect(expected.keys.toList(), DateDisplayFormat.values);

      for (final entry in expected.entries) {
        expect(entry.key.formatFull(date), entry.value);
      }
    });

    test('表头片段沿用顺序、分隔符与补零规则，只丢掉年份', () {
      expect(DateDisplayFormat.dayMonthYearDot.formatMonthDay(date), '19.08');
      expect(DateDisplayFormat.yearMonthDayDash.formatMonthDay(date), '08-19');
      expect(DateDisplayFormat.monthDayYearSlash.formatMonthDay(date), '8/19');
    });

    test('月日补零只影响日月，两位年份仍按短年取后两位', () {
      expect(
        DateDisplayFormat.dayMonthShortYearSlash.formatFull(
          DateTime(2026, 1, 5),
        ),
        '5/1/26',
      );
      expect(
        DateDisplayFormat.dayMonthYearSlash.formatFull(DateTime(2026, 1, 5)),
        '05/01/2026',
      );
    });
  });

  group('AppConfigProvider.dateDisplayFormat', () {
    test('缺省为「月/日/年」并持久化用户选择', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final provider = AppConfigProvider(preferences);
      await provider.init();

      expect(
        provider.dateDisplayFormat.value,
        DateDisplayFormat.monthDayYearSlash,
      );

      provider.dateDisplayFormat.value = DateDisplayFormat.dayMonthYearDot;

      expect(
        preferences.getInt('dateDisplayFormat'),
        DateDisplayFormat.dayMonthYearDot.index,
      );
    });

    test('越界的已存索引回落默认值', () async {
      SharedPreferences.setMockInitialValues({'dateDisplayFormat': 99});
      final preferences = await SharedPreferences.getInstance();
      final provider = AppConfigProvider(preferences);
      await provider.init();

      expect(
        provider.dateDisplayFormat.value,
        DateDisplayFormat.monthDayYearSlash,
      );
    });
  });
}
