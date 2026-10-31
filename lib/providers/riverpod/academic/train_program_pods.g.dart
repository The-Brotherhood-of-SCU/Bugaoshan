// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'train_program_pods.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TrainProgramNotifier)
final trainProgramProvider = TrainProgramNotifierProvider._();

final class TrainProgramNotifierProvider
    extends $NotifierProvider<TrainProgramNotifier, TrainProgramProvider> {
  TrainProgramNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trainProgramProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trainProgramNotifierHash();

  @$internal
  @override
  TrainProgramNotifier create() => TrainProgramNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TrainProgramProvider value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TrainProgramProvider>(value),
    );
  }
}

String _$trainProgramNotifierHash() =>
    r'8cd9659c383b32e70f9a99f482e502a89f342c34';

abstract class _$TrainProgramNotifier extends $Notifier<TrainProgramProvider> {
  TrainProgramProvider build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<TrainProgramProvider, TrainProgramProvider>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<TrainProgramProvider, TrainProgramProvider>,
              TrainProgramProvider,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(GraduateTrainPlanNotifier)
final graduateTrainPlanProvider = GraduateTrainPlanNotifierProvider._();

final class GraduateTrainPlanNotifierProvider
    extends
        $NotifierProvider<
          GraduateTrainPlanNotifier,
          GraduateTrainPlanProvider
        > {
  GraduateTrainPlanNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'graduateTrainPlanProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$graduateTrainPlanNotifierHash();

  @$internal
  @override
  GraduateTrainPlanNotifier create() => GraduateTrainPlanNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GraduateTrainPlanProvider value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GraduateTrainPlanProvider>(value),
    );
  }
}

String _$graduateTrainPlanNotifierHash() =>
    r'7825c05957154477f7b1bafc6c759157f5e62ebb';

