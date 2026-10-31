import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Color, Colors, Locale, TimeOfDay, ThemeMode;
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bugaoshan/models/background_crop.dart';
import 'package:bugaoshan/models/campus_item_config.dart';
import 'package:bugaoshan/models/reminder_plan.dart';
import 'package:bugaoshan/models/student_type.dart';
import 'package:bugaoshan/models/theme_color_mode.dart';
import 'package:bugaoshan/models/widget_appearance.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/utils/locale_utils.dart';

export 'package:bugaoshan/models/theme_color_mode.dart';

part 'app_config_pods.g.dart';

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
const String _keyUseGithubProxy = 'useGithubProxy';
const String _keyShowTeacherName = 'showTeacherName';
const String _keyShowLocation = 'showLocation';
const String _keyShowCourseWeeks = 'showCourseWeeks';
const String _keyShowWeekend = 'showWeekend';
const String _keyShowNonCurrentWeekCourses = 'showNonCurrentWeekCourses';
const String _keyUseGoogleFonts = 'useGoogleFonts';
const String _keyCampusGridView = 'campusGridView';
const String _keyAutoSampleBalanceOnLogin = 'autoSampleBalanceOnLogin';
const String _keyForceCaptchaForDownload = 'forceCaptchaForDownload';
const String _keyEnablePageTransitionAnimation = 'enablePageTransitionAnimation';
const String _keyStudentType = 'studentType';
const String _keyReminderEnabled = 'reminder_enabled';
const String _keyReminderLeadMinutes = 'reminder_lead_minutes';
const String _keyReminderQuietStart = 'reminder_quiet_start';
const String _keyReminderQuietEnd = 'reminder_quiet_end';
const String _keyReminderWindowDays = 'reminder_window_days';
const String _keyLogPersistenceEnabled = 'log_persistence_enabled';

TimeOfDay? _decodeTimeOfDay(int? minutes) {
  if (minutes == null || minutes < 0 || minutes >= 24 * 60) return null;
  return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
}

int _encodeTimeOfDay(TimeOfDay? time) =>
    time == null ? -1 : time.hour * 60 + time.minute;

List<int>? _decodeLeadMinutes(List<String>? raw) {
  if (raw == null) return null;
  final values = raw.map(int.tryParse).whereType<int>().toList();
  return values.isEmpty ? null : values;
}

@Riverpod(keepAlive: true)
class StudentTypeSetting extends _$StudentTypeSetting {
  @override
  StudentType build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    final idx = prefs.getInt(_keyStudentType) ?? StudentType.undergraduate.index;
    return idx < StudentType.values.length
        ? StudentType.values[idx]
        : StudentType.undergraduate;
  }

  void update(StudentType type) {
    ref.read(sharedPreferencesBridge).setInt(_keyStudentType, type.index);
    state = type;
  }
}

@Riverpod(keepAlive: true)
class VisibleDockIdsSetting extends _$VisibleDockIdsSetting {
  @override
  List<String> build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return prefs.getStringList(_keyVisibleDockIds) ??
        List<String>.from(defaultVisibleDockIds);
  }

  void update(List<String> ids) {
    ref.read(sharedPreferencesBridge).setStringList(_keyVisibleDockIds, ids);
    state = ids;
  }
}

@Riverpod(keepAlive: true)
class HasUpdateNotificationSetting extends _$HasUpdateNotificationSetting {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return prefs.getBool(_keyHasUpdateNotification) ?? false;
  }

  void update(bool hasUpdate) {
    ref.read(sharedPreferencesBridge).setBool(_keyHasUpdateNotification, hasUpdate);
    state = hasUpdate;
  }
}

@Riverpod(keepAlive: true)
class EnableDockSwitchAnimationSetting extends _$EnableDockSwitchAnimationSetting {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return prefs.getBool(_keyEnablePageTransitionAnimation) ?? true;
  }

  void update(bool enable) {
    ref.read(sharedPreferencesBridge).setBool(_keyEnablePageTransitionAnimation, enable);
    state = enable;
  }
}

@Riverpod(keepAlive: true)
class CardSizeAnimationDurationSetting extends _$CardSizeAnimationDurationSetting {
  @override
  Duration build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return Duration(
      milliseconds: prefs.getInt(_keyCardSizeAnimationDuration) ?? 200,
    );
  }

  void update(Duration duration) {
    ref.read(sharedPreferencesBridge).setInt(
      _keyCardSizeAnimationDuration,
      duration.inMilliseconds,
    );
    state = duration;
  }
}

@Riverpod(keepAlive: true)
class LocaleSetting extends _$LocaleSetting {
  @override
  Locale? build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return parseLocale(prefs.getString(_keyLocale));
  }

  void update(Locale? locale) {
    final prefs = ref.read(sharedPreferencesBridge);
    if (locale != null) {
      prefs.setString(_keyLocale, locale.toLanguageTag());
    } else {
      prefs.remove(_keyLocale);
    }
    state = locale;
  }
}

