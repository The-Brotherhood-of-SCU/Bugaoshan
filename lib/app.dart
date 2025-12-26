import 'package:flutter/material.dart';
import 'package:rubbish_plan/injection/injector.dart';
import 'package:rubbish_plan/pages/home_page.dart';
import 'package:rubbish_plan/serivces/app_config_service.dart';
import 'package:rubbish_plan/widgets/route/router_utils.dart';
import 'l10n/app_localizations.dart';

class MyApp extends StatelessWidget {
  MyApp({super.key});
  final AppConfigService appConfigService = getIt<AppConfigService>();

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
      onGenerateTitle: (context) => AppLocalizations.of(context)!.rubbishPlan,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      title: 'Rubbish Plan',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: appConfigService.themeColor.value,
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: appConfigService.themeColor.value,
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
      home: HomePage(),
    );
  }
}
