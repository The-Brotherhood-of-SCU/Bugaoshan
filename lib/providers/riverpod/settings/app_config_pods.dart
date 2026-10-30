import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bugaoshan/models/student_type.dart';
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