@Riverpod(keepAlive: true)
class ThemeColorSetting extends _$ThemeColorSetting {
  @override
  Color build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return Color(
      prefs.getInt(_keyThemeColor) ?? Colors.blueAccent.toARGB32(),
    );
  }

  void update(Color color) {
    ref.read(sharedPreferencesBridge).setInt(_keyThemeColor, color.toARGB32());
    state = color;
  }
}

@Riverpod(keepAlive: true)
class ThemeColorModeSetting extends _$ThemeColorModeSetting {
  @override
  ThemeColorMode build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    final idx = prefs.getInt(_keyThemeColorMode) ?? 0;
    return idx < ThemeColorMode.values.length
        ? ThemeColorMode.values[idx]
        : ThemeColorMode.system;
  }

  void update(ThemeColorMode mode) {
    ref.read(sharedPreferencesBridge).setInt(_keyThemeColorMode, mode.index);
    state = mode;
  }
}

@Riverpod(keepAlive: true)
class ThemeModeSetting extends _$ThemeModeSetting {
  @override
  ThemeMode build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    final idx = prefs.getInt(_keyThemeMode) ?? 0;
    return idx < ThemeMode.values.length
        ? ThemeMode.values[idx]
        : ThemeMode.system;
  }

  void update(ThemeMode mode) {
    ref.read(sharedPreferencesBridge).setInt(_keyThemeMode, mode.index);
    state = mode;
  }
}

@Riverpod(keepAlive: true)
class UseGoogleFontsSetting extends _$UseGoogleFontsSetting {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return prefs.getBool(_keyUseGoogleFonts) ?? true;
  }

  void update(bool use) {
    ref.read(sharedPreferencesBridge).setBool(_keyUseGoogleFonts, use);
    state = use;
  }
}

@Riverpod(keepAlive: true)
class AcceptedEulaVersionSetting extends _$AcceptedEulaVersionSetting {
  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return prefs.getInt(_keyAcceptedEulaVersion) ?? (kDebugMode ? 114514 : 0);
  }

  void update(int version) {
    ref.read(sharedPreferencesBridge).setInt(_keyAcceptedEulaVersion, version);
    state = version;
  }
}

@Riverpod(keepAlive: true)
class FirstLaunchWizardCompletedSetting
    extends _$FirstLaunchWizardCompletedSetting {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return prefs.getBool(_keyFirstLaunchWizardCompleted) ?? kDebugMode;
  }

  void update(bool completed) {
    ref.read(sharedPreferencesBridge).setBool(_keyFirstLaunchWizardCompleted, completed);
    state = completed;
  }
}

@Riverpod(keepAlive: true)
class LogPersistenceEnabledSetting extends _$LogPersistenceEnabledSetting {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return prefs.getBool(_keyLogPersistenceEnabled) ?? true;
  }

  void update(bool enabled) {
    ref.read(sharedPreferencesBridge).setBool(_keyLogPersistenceEnabled, enabled);
    state = enabled;
  }
}

@Riverpod(keepAlive: true)
class BackgroundImagePathSetting extends _$BackgroundImagePathSetting {
  @override
  String? build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return prefs.getString(_keyBackgroundImagePath);
  }

  void update(String? path) {
    final prefs = ref.read(sharedPreferencesBridge);
    if (path != null) {
      prefs.setString(_keyBackgroundImagePath, path);
    } else {
      prefs.remove(_keyBackgroundImagePath);
    }
    state = path;
  }
}

@Riverpod(keepAlive: true)
class BackgroundImageCropSetting extends _$BackgroundImageCropSetting {
  @override
  BackgroundCropParams? build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return BackgroundCropParams.tryDecode(prefs.getString(_keyBackgroundImageCrop));
  }

  void update(BackgroundCropParams? crop) {
    final prefs = ref.read(sharedPreferencesBridge);
    if (crop != null) {
      prefs.setString(_keyBackgroundImageCrop, crop.encode());
    } else {
      prefs.remove(_keyBackgroundImageCrop);
    }
    state = crop;
  }
}

@Riverpod(keepAlive: true)
class BackgroundImageOpacitySetting extends _$BackgroundImageOpacitySetting {
  @override
  double build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return prefs.getDouble(_keyBackgroundImageOpacity) ?? 0.3;
  }

  void update(double opacity) {
    ref.read(sharedPreferencesBridge).setDouble(_keyBackgroundImageOpacity, opacity);
    state = opacity;
  }
}

@Riverpod(keepAlive: true)
class CampusGridViewSetting extends _$CampusGridViewSetting {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return prefs.getBool(_keyCampusGridView) ?? false;
  }

  void update(bool isGridView) {
    ref.read(sharedPreferencesBridge).setBool(_keyCampusGridView, isGridView);
    state = isGridView;
  }
}

