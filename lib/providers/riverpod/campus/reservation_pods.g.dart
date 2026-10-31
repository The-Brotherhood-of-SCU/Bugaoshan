// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reservation_pods.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ReservationNotifier)
final reservationProvider = ReservationNotifierProvider._();

final class ReservationNotifierProvider
    extends $NotifierProvider<ReservationNotifier, ReservationProvider> {
  ReservationNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reservationProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reservationNotifierHash();

  @$internal
  @override
  ReservationNotifier create() => ReservationNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReservationProvider value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReservationProvider>(value),
    );
  }
}

String _$reservationNotifierHash() =>
    r'485d271dc9a21d182ad2297f8e2f9a6e14d3a9c2';

abstract class _$ReservationNotifier extends $Notifier<ReservationProvider> {
  ReservationProvider build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ReservationProvider, ReservationProvider>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ReservationProvider, ReservationProvider>,
              ReservationProvider,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
