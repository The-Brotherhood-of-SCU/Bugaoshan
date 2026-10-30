import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bugaoshan/models/background_crop.dart';
import 'package:bugaoshan/models/student_type.dart';
import 'package:bugaoshan/models/widget_appearance.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';

part 'app_config_pods.g.dart';

@Riverpod(keepAlive: true)
class StudentTypeSetting extends _$StudentTypeSetting {
  @override
  StudentType build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.studentType.value;
    appConfig.studentType.addListener(listener);
    ref.onDispose(() => appConfig.studentType.removeListener(listener));
    return appConfig.studentType.value;
  }

  void update(StudentType type) {
    ref.read(appConfigProviderBridge).studentType.value = type;
    state = type;
  }
}

@Riverpod(keepAlive: true)
class VisibleDockIdsSetting extends _$VisibleDockIdsSetting {
  @override
  List<String> build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.visibleDockIds.value;
    appConfig.visibleDockIds.addListener(listener);
    ref.onDispose(() => appConfig.visibleDockIds.removeListener(listener));
    return appConfig.visibleDockIds.value;
  }

  void update(List<String> ids) {
    ref.read(appConfigProviderBridge).visibleDockIds.value = ids;
    state = ids;
  }
}

@Riverpod(keepAlive: true)
class HasUpdateNotificationSetting extends _$HasUpdateNotificationSetting {
  @override
  bool build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.hasUpdateNotification.value;
    appConfig.hasUpdateNotification.addListener(listener);
    ref.onDispose(() => appConfig.hasUpdateNotification.removeListener(listener));
    return appConfig.hasUpdateNotification.value;
  }

  void update(bool hasUpdate) {
    ref.read(appConfigProviderBridge).hasUpdateNotification.value = hasUpdate;
    state = hasUpdate;
  }
}

@Riverpod(keepAlive: true)
class EnableDockSwitchAnimationSetting extends _$EnableDockSwitchAnimationSetting {
  @override
  bool build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.enableDockSwitchAnimation.value;
    appConfig.enableDockSwitchAnimation.addListener(listener);
    ref.onDispose(() => appConfig.enableDockSwitchAnimation.removeListener(listener));
    return appConfig.enableDockSwitchAnimation.value;
  }

  void update(bool enable) {
    ref.read(appConfigProviderBridge).enableDockSwitchAnimation.value = enable;
    state = enable;
  }
}

@Riverpod(keepAlive: true)
class CardSizeAnimationDurationSetting extends _$CardSizeAnimationDurationSetting {
  @override
  Duration build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.cardSizeAnimationDuration.value;
    appConfig.cardSizeAnimationDuration.addListener(listener);
    ref.onDispose(() => appConfig.cardSizeAnimationDuration.removeListener(listener));
    return appConfig.cardSizeAnimationDuration.value;
  }

  void update(Duration duration) {
    ref.read(appConfigProviderBridge).cardSizeAnimationDuration.value = duration;
    state = duration;
  }
}

@Riverpod(keepAlive: true)
class LocaleSetting extends _$LocaleSetting {
  @override
  Locale? build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.locale.value;
    appConfig.locale.addListener(listener);
    ref.onDispose(() => appConfig.locale.removeListener(listener));
    return appConfig.locale.value;
  }

  void update(Locale? locale) {
    ref.read(appConfigProviderBridge).locale.value = locale;
    state = locale;
  }
}

@Riverpod(keepAlive: true)
class ThemeColorSetting extends _$ThemeColorSetting {
  @override
  Color build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.themeColor.value;
    appConfig.themeColor.addListener(listener);
    ref.onDispose(() => appConfig.themeColor.removeListener(listener));
    return appConfig.themeColor.value;
  }

  void update(Color color) {
    ref.read(appConfigProviderBridge).themeColor.value = color;
    state = color;
  }
}

