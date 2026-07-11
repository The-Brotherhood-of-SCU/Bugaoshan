import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/settings/add_widget/add_widget_page.dart';
import 'package:bugaoshan/services/widget_update_service.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';

class FakeWidgetUpdateService implements WidgetUpdateService {
  String? lastSizeArg;

  @override
  Future<void> updateWidgetData({bool force = false}) async {}

  @override
  void dispose() {}

  @override
  Future<bool> pinWidget(String size) async {
    lastSizeArg = size;
    return true;
  }

  @override
  Future<bool> isIgnoringBatteryOptimizations() async => true;

  @override
  Future<bool> requestIgnoreBatteryOptimizations() async => true;
}

void main() {
  setUp(() async {
    await getIt.reset();

    // 设置 Mock SharedPreferences
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final appConfigProvider = AppConfigProvider(prefs);

    // 注册依赖
    getIt.registerSingleton<AppConfigProvider>(appConfigProvider);
    getIt.registerSingleton<WidgetUpdateService>(FakeWidgetUpdateService());
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('AddWidget picker default, change selection and pin', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SingleChildScrollView(
            child: AddWidgetContent(showDescription: false),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(AddWidgetContent)),
    )!;

    final fake = getIt<WidgetUpdateService>() as FakeWidgetUpdateService;

    // Press add with default selection (small)
    await tester.tap(find.text(l10n.pinWidgetButton));
    await tester.pumpAndSettle();
    expect(fake.lastSizeArg, equals('small'));

    // Select medium and pin
    await tester.tap(find.text(l10n.widgetSizeMedium));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.pinWidgetButton));
    await tester.pumpAndSettle();
    expect(fake.lastSizeArg, equals('medium'));

    // Select large and pin
    await tester.tap(find.text(l10n.widgetSizeLarge));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.pinWidgetButton));
    await tester.pumpAndSettle();
    expect(fake.lastSizeArg, equals('large'));
  });
}
