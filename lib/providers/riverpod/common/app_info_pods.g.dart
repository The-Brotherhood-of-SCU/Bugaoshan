// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_info_pods.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(AppInfoNotifier)
final appInfoProvider = AppInfoNotifierProvider._();

final class AppInfoNotifierProvider
    extends $NotifierProvider<AppInfoNotifier, AppInfoState> {
  AppInfoNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appInfoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appInfoNotifierHash();

  @$internal
  @override
  AppInfoNotifier create() => AppInfoNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppInfoState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppInfoState>(value),
    );
  }
}

String _$appInfoNotifierHash() => r'25746c97a18112308387b9d3f36c46306c9fa659';

abstract class _$AppInfoNotifier extends $Notifier<AppInfoState> {
  AppInfoState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AppInfoState, AppInfoState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AppInfoState, AppInfoState>,
              AppInfoState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
