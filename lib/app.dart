import 'package:flutter/material.dart';
import 'package:Bugaoshan/injection/injector.dart';
import 'package:Bugaoshan/pages/home_page.dart';
import 'package:Bugaoshan/providers/app_config_provider.dart';
import 'package:Bugaoshan/widgets/route/router_utils.dart';
import 'l10n/app_localizations.dart';

class MyApp extends StatelessWidget {
  MyApp({super.key});
  final AppConfigProvider appConfigService = getIt<AppConfigProvider>();

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        appConfigService.locale,
        appConfigService.themeColor,
      ]),
      builder: (context, child) {
        return _build(context);
      },
    );
  }

  Widget _build(BuildContext context) {
    return MaterialApp(
      navigatorKey: navigatorKey,
      locale: appConfigService.locale.value,
      onGenerateTitle: (context) => AppLocalizations.of(context)!.bugaoshan,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      title: 'Bugaoshan',
      theme: _buildTheme(Brightness.light),
      darkTheme: _buildTheme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: HomePage(),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    return ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: appConfigService.themeColor.value,
        brightness: brightness,
      ),
      appBarTheme: const AppBarTheme(
        toolbarHeight: 48,
        centerTitle: true,
        scrolledUnderElevation: 0,
      ),
      navigationBarTheme: const NavigationBarThemeData(height: 64),
    );
  }
}
