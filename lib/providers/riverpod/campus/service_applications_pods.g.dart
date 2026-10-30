// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'service_applications_pods.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ServiceApplicationsNotifier)
final serviceApplicationsProvider = ServiceApplicationsNotifierProvider._();

final class ServiceApplicationsNotifierProvider
    extends
        $NotifierProvider<
          ServiceApplicationsNotifier,
          ServiceApplicationsState
        > {
  ServiceApplicationsNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'serviceApplicationsProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$serviceApplicationsNotifierHash();

  @$internal
  @override
  ServiceApplicationsNotifier create() => ServiceApplicationsNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ServiceApplicationsState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ServiceApplicationsState>(value),
    );
  }
}

String _$serviceApplicationsNotifierHash() =>
    r'0cf7181b7c7b524d9529ce517be86649a8a50b3e';

abstract class _$ServiceApplicationsNotifier
    extends $Notifier<ServiceApplicationsState> {
  ServiceApplicationsState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<ServiceApplicationsState, ServiceApplicationsState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ServiceApplicationsState, ServiceApplicationsState>,
              ServiceApplicationsState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
