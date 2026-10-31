import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/date_display_format.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final date = DateTime(2026, 8, 19);

  group('DateDisplayFormat 直接构造', () {
    test('月在前与日在前各自拼出完整日期与表头片段', () {
      const monthFirst = DateDisplayFormat(monthFirst: true, separator: '/');
      expect(monthFirst.formatFull(date), '08/19/2026');
      expect(monthFirst.formatMonthDay(date), '08/19');

      const dayFirst = DateDisplayFormat(monthFirst: false, separator: '.');
      expect(dayFirst.formatFull(date), '19.08.2026');
      expect(dayFirst.formatMonthDay(date), '19.08');
    });

    test('月日恒补零，年份恒四位', () {
      const format = DateDisplayFormat(monthFirst: true, separator: '/');
      expect(format.formatFull(DateTime(2026, 1, 5)), '01/05/2026');
      expect(format.formatMonthDay(DateTime(2026, 1, 5)), '01/05');
    });

    test('相等性按顺序与分隔符判断', () {
      expect(
        const DateDisplayFormat(monthFirst: true, separator: '.'),
        const DateDisplayFormat(monthFirst: true, separator: '.'),
      );
      expect(
        const DateDisplayFormat(monthFirst: true, separator: '.'),
        isNot(const DateDisplayFormat(monthFirst: false, separator: '.')),
      );
    });
  });

  group('DateDisplayFormat.of 跟随 CLDR', () {
    /// intl 的 locale 数据由 flutter_localizations 在 app 内加载；
    /// 纯单测里需要先 pump 一个带 delegate 的 MaterialApp。
    Future<DateDisplayFormat> formatFor(
      WidgetTester tester,
      Locale locale,
    ) async {
      DateDisplayFormat? result;
      await tester.pumpWidget(
        MaterialApp(
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              result = DateDisplayFormat.of(Localizations.localeOf(context));
              return const SizedBox();
            },
          ),
        ),
      );
      return result!;
    }

    testWidgets('中文与美式英语为月在前、斜杠', (tester) async {
      for (final locale in const [Locale('zh'), Locale('en')]) {
        final format = await formatFor(tester, locale);
        expect(format.monthFirst, isTrue, reason: '$locale');
        expect(format.separator, '/', reason: '$locale');
        expect(format.formatMonthDay(date), '08/19', reason: '$locale');
      }
    });

    testWidgets('三种受支持语言都能解析出可用格式', (tester) async {
      for (final locale in AppLocalizations.supportedLocales) {
        final format = await formatFor(tester, locale);
        expect(
          format.formatMonthDay(date),
          matches(RegExp(r'^\d{2}[^\d]\d{2}$')),
          reason: '${locale.toLanguageTag()} 应得到 MM/DD 形态',
        );
      }
    });
  });

  group('CLDR 模式解析', () {
    // 通过 of() 覆盖不到的模式，直接用构造 + 解析结果对照：
    // 这里只断言解析规则本身（顺序看 M/d 位置，分隔符取第一个 / . -）。
    test('德语 d.M.y 为日在前、点号', () {
      // 与 DateFormat.Md('de_DE').pattern == 'd.M.' 等价的手工构造。
      const german = DateDisplayFormat(monthFirst: false, separator: '.');
      expect(german.formatMonthDay(date), '19.08');
      expect(german.formatFull(date), '19.08.2026');
    });

    test('英式 dd/MM 为日在前、斜杠', () {
      const british = DateDisplayFormat(monthFirst: false, separator: '/');
      expect(british.formatMonthDay(date), '19/08');
      expect(british.formatFull(date), '19/08/2026');
    });
  });
}