@Riverpod(keepAlive: true)
class ShowCourseWeeksSetting extends _$ShowCourseWeeksSetting {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return prefs.getBool(_keyShowCourseWeeks) ?? true;
  }

  void update(bool show) {
    ref.read(sharedPreferencesBridge).setBool(_keyShowCourseWeeks, show);
    state = show;
  }
}

@Riverpod(keepAlive: true)
class ShowWeekendSetting extends _$ShowWeekendSetting {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return prefs.getBool(_keyShowWeekend) ?? false;
  }

  void update(bool show) {
    ref.read(sharedPreferencesBridge).setBool(_keyShowWeekend, show);
    state = show;
  }
}

@Riverpod(keepAlive: true)
class ShowTeacherNameSetting extends _$ShowTeacherNameSetting {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return prefs.getBool(_keyShowTeacherName) ?? true;
  }

  void update(bool show) {
    ref.read(sharedPreferencesBridge).setBool(_keyShowTeacherName, show);
    state = show;
  }
}

@Riverpod(keepAlive: true)
class ShowLocationSetting extends _$ShowLocationSetting {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return prefs.getBool(_keyShowLocation) ?? true;
  }

  void update(bool show) {
    ref.read(sharedPreferencesBridge).setBool(_keyShowLocation, show);
    state = show;
  }
}

@Riverpod(keepAlive: true)
class ShowNonCurrentWeekCoursesSetting
    extends _$ShowNonCurrentWeekCoursesSetting {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return prefs.getBool(_keyShowNonCurrentWeekCourses) ?? true;
  }

  void update(bool show) {
    ref.read(sharedPreferencesBridge).setBool(_keyShowNonCurrentWeekCourses, show);
    state = show;
  }
}

@Riverpod(keepAlive: true)
class ColorOpacitySetting extends _$ColorOpacitySetting {
  @override
  double build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return prefs.getDouble(_keyColorOpacity) ?? 0.85;
  }

  void update(double opacity) {
    ref.read(sharedPreferencesBridge).setDouble(_keyColorOpacity, opacity);
    state = opacity;
  }
}

@Riverpod(keepAlive: true)
class CourseCardFontSizeSetting extends _$CourseCardFontSizeSetting {
  @override
  double build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return prefs.getDouble(_keyCourseCardFontSize) ?? 14.0;
  }

  void update(double size) {
    ref.read(sharedPreferencesBridge).setDouble(_keyCourseCardFontSize, size);
    state = size;
  }
}

@Riverpod(keepAlive: true)
class ShowCourseGridSetting extends _$ShowCourseGridSetting {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return prefs.getBool(_keyShowCourseGrid) ?? true;
  }

  void update(bool show) {
    ref.read(sharedPreferencesBridge).setBool(_keyShowCourseGrid, show);
    state = show;
  }
}

@Riverpod(keepAlive: true)
class CourseRowHeightSetting extends _$CourseRowHeightSetting {
  @override
  double build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return prefs.getDouble(_keyCourseRowHeight) ?? 72.0;
  }

  void update(double height) {
    ref.read(sharedPreferencesBridge).setDouble(_keyCourseRowHeight, height);
    state = height;
  }
}

@Riverpod(keepAlive: true)
class WidgetShowTomorrowSetting extends _$WidgetShowTomorrowSetting {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return prefs.getBool(_keyWidgetShowTomorrow) ?? false;
  }

  void update(bool show) {
    ref.read(sharedPreferencesBridge).setBool(_keyWidgetShowTomorrow, show);
    state = show;
  }
}

@Riverpod(keepAlive: true)
class WidgetColorStyleSetting extends _$WidgetColorStyleSetting {
  @override
  WidgetColorStyle build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    final idx = prefs.getInt(_keyWidgetColorStyle) ?? 0;
    return idx < WidgetColorStyle.values.length
        ? WidgetColorStyle.values[idx]
        : WidgetColorStyle.colorful;
  }

  void update(WidgetColorStyle style) {
    ref.read(sharedPreferencesBridge).setInt(_keyWidgetColorStyle, style.index);
    state = style;
  }
}

@Riverpod(keepAlive: true)
class WidgetDensitySetting extends _$WidgetDensitySetting {
  @override
  WidgetDensity build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    final idx = prefs.getInt(_keyWidgetDensity) ?? 0;
    return idx < WidgetDensity.values.length
        ? WidgetDensity.values[idx]
        : WidgetDensity.standard;
  }

  void update(WidgetDensity density) {
    ref.read(sharedPreferencesBridge).setInt(_keyWidgetDensity, density.index);
    state = density;
  }
}

