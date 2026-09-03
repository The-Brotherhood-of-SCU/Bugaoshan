import 'dart:async';

import 'package:bugaoshan/models/passpoint.dart';
import 'package:bugaoshan/providers/passpoint_provider.dart';
import 'package:bugaoshan/services/api/new_service_api_service.dart';
import 'package:bugaoshan/services/auth/auth_state.dart';
import 'package:bugaoshan/services/auth/new_service_auth.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('concurrent ensure calls share a single list request', () async {
    final api = _ControllablePasspointApi();
    final provider = _readyProvider(api);

    final first = provider.ensureLoaded();
    final second = provider.ensureLoaded();
    expect(api.deviceRequests, hasLength(1));
    expect(provider.state, PasspointLoadState.loading);

    api.completeDevices([
      PasspointDevice(
        userMac: 'B8782EBDCE85',
        macExpireTime: DateTime(2026, 9, 3),
        defaultServiceName: '',
        isOnline: true,
      ),
    ]);
    await Future.wait([first, second]);

    expect(provider.state, PasspointLoadState.loaded);
    expect(provider.devices.single.userMac, 'B8782EBDCE85');
    provider.dispose();
  });

  test('a completed request after clear cannot restore old devices', () async {
    final api = _ControllablePasspointApi();
    final provider = _readyProvider(api);

    final request = provider.ensureLoaded();
    provider.clear();
    api.completeDevices([
      PasspointDevice(
        userMac: 'B8782EBDCE85',
        macExpireTime: DateTime(2026, 9, 3),
        defaultServiceName: '',
        isOnline: false,
      ),
    ]);
    await request;

    expect(provider.state, PasspointLoadState.idle);
    expect(provider.devices, isEmpty);
    provider.dispose();
  });

  test('authentication errors map to session-expired state', () async {
    final api = _ControllablePasspointApi();
    final provider = _readyProvider(api);

    final request = provider.ensureLoaded();
    api.failDevices(const UnauthenticatedException());
    await request;

    expect(provider.state, PasspointLoadState.error);
    expect(provider.error, LoadErrorType.sessionExpired);
    provider.dispose();
  });

  test('add device refreshes the list after the operation succeeds', () async {
    final api = _ControllablePasspointApi();
    final provider = _readyProvider(api);

    final initial = provider.ensureLoaded();
    api.completeDevices(const []);
    await initial;

    final add = provider.addDevice(
      userMac: 'B8782EBDCE85',
      macExpireTime: 365,
      defaultServiceName: '校园网',
    );
    expect(provider.isAdding, isTrue);
    expect(api.addRequests, hasLength(1));

    api.completeAdd(0);
    await Future<void>.delayed(Duration.zero);
    expect(api.deviceRequests, hasLength(2));
    api.completeDevices([
      PasspointDevice(
        userMac: 'B8782EBDCE85',
        macExpireTime: DateTime(2026, 9, 3),
        defaultServiceName: '校园网',
        isOnline: false,
      ),
    ]);

    expect(await add, isTrue);
    expect(provider.isAdding, isFalse);
    expect(provider.devices, hasLength(1));
    provider.dispose();
  });

  test('add device failure exposes the server error message', () async {
    final api = _ControllablePasspointApi();
    final provider = _readyProvider(api);

    final initial = provider.ensureLoaded();
    api.completeDevices(const []);
    await initial;

    final add = provider.addDevice(
      userMac: 'B8782EBDCE85',
      macExpireTime: 365,
      defaultServiceName: '',
    );
    expect(provider.isAdding, isTrue);
    expect(api.addRequests, hasLength(1));

    // 模拟服务端业务拒绝（如 MAC 已绑定）
    api.failAdd(0, const ServiceException('该设备已绑定，无需重复添加'));

    expect(await add, isFalse);
    expect(provider.isAdding, isFalse);
    // 具体错误文案应透传到 UI 层
    expect(provider.addErrorMessage, '该设备已绑定，无需重复添加');
    provider.dispose();
  });

  test('cancel device failure exposes the server error message', () async {
    final api = _ControllablePasspointApi();
    final provider = _readyProvider(api);

    final initial = provider.ensureLoaded();
    api.completeDevices([
      PasspointDevice(
        userMac: 'B8782EBDCE85',
        macExpireTime: DateTime(2026, 9, 3),
        defaultServiceName: '',
        isOnline: false,
      ),
    ]);
    await initial;
    final device = provider.devices.single;

    final cancel = provider.cancelDevice(device);
    expect(provider.isCancelling, isTrue);
    expect(provider.cancellingMac, 'B8782EBDCE85');

    // 模拟服务端取消失败
    api.failCancel(0, const ServiceException('取消失败，请稍后重试'));

    expect(await cancel, isFalse);
    expect(provider.isCancelling, isFalse);
    expect(provider.cancellingMac, isNull);
    // 具体错误文案应透传，且不污染列表加载状态
    expect(provider.cancelErrorMessage, '取消失败，请稍后重试');
    expect(provider.error, isNull);
    provider.dispose();
  });

  test(
    'does not fetch until both SCU and newservice sessions are ready',
    () async {
      final api = _ControllablePasspointApi();
      final scuAuth = _FakeScuAuth(AuthState.unknown);
      final newServiceAuth = _FakeNewServiceAuth(false);
      final provider = PasspointProvider(api, newServiceAuth, scuAuth);

      await provider.ensureLoaded();
      expect(api.deviceRequests, isEmpty);
      expect(provider.state, PasspointLoadState.idle);

      scuAuth.setState(AuthState.ready);
      await Future<void>.delayed(Duration.zero);
      expect(api.deviceRequests, isEmpty);

      newServiceAuth.setReady(true);
      await Future<void>.delayed(Duration.zero);
      expect(api.deviceRequests, hasLength(1));

      api.completeDevices(const []);
      await Future<void>.delayed(Duration.zero);
      provider.dispose();
    },
  );

  test('loads when newservice becomes ready after SCU login', () async {
    final api = _ControllablePasspointApi();
    final scuAuth = _FakeScuAuth(AuthState.ready);
    final newServiceAuth = _FakeNewServiceAuth(false);
    final provider = PasspointProvider(api, newServiceAuth, scuAuth);

    await provider.ensureLoaded();
    expect(api.deviceRequests, isEmpty);

    newServiceAuth.setReady(true);
    await Future<void>.delayed(Duration.zero);
    expect(api.deviceRequests, hasLength(1));

    api.completeDevices(const []);
    await Future<void>.delayed(Duration.zero);
    provider.dispose();
  });

  test('logout clears devices and ignores an in-flight result', () async {
    final api = _ControllablePasspointApi();
    final scuAuth = _FakeScuAuth(AuthState.ready);
    final provider = PasspointProvider(api, _FakeNewServiceAuth(true), scuAuth);

    final request = provider.ensureLoaded();
    scuAuth.setState(AuthState.unknown);
    api.completeDevices([
      PasspointDevice(
        userMac: 'B8782EBDCE85',
        macExpireTime: null,
        defaultServiceName: '',
        isOnline: false,
      ),
    ]);
    await request;

    expect(provider.state, PasspointLoadState.idle);
    expect(provider.devices, isEmpty);
    provider.dispose();
  });
}

