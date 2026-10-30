// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_pods.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CourseNotifier)
final courseProvider = CourseNotifierProvider._();

final class CourseNotifierProvider
    extends $NotifierProvider<CourseNotifier, CourseProvider> {
  CourseNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'courseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$courseNotifierHash();

  @$internal
  @override
  CourseNotifier create() => CourseNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CourseProvider value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CourseProvider>(value),
    );
  }
}

String _$courseNotifierHash() => r'881a800e156b6386662eac96831a54b96e7d9ddd';

abstract class _$CourseNotifier extends $Notifier<CourseProvider> {
  CourseProvider build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CourseProvider, CourseProvider>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CourseProvider, CourseProvider>,
              CourseProvider,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// 当前课表课程列表

@ProviderFor(coursesList)
final coursesListProvider = CoursesListProvider._();

/// 当前课表课程列表

final class CoursesListProvider
    extends $FunctionalProvider<List<Course>, List<Course>, List<Course>>
    with $Provider<List<Course>> {
  /// 当前课表课程列表
  CoursesListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'coursesListProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$coursesListHash();

  @$internal
  @override
  $ProviderElement<List<Course>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<Course> create(Ref ref) {
    return coursesList(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Course> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Course>>(value),
    );
  }
}

String _$coursesListHash() => r'c116b10e6a519b47779adfcbc3e3cf642600c23a';

/// 当前课表配置

@ProviderFor(currentScheduleConfig)
final currentScheduleConfigProvider = CurrentScheduleConfigProvider._();

/// 当前课表配置

final class CurrentScheduleConfigProvider
    extends
        $FunctionalProvider<ScheduleConfig?, ScheduleConfig?, ScheduleConfig?>
    with $Provider<ScheduleConfig?> {
  /// 当前课表配置
  CurrentScheduleConfigProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentScheduleConfigProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentScheduleConfigHash();

  @$internal
  @override
  $ProviderElement<ScheduleConfig?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  ScheduleConfig? create(Ref ref) {
    return currentScheduleConfig(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ScheduleConfig? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ScheduleConfig?>(value),
    );
  }
}

String _$currentScheduleConfigHash() =>
    r'122eb25b5f4d10220e3267aba2da462e4aed1c89';

/// 所有课表配置列表

@ProviderFor(allSchedules)
final allSchedulesProvider = AllSchedulesProvider._();

/// 所有课表配置列表

final class AllSchedulesProvider
    extends
        $FunctionalProvider<
          List<ScheduleConfig>,
          List<ScheduleConfig>,
          List<ScheduleConfig>
        >
    with $Provider<List<ScheduleConfig>> {
  /// 所有课表配置列表
  AllSchedulesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'allSchedulesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$allSchedulesHash();

  @$internal
  @override
  $ProviderElement<List<ScheduleConfig>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<ScheduleConfig> create(Ref ref) {
    return allSchedules(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<ScheduleConfig> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<ScheduleConfig>>(value),
    );
  }
}

String _$allSchedulesHash() => r'c270cc51cce391b1ae83ed18e5c6486bb1988574';

/// 课表加载状态

@ProviderFor(courseIsLoading)
final courseIsLoadingProvider = CourseIsLoadingProvider._();

/// 课表加载状态

final class CourseIsLoadingProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// 课表加载状态
  CourseIsLoadingProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'courseIsLoadingProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$courseIsLoadingHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return courseIsLoading(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$courseIsLoadingHash() => r'ce90aab5ea6e8e21a3bb54c1fff715a284cc966a';

/// 是否存在课表

@ProviderFor(hasSchedule)
final hasScheduleProvider = HasScheduleProvider._();

/// 是否存在课表

final class HasScheduleProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// 是否存在课表
  HasScheduleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'hasScheduleProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$hasScheduleHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return hasSchedule(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$hasScheduleHash() => r'89e7bca53d6fc1bd095381b93a6c78ef9f7fb82f';