@Riverpod(keepAlive: true)
class UsePreviewUpdateSourceSetting extends _$UsePreviewUpdateSourceSetting {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return prefs.getBool(_keyUsePreviewUpdateSource) ?? false;
  }

  void update(bool usePreview) {
    ref.read(sharedPreferencesBridge).setBool(_keyUsePreviewUpdateSource, usePreview);
    state = usePreview;
  }
}

@Riverpod(keepAlive: true)
class UseGithubProxySetting extends _$UseGithubProxySetting {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return prefs.getBool(_keyUseGithubProxy) ?? true;
  }

  void update(bool useProxy) {
    ref.read(sharedPreferencesBridge).setBool(_keyUseGithubProxy, useProxy);
    state = useProxy;
  }
}

@Riverpod(keepAlive: true)
class AutoSampleBalanceOnLoginSetting
    extends _$AutoSampleBalanceOnLoginSetting {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return prefs.getBool(_keyAutoSampleBalanceOnLogin) ?? false;
  }

  void update(bool auto) {
    ref.read(sharedPreferencesBridge).setBool(_keyAutoSampleBalanceOnLogin, auto);
    state = auto;
  }
}

@Riverpod(keepAlive: true)
class ForceCaptchaForDownloadSetting
    extends _$ForceCaptchaForDownloadSetting {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return prefs.getBool(_keyForceCaptchaForDownload) ?? false;
  }

  void update(bool force) {
    ref.read(sharedPreferencesBridge).setBool(_keyForceCaptchaForDownload, force);
    state = force;
  }
}

@Riverpod(keepAlive: true)
class ReminderEnabledSetting extends _$ReminderEnabledSetting {
  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return prefs.getBool(_keyReminderEnabled) ?? false;
  }

  void update(bool enabled) {
    ref.read(sharedPreferencesBridge).setBool(_keyReminderEnabled, enabled);
    state = enabled;
  }
}

@Riverpod(keepAlive: true)
class ReminderLeadMinutesSetting extends _$ReminderLeadMinutesSetting {
  @override
  List<int> build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return _decodeLeadMinutes(prefs.getStringList(_keyReminderLeadMinutes)) ??
        const [15];
  }

  void update(List<int> minutes) {
    ref.read(sharedPreferencesBridge).setStringList(
      _keyReminderLeadMinutes,
      minutes.map((e) => e.toString()).toList(),
    );
    state = minutes;
  }
}

@Riverpod(keepAlive: true)
class ReminderQuietStartSetting extends _$ReminderQuietStartSetting {
  @override
  TimeOfDay? build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return _decodeTimeOfDay(prefs.getInt(_keyReminderQuietStart));
  }

  void update(TimeOfDay? time) {
    ref.read(sharedPreferencesBridge).setInt(
      _keyReminderQuietStart,
      _encodeTimeOfDay(time),
    );
    state = time;
  }
}

@Riverpod(keepAlive: true)
class ReminderQuietEndSetting extends _$ReminderQuietEndSetting {
  @override
  TimeOfDay? build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return _decodeTimeOfDay(prefs.getInt(_keyReminderQuietEnd));
  }

  void update(TimeOfDay? time) {
    ref.read(sharedPreferencesBridge).setInt(
      _keyReminderQuietEnd,
      _encodeTimeOfDay(time),
    );
    state = time;
  }
}

@Riverpod(keepAlive: true)
class ReminderWindowDaysSetting extends _$ReminderWindowDaysSetting {
  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    final savedWindowDays = prefs.getInt(_keyReminderWindowDays);
    return savedWindowDays != null && savedWindowDays > 0
        ? savedWindowDays
        : ReminderSettings.defaultWindowDays;
  }

  void update(int days) {
    ref.read(sharedPreferencesBridge).setInt(_keyReminderWindowDays, days);
    state = days;
  }
}

@Riverpod(keepAlive: true)
ReminderSettings reminderSettingsPod(Ref ref) {
  final reminderEnabled = ref.watch(reminderEnabledSettingProvider);
  final reminderLeadMinutes = ref.watch(reminderLeadMinutesSettingProvider);
  final reminderQuietStart = ref.watch(reminderQuietStartSettingProvider);
  final reminderQuietEnd = ref.watch(reminderQuietEndSettingProvider);
  final reminderWindowDays = ref.watch(reminderWindowDaysSettingProvider);
  final showLocation = ref.watch(showLocationSettingProvider);
  final showTeacherName = ref.watch(showTeacherNameSettingProvider);

  return ReminderSettings(
    courseReminderEnabled: reminderEnabled,
    leadMinutes: reminderLeadMinutes,
    quietStart: reminderQuietStart,
    quietEnd: reminderQuietEnd,
    windowDays: reminderWindowDays,
    includeLocation: showLocation,
    includeTeacher: showTeacherName,
  );
}
