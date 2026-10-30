// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'plan_completion_pods.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(PlanCompletionNotifier)
final planCompletionProvider = PlanCompletionNotifierProvider._();

final class PlanCompletionNotifierProvider
    extends $NotifierProvider<PlanCompletionNotifier, PlanCompletionProvider> {
  PlanCompletionNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'planCompletionProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$planCompletionNotifierHash();

  @$internal
  @override
  PlanCompletionNotifier create() => PlanCompletionNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PlanCompletionProvider value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PlanCompletionProvider>(value),
    );
  }
}

String _$planCompletionNotifierHash() =>
    r'29c0be4a30d92aba7dbfd8d73ebc946a7c834a05';

abstract class _$PlanCompletionNotifier
    extends $Notifier<PlanCompletionProvider> {
  PlanCompletionProvider build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<PlanCompletionProvider, PlanCompletionProvider>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<PlanCompletionProvider, PlanCompletionProvider>,
              PlanCompletionProvider,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(planCompletionPlans)
final planCompletionPlansProvider = PlanCompletionPlansProvider._();

final class PlanCompletionPlansProvider
    extends
        $FunctionalProvider<
          List<PlanCompletionPlan>,
          List<PlanCompletionPlan>,
          List<PlanCompletionPlan>
        >
    with $Provider<List<PlanCompletionPlan>> {
  PlanCompletionPlansProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'planCompletionPlansProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$planCompletionPlansHash();

  @$internal
  @override
  $ProviderElement<List<PlanCompletionPlan>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<PlanCompletionPlan> create(Ref ref) {
    return planCompletionPlans(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<PlanCompletionPlan> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<PlanCompletionPlan>>(value),
    );
  }
}

String _$planCompletionPlansHash() =>
    r'51dff08a1059eaa46ee7451e611bf02a7c2a791d';

@ProviderFor(planCompletionCurrentIndex)
final planCompletionCurrentIndexProvider =
    PlanCompletionCurrentIndexProvider._();

final class PlanCompletionCurrentIndexProvider
    extends $FunctionalProvider<int, int, int>
    with $Provider<int> {
  PlanCompletionCurrentIndexProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'planCompletionCurrentIndexProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$planCompletionCurrentIndexHash();

  @$internal
  @override
  $ProviderElement<int> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  int create(Ref ref) {
    return planCompletionCurrentIndex(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$planCompletionCurrentIndexHash() =>
    r'b572d21920038e066db37e20c4ecd9fabb69ca71';

@ProviderFor(planCompletionNodes)
final planCompletionNodesProvider = PlanCompletionNodesProvider._();

final class PlanCompletionNodesProvider
    extends
        $FunctionalProvider<
          List<PlanCompletionNode>,
          List<PlanCompletionNode>,
          List<PlanCompletionNode>
        >
    with $Provider<List<PlanCompletionNode>> {
  PlanCompletionNodesProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'planCompletionNodesProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$planCompletionNodesHash();

  @$internal
  @override
  $ProviderElement<List<PlanCompletionNode>> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  List<PlanCompletionNode> create(Ref ref) {
    return planCompletionNodes(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<PlanCompletionNode> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<PlanCompletionNode>>(value),
    );
  }
}

String _$planCompletionNodesHash() =>
    r'c3a68f7e666bd0d736c3206db0e6695fb9466969';
