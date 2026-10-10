import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart'
    show Colors, Curve, Curves, ThemeMode, TimeOfDay;
import 'package:bugaoshan/models/background_crop.dart';
import 'package:bugaoshan/models/reminder_plan.dart';
import 'package:bugaoshan/models/student_type.dart';
import 'package:bugaoshan/models/widget_appearance.dart';
import 'package:bugaoshan/utils/locale_utils.dart';
import 'package:bugaoshan/models/campus_item_config.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:system_theme/system_theme.dart';

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
const String _keyBackgroundImageCrop = 'backgroundImageCrop';
const String _keyFirstLaunchWizardCompleted = 'firstLaunchWizardCompleted';
const String _keyHasUpdateNotification = 'hasUpdateNotification';
const String _keyVisibleDockIds = 'visibleDockIds';
const String _keyAcceptedEulaVersion = 'acceptedEulaVersion';
const String _keyThemeColorMode = 'themeColorMode';
const String _keyThemeMode = 'themeMode';
const String _keyWidgetShowTomorrow = 'widget_show_tomorrow';
const String _keyWidgetColorStyle = 'widget_color_style';
const String _keyWidgetDensity = 'widget_density';
const String _keyUsePreviewUpdateSource = 'usePreviewUpdateSource';
const String _keyShowTeacherName = 'showTeacherName';
const String _keyShowLocation = 'showLocation';
const String _keyShowCourseWeeks = 'showCourseWeeks';
const String _keyShowWeekend = 'showWeekend';
const String _keyShowNonCurrentWeekCourses = 'showNonCurrentWeekCourses';
const String _keyUseGoogleFonts = 'useGoogleFonts';
const String _keyCampusGridView = 'campusGridView';
const String _keyAutoSampleBalanceOnLogin = 'autoSampleBalanceOnLogin';
const String _keyForceCaptchaForDownload = 'forceCaptchaForDownload';
const String _keyEnablePageTransitionAnimation =
    'enablePageTransitionAnimation';
const String _keyStudentType = 'studentType';
// ── 本地提醒（见 docs/decisions 与 issue #358）───────────────────────
const String _keyReminderEnabled = 'reminder_enabled';
const String _keyReminderLeadMinutes = 'reminder_lead_minutes';
// 免打扰时段以「当日分钟数」存储（0..1439）；负值表示未启用。
const String _keyReminderQuietStart = 'reminder_quiet_start';
const String _keyReminderQuietEnd = 'reminder_quiet_end';
const String _keyReminderWindowDays = 'reminder_window_days';

/// 是否把 warn/error 级日志落盘到本机文件。
const String _keyLogPersistenceEnabled = 'log_persistence_enabled';
const Curve appCurve = Curves.easeOutQuart;

enum ThemeColorMode { system, backgroundImage, custom }

class AppConfigProvider {
  final SharedPreferences _sharedPreferences;

  AppConfigProvider(this._sharedPreferences);
  Future<void> init() async {
    await _loadPreferences();
    _addSaveCallback();
  }

  //variable
  final ValueNotifier<Locale?> locale = ValueNotifier<Locale?>(null);
  final ValueNotifier<Duration> cardSizeAnimationDuration =
      ValueNotifier<Duration>(const Duration(milliseconds: 200));
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

  /// 背景图裁剪/显示区域参数；null 表示沿用 BoxFit.cover 居中裁剪（旧行为）。
  final ValueNotifier<BackgroundCropParams?> backgroundImageCrop =
      ValueNotifier<BackgroundCropParams?>(null);
  final ValueNotifier<bool> firstLaunchWizardCompleted = ValueNotifier<bool>(
    false,
  );
  final ValueNotifier<bool> hasUpdateNotification = ValueNotifier<bool>(false);
  final ValueNotifier<List<String>> visibleDockIds =
      ValueNotifier<List<String>>([]);
  final ValueNotifier<int> acceptedEulaVersion = ValueNotifier<int>(0);
  final ValueNotifier<ThemeColorMode> themeColorMode =
      ValueNotifier<ThemeColorMode>(ThemeColorMode.system);

