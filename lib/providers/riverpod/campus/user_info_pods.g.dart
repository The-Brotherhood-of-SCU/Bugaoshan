// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_info_pods.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(UserInfoNotifier)
final userInfoProvider = UserInfoNotifierProvider._();

final class UserInfoNotifierProvider
    extends $NotifierProvider<UserInfoNotifier, UserInfoState> {
  UserInfoNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'userInfoProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$userInfoNotifierHash();

  @$internal
  @override
  UserInfoNotifier create() => UserInfoNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserInfoState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserInfoState>(value),
    );
  }
}

String _$userInfoNotifierHash() => r'19e3002d8e75f14fe3af3151396d385331b46bac';

abstract class _$UserInfoNotifier extends $Notifier<UserInfoState> {
  UserInfoState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<UserInfoState, UserInfoState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UserInfoState, UserInfoState>,
              UserInfoState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
