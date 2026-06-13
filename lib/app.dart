// 这个库是为了在iOS上使用CupertinoPageTransitionsBuilder，flutter新版已经分离出来了，不要删
import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/pages/home_page.dart';
import 'package:bugaoshan/pages/wizard/eula_gate_page.dart';
import 'package:bugaoshan/pages/wizard/wizard_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/services/background_cache_service.dart';
import 'package:bugaoshan/theme.dart';
import 'package:bugaoshan/widgets/common/session_expired_listener.dart';
import 'package:bugaoshan/widgets/eula_content.dart';
import 'package:bugaoshan/widgets/route/mouse_back_handler.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:system_theme/system_theme.dart';
import 'l10n/app_localizations.dart';

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final AppConfigProvider _appConfig = getIt<AppConfigProvider>();
  late final BackgroundCacheService _bgCache = getIt<BackgroundCacheService>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _bgCache.precache();
    });
  }

  @override
  void dispose() {
    _bgCache.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        _appConfig.locale,
        _appConfig.themeColor,
        _appConfig.themeColorMode,
        _appConfig.useGoogleFonts,
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
        builder: (context, child) => MouseBackHandler(
          child: SessionExpiredListener(child: child ?? const SizedBox()),
        ),
        home: ValueListenableBuilder<int>(
          valueListenable: _appConfig.acceptedEulaVersion,
          builder: (_, eulaVersion, _) {
            if (eulaVersion < currentEulaVersion) {
              return const EulaGatePage();
            }
            return ValueListenableBuilder<bool>(
              valueListenable: _appConfig.firstLaunchWizardCompleted,
              builder: (_, completed, _) =>
                  completed ? const HomePage() : const WizardPage(),
            );
          },
        ),
      ),
    );
  }

  ThemeData _buildTheme(Brightness brightness) {
    final seedColor = _appConfig.themeColorMode.value == ThemeColorMode.system
        ? SystemTheme.accentColor.accent
        : _appConfig.themeColor.value;
    return buildTheme(
      brightness: brightness,
      seedColor: seedColor,
      useGoogleFonts: _appConfig.useGoogleFonts.value,
    );
  }
}
