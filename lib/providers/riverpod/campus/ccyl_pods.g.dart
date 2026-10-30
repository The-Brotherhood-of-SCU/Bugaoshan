// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'ccyl_pods.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CcylAuthNotifier)
final ccylAuthProvider = CcylAuthNotifierProvider._();

final class CcylAuthNotifierProvider
    extends $NotifierProvider<CcylAuthNotifier, CcylAuthState> {
  CcylAuthNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'ccylAuthProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$ccylAuthNotifierHash();

  @$internal
  @override
  CcylAuthNotifier create() => CcylAuthNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CcylAuthState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CcylAuthState>(value),
    );
  }
}

String _$ccylAuthNotifierHash() => r'fab74161b48187d4e7f377f00cc495363dd26a9d';

abstract class _$CcylAuthNotifier extends $Notifier<CcylAuthState> {
  CcylAuthState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CcylAuthState, CcylAuthState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CcylAuthState, CcylAuthState>,
              CcylAuthState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