abstract class _$GraduateTrainPlanNotifier
    extends $Notifier<GraduateTrainPlanProvider> {
  GraduateTrainPlanProvider build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<GraduateTrainPlanProvider, GraduateTrainPlanProvider>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<GraduateTrainPlanProvider, GraduateTrainPlanProvider>,
              GraduateTrainPlanProvider,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(trainProgramColleges)
final trainProgramCollegesProvider = TrainProgramCollegesProvider._();

final class TrainProgramCollegesProvider
    extends $FunctionalProvider<List<College>, List<College>, List<College>>
    with $Provider<List<College>> {
  TrainProgramCollegesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trainProgramCollegesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trainProgramCollegesHash();

  @$internal
  @override
  $ProviderElement<List<College>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<College> create(Ref ref) {
    return trainProgramColleges(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<College> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<College>>(value),
    );
  }
}

String _$trainProgramCollegesHash() =>
    r'10af7308abc5e8d0518238d91c68cfbd06192730';

@ProviderFor(trainProgramGrades)
final trainProgramGradesProvider = TrainProgramGradesProvider._();

final class TrainProgramGradesProvider
    extends $FunctionalProvider<List<Grade>, List<Grade>, List<Grade>>
    with $Provider<List<Grade>> {
  TrainProgramGradesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trainProgramGradesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trainProgramGradesHash();

  @$internal
  @override
  $ProviderElement<List<Grade>> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  List<Grade> create(Ref ref) {
    return trainProgramGrades(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<Grade> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<Grade>>(value),
    );
  }
}

String _$trainProgramGradesHash() =>
    r'c9a048d7e7facbaa222e67fbe5c85a1005d26455';

@ProviderFor(trainPrograms)
final trainProgramsProvider = TrainProgramsProvider._();

final class TrainProgramsProvider
    extends
        $FunctionalProvider<
          List<TrainProgram>,
          List<TrainProgram>,
          List<TrainProgram>
        >
    with $Provider<List<TrainProgram>> {
  TrainProgramsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trainProgramsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trainProgramsHash();

  @$internal
  @override
  $ProviderElement<List<TrainProgram>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<TrainProgram> create(Ref ref) {
    return trainPrograms(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<TrainProgram> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<TrainProgram>>(value),
    );
  }
}

String _$trainProgramsHash() => r'37ae5d5e8aa88bdb96fb4f8b1383a06c722ee168';

@ProviderFor(trainProgramDetail)
final trainProgramDetailProvider = TrainProgramDetailProvider._();

final class TrainProgramDetailProvider
    extends
        $FunctionalProvider<
          TrainProgramDetail?,
          TrainProgramDetail?,
          TrainProgramDetail?
        >
    with $Provider<TrainProgramDetail?> {
  TrainProgramDetailProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'trainProgramDetailProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$trainProgramDetailHash();

  @$internal
  @override
  $ProviderElement<TrainProgramDetail?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  TrainProgramDetail? create(Ref ref) {
    return trainProgramDetail(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TrainProgramDetail? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TrainProgramDetail?>(value),
    );
  }
}

String _$trainProgramDetailHash() =>
    r'92539160398e35b5e5150017bb129480321dac00';

@ProviderFor(graduateTrainPlanInfo)
final graduateTrainPlanInfoProvider = GraduateTrainPlanInfoProvider._();

final class GraduateTrainPlanInfoProvider
    extends
        $FunctionalProvider<
          GraduateTrainPlanInfo?,
          GraduateTrainPlanInfo?,
          GraduateTrainPlanInfo?
        >
    with $Provider<GraduateTrainPlanInfo?> {
  GraduateTrainPlanInfoProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'graduateTrainPlanInfoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$graduateTrainPlanInfoHash();

  @$internal
  @override
  $ProviderElement<GraduateTrainPlanInfo?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GraduateTrainPlanInfo? create(Ref ref) {
    return graduateTrainPlanInfo(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GraduateTrainPlanInfo? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GraduateTrainPlanInfo?>(value),
    );
  }
}

String _$graduateTrainPlanInfoHash() =>
    r'4609e262ae137029ce9391bb5dcdd8e92b0725cf';

@ProviderFor(graduateTrainPlanCreditStats)
final graduateTrainPlanCreditStatsProvider =
    GraduateTrainPlanCreditStatsProvider._();

final class GraduateTrainPlanCreditStatsProvider
    extends
        $FunctionalProvider<
          GraduateTrainPlanCreditStats?,
          GraduateTrainPlanCreditStats?,
          GraduateTrainPlanCreditStats?
        >
    with $Provider<GraduateTrainPlanCreditStats?> {
  GraduateTrainPlanCreditStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'graduateTrainPlanCreditStatsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$graduateTrainPlanCreditStatsHash();

  @$internal
  @override
  $ProviderElement<GraduateTrainPlanCreditStats?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GraduateTrainPlanCreditStats? create(Ref ref) {
    return graduateTrainPlanCreditStats(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GraduateTrainPlanCreditStats? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GraduateTrainPlanCreditStats?>(
        value,
      ),
    );
  }
}

String _$graduateTrainPlanCreditStatsHash() =>
    r'147b1aa6854f85d56d1eea6ee742a3c58aa3bcd6';

@ProviderFor(graduateTrainPlanSectionsList)
final graduateTrainPlanSectionsListProvider =
    GraduateTrainPlanSectionsListProvider._();

final class GraduateTrainPlanSectionsListProvider
    extends
        $FunctionalProvider<
          List<TrainPlanProgressSection>,
          List<TrainPlanProgressSection>,
          List<TrainPlanProgressSection>
        >
    with $Provider<List<TrainPlanProgressSection>> {
  GraduateTrainPlanSectionsListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'graduateTrainPlanSectionsListProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$graduateTrainPlanSectionsListHash();

  @$internal
  @override
  $ProviderElement<List<TrainPlanProgressSection>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<TrainPlanProgressSection> create(Ref ref) {
    return graduateTrainPlanSectionsList(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<TrainPlanProgressSection> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<TrainPlanProgressSection>>(
        value,
      ),
    );
  }
}

String _$graduateTrainPlanSectionsListHash() =>
    r'f65227daac54349bf6e6e430c5e105f4bf0e7332';

@ProviderFor(graduateTrainPlanEarnedInPlan)
final graduateTrainPlanEarnedInPlanProvider =
    GraduateTrainPlanEarnedInPlanProvider._();

final class GraduateTrainPlanEarnedInPlanProvider
    extends $FunctionalProvider<double, double, double>
    with $Provider<double> {
  GraduateTrainPlanEarnedInPlanProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'graduateTrainPlanEarnedInPlanProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$graduateTrainPlanEarnedInPlanHash();

  @$internal
  @override
  $ProviderElement<double> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  double create(Ref ref) {
    return graduateTrainPlanEarnedInPlan(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(double value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<double>(value),
    );
  }
}

String _$graduateTrainPlanEarnedInPlanHash() =>
    r'7e4abb0730955ca0335f6fca6b47991a3fe40b2d';
