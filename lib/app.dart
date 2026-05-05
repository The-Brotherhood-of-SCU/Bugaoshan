import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/pages/home_page.dart';
import 'package:bugaoshan/pages/wizard/wizard_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:system_theme/system_theme.dart';
import 'l10n/app_localizations.dart';

const _pageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
  },
);

const _appBarTheme = AppBarTheme(
  toolbarHeight: 48,
  centerTitle: true,
  scrolledUnderElevation: 0,
);

const _navigationBarTheme = NavigationBarThemeData(height: 64);

class MyApp extends StatelessWidget {
  MyApp({super.key});

  final AppConfigProvider _appConfig = getIt<AppConfigProvider>();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _appConfig.locale,
        _appConfig.themeColor,
        _appConfig.themeColorMode,
      ]),
      builder: (context, _) => MaterialApp(
        navigatorKey: navigatorKey,
        locale: _appConfig.locale.value,
        onGenerateTitle: (ctx) => AppLocalizations.of(ctx)!.bugaoshan,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: _buildTheme(Brightness.light),
        darkTheme: _buildTheme(Brightness.dark),
        themeMode: ThemeMode.system,
        home: ValueListenableBuilder<bool>(
          valueListenable: _appConfig.firstLaunchWizardCompleted,
          builder: (_, completed, _) =>
              completed ? const HomePage() : const WizardPage(),
        ),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final seedColor = _appConfig.themeColorMode.value == ThemeColorMode.system
        ? SystemTheme.accentColor.accent
        : _appConfig.themeColor.value;
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
      ),
      pageTransitionsTheme: _pageTransitionsTheme,
      appBarTheme: _appBarTheme,
      navigationBarTheme: _navigationBarTheme,
    );

    return baseTheme.copyWith(
      textTheme: GoogleFonts.notoSansScTextTheme(baseTheme.textTheme),
    );
  }
}
