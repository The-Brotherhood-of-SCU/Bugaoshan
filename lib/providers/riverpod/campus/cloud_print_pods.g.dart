// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'cloud_print_pods.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CloudPrintNotifier)
final cloudPrintProvider = CloudPrintNotifierProvider._();

final class CloudPrintNotifierProvider
    extends $NotifierProvider<CloudPrintNotifier, CloudPrintProvider> {
  CloudPrintNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'cloudPrintProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$cloudPrintNotifierHash();

  @$internal
  @override
  CloudPrintNotifier create() => CloudPrintNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CloudPrintProvider value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CloudPrintProvider>(value),
    );
  }
}

String _$cloudPrintNotifierHash() =>
    r'ff3e8da092a56930ebe432cfe7f1d1768badcea9';

abstract class _$CloudPrintNotifier extends $Notifier<CloudPrintProvider> {
  CloudPrintProvider build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CloudPrintProvider, CloudPrintProvider>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CloudPrintProvider, CloudPrintProvider>,
              CloudPrintProvider,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
