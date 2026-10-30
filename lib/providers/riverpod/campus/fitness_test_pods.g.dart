// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fitness_test_pods.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(FitnessSelectedYear)
final fitnessSelectedYearProvider = FitnessSelectedYearProvider._();

final class FitnessSelectedYearProvider
    extends $NotifierProvider<FitnessSelectedYear, int> {
  FitnessSelectedYearProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fitnessSelectedYearProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fitnessSelectedYearHash();

  @$internal
  @override
  FitnessSelectedYear create() => FitnessSelectedYear();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$fitnessSelectedYearHash() =>
    r'6eb120c2746018830225434e845adc6f754ee220';

abstract class _$FitnessSelectedYear extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(FitnessNotices)
final fitnessNoticesProvider = FitnessNoticesProvider._();

final class FitnessNoticesProvider
    extends $AsyncNotifierProvider<FitnessNotices, List<FitnessNotice>> {
  FitnessNoticesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'fitnessNoticesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$fitnessNoticesHash();

  @$internal
  @override
  FitnessNotices create() => FitnessNotices();
}

String _$fitnessNoticesHash() => r'b3d5045e8a334aa392646a8718b8cdbe091c28f0';

abstract class _$FitnessNotices extends $AsyncNotifier<List<FitnessNotice>> {
  FutureOr<List<FitnessNotice>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<List<FitnessNotice>>, List<FitnessNotice>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<FitnessNotice>>, List<FitnessNotice>>,
              AsyncValue<List<FitnessNotice>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(FitnessScoreData)
final fitnessScoreDataProvider = FitnessScoreDataFamily._();

final class FitnessScoreDataProvider
    extends $AsyncNotifierProvider<FitnessScoreData, FitnessScore?> {
  FitnessScoreDataProvider._({
    required FitnessScoreDataFamily super.from,
    required int super.argument,
  }) : super(
         retry: null,
         name: r'fitnessScoreDataProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$fitnessScoreDataHash();

  @override
  String toString() {
    return r'fitnessScoreDataProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  FitnessScoreData create() => FitnessScoreData();

  @override
  bool operator ==(Object other) {
    return other is FitnessScoreDataProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$fitnessScoreDataHash() => r'071a3eeadd5f0f105ab6ada5e7589685962991f5';

final class FitnessScoreDataFamily extends $Family
    with
        $ClassFamilyOverride<
          FitnessScoreData,
          AsyncValue<FitnessScore?>,
          FitnessScore?,
          FutureOr<FitnessScore?>,
          int
        > {
  FitnessScoreDataFamily._()
    : super(
        retry: null,
        name: r'fitnessScoreDataProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  FitnessScoreDataProvider call(int year) =>
      FitnessScoreDataProvider._(argument: year, from: this);

  @override
  String toString() => r'fitnessScoreDataProvider';
}

abstract class _$FitnessScoreData extends $AsyncNotifier<FitnessScore?> {
  late final _$args = ref.$arg as int;
  int get year => _$args;

  FutureOr<FitnessScore?> build(int year);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<FitnessScore?>, FitnessScore?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<FitnessScore?>, FitnessScore?>,
              AsyncValue<FitnessScore?>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
