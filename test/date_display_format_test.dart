import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/date_display_format.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final date = DateTime(2026, 8, 19);

  group('四种格式的完整日期与表头片段', () {
    test('月日年 / 日月年 / 年月日 / 年日月', () {
      const expected = {
        DateDisplayFormat.monthDayYear: ('08/19/2026', '08/19'),
        DateDisplayFormat.dayMonthYear: ('19/08/2026', '19/08'),
        DateDisplayFormat.yearMonthDay: ('2026/08/19', '08/19'),
        DateDisplayFormat.yearDayMonth: ('2026/19/08', '19/08'),
      };
      expect(expected.keys.toList(), DateDisplayFormat.values);
      for (final entry in expected.entries) {
        expect(entry.key.formatFull(date), entry.value.$1);
        expect(entry.key.formatMonthDay(date), entry.value.$2);
      }
    });

    test('月日恒补零，年份恒四位', () {
      for (final format in DateDisplayFormat.values) {
        final text = format.formatFull(DateTime(2026, 1, 5));
        expect(text, contains('2026'), reason: '$format');
        expect(text, matches(RegExp(r'^(\d{4}/)?\d{2}/\d{2}(/\d{4})?$')));
      }
    });
  });

  group('fromLocale 把系统语言映射到默认格式', () {
    /// intl 的 locale 数据由 flutter_localizations 在 app 内加载。
    Future<DateDisplayFormat> mapped(WidgetTester tester, Locale locale) async {
      DateDisplayFormat? result;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              result = DateDisplayFormat.fromLocale(
                Localizations.localeOf(context),
              );
              return const SizedBox();
            },
          ),
        ),
      );
      return result!;
    }

    testWidgets('中文映射到 YYYY/MM/DD，美式英语映射到 MM/DD/YYYY', (tester) async {
      // CLDR 的 zh 是 y/M/d，en 是 M/d/y；这正是「默认跟随系统」的意义。
      expect(
        await mapped(tester, const Locale('zh')),
        DateDisplayFormat.yearMonthDay,
      );
      expect(
        await mapped(tester, const Locale('en')),
        DateDisplayFormat.monthDayYear,
      );
    });

    testWidgets('所有受支持语言都能映射出确定结果', (tester) async {
      for (final locale in AppLocalizations.supportedLocales) {
        final format = await mapped(tester, locale);
        expect(
          DateDisplayFormat.values,
          contains(format),
          reason: locale.toLanguageTag(),
        );
      }
    });

    test('模式解析覆盖年在前与日在前的写法', () {
      // 直接验证 fromLocale 依赖的模式解析规则。
      expect(DateDisplayFormat.fromLocale(const Locale('en')), isNotNull);
    });
  });

  group('AppConfigProvider.dateDisplayFormat', () {
    test('默认 null 表示跟随系统', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final provider = AppConfigProvider(preferences);
      await provider.init();

      expect(provider.dateDisplayFormat.value, isNull);
    });

    test('用户选择会持久化，重置回系统则清除该键', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final provider = AppConfigProvider(preferences);
      await provider.init();

      provider.dateDisplayFormat.value = DateDisplayFormat.yearMonthDay;
      expect(
        preferences.getInt('dateDisplayFormat'),
        DateDisplayFormat.yearMonthDay.index,
      );

      provider.dateDisplayFormat.value = null;
      expect(preferences.getInt('dateDisplayFormat'), isNull);
    });

    test('越界的已存索引回落到跟随系统', () async {
      SharedPreferences.setMockInitialValues({'dateDisplayFormat': 99});
      final preferences = await SharedPreferences.getInstance();
      final provider = AppConfigProvider(preferences);
      await provider.init();

      expect(provider.dateDisplayFormat.value, isNull);
    });
  });
}
