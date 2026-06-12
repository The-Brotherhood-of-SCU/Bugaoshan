// 这个库是为了在iOS上使用CupertinoPageTransitionsBuilder，flutter新版已经分离出来了，不要删
import 'package:flutter/cupertino.dart';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/pages/home_page.dart';
import 'package:bugaoshan/pages/wizard/eula_gate_page.dart';
import 'package:bugaoshan/pages/wizard/wizard_page.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/services/background_cache_service.dart';
import 'package:bugaoshan/theme/m3e_tokens.dart';
import 'package:bugaoshan/theme/semantic_colors.dart';
import 'package:bugaoshan/widgets/common/session_expired_listener.dart';
import 'package:bugaoshan/widgets/eula_content.dart';
import 'package:bugaoshan/widgets/route/mouse_back_handler.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:system_theme/system_theme.dart';
import 'l10n/app_localizations.dart';

const _pageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    //desktop use FadeForwardsPageTransitionsBuilder
    TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
  },
);

const _appBarTheme = AppBarTheme(
  toolbarHeight: 48,
  centerTitle: false,
  scrolledUnderElevation: 0,
);

const _navigationBarTheme = NavigationBarThemeData(height: 64);

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
    final colorScheme = ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    );
    final baseTheme = ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      pageTransitionsTheme: _pageTransitionsTheme,
      appBarTheme: _appBarTheme,
      navigationBarTheme: _navigationBarTheme,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: const EdgeInsets.only(bottom: 16),
        shape: AppShapes.outlined(
          radius: AppRadius.lg,
          outlineColor: colorScheme.outline.withValues(alpha: 0.2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(20)),
          ),
        ),
      ),
      extensions: <ThemeExtension<dynamic>>[
        brightness == Brightness.dark
            ? SemanticColors.dark
            : SemanticColors.light,
      ],
    );

    TextTheme textTheme = baseTheme.textTheme;
    if (_appConfig.useGoogleFonts.value) {
      textTheme = GoogleFonts.notoSansScTextTheme(textTheme);
    }
    return baseTheme.copyWith(textTheme: textTheme);
  }
}
