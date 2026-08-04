import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'theme_shape.dart';

const pageTransitionsTheme = PageTransitionsTheme(
  builders: {
    TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
    TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
    //desktop use FadeForwardsPageTransitionsBuilder
    TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
    TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
  },
);

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
}) {
  final baseTheme = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: seedColor,
      brightness: brightness,
    ),
    pageTransitionsTheme: pageTransitionsTheme,
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
