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
    extends $AsyncNotifierProvider<UserInfoNotifier, UserInfoState> {
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
}

String _$userInfoNotifierHash() => r'4d58b3bfb305ee6335c54010042ad104e58ced2f';

abstract class _$UserInfoNotifier extends $AsyncNotifier<UserInfoState> {
  FutureOr<UserInfoState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<UserInfoState>, UserInfoState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<UserInfoState>, UserInfoState>,
              AsyncValue<UserInfoState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