@Riverpod(keepAlive: true)
class ThemeColorModeSetting extends _$ThemeColorModeSetting {
  @override
  ThemeColorMode build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.themeColorMode.value;
    appConfig.themeColorMode.addListener(listener);
    ref.onDispose(() => appConfig.themeColorMode.removeListener(listener));
    return appConfig.themeColorMode.value;
  }

  void update(ThemeColorMode mode) {
    ref.read(appConfigProviderBridge).themeColorMode.value = mode;
    state = mode;
  }
}

@Riverpod(keepAlive: true)
class ThemeModeSetting extends _$ThemeModeSetting {
  @override
  ThemeMode build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.themeMode.value;
    appConfig.themeMode.addListener(listener);
    ref.onDispose(() => appConfig.themeMode.removeListener(listener));
    return appConfig.themeMode.value;
  }

  void update(ThemeMode mode) {
    ref.read(appConfigProviderBridge).themeMode.value = mode;
    state = mode;
  }
}

@Riverpod(keepAlive: true)
class UseGoogleFontsSetting extends _$UseGoogleFontsSetting {
  @override
  bool build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.useGoogleFonts.value;
    appConfig.useGoogleFonts.addListener(listener);
    ref.onDispose(() => appConfig.useGoogleFonts.removeListener(listener));
    return appConfig.useGoogleFonts.value;
  }

  void update(bool use) {
    ref.read(appConfigProviderBridge).useGoogleFonts.value = use;
    state = use;
  }
}

@Riverpod(keepAlive: true)
class AcceptedEulaVersionSetting extends _$AcceptedEulaVersionSetting {
  @override
  int build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.acceptedEulaVersion.value;
    appConfig.acceptedEulaVersion.addListener(listener);
    ref.onDispose(() => appConfig.acceptedEulaVersion.removeListener(listener));
    return appConfig.acceptedEulaVersion.value;
  }

  void update(int version) {
    ref.read(appConfigProviderBridge).acceptedEulaVersion.value = version;
    state = version;
  }
}

@Riverpod(keepAlive: true)
class FirstLaunchWizardCompletedSetting
    extends _$FirstLaunchWizardCompletedSetting {
  @override
  bool build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.firstLaunchWizardCompleted.value;
    appConfig.firstLaunchWizardCompleted.addListener(listener);
    ref.onDispose(
      () => appConfig.firstLaunchWizardCompleted.removeListener(listener),
    );
    return appConfig.firstLaunchWizardCompleted.value;
  }

  void update(bool completed) {
    ref.read(appConfigProviderBridge).firstLaunchWizardCompleted.value =
        completed;
    state = completed;
  }
}

@Riverpod(keepAlive: true)
class LogPersistenceEnabledSetting extends _$LogPersistenceEnabledSetting {
  @override
  bool build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.logPersistenceEnabled.value;
    appConfig.logPersistenceEnabled.addListener(listener);
    ref.onDispose(
      () => appConfig.logPersistenceEnabled.removeListener(listener),
    );
    return appConfig.logPersistenceEnabled.value;
  }

  void update(bool enabled) {
    ref.read(appConfigProviderBridge).logPersistenceEnabled.value = enabled;
    state = enabled;
  }
}

@Riverpod(keepAlive: true)
class BackgroundImagePathSetting extends _$BackgroundImagePathSetting {
  @override
  String? build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.backgroundImagePath.value;
    appConfig.backgroundImagePath.addListener(listener);
    ref.onDispose(() => appConfig.backgroundImagePath.removeListener(listener));
    return appConfig.backgroundImagePath.value;
  }

  void update(String? path) {
    ref.read(appConfigProviderBridge).backgroundImagePath.value = path;
    state = path;
  }
}

@Riverpod(keepAlive: true)
class BackgroundImageCropSetting extends _$BackgroundImageCropSetting {
  @override
  BackgroundCropParams? build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.backgroundImageCrop.value;
    appConfig.backgroundImageCrop.addListener(listener);
    ref.onDispose(() => appConfig.backgroundImageCrop.removeListener(listener));
    return appConfig.backgroundImageCrop.value;
  }

  void update(BackgroundCropParams? crop) {
    ref.read(appConfigProviderBridge).backgroundImageCrop.value = crop;
    state = crop;
  }
}

