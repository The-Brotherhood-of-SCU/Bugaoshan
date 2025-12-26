import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:rubbish_plan/utils/locale_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

//define key
const String _keyLocale = 'locale';
const String _keyCardSizeAnimationDuration = 'cardSizeAnimationDuration';

class AppConfigService {
  final SharedPreferences _sharedPreferences;

  AppConfigService(this._sharedPreferences) {
    _loadLocale();
    _addSaveCallback();
  }

  //variable
  final ValueNotifier<Locale?> locale = ValueNotifier<Locale?>(null);
  final ValueNotifier<Duration> cardSizeAnimationDuration =
      ValueNotifier<Duration>(const Duration(milliseconds: 300));

  void _loadLocale() {
    final localeString = _sharedPreferences.getString(_keyLocale);
    locale.value = parseLocale(localeString);
    cardSizeAnimationDuration.value = Duration(
      milliseconds:
          _sharedPreferences.getInt(_keyCardSizeAnimationDuration) ?? 300,
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
  }

  void clearAll() {
    _sharedPreferences.clear();
    _loadLocale();
  }
}