  /// 深色模式：跟随系统 / 浅色 / 深色，驱动 MaterialApp.themeMode。
  final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
    ThemeMode.system,
  );
  final ValueNotifier<bool> widgetShowTomorrow = ValueNotifier<bool>(false);
  final ValueNotifier<WidgetColorStyle> widgetColorStyle =
      ValueNotifier<WidgetColorStyle>(WidgetColorStyle.colorful);
  final ValueNotifier<WidgetDensity> widgetDensity =
      ValueNotifier<WidgetDensity>(WidgetDensity.standard);
  final ValueNotifier<bool> usePreviewUpdateSource = ValueNotifier<bool>(false);
  final ValueNotifier<bool> useGoogleFonts = ValueNotifier<bool>(true);
  final ValueNotifier<bool> showTeacherName = ValueNotifier<bool>(true);
  final ValueNotifier<bool> showLocation = ValueNotifier<bool>(true);
  final ValueNotifier<bool> showCourseWeeks = ValueNotifier<bool>(true);
  final ValueNotifier<bool> showWeekend = ValueNotifier<bool>(false);
  final ValueNotifier<bool> showNonCurrentWeekCourses = ValueNotifier<bool>(
    true,
  );
  final ValueNotifier<bool> campusGridView = ValueNotifier<bool>(false);
  final ValueNotifier<bool> autoSampleBalanceOnLogin = ValueNotifier<bool>(
    true,
  );
  final ValueNotifier<bool> forceCaptchaForDownload = ValueNotifier<bool>(
    false,
  );
  final ValueNotifier<bool> enableDockSwitchAnimation = ValueNotifier<bool>(
    true,
  );

  /// 学生身份（本科生 / 研究生），决定课表导入入口与校园页功能分区展示范围。
  final ValueNotifier<StudentType> studentType = ValueNotifier<StudentType>(
    StudentType.undergraduate,
  );

  // ── 本地提醒 ──────────────────────────────────────────────────────
  //
  // 提醒的**内容**由 AppConfigProvider 的隐私开关约束（showLocation /
  // showTeacherName），这里只保存提醒自身的开关与时机。默认全部关闭：
  // 请求通知权限属于高打扰动作，不在用户未表达意愿时替他决定。
  final ValueNotifier<bool> reminderEnabled = ValueNotifier<bool>(false);

  /// 是否把 warn/error 级日志落盘。**默认开启**。
  ///
  /// 落盘是崩溃现场唯一的后手：日志先经 [LogRedactor] 脱敏，且只保留最近
  /// 若干份共约 6 MB（见 `AppLogger` 的轮转参数），不随运行时长无限增长。
  /// 关闭后日志仅存在于内存环形缓冲，进程退出即丢失。
  final ValueNotifier<bool> logPersistenceEnabled = ValueNotifier<bool>(true);

  /// 提前量（分钟），可多选。存为升序去重的列表。
  final ValueNotifier<List<int>> reminderLeadMinutes = ValueNotifier<List<int>>(
    const [15],
  );

  /// 免打扰时段。两者同为 null 表示不启用。
  final ValueNotifier<TimeOfDay?> reminderQuietStart =
      ValueNotifier<TimeOfDay?>(null);
  final ValueNotifier<TimeOfDay?> reminderQuietEnd = ValueNotifier<TimeOfDay?>(
    null,
  );

  /// 排期窗口长度（天）。见 [ReminderSettings.defaultWindowDays] 的取值理由。
  final ValueNotifier<int> reminderWindowDays = ValueNotifier<int>(
    ReminderSettings.defaultWindowDays,
  );

  /// 汇总成构建器所需的设置对象，并保持与隐私开关同源。
  ReminderSettings get reminderSettings => ReminderSettings(
    courseReminderEnabled: reminderEnabled.value,
    leadMinutes: reminderLeadMinutes.value,
    quietStart: reminderQuietStart.value,
    quietEnd: reminderQuietEnd.value,
    windowDays: reminderWindowDays.value,
    includeLocation: showLocation.value,
    includeTeacher: showTeacherName.value,
  );

  Future<void> _loadPreferences() async {
    final localeString = _sharedPreferences.getString(_keyLocale);
    locale.value = parseLocale(localeString);
    cardSizeAnimationDuration.value = Duration(
      milliseconds:
          _sharedPreferences.getInt(_keyCardSizeAnimationDuration) ?? 200,
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
    // Load the saved path immediately to allow early image loading.
    // Existence will be checked later in the Settings UI when needed.
    final savedPath = _sharedPreferences.getString(_keyBackgroundImagePath);
    backgroundImagePath.value = savedPath;
    backgroundImageCrop.value = BackgroundCropParams.tryDecode(
      _sharedPreferences.getString(_keyBackgroundImageCrop),
    );
    firstLaunchWizardCompleted.value =
        _sharedPreferences.getBool(_keyFirstLaunchWizardCompleted) ??
        kDebugMode;
    hasUpdateNotification.value =
        _sharedPreferences.getBool(_keyHasUpdateNotification) ?? false;
    visibleDockIds.value =
        _sharedPreferences.getStringList(_keyVisibleDockIds) ??
        List<String>.from(defaultVisibleDockIds);
    acceptedEulaVersion.value =
        _sharedPreferences.getInt(_keyAcceptedEulaVersion) ??
        (kDebugMode ? 114514 : 0); //debug mode default 114514, skip eula check
    final themeColorIndex = _sharedPreferences.getInt(_keyThemeColorMode) ?? 0;
    themeColorMode.value = themeColorIndex < ThemeColorMode.values.length
        ? ThemeColorMode.values[themeColorIndex]
        : ThemeColorMode.custom;
    final themeModeIndex = _sharedPreferences.getInt(_keyThemeMode) ?? 0;
    themeMode.value = themeModeIndex < ThemeMode.values.length
        ? ThemeMode.values[themeModeIndex]
        : ThemeMode.system;
    widgetShowTomorrow.value =
        _sharedPreferences.getBool(_keyWidgetShowTomorrow) ?? false;
    final widgetColorStyleIndex =
        _sharedPreferences.getInt(_keyWidgetColorStyle) ?? 0;
    widgetColorStyle.value =
        widgetColorStyleIndex < WidgetColorStyle.values.length
        ? WidgetColorStyle.values[widgetColorStyleIndex]
        : WidgetColorStyle.colorful;
    final widgetDensityIndex =
        _sharedPreferences.getInt(_keyWidgetDensity) ?? 0;
    widgetDensity.value = widgetDensityIndex < WidgetDensity.values.length
        ? WidgetDensity.values[widgetDensityIndex]
        : WidgetDensity.standard;
    usePreviewUpdateSource.value =
        _sharedPreferences.getBool(_keyUsePreviewUpdateSource) ?? false;
    useGoogleFonts.value =
        _sharedPreferences.getBool(_keyUseGoogleFonts) ?? true;
    showTeacherName.value =
        _sharedPreferences.getBool(_keyShowTeacherName) ?? true;
    showLocation.value = _sharedPreferences.getBool(_keyShowLocation) ?? true;
    showCourseWeeks.value =
        _sharedPreferences.getBool(_keyShowCourseWeeks) ?? true;
    showWeekend.value = _sharedPreferences.getBool(_keyShowWeekend) ?? false;
    showNonCurrentWeekCourses.value =
        _sharedPreferences.getBool(_keyShowNonCurrentWeekCourses) ?? true;
    campusGridView.value =
        _sharedPreferences.getBool(_keyCampusGridView) ?? false;
    autoSampleBalanceOnLogin.value =
        _sharedPreferences.getBool(_keyAutoSampleBalanceOnLogin) ?? false;
    forceCaptchaForDownload.value =
        _sharedPreferences.getBool(_keyForceCaptchaForDownload) ?? false;
    enableDockSwitchAnimation.value =
        _sharedPreferences.getBool(_keyEnablePageTransitionAnimation) ?? true;
    final studentTypeIndex =
        _sharedPreferences.getInt(_keyStudentType) ??
        StudentType.undergraduate.index;
    studentType.value = studentTypeIndex < StudentType.values.length
        ? StudentType.values[studentTypeIndex]
        : StudentType.undergraduate;

    reminderEnabled.value =
        _sharedPreferences.getBool(_keyReminderEnabled) ?? false;
    logPersistenceEnabled.value =
        _sharedPreferences.getBool(_keyLogPersistenceEnabled) ?? true;
    reminderLeadMinutes.value =
        _decodeLeadMinutes(
          _sharedPreferences.getStringList(_keyReminderLeadMinutes),
        ) ??
        const [15];
    reminderQuietStart.value = _decodeTimeOfDay(
      _sharedPreferences.getInt(_keyReminderQuietStart),
    );
    reminderQuietEnd.value = _decodeTimeOfDay(
      _sharedPreferences.getInt(_keyReminderQuietEnd),
    );
    final savedWindowDays = _sharedPreferences.getInt(_keyReminderWindowDays);
    reminderWindowDays.value = savedWindowDays != null && savedWindowDays > 0
        ? savedWindowDays
        : ReminderSettings.defaultWindowDays;
  }

  /// 「当日分钟数」→ [TimeOfDay]；越界或负值一律视为未设置。
  static TimeOfDay? _decodeTimeOfDay(int? minutes) {
    if (minutes == null || minutes < 0 || minutes >= 24 * 60) return null;
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  static int _encodeTimeOfDay(TimeOfDay? time) =>
      time == null ? -1 : time.hour * 60 + time.minute;

  /// 提前量存为字符串列表（SharedPreferences 无 int 列表），脏值一律丢弃；
  /// 解析不出任何有效值时返回 null，由调用方回退默认。
  static List<int>? _decodeLeadMinutes(List<String>? raw) {
    if (raw == null) return null;
    final values = raw.map(int.tryParse).whereType<int>().toList();
    return values.isEmpty ? null : values;
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
      if (path == null &&
          themeColorMode.value == ThemeColorMode.backgroundImage) {
        _switchToSystemColor();
      }
    });
    backgroundImageCrop.addListener(() {
      final crop = backgroundImageCrop.value;
      if (crop != null) {
        _sharedPreferences.setString(_keyBackgroundImageCrop, crop.encode());
      } else {
        _sharedPreferences.remove(_keyBackgroundImageCrop);
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
    visibleDockIds.addListener(() {
      _sharedPreferences.setStringList(
        _keyVisibleDockIds,
        visibleDockIds.value,
      );
    });
    acceptedEulaVersion.addListener(() {
      _sharedPreferences.setInt(
        _keyAcceptedEulaVersion,
        acceptedEulaVersion.value,
      );
    });
    themeColorMode.addListener(() {
      _sharedPreferences.setInt(_keyThemeColorMode, themeColorMode.value.index);
    });
    themeMode.addListener(() {
      _sharedPreferences.setInt(_keyThemeMode, themeMode.value.index);
    });
    widgetShowTomorrow.addListener(() {
      _sharedPreferences.setBool(
        _keyWidgetShowTomorrow,
        widgetShowTomorrow.value,
      );
    });
    widgetColorStyle.addListener(() {
      _sharedPreferences.setInt(
        _keyWidgetColorStyle,
        widgetColorStyle.value.index,
      );
    });
    widgetDensity.addListener(() {
      _sharedPreferences.setInt(_keyWidgetDensity, widgetDensity.value.index);
    });
    usePreviewUpdateSource.addListener(() {
      _sharedPreferences.setBool(
        _keyUsePreviewUpdateSource,
        usePreviewUpdateSource.value,
      );
    });
    useGoogleFonts.addListener(() {
      _sharedPreferences.setBool(_keyUseGoogleFonts, useGoogleFonts.value);
    });
    showTeacherName.addListener(() {
      _sharedPreferences.setBool(_keyShowTeacherName, showTeacherName.value);
    });
    showLocation.addListener(() {
      _sharedPreferences.setBool(_keyShowLocation, showLocation.value);
    });
    showCourseWeeks.addListener(() {
      _sharedPreferences.setBool(_keyShowCourseWeeks, showCourseWeeks.value);
    });
    showWeekend.addListener(() {
      _sharedPreferences.setBool(_keyShowWeekend, showWeekend.value);
    });
    showNonCurrentWeekCourses.addListener(() {
      _sharedPreferences.setBool(
        _keyShowNonCurrentWeekCourses,
        showNonCurrentWeekCourses.value,
      );
    });
    campusGridView.addListener(() {
      _sharedPreferences.setBool(_keyCampusGridView, campusGridView.value);
    });
    autoSampleBalanceOnLogin.addListener(() {
      _sharedPreferences.setBool(
        _keyAutoSampleBalanceOnLogin,
        autoSampleBalanceOnLogin.value,
      );
    });
    forceCaptchaForDownload.addListener(() {
      _sharedPreferences.setBool(
        _keyForceCaptchaForDownload,
        forceCaptchaForDownload.value,
      );
    });
    enableDockSwitchAnimation.addListener(() {
      _sharedPreferences.setBool(
        _keyEnablePageTransitionAnimation,
        enableDockSwitchAnimation.value,
      );
    });
    studentType.addListener(() {
      _sharedPreferences.setInt(_keyStudentType, studentType.value.index);
    });
    reminderEnabled.addListener(() {
      _sharedPreferences.setBool(_keyReminderEnabled, reminderEnabled.value);
    });
    logPersistenceEnabled.addListener(() {
      _sharedPreferences.setBool(
        _keyLogPersistenceEnabled,
        logPersistenceEnabled.value,
      );
    });
    reminderLeadMinutes.addListener(() {
      _sharedPreferences.setStringList(
        _keyReminderLeadMinutes,
        reminderLeadMinutes.value.map((e) => e.toString()).toList(),
      );
    });
    reminderQuietStart.addListener(() {
      _sharedPreferences.setInt(
        _keyReminderQuietStart,
        _encodeTimeOfDay(reminderQuietStart.value),
      );
    });
    reminderQuietEnd.addListener(() {
      _sharedPreferences.setInt(
        _keyReminderQuietEnd,
        _encodeTimeOfDay(reminderQuietEnd.value),
      );
    });
    reminderWindowDays.addListener(() {
      _sharedPreferences.setInt(
        _keyReminderWindowDays,
        reminderWindowDays.value,
      );
    });
  }

  void resetDockToDefault() {
    visibleDockIds.value = List<String>.from(defaultVisibleDockIds);
  }

  Future<void> clearAll() async {
    await _sharedPreferences.clear();
    await _loadPreferences();
  }

  Future<void> _switchToSystemColor() async {
    themeColorMode.value = ThemeColorMode.system;
    await SystemTheme.accentColor.load();
    themeColor.value = SystemTheme.accentColor.accent;
  }
}