@Riverpod(keepAlive: true)
class BackgroundImageOpacitySetting extends _$BackgroundImageOpacitySetting {
  @override
  double build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.backgroundImageOpacity.value;
    appConfig.backgroundImageOpacity.addListener(listener);
    ref.onDispose(
      () => appConfig.backgroundImageOpacity.removeListener(listener),
    );
    return appConfig.backgroundImageOpacity.value;
  }

  void update(double opacity) {
    ref.read(appConfigProviderBridge).backgroundImageOpacity.value = opacity;
    state = opacity;
  }
}

@Riverpod(keepAlive: true)
class CampusGridViewSetting extends _$CampusGridViewSetting {
  @override
  bool build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.campusGridView.value;
    appConfig.campusGridView.addListener(listener);
    ref.onDispose(() => appConfig.campusGridView.removeListener(listener));
    return appConfig.campusGridView.value;
  }

  void update(bool isGridView) {
    ref.read(appConfigProviderBridge).campusGridView.value = isGridView;
    state = isGridView;
  }
}

@Riverpod(keepAlive: true)
class ShowCourseWeeksSetting extends _$ShowCourseWeeksSetting {
  @override
  bool build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.showCourseWeeks.value;
    appConfig.showCourseWeeks.addListener(listener);
    ref.onDispose(() => appConfig.showCourseWeeks.removeListener(listener));
    return appConfig.showCourseWeeks.value;
  }

  void update(bool show) {
    ref.read(appConfigProviderBridge).showCourseWeeks.value = show;
    state = show;
  }
}

@Riverpod(keepAlive: true)
class ShowWeekendSetting extends _$ShowWeekendSetting {
  @override
  bool build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.showWeekend.value;
    appConfig.showWeekend.addListener(listener);
    ref.onDispose(() => appConfig.showWeekend.removeListener(listener));
    return appConfig.showWeekend.value;
  }

  void update(bool show) {
    ref.read(appConfigProviderBridge).showWeekend.value = show;
    state = show;
  }
}

@Riverpod(keepAlive: true)
class ShowTeacherNameSetting extends _$ShowTeacherNameSetting {
  @override
  bool build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.showTeacherName.value;
    appConfig.showTeacherName.addListener(listener);
    ref.onDispose(() => appConfig.showTeacherName.removeListener(listener));
    return appConfig.showTeacherName.value;
  }

  void update(bool show) {
    ref.read(appConfigProviderBridge).showTeacherName.value = show;
    state = show;
  }
}

@Riverpod(keepAlive: true)
class ShowLocationSetting extends _$ShowLocationSetting {
  @override
  bool build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.showLocation.value;
    appConfig.showLocation.addListener(listener);
    ref.onDispose(() => appConfig.showLocation.removeListener(listener));
    return appConfig.showLocation.value;
  }

  void update(bool show) {
    ref.read(appConfigProviderBridge).showLocation.value = show;
    state = show;
  }
}

@Riverpod(keepAlive: true)
class ShowNonCurrentWeekCoursesSetting
    extends _$ShowNonCurrentWeekCoursesSetting {
  @override
  bool build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.showNonCurrentWeekCourses.value;
    appConfig.showNonCurrentWeekCourses.addListener(listener);
    ref.onDispose(
      () => appConfig.showNonCurrentWeekCourses.removeListener(listener),
    );
    return appConfig.showNonCurrentWeekCourses.value;
  }

  void update(bool show) {
    ref.read(appConfigProviderBridge).showNonCurrentWeekCourses.value = show;
    state = show;
  }
}

@Riverpod(keepAlive: true)
class ColorOpacitySetting extends _$ColorOpacitySetting {
  @override
  double build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.colorOpacity.value;
    appConfig.colorOpacity.addListener(listener);
    ref.onDispose(() => appConfig.colorOpacity.removeListener(listener));
    return appConfig.colorOpacity.value;
  }

  void update(double opacity) {
    ref.read(appConfigProviderBridge).colorOpacity.value = opacity;
    state = opacity;
  }
}