class _FakeNewServiceAuth extends ChangeNotifier implements NewServiceAuth {
  _FakeNewServiceAuth(this._ready);

  bool _ready;

  @override
  bool get isReady => _ready;

  void setReady(bool ready) {
    _ready = ready;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeScuAuth extends ChangeNotifier implements ScuAuth {
  _FakeScuAuth(this._state);

  AuthState _state;

  @override
  AuthState get state => _state;

  @override
  bool get isReady => _state == AuthState.ready;

  void setState(AuthState state) {
    _state = state;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

PasspointProvider _readyProvider(_ControllablePasspointApi api) {
  return PasspointProvider(
    api,
    _FakeNewServiceAuth(true),
    _FakeScuAuth(AuthState.ready),
  );
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
  Future<PasspointUserInfo?> fetchUserInfo() async => null;

  @override
  Future<void> cancelDevice({required String userMac, String? userId}) {
    final request = Completer<void>();
    cancelRequests.add(request);
    return request.future;
  }

  void completeDevices(List<PasspointDevice> devices) {
    deviceRequests.last.complete(devices);
  }

  void completeAdd(int index) {
    addRequests[index].complete();
  }

  void failAdd(int index, Object error) {
    addRequests[index].completeError(error);
  }

  void failCancel(int index, Object error) {
    cancelRequests[index].completeError(error);
  }

  void failDevices(Object error) {
    deviceRequests.last.completeError(error);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
