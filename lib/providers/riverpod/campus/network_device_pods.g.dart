// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'network_device_pods.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(OffliningDeviceId)
final offliningDeviceIdProvider = OffliningDeviceIdProvider._();

final class OffliningDeviceIdProvider
    extends $NotifierProvider<OffliningDeviceId, String?> {
  OffliningDeviceIdProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'offliningDeviceIdProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$offliningDeviceIdHash();

  @$internal
  @override
  OffliningDeviceId create() => OffliningDeviceId();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String?>(value),
    );
  }
}

String _$offliningDeviceIdHash() => r'4330b4a30921784eb23e309e8b9a467a75324ceb';

abstract class _$OffliningDeviceId extends $Notifier<String?> {
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

@ProviderFor(NetworkDevicesNotifier)
final networkDevicesProvider = NetworkDevicesNotifierProvider._();

final class NetworkDevicesNotifierProvider
    extends
        $AsyncNotifierProvider<
          NetworkDevicesNotifier,
          List<Map<String, dynamic>>
        > {
  NetworkDevicesNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'networkDevicesProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$networkDevicesNotifierHash();

  @$internal
  @override
  NetworkDevicesNotifier create() => NetworkDevicesNotifier();
}

String _$networkDevicesNotifierHash() =>
    r'35b137bfed5478b0eea15f1d5e2c56f7acaa5307';

abstract class _$NetworkDevicesNotifier
    extends $AsyncNotifier<List<Map<String, dynamic>>> {
  FutureOr<List<Map<String, dynamic>>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<Map<String, dynamic>>>,
              List<Map<String, dynamic>>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<Map<String, dynamic>>>,
                List<Map<String, dynamic>>
              >,
              AsyncValue<List<Map<String, dynamic>>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