@Riverpod(keepAlive: true)
class CourseCardFontSizeSetting extends _$CourseCardFontSizeSetting {
  @override
  double build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.courseCardFontSize.value;
    appConfig.courseCardFontSize.addListener(listener);
    ref.onDispose(() => appConfig.courseCardFontSize.removeListener(listener));
    return appConfig.courseCardFontSize.value;
  }

  void update(double size) {
    ref.read(appConfigProviderBridge).courseCardFontSize.value = size;
    state = size;
  }
}

@Riverpod(keepAlive: true)
class ShowCourseGridSetting extends _$ShowCourseGridSetting {
  @override
  bool build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.showCourseGrid.value;
    appConfig.showCourseGrid.addListener(listener);
    ref.onDispose(() => appConfig.showCourseGrid.removeListener(listener));
    return appConfig.showCourseGrid.value;
  }

  void update(bool show) {
    ref.read(appConfigProviderBridge).showCourseGrid.value = show;
    state = show;
  }
}

@Riverpod(keepAlive: true)
class CourseRowHeightSetting extends _$CourseRowHeightSetting {
  @override
  double build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.courseRowHeight.value;
    appConfig.courseRowHeight.addListener(listener);
    ref.onDispose(() => appConfig.courseRowHeight.removeListener(listener));
    return appConfig.courseRowHeight.value;
  }

  void update(double height) {
    ref.read(appConfigProviderBridge).courseRowHeight.value = height;
    state = height;
  }
}

@Riverpod(keepAlive: true)
class WidgetShowTomorrowSetting extends _$WidgetShowTomorrowSetting {
  @override
  bool build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.widgetShowTomorrow.value;
    appConfig.widgetShowTomorrow.addListener(listener);
    ref.onDispose(() => appConfig.widgetShowTomorrow.removeListener(listener));
    return appConfig.widgetShowTomorrow.value;
  }

  void update(bool show) {
    ref.read(appConfigProviderBridge).widgetShowTomorrow.value = show;
    state = show;
  }
}

@Riverpod(keepAlive: true)
class WidgetColorStyleSetting extends _$WidgetColorStyleSetting {
  @override
  WidgetColorStyle build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.widgetColorStyle.value;
    appConfig.widgetColorStyle.addListener(listener);
    ref.onDispose(() => appConfig.widgetColorStyle.removeListener(listener));
    return appConfig.widgetColorStyle.value;
  }

  void update(WidgetColorStyle style) {
    ref.read(appConfigProviderBridge).widgetColorStyle.value = style;
    state = style;
  }
}

@Riverpod(keepAlive: true)
class WidgetDensitySetting extends _$WidgetDensitySetting {
  @override
  WidgetDensity build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.widgetDensity.value;
    appConfig.widgetDensity.addListener(listener);
    ref.onDispose(() => appConfig.widgetDensity.removeListener(listener));
    return appConfig.widgetDensity.value;
  }

  void update(WidgetDensity density) {
    ref.read(appConfigProviderBridge).widgetDensity.value = density;
    state = density;
  }
}

@Riverpod(keepAlive: true)
class UsePreviewUpdateSourceSetting extends _$UsePreviewUpdateSourceSetting {
  @override
  bool build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.usePreviewUpdateSource.value;
    appConfig.usePreviewUpdateSource.addListener(listener);
    ref.onDispose(
      () => appConfig.usePreviewUpdateSource.removeListener(listener),
    );
    return appConfig.usePreviewUpdateSource.value;
  }

  void update(bool usePreview) {
    ref.read(appConfigProviderBridge).usePreviewUpdateSource.value = usePreview;
    state = usePreview;
  }
}

@Riverpod(keepAlive: true)
class UseGithubProxySetting extends _$UseGithubProxySetting {
  @override
  bool build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.useGithubProxy.value;
    appConfig.useGithubProxy.addListener(listener);
    ref.onDispose(() => appConfig.useGithubProxy.removeListener(listener));
    return appConfig.useGithubProxy.value;
  }

  void update(bool useProxy) {
    ref.read(appConfigProviderBridge).useGithubProxy.value = useProxy;
    state = useProxy;
  }
}

