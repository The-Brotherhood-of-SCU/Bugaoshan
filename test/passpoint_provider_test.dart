import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/models/passpoint.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/providers/riverpod/campus/passpoint_pods.dart';
import 'package:bugaoshan/scu_backend/core/scu_exceptions.dart';
import 'package:bugaoshan/scu_backend/passpoint/new_service_api_service.dart';

void main() {
  test('PasspointNotifier loads devices and user info on build', () async {
    final api = _ControllablePasspointApi();
    final container = ProviderContainer(
      overrides: [newServiceApiServiceBridge.overrideWithValue(api)],
    );
    addTearDown(container.dispose);

    final future = container.read(passpointProvider.future);
    expect(api.deviceRequests, hasLength(1));

    api.completeDevices([
      PasspointDevice(
        userMac: 'B8782EBDCE85',
        macExpireTime: DateTime(2026, 9, 3),
        defaultServiceName: '',
        isOnline: true,
      ),
    ]);
    final data = await future;

    expect(data.devices.single.userMac, 'B8782EBDCE85');
  });

  test('authentication errors map to AsyncError in Pod', () async {
    final api = _ControllablePasspointApi();
    final container = ProviderContainer(
      overrides: [newServiceApiServiceBridge.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(passpointProvider, (_, _) {});

    expect(api.deviceRequests, hasLength(1));
    api.failDevices(const UnauthenticatedException());
    await Future<void>.delayed(Duration.zero);

    expect(container.read(passpointProvider).hasError, isTrue);
    expect(
      container.read(passpointProvider).error,
      isA<UnauthenticatedException>(),
    );
  });

  test('add device refreshes the list after operation succeeds', () async {
    final api = _ControllablePasspointApi();
    final container = ProviderContainer(
      overrides: [newServiceApiServiceBridge.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(passpointProvider, (_, _) {});

    final initialFuture = container.read(passpointProvider.future);
    api.completeDevices(const []);
    await initialFuture;

    final addFuture = container.read(passpointProvider.notifier).addDevice(
      userMac: 'B8782EBDCE85',
      macExpireTime: 30,
      defaultServiceName: 'test',
    );
    expect(api.addRequests, hasLength(1));

    api.completeAdd();
    await Future<void>.delayed(Duration.zero);
    expect(api.deviceRequests, hasLength(2));

    api.completeDevices([
      PasspointDevice(
        userMac: 'B8782EBDCE85',
        macExpireTime: DateTime(2026, 9, 3),
        defaultServiceName: 'test',
        isOnline: false,
      ),
    ]);

    final addResult = await addFuture;
    expect(addResult.success, isTrue);
    final refreshed = await container.read(passpointProvider.future);
    expect(refreshed.devices.single.userMac, 'B8782EBDCE85');
  });

  test('cancel device refreshes list and manages cancelling state', () async {
    final api = _ControllablePasspointApi();
    final container = ProviderContainer(
      overrides: [newServiceApiServiceBridge.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(passpointProvider, (_, _) {});

    final device = PasspointDevice(
      userMac: 'B8782EBDCE85',
      macExpireTime: DateTime(2026, 9, 3),
      defaultServiceName: '',
      isOnline: false,
    );
    final initialFuture = container.read(passpointProvider.future);
    api.completeDevices([device]);
    await initialFuture;

    final cancelFuture = container
        .read(passpointProvider.notifier)
        .cancelDevice(device);

    expect(container.read(cancellingPasspointMacProvider), 'B8782EBDCE85');
    expect(api.cancelRequests, hasLength(1));

    api.completeCancel();
    await Future<void>.delayed(Duration.zero);
    expect(api.deviceRequests, hasLength(2));
    api.completeDevices(const []);

    final cancelResult = await cancelFuture;
    expect(cancelResult.success, isTrue);
    expect(container.read(cancellingPasspointMacProvider), isNull);
    final refreshed = await container.read(passpointProvider.future);
    expect(refreshed.devices, isEmpty);
  });
}

class _ControllablePasspointApi implements NewServiceApiService {
  final deviceRequests = <Completer<List<PasspointDevice>>>[];
  final addRequests = <Completer<void>>[];
  final cancelRequests = <Completer<void>>[];

  @override
  Future<List<PasspointDevice>> fetchDevices({int limit = 100}) {
    final request = Completer<List<PasspointDevice>>();
    deviceRequests.add(request);
    return request.future;
  }

  @override
  Future<PasspointUserInfo?> fetchUserInfo() async => null;

  @override
  Future<void> addDevice({
    required String userMac,
    required int macExpireTime,
    String defaultServiceName = '',
  }) {
    final request = Completer<void>();
    addRequests.add(request);
    return request.future;
  }

  @override
  Future<void> cancelDevice({required String userMac, String? userId}) {
    final request = Completer<void>();
    cancelRequests.add(request);
    return request.future;
  }

  void completeDevices(List<PasspointDevice> devices) =>
      deviceRequests.last.complete(devices);

  void failDevices(Object error) => deviceRequests.last.completeError(error);

  void completeAdd() => addRequests.last.complete();

  void completeCancel() => cancelRequests.last.complete();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
