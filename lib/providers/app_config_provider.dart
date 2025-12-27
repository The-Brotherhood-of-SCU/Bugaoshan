import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Colors;
import 'package:rubbish_plan/utils/locale_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

//define key
const String _keyLocale = 'locale';
const String _keyCardSizeAnimationDuration = 'cardSizeAnimationDuration';
const String _keyThemeColor = 'themeColor';

class AppConfigProvider {
  final SharedPreferences _sharedPreferences;

  AppConfigProvider(this._sharedPreferences) {
    _loadLocale();
    _addSaveCallback();
  }

  //variable
  final ValueNotifier<Locale?> locale = ValueNotifier<Locale?>(null);
  final ValueNotifier<Duration> cardSizeAnimationDuration =
      ValueNotifier<Duration>(const Duration(milliseconds: 300));
  final ValueNotifier<Color> themeColor = ValueNotifier<Color>(
    Colors.blueAccent,
  );

  void _loadLocale() {
    final localeString = _sharedPreferences.getString(_keyLocale);
    locale.value = parseLocale(localeString);
    cardSizeAnimationDuration.value = Duration(
      milliseconds:
          _sharedPreferences.getInt(_keyCardSizeAnimationDuration) ?? 300,
    );
    themeColor.value = Color(
      _sharedPreferences.getInt(_keyThemeColor) ?? Colors.blueAccent.toARGB32(),
    );
  }

  void _addSaveCallback() {
    locale.addListener(() {
      if (locale.value != null) {
        _sharedPreferences.setString(_keyLocale, locale.value!.toLanguageTag());
      } else {
        _sharedPreferences.remove(_keyLocale);
      }
    });
    cardSizeAnimationDuration.addListener(() {
      _sharedPreferences.setInt(
        _keyCardSizeAnimationDuration,
        cardSizeAnimationDuration.value.inMilliseconds,
      );
    });
    themeColor.addListener(() {
      _sharedPreferences.setInt(_keyThemeColor, themeColor.value.toARGB32());
    });
  }

  void clearAll() {
    _sharedPreferences.clear();
    _loadLocale();
  }
}