@Riverpod(keepAlive: true)
class AutoSampleBalanceOnLoginSetting
    extends _$AutoSampleBalanceOnLoginSetting {
  @override
  bool build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.autoSampleBalanceOnLogin.value;
    appConfig.autoSampleBalanceOnLogin.addListener(listener);
    ref.onDispose(
      () => appConfig.autoSampleBalanceOnLogin.removeListener(listener),
    );
    return appConfig.autoSampleBalanceOnLogin.value;
  }

  void update(bool auto) {
    ref.read(appConfigProviderBridge).autoSampleBalanceOnLogin.value = auto;
    state = auto;
  }
}

@Riverpod(keepAlive: true)
class ForceCaptchaForDownloadSetting
    extends _$ForceCaptchaForDownloadSetting {
  @override
  bool build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.forceCaptchaForDownload.value;
    appConfig.forceCaptchaForDownload.addListener(listener);
    ref.onDispose(
      () => appConfig.forceCaptchaForDownload.removeListener(listener),
    );
    return appConfig.forceCaptchaForDownload.value;
  }

  void update(bool force) {
    ref.read(appConfigProviderBridge).forceCaptchaForDownload.value = force;
    state = force;
  }
}

@Riverpod(keepAlive: true)
class ReminderEnabledSetting extends _$ReminderEnabledSetting {
  @override
  bool build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.reminderEnabled.value;
    appConfig.reminderEnabled.addListener(listener);
    ref.onDispose(() => appConfig.reminderEnabled.removeListener(listener));
    return appConfig.reminderEnabled.value;
  }

  void update(bool enabled) {
    ref.read(appConfigProviderBridge).reminderEnabled.value = enabled;
    state = enabled;
  }
}

@Riverpod(keepAlive: true)
class ReminderLeadMinutesSetting extends _$ReminderLeadMinutesSetting {
  @override
  List<int> build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.reminderLeadMinutes.value;
    appConfig.reminderLeadMinutes.addListener(listener);
    ref.onDispose(() => appConfig.reminderLeadMinutes.removeListener(listener));
    return appConfig.reminderLeadMinutes.value;
  }

  void update(List<int> minutes) {
    ref.read(appConfigProviderBridge).reminderLeadMinutes.value = minutes;
    state = minutes;
  }
}

@Riverpod(keepAlive: true)
class ReminderQuietStartSetting extends _$ReminderQuietStartSetting {
  @override
  TimeOfDay? build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.reminderQuietStart.value;
    appConfig.reminderQuietStart.addListener(listener);
    ref.onDispose(() => appConfig.reminderQuietStart.removeListener(listener));
    return appConfig.reminderQuietStart.value;
  }

  void update(TimeOfDay? time) {
    ref.read(appConfigProviderBridge).reminderQuietStart.value = time;
    state = time;
  }
}

@Riverpod(keepAlive: true)
class ReminderQuietEndSetting extends _$ReminderQuietEndSetting {
  @override
  TimeOfDay? build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.reminderQuietEnd.value;
    appConfig.reminderQuietEnd.addListener(listener);
    ref.onDispose(() => appConfig.reminderQuietEnd.removeListener(listener));
    return appConfig.reminderQuietEnd.value;
  }

  void update(TimeOfDay? time) {
    ref.read(appConfigProviderBridge).reminderQuietEnd.value = time;
    state = time;
  }
}

@Riverpod(keepAlive: true)
class ReminderWindowDaysSetting extends _$ReminderWindowDaysSetting {
  @override
  int build() {
    final appConfig = ref.watch(appConfigProviderBridge);
    void listener() => state = appConfig.reminderWindowDays.value;
    appConfig.reminderWindowDays.addListener(listener);
    ref.onDispose(() => appConfig.reminderWindowDays.removeListener(listener));
    return appConfig.reminderWindowDays.value;
  }

  void update(int days) {
    ref.read(appConfigProviderBridge).reminderWindowDays.value = days;
    state = days;
  }
}
