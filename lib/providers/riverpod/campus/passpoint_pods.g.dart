// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'passpoint_pods.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CancellingPasspointMac)
final cancellingPasspointMacProvider = CancellingPasspointMacProvider._();

final class CancellingPasspointMacProvider
    extends $NotifierProvider<CancellingPasspointMac, String?> {
  CancellingPasspointMacProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cancellingPasspointMacProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cancellingPasspointMacHash();

  @$internal
  @override
  CancellingPasspointMac create() => CancellingPasspointMac();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$cancellingPasspointMacHash() =>
    r'07ea505565c4c89edc065e369576074f18cad691';

abstract class _$CancellingPasspointMac extends $Notifier<String?> {
  String? build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<String?, String?>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<String?, String?>,
              String?,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(PasspointNotifier)
final passpointProvider = PasspointNotifierProvider._();

final class PasspointNotifierProvider
    extends $AsyncNotifierProvider<PasspointNotifier, PasspointData> {
  PasspointNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'passpointProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$passpointNotifierHash();

  @$internal
  @override
  PasspointNotifier create() => PasspointNotifier();
}

String _$passpointNotifierHash() => r'd0c193cec53020db2877db187bbfd1062b19d741';

abstract class _$PasspointNotifier extends $AsyncNotifier<PasspointData> {
  FutureOr<PasspointData> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<PasspointData>, PasspointData>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<PasspointData>, PasspointData>,
              AsyncValue<PasspointData>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
