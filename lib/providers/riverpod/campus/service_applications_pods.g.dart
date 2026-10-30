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
        $AsyncNotifierProvider<
          ServiceApplicationsNotifier,
          List<Map<String, dynamic>>
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
}

String _$serviceApplicationsNotifierHash() =>
    r'e6731bdf10003642b2f0db89bca8dfeb29e945a4';

abstract class _$ServiceApplicationsNotifier
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
