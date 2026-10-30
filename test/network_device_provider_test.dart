import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/providers/riverpod/campus/network_device_pods.dart';
import 'package:bugaoshan/scu_backend/core/scu_exceptions.dart';
import 'package:bugaoshan/scu_backend/wfw/wfw_api_service.dart';

void main() {
  test('NetworkDevicesNotifier loads devices on build', () async {
    final api = _ControllableNetworkApi();
    final container = ProviderContainer(
      overrides: [wfwApiServiceBridge.overrideWithValue(api)],
    );
    addTearDown(container.dispose);

    final future = container.read(networkDevicesProvider.future);
    expect(api.deviceRequests, hasLength(1));

    api.completeDevices(0, [
      {'device_id': 'device-1', 'ip': '10.0.0.1'},
    ]);
    final devices = await future;

    expect(devices.single['device_id'], 'device-1');
  });

  test('authentication errors map to AsyncError in Pod', () async {
    final api = _ControllableNetworkApi();
    final container = ProviderContainer(
      overrides: [wfwApiServiceBridge.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(networkDevicesProvider, (_, _) {});

    expect(api.deviceRequests, hasLength(1));
    api.failDevices(0, const UnauthenticatedException());
    await Future<void>.delayed(Duration.zero);

    expect(container.read(networkDevicesProvider).hasError, isTrue);
    expect(
      container.read(networkDevicesProvider).error,
      isA<UnauthenticatedException>(),
    );
  });

  test('force offline refreshes the list after operation succeeds', () async {
    final api = _ControllableNetworkApi();
    final container = ProviderContainer(
      overrides: [wfwApiServiceBridge.overrideWithValue(api)],
    );
    addTearDown(container.dispose);
    container.listen(networkDevicesProvider, (_, _) {});

    final device = {'device_id': 'device-1', 'ip': '10.0.0.1'};
    final initialFuture = container.read(networkDevicesProvider.future);
    api.completeDevices(0, [device]);
    await initialFuture;

    final offlineFuture = container
        .read(networkDevicesProvider.notifier)
        .forceOffline(device);

    expect(container.read(offliningDeviceIdProvider), 'device-1');
    expect(api.offlineRequests, hasLength(1));

    api.completeOffline(0);
    await Future<void>.delayed(Duration.zero);
    expect(api.deviceRequests, hasLength(2));
    api.completeDevices(1, const []);

    expect(await offlineFuture, isTrue);
    expect(container.read(offliningDeviceIdProvider), isNull);
    final refreshed = await container.read(networkDevicesProvider.future);
    expect(refreshed, isEmpty);
  });

  test('refresh updates state to loading and re-fetches', () async {
    final api = _ControllableNetworkApi();
    final container = ProviderContainer(
      overrides: [wfwApiServiceBridge.overrideWithValue(api)],
    );
    addTearDown(container.dispose);

    final initialFuture = container.read(networkDevicesProvider.future);
    api.completeDevices(0, [{'device_id': 'device-1', 'ip': '10.0.0.1'}]);
    await initialFuture;

    final refreshFuture = container.read(networkDevicesProvider.notifier).refresh();
    expect(container.read(networkDevicesProvider).isLoading, isTrue);
    expect(api.deviceRequests, hasLength(2));

    api.completeDevices(1, []);
    await refreshFuture;

    final updated = await container.read(networkDevicesProvider.future);
    expect(updated, isEmpty);
  });
}

class _ControllableNetworkApi implements WfwApiService {
  final deviceRequests = <Completer<List<Map<String, dynamic>>>>[];
  final offlineRequests = <Completer<void>>[];

  @override
  Future<List<Map<String, dynamic>>> fetchNetworkDevices() {
    final request = Completer<List<Map<String, dynamic>>>();
    deviceRequests.add(request);
    return request.future;
  }

  @override
  Future<void> forceNetworkDeviceOffline({
    required String deviceId,
    required String ip,
  }) {
    final request = Completer<void>();
    offlineRequests.add(request);
    return request.future;
  }

  void completeDevices(int index, List<Map<String, dynamic>> devices) =>
      deviceRequests[index].complete(devices);

  void failDevices(int index, Object error) =>
      deviceRequests[index].completeError(error);

  void completeOffline(int index) => offlineRequests[index].complete();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
