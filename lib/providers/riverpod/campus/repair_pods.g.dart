// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'repair_pods.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(RepairNotifier)
final repairProvider = RepairNotifierProvider._();

final class RepairNotifierProvider
    extends $NotifierProvider<RepairNotifier, ZhhqRepairProvider> {
  RepairNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'repairProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$repairNotifierHash();

  @$internal
  @override
  RepairNotifier create() => RepairNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ZhhqRepairProvider value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ZhhqRepairProvider>(value),
    );
  }
}

String _$repairNotifierHash() => r'2aeaf8cca534b96a5e870e6e4ccd387aa8332106';

abstract class _$RepairNotifier extends $Notifier<ZhhqRepairProvider> {
  ZhhqRepairProvider build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ZhhqRepairProvider, ZhhqRepairProvider>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ZhhqRepairProvider, ZhhqRepairProvider>,
              ZhhqRepairProvider,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
