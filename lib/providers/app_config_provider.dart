import 'dart:convert';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Colors, Curve, Curves;
import 'package:bugaoshan/models/dock_item_config.dart';
import 'package:bugaoshan/utils/locale_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

//define key
const String _keyLocale = 'locale';
const String _keyCardSizeAnimationDuration = 'cardSizeAnimationDuration';
const String _keyThemeColor = 'themeColor';
const String _keyColorOpacity = 'colorOpacity';
const String _keyCourseCardFontSize = 'courseCardFontSize';
const String _keyShowCourseGrid = 'showCourseGrid';
const String _keyCourseRowHeight = 'courseRowHeight';
const String _keyBackgroundImageOpacity = 'backgroundImageOpacity';
const String _keyBackgroundImagePath = 'backgroundImagePath';
const String _keyFirstLaunchWizardCompleted = 'firstLaunchWizardCompleted';
const String _keyHasUpdateNotification = 'hasUpdateNotification';
const String _keyDockItems = 'dockItems';
const Curve appCurve = Curves.easeOutQuart;

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
  final ValueNotifier<double> colorOpacity = ValueNotifier<double>(0.85);
  final ValueNotifier<double> courseCardFontSize = ValueNotifier<double>(13.0);
  final ValueNotifier<bool> showCourseGrid = ValueNotifier<bool>(true);
  final ValueNotifier<double> courseRowHeight = ValueNotifier<double>(72.0);
  final ValueNotifier<double> backgroundImageOpacity = ValueNotifier<double>(
    0.3,
  );
  final ValueNotifier<String?> backgroundImagePath = ValueNotifier<String?>(
    null,
  );
  final ValueNotifier<int> backgroundImageVersion = ValueNotifier<int>(0);
  final ValueNotifier<bool> firstLaunchWizardCompleted = ValueNotifier<bool>(
    false,
  );
  final ValueNotifier<bool> hasUpdateNotification = ValueNotifier<bool>(false);
  final ValueNotifier<List<DockItemConfig>> dockItems =
      ValueNotifier<List<DockItemConfig>>([]);

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
    colorOpacity.value = _sharedPreferences.getDouble(_keyColorOpacity) ?? 0.85;
    courseCardFontSize.value =
        _sharedPreferences.getDouble(_keyCourseCardFontSize) ?? 14.0;
    showCourseGrid.value =
        _sharedPreferences.getBool(_keyShowCourseGrid) ?? true;
    courseRowHeight.value =
        _sharedPreferences.getDouble(_keyCourseRowHeight) ?? 72.0;
    backgroundImageOpacity.value =
        _sharedPreferences.getDouble(_keyBackgroundImageOpacity) ?? 0.3;
    backgroundImagePath.value = _sharedPreferences.getString(
      _keyBackgroundImagePath,
    );
    firstLaunchWizardCompleted.value =
        _sharedPreferences.getBool(_keyFirstLaunchWizardCompleted) ?? false;
    hasUpdateNotification.value =
        _sharedPreferences.getBool(_keyHasUpdateNotification) ?? false;
    final dockJson = _sharedPreferences.getString(_keyDockItems);
    if (dockJson != null) {
      try {
        final list = (jsonDecode(dockJson) as List)
            .map((e) => DockItemConfig.fromJson(e as Map<String, dynamic>))
            .toList();
        dockItems.value = list;
      } catch (_) {
        dockItems.value = defaultDockItems();
      }
    } else {
      dockItems.value = defaultDockItems();
    }
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
    colorOpacity.addListener(() {
      _sharedPreferences.setDouble(_keyColorOpacity, colorOpacity.value);
    });
    courseCardFontSize.addListener(() {
      _sharedPreferences.setDouble(
        _keyCourseCardFontSize,
        courseCardFontSize.value,
      );
    });
    showCourseGrid.addListener(() {
      _sharedPreferences.setBool(_keyShowCourseGrid, showCourseGrid.value);
    });
    courseRowHeight.addListener(() {
      _sharedPreferences.setDouble(_keyCourseRowHeight, courseRowHeight.value);
    });
    backgroundImageOpacity.addListener(() {
      _sharedPreferences.setDouble(
        _keyBackgroundImageOpacity,
        backgroundImageOpacity.value,
      );
    });
    backgroundImagePath.addListener(() {
      final path = backgroundImagePath.value;
      if (path != null) {
        _sharedPreferences.setString(_keyBackgroundImagePath, path);
      } else {
        _sharedPreferences.remove(_keyBackgroundImagePath);
      }
    });
    firstLaunchWizardCompleted.addListener(() {
      _sharedPreferences.setBool(
        _keyFirstLaunchWizardCompleted,
        firstLaunchWizardCompleted.value,
      );
    });
    hasUpdateNotification.addListener(() {
      _sharedPreferences.setBool(
        _keyHasUpdateNotification,
        hasUpdateNotification.value,
      );
    });
    dockItems.addListener(() {
      final json = dockItems.value.map((e) => e.toJson()).toList();
      _sharedPreferences.setString(_keyDockItems, jsonEncode(json));
    });
  }

  void resetDockToDefault() {
    dockItems.value = defaultDockItems();
  }

  void clearAll() {
    _sharedPreferences.clear();
    _loadLocale();
  }
}
