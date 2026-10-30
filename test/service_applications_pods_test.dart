import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/providers/riverpod/campus/service_applications_pods.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/scu_backend/service_hall/service_api_service.dart';

class _FakeScuAuthProvider implements ScuAuthProvider {
  final bool _loggedIn;
  _FakeScuAuthProvider({required bool loggedIn}) : _loggedIn = loggedIn;

  @override
  bool get isLoggedIn => _loggedIn;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeBridgeNotifier extends ScuAuthProviderBridgeNotifier {
  final ScuAuthProvider _auth;
  _FakeBridgeNotifier(this._auth);

  @override
  ScuAuthProvider build() => _auth;
}

class _FakeServiceApi implements ServiceApiService {
  int calls = 0;
  Completer<List<Map<String, dynamic>>>? pending;

  @override
  Future<List<Map<String, dynamic>>> fetchMyApplications({
    int status = 0,
    int page = 1,
  }) {
    calls++;
    final request = pending;
    if (request != null) {
      pending = null;
      return request.future;
    }
    return Future.value([
      {'app_name': calls == 1 ? 'first' : 'second'},
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('ServiceApplicationsNotifier loads when logged in and caches', () async {
    final fakeAuth = _FakeScuAuthProvider(loggedIn: true);
    final fakeApi = _FakeServiceApi();

    final container = ProviderContainer(
      overrides: [
        scuAuthProviderBridge.overrideWith(() => _FakeBridgeNotifier(fakeAuth)),
        serviceApiServiceBridge.overrideWithValue(fakeApi),
      ],
    );
    addTearDown(container.dispose);

    final apps = await container.read(serviceApplicationsProvider.future);
    expect(apps.single['app_name'], 'first');
    expect(fakeApi.calls, 1);

    // Re-reading reuses the cached value
    final cached = await container.read(serviceApplicationsProvider.future);
    expect(cached.single['app_name'], 'first');
    expect(fakeApi.calls, 1);

    // Refresh fetches fresh data
    await container.read(serviceApplicationsProvider.notifier).refresh();
    final fresh = await container.read(serviceApplicationsProvider.future);
    expect(fresh.single['app_name'], 'second');
    expect(fakeApi.calls, 2);
  });

  test('ServiceApplicationsNotifier returns empty list when logged out', () async {
    final fakeAuth = _FakeScuAuthProvider(loggedIn: false);
    final fakeApi = _FakeServiceApi();

    final container = ProviderContainer(
      overrides: [
        scuAuthProviderBridge.overrideWith(() => _FakeBridgeNotifier(fakeAuth)),
        serviceApiServiceBridge.overrideWithValue(fakeApi),
      ],
    );
    addTearDown(container.dispose);

    final apps = await container.read(serviceApplicationsProvider.future);
    expect(apps, isEmpty);
    expect(fakeApi.calls, 0);
  });
}
