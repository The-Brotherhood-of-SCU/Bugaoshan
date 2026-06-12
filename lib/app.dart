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
import 'package:bugaoshan/utils/app_shapes.dart';
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

/// MD3 Expressive 组件形状覆盖
const _cardTheme = CardThemeData(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppShapes.largeIncreased)),
  ),
);

const _dialogTheme = DialogThemeData(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppShapes.extraLarge)),
  ),
);

const _bottomSheetTheme = BottomSheetThemeData(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(AppShapes.extraLarge),
    ),
  ),
);

const _chipTheme = ChipThemeData(shape: StadiumBorder());

const _filledButtonTheme = FilledButtonThemeData(
  style: ButtonStyle(shape: WidgetStatePropertyAll(StadiumBorder())),
);

const _elevatedButtonTheme = ElevatedButtonThemeData(
  style: ButtonStyle(shape: WidgetStatePropertyAll(StadiumBorder())),
);

const _outlinedButtonTheme = OutlinedButtonThemeData(
  style: ButtonStyle(shape: WidgetStatePropertyAll(StadiumBorder())),
);

const _textButtonTheme = TextButtonThemeData(
  style: ButtonStyle(shape: WidgetStatePropertyAll(StadiumBorder())),
);

const _snackBarTheme = SnackBarThemeData(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppShapes.medium)),
  ),
);

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
    final baseTheme = ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor,
        brightness: brightness,
      ),
      pageTransitionsTheme: _pageTransitionsTheme,
      appBarTheme: _appBarTheme,
      navigationBarTheme: _navigationBarTheme,
      // MD3 Expressive 组件形状覆盖
      cardTheme: _cardTheme,
      dialogTheme: _dialogTheme,
      bottomSheetTheme: _bottomSheetTheme,
      chipTheme: _chipTheme,
      filledButtonTheme: _filledButtonTheme,
      elevatedButtonTheme: _elevatedButtonTheme,
      outlinedButtonTheme: _outlinedButtonTheme,
      textButtonTheme: _textButtonTheme,
      snackBarTheme: _snackBarTheme,
    );

    TextTheme textTheme = baseTheme.textTheme;
    if (_appConfig.useGoogleFonts.value) {
      textTheme = GoogleFonts.notoSansScTextTheme(textTheme);
    }
    return baseTheme.copyWith(textTheme: textTheme);
  }
}
