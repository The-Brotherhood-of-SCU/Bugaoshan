import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/pages/campus/reservation/models/reservation_models.dart';
import 'package:bugaoshan/providers/reservation_provider.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/scu_backend/core/auth_state.dart';

part 'reservation_pods.g.dart';

@Riverpod(keepAlive: true)
class ReservationNotifier extends _$ReservationNotifier {
  @override
  bool updateShouldNotify(
    ReservationProvider previous,
    ReservationProvider next,
  ) =>
      true;

  @override
  ReservationProvider build() {
    final ReservationProvider provider;
    if (getIt.isRegistered<ReservationProvider>()) {
      provider = getIt<ReservationProvider>();
    } else {
      final api = ref.watch(reservationApiServiceBridge);
      final scuAuth = ref.watch(scuAuthBridge);
      provider = ReservationProvider(api);
      void onScuAuthChanged() {
        if (scuAuth.state == AuthState.unknown) {
          provider.clear();
        }
      }

      scuAuth.addListener(onScuAuthChanged);
      ref.onDispose(() {
        scuAuth.removeListener(onScuAuthChanged);
        provider.dispose();
      });
    }

    void listener() {
      state = provider;
    }

    provider.addListener(listener);
    ref.onDispose(() => provider.removeListener(listener));

    return provider;
  }

  Future<void> ensureLoaded() => state.ensureLoaded();

  Future<void> refresh() => state.refresh();

  Future<void> selectResource(String resourceId) =>
      state.selectResource(resourceId);

  Future<void> shiftRange(int days) => state.shiftRange(days);

  bool get isAtTodayRange => state.isAtTodayRange;

  Future<void> ensureRangeNotPast() => state.ensureRangeNotPast();

  Future<void> resetRange() => state.resetRange();

  Future<ReservationLaunchResult> launchReservation({
    required List<ReservationLaunchSlot> slots,
    required int number,
  }) =>
      state.launchReservation(slots: slots, number: number);

  Future<void> loadAppointments() => state.loadAppointments();

  Future<void> cancelAppointment(ReservationAppointment appointment) =>
      state.cancelAppointment(appointment);

  void clear() => state.clear();
}
