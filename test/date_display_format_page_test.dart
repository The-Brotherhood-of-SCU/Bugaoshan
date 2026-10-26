import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/date_display_format.dart';
import 'package:bugaoshan/pages/settings/set_date_display_format_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<AppConfigProvider> _registerAppConfig({
  Map<String, Object> initial = const {},
}) async {
  SharedPreferences.setMockInitialValues(initial);
  final preferences = await SharedPreferences.getInstance();
  final appConfig = AppConfigProvider(preferences);
  await appConfig.init();
  getIt.registerSingleton<AppConfigProvider>(appConfig);
  return appConfig;
}

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('zh'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: child,
);

void main() {
  tearDown(getIt.reset);
  setUp(getIt.reset);

  testWidgets('下拉列出九种格式，选中项写回设置', (tester) async {
    final appConfig = await _registerAppConfig();

    await tester.pumpWidget(_wrap(const SetDateDisplayFormatPage()));
    await tester.pumpAndSettle();

    final today = DateTime.now();
    // 收起状态下只显示当前选中项的完整日期。
    expect(
      find.text(DateDisplayFormat.monthDayYearSlash.formatFull(today)),
      findsOneWidget,
    );

    await tester.tap(find.byType(DropdownButtonFormField<DateDisplayFormat>));
    await tester.pumpAndSettle();

    final expected = DateDisplayFormat.dayMonthYearDot.formatFull(today);
    await tester.tap(find.text(expected).last);
    await tester.pumpAndSettle();

    expect(
      appConfig.dateDisplayFormat.value,
      DateDisplayFormat.dayMonthYearDot,
    );
    // 示例行同步显示完整日期与表头片段。
    final l10n = AppLocalizations.of(
      tester.element(find.byType(SetDateDisplayFormatPage)),
    )!;
    expect(
      find.text(
        l10n.dateFormatSamples(
          expected,
          DateDisplayFormat.dayMonthYearDot.formatMonthDay(today),
        ),
      ),
      findsOneWidget,
    );
  });

  testWidgets('下拉包含全部九项', (tester) async {
    await _registerAppConfig();

    await tester.pumpWidget(_wrap(const SetDateDisplayFormatPage()));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<DateDisplayFormat>));
    await tester.pumpAndSettle();

    final today = DateTime.now();
    for (final format in DateDisplayFormat.values) {
      expect(
        find.text(format.formatFull(today)),
        findsWidgets,
        reason: '${format.name} 应出现在下拉中',
      );
    }
  });
}
