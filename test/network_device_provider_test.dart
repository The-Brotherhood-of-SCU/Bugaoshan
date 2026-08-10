import 'dart:async';

import 'package:bugaoshan/providers/network_device_provider.dart';
import 'package:bugaoshan/services/api/wfw_api_service.dart';
import 'package:bugaoshan/services/auth/auth_state.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/auth/wfw_auth.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('concurrent ensure calls share a single list request', () async {
    final api = _ControllableNetworkApi();
    final provider = NetworkDeviceProvider(api, _FakeWfwAuth());

    final first = provider.ensureDevices();
    final second = provider.ensureDevices();
    expect(api.deviceRequests, hasLength(1));
    expect(provider.state, NetworkDeviceLoadState.loading);

    api.completeDevices(0, [
      {'device_id': 'device-1', 'ip': '10.0.0.1'},
    ]);
    await Future.wait([first, second]);

    expect(provider.state, NetworkDeviceLoadState.loaded);
    expect(provider.devices.single['device_id'], 'device-1');
    provider.dispose();
  });

  test('a completed request after clear cannot restore old devices', () async {
    final api = _ControllableNetworkApi();
    final provider = NetworkDeviceProvider(api, _FakeWfwAuth());

    final request = provider.ensureDevices();
    provider.clear();
    api.completeDevices(0, [
      {'device_id': 'old-device', 'ip': '10.0.0.2'},
    ]);
    await request;

    expect(provider.state, NetworkDeviceLoadState.idle);
    expect(provider.devices, isEmpty);
    provider.dispose();
  });

  test('authentication errors map to session-expired state', () async {
    final api = _ControllableNetworkApi();
    final provider = NetworkDeviceProvider(api, _FakeWfwAuth());

    final request = provider.ensureDevices();
    api.failDevices(0, const UnauthenticatedException());
    await request;

    expect(provider.state, NetworkDeviceLoadState.error);
    expect(provider.error, LoadErrorType.sessionExpired);
    provider.dispose();
  });

  test(
    'force offline refreshes the list after the operation succeeds',
    () async {
      final api = _ControllableNetworkApi();
      final provider = NetworkDeviceProvider(api, _FakeWfwAuth());
      final device = {'device_id': 'device-1', 'ip': '10.0.0.1'};

      final initial = provider.ensureDevices();
      api.completeDevices(0, [device]);
      await initial;

      final offline = provider.forceOffline(device);
      expect(provider.isOfflining, isTrue);
      expect(api.offlineRequests, hasLength(1));

      api.completeOffline(0);
      await Future<void>.delayed(Duration.zero);
      expect(api.deviceRequests, hasLength(2));
      api.completeDevices(1, const []);

      expect(await offline, isTrue);
      expect(provider.isOfflining, isFalse);
      expect(provider.devices, isEmpty);
      provider.dispose();
    },
  );
}

class _FakeWfwAuth extends ChangeNotifier implements WfwAuth {
  @override
  AuthState get state => AuthState.unknown;

  @override
  bool get isReady => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
