import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/providers/service_applications_provider.dart';
import 'package:bugaoshan/services/api/service_api_service.dart';

void main() {
  test('loaded applications are reused until an explicit refresh', () async {
    final api = _FakeServiceApi();
    final provider = ServiceApplicationsProvider(api);

    await provider.ensureLoaded();
    await provider.ensureLoaded();

    expect(api.calls, 1);
    expect(provider.state, ServiceApplicationsLoadState.loaded);
    expect(provider.items.single['app_name'], 'first');

    await provider.refresh();
    expect(api.calls, 2);
    expect(provider.items.single['app_name'], 'second');
  });

  test(
    'a response completed after clear cannot restore applications',
    () async {
      final pending = Completer<List<Map<String, dynamic>>>();
      final api = _FakeServiceApi()..pending = pending;
      final provider = ServiceApplicationsProvider(api);

      final request = provider.ensureLoaded();
      provider.clear();
      pending.complete([
        {'app_name': 'stale'},
      ]);
      await request;

      expect(provider.state, ServiceApplicationsLoadState.idle);
      expect(provider.items, isEmpty);
    },
  );
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
