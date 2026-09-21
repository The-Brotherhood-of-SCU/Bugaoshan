import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme_shape.dart';

/// 页面转场时长跟随「设置 → 动画时长」滑杆（进页与退出同值）；转场形态
/// 维持 Material 规格不变。不直接用规格默认值的原因：Flutter 3.44 起
/// MaterialPageRoute 的时长改由 PageTransitionsBuilder 决定且退出默认等于
/// 进页时长（450-500ms），返回期间退出页占据整屏、下层页面要等动画结束才
/// 能跟手滚动，窗口偏长。
///
/// 注意：「动画时长」页里的「页面切换动画」开关只控制 Dock 栏页面切换动画
/// （见 home_page.dart → AuthScopedIndexedStack），不影响这里的全局转场。
class _AppFadeForwardsBuilder extends FadeForwardsPageTransitionsBuilder {
  const _AppFadeForwardsBuilder(this.duration);

  final Duration duration;

  @override
  Duration get transitionDuration => duration;

  @override
  Duration get reverseTransitionDuration => duration;
}

class _AppPredictiveBackBuilder extends PredictiveBackPageTransitionsBuilder {
  const _AppPredictiveBackBuilder(this.duration);

  final Duration duration;

  @override
  Duration get transitionDuration => duration;

  @override
  Duration get reverseTransitionDuration => duration;
}

class _AppCupertinoBuilder extends CupertinoPageTransitionsBuilder {
  const _AppCupertinoBuilder(this.duration);

  final Duration duration;

  @override
  Duration get transitionDuration => duration;

  @override
  Duration get reverseTransitionDuration => duration;
}

PageTransitionsTheme _pageTransitionsTheme(Duration duration) {
  return PageTransitionsTheme(
    builders: {
      TargetPlatform.android: _AppPredictiveBackBuilder(duration),
      TargetPlatform.iOS: _AppCupertinoBuilder(duration),
      //desktop use FadeForwardsPageTransitionsBuilder
      TargetPlatform.windows: _AppFadeForwardsBuilder(duration),
      TargetPlatform.linux: _AppFadeForwardsBuilder(duration),
      TargetPlatform.macOS: _AppFadeForwardsBuilder(duration),
    },
  );
}

AppBarTheme appBarTheme({double textScale = 1.0}) => AppBarTheme(
  toolbarHeight: 48 * textScale,
  centerTitle: false,
  scrolledUnderElevation: 0,
);

NavigationBarThemeData navigationBarTheme({double textScale = 1.0}) =>
    NavigationBarThemeData(height: 64 * textScale);

/// MD3 Expressive 组件形状覆盖
const cardTheme = CardThemeData(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppShapes.largeIncreased)),
  ),
);

const dialogTheme = DialogThemeData(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(AppShapes.extraLarge)),
  ),
);

const bottomSheetTheme = BottomSheetThemeData(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(
      top: Radius.circular(AppShapes.extraLarge),
    ),
  ),
);

const chipTheme = ChipThemeData(shape: StadiumBorder());

const filledButtonTheme = FilledButtonThemeData(
  style: ButtonStyle(shape: WidgetStatePropertyAll(StadiumBorder())),
);

const elevatedButtonTheme = ElevatedButtonThemeData(
  style: ButtonStyle(shape: WidgetStatePropertyAll(StadiumBorder())),
);

const outlinedButtonTheme = OutlinedButtonThemeData(
  style: ButtonStyle(shape: WidgetStatePropertyAll(StadiumBorder())),
);

const textButtonTheme = TextButtonThemeData(
  style: ButtonStyle(shape: WidgetStatePropertyAll(StadiumBorder())),
);

const snackBarTheme = SnackBarThemeData();

final listTileTheme = ListTileThemeData(
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(AppShapes.large),
  ),
);

final dropdownMenuTheme = DropdownMenuThemeData();

ThemeData buildTheme({
  required Brightness brightness,
  required Color seedColor,
  bool useGoogleFonts = false,
  double textScale = 1.0,
  Duration pageTransitionDuration = const Duration(milliseconds: 300),
}) {
  final baseTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    ),
    pageTransitionsTheme: _pageTransitionsTheme(pageTransitionDuration),
    appBarTheme: appBarTheme(textScale: textScale),
    navigationBarTheme: navigationBarTheme(textScale: textScale),
    // MD3 Expressive 组件形状覆盖
    cardTheme: cardTheme,
    dialogTheme: dialogTheme,
    bottomSheetTheme: bottomSheetTheme,
    chipTheme: chipTheme,
    filledButtonTheme: filledButtonTheme,
    elevatedButtonTheme: elevatedButtonTheme,
    outlinedButtonTheme: outlinedButtonTheme,
    textButtonTheme: textButtonTheme,
    snackBarTheme: snackBarTheme,
    listTileTheme: listTileTheme,
    dropdownMenuTheme: dropdownMenuTheme,
  );

  TextTheme textTheme = baseTheme.textTheme;
  if (useGoogleFonts) {
    textTheme = GoogleFonts.notoSansScTextTheme(textTheme);
  }
  return baseTheme.copyWith(textTheme: textTheme);
}
