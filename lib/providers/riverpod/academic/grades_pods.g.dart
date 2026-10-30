// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'grades_pods.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(GradesNotifier)
final gradesProvider = GradesNotifierProvider._();

final class GradesNotifierProvider
    extends $NotifierProvider<GradesNotifier, GradesProvider> {
  GradesNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gradesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gradesNotifierHash();

  @$internal
  @override
  GradesNotifier create() => GradesNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GradesProvider value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GradesProvider>(value),
    );
  }
}

String _$gradesNotifierHash() => r'33e38443879fdf7933e4005f3cb88c0ddf1c3d8d';

abstract class _$GradesNotifier extends $Notifier<GradesProvider> {
  GradesProvider build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<GradesProvider, GradesProvider>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<GradesProvider, GradesProvider>,
              GradesProvider,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(GraduateGradesNotifier)
final graduateGradesProvider = GraduateGradesNotifierProvider._();

final class GraduateGradesNotifierProvider
    extends $NotifierProvider<GraduateGradesNotifier, GraduateGradesProvider> {
  GraduateGradesNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'graduateGradesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$graduateGradesNotifierHash();

  @$internal
  @override
  GraduateGradesNotifier create() => GraduateGradesNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GraduateGradesProvider value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GraduateGradesProvider>(value),
    );
  }
}

String _$graduateGradesNotifierHash() =>
    r'bd288be4c5883f9bce86627e5311f7b48f43f2f3';

abstract class _$GraduateGradesNotifier
    extends $Notifier<GraduateGradesProvider> {
  GraduateGradesProvider build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<GraduateGradesProvider, GraduateGradesProvider>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<GraduateGradesProvider, GraduateGradesProvider>,
              GraduateGradesProvider,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(passingScores)
final passingScoresProvider = PassingScoresProvider._();

final class PassingScoresProvider
    extends
        $FunctionalProvider<
          PassingScoreResult?,
          PassingScoreResult?,
          PassingScoreResult?
        >
    with $Provider<PassingScoreResult?> {
  PassingScoresProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'passingScoresProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$passingScoresHash();

  @$internal
  @override
  $ProviderElement<PassingScoreResult?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PassingScoreResult? create(Ref ref) {
    return passingScores(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PassingScoreResult? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PassingScoreResult?>(value),
    );
  }
}

String _$passingScoresHash() => r'dcfeb2d3715fc7fa547e5cb8bc533ead7aab0587';

@ProviderFor(schemeScores)
final schemeScoresProvider = SchemeScoresProvider._();

final class SchemeScoresProvider
    extends
        $FunctionalProvider<
          SchemeScoreSummary?,
          SchemeScoreSummary?,
          SchemeScoreSummary?
        >
    with $Provider<SchemeScoreSummary?> {
  SchemeScoresProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'schemeScoresProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$schemeScoresHash();

  @$internal
  @override
  $ProviderElement<SchemeScoreSummary?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SchemeScoreSummary? create(Ref ref) {
    return schemeScores(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SchemeScoreSummary? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SchemeScoreSummary?>(value),
    );
  }
}

String _$schemeScoresHash() => r'ebfd4084a6705e9597a45a321178389d5c5931ef';

@ProviderFor(schemeScoresList)
final schemeScoresListProvider = SchemeScoresListProvider._();

final class SchemeScoresListProvider
    extends
        $FunctionalProvider<
          List<SchemeScoreSummary>,
          List<SchemeScoreSummary>,
          List<SchemeScoreSummary>
        >
    with $Provider<List<SchemeScoreSummary>> {
  SchemeScoresListProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'schemeScoresListProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$schemeScoresListHash();

  @$internal
  @override
  $ProviderElement<List<SchemeScoreSummary>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<SchemeScoreSummary> create(Ref ref) {
    return schemeScoresList(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<SchemeScoreSummary> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<SchemeScoreSummary>>(value),
    );
  }
}

String _$schemeScoresListHash() => r'12967817e3120d8a68614d8cb0f1b2c12c8b51e5';

@ProviderFor(graduateGradesStats)
final graduateGradesStatsProvider = GraduateGradesStatsProvider._();

final class GraduateGradesStatsProvider
    extends
        $FunctionalProvider<
          GraduateGradesStats?,
          GraduateGradesStats?,
          GraduateGradesStats?
        >
    with $Provider<GraduateGradesStats?> {
  GraduateGradesStatsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'graduateGradesStatsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$graduateGradesStatsHash();

  @$internal
  @override
  $ProviderElement<GraduateGradesStats?> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GraduateGradesStats? create(Ref ref) {
    return graduateGradesStats(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GraduateGradesStats? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GraduateGradesStats?>(value),
    );
  }
}

String _$graduateGradesStatsHash() =>
    r'3de1f3fbe73f2d390e78f2c51c56b5c1a60785ac';

@ProviderFor(graduateGradeRows)
final graduateGradeRowsProvider = GraduateGradeRowsProvider._();

final class GraduateGradeRowsProvider
    extends
        $FunctionalProvider<
          List<GraduateGradeRow>,
          List<GraduateGradeRow>,
          List<GraduateGradeRow>
        >
    with $Provider<List<GraduateGradeRow>> {
  GraduateGradeRowsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'graduateGradeRowsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$graduateGradeRowsHash();

  @$internal
  @override
  $ProviderElement<List<GraduateGradeRow>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<GraduateGradeRow> create(Ref ref) {
    return graduateGradeRows(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<GraduateGradeRow> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<GraduateGradeRow>>(value),
    );
  }
}

String _$graduateGradeRowsHash() => r'98dbbb83d103c4e8a04b64ab83240b532eda82c2';
