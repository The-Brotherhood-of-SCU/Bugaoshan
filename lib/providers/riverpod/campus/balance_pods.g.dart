// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'balance_pods.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(BalanceQueryNotifier)
final balanceQueryProvider = BalanceQueryNotifierProvider._();

final class BalanceQueryNotifierProvider
    extends $NotifierProvider<BalanceQueryNotifier, BalanceQueryProvider> {
  BalanceQueryNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'balanceQueryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$balanceQueryNotifierHash();

  @$internal
  @override
  BalanceQueryNotifier create() => BalanceQueryNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(BalanceQueryProvider value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<BalanceQueryProvider>(value),
    );
  }
}

String _$balanceQueryNotifierHash() =>
    r'ed0071b86b37147b074994a81a96de980a7489ff';

abstract class _$BalanceQueryNotifier extends $Notifier<BalanceQueryProvider> {
  BalanceQueryProvider build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<BalanceQueryProvider, BalanceQueryProvider>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<BalanceQueryProvider, BalanceQueryProvider>,
              BalanceQueryProvider,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
