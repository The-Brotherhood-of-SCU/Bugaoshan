import 'dart:async';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/providers/user_info_provider.dart';
import 'package:bugaoshan/services/api/wfw_api_service.dart';
import 'package:bugaoshan/services/auth/auth_state.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/auth/wfw_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    getIt.registerSingleton<SharedPreferences>(
      await SharedPreferences.getInstance(),
    );
    getIt.registerSingleton<ScuAuthProvider>(_FakeScuAuthProvider());
  });

  tearDown(() async {
    await getIt.reset();
  });

  test('a response completed after logout cannot restore user data', () async {
    final auth = _FakeWfwAuth(ready: true);
    final api = _ControllableWfwApiService();
    final provider = UserInfoProvider(auth, api);
    await Future<void>.delayed(Duration.zero);

    expect(api.profileRequests, hasLength(1));
    auth.setReady(false);
    api.complete(0, name: 'old-name', number: 'old-number');
    await Future<void>.delayed(Duration.zero);

    expect(provider.userRealname, isNull);
    expect(provider.userNumber, isNull);
    expect(provider.labels, isNull);
    expect(provider.loading, isFalse);
  });

  test('an older account response cannot overwrite the new account', () async {
    final auth = _FakeWfwAuth(ready: true);
    final api = _ControllableWfwApiService();
    final provider = UserInfoProvider(auth, api);
    await Future<void>.delayed(Duration.zero);

    auth.setReady(false);
    auth.setReady(true);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    expect(api.profileRequests, hasLength(2));

    api.complete(1, name: 'new-name', number: 'new-number');
    await Future<void>.delayed(Duration.zero);
    expect(provider.userNumber, 'new-number');

    api.complete(0, name: 'old-name', number: 'old-number');
    await Future<void>.delayed(Duration.zero);

    expect(provider.userRealname, 'new-name');
    expect(provider.userNumber, 'new-number');
    expect(provider.labels?.single['owner'], 'new-number');
    expect(provider.loading, isFalse);
  });

  test('logout cleanup runs after an in-progress user cache write', () async {
    final auth = _FakeWfwAuth(ready: true);
    final api = _ControllableWfwApiService();
    final persistence = _ControllableUserInfoPersistence();
    UserInfoProvider(auth, api, persistUserInfo: persistence.call);
    await Future<void>.delayed(Duration.zero);

    api.complete(0, name: 'old-name', number: 'old-number');
    await Future<void>.delayed(Duration.zero);
    expect(persistence.requests, hasLength(1));
    expect(persistence.requests.single.realname, 'old-name');

    auth.setReady(false);
    await Future<void>.delayed(Duration.zero);

    // 清理必须排在旧写入之后，不能和它并发后被旧值反向覆盖。
    expect(persistence.requests, hasLength(1));
    persistence.complete(0);
    await Future<void>.delayed(Duration.zero);
    expect(persistence.requests, hasLength(2));
    expect(persistence.requests[1].realname, isNull);
    expect(persistence.requests[1].number, isNull);

    persistence.complete(1);
    await Future<void>.delayed(Duration.zero);
    expect(persistence.storedRealname, isNull);
    expect(persistence.storedNumber, isNull);
  });

  test(
    'a repeated ready notification without a transition does not refetch',
    () async {
      final auth = _FakeWfwAuth(ready: true);
      final api = _ControllableWfwApiService();
      final provider = UserInfoProvider(auth, api);
      await Future<void>.delayed(Duration.zero);
      expect(api.profileRequests, hasLength(1));

      // 自动重试路径里 invalidate（无声）→ 预热 → ready 会再次 notify；
      // 同状态重复通知不得触发重新取数，否则一旦预热是误报（session 实际
      // 未建立），「取数失败 → 预热 ready → 再取数」会无限循环。
      auth.setReady(true);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(api.profileRequests, hasLength(1));

      // 真正的 unknown→ready 边沿仍然触发取数。
      auth.setReady(false);
      auth.setReady(true);
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(api.profileRequests, hasLength(2));

      provider.dispose();
    },
  );

  test(
    'manual retry after a silently-rebuilt session still refetches',
    () async {
      final auth = _FakeWfwAuth(ready: true);
      final api = _ControllableWfwApiService();
      final provider = UserInfoProvider(auth, api);
      await Future<void>.delayed(Duration.zero);
      expect(api.profileRequests, hasLength(1));

      // 首次取数因会话失效失败
      api.fail(0, const UnauthenticatedException());
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect(provider.error, isTrue);

      // invalidate 无声：provider 记录的边沿状态仍停留在 ready，
      // 此时 wfw 实际未就绪。手动重试走 ensureAuthenticated 预热，
      // 成功后 ready 重通知不构成边沿，retry() 必须显式兜底调度取数。
      auth.setReadySilently(false);
      provider.retry();
      await Future<void>.delayed(const Duration(milliseconds: 350));
      expect(auth.ensureAuthenticatedCalls, 1);
      expect(api.profileRequests, hasLength(2));

      provider.dispose();
    },
  );
}

typedef _PersistenceRequest = ({
  String? realname,
  String? number,
  Completer<void> completer,
});

class _ControllableUserInfoPersistence {
  final requests = <_PersistenceRequest>[];
  String? storedRealname;
  String? storedNumber;

  Future<void> call(String? realname, String? number) {
    final completer = Completer<void>();
    requests.add((realname: realname, number: number, completer: completer));
    return completer.future.then((_) {
      storedRealname = realname;
      storedNumber = number;
    });
  }

  void complete(int index) => requests[index].completer.complete();
}

class _FakeWfwAuth extends ChangeNotifier implements WfwAuth {
  _FakeWfwAuth({required bool ready}) : _ready = ready;

  bool _ready;
  int ensureAuthenticatedCalls = 0;

  @override
  bool get isReady => _ready;

  @override
  AuthState get state => _ready ? AuthState.ready : AuthState.unknown;

  void setReady(bool value) {
    _ready = value;
    notifyListeners();
  }

  /// 静默切换状态（不 notify）：模拟 invalidate() 的无声失效。
  void setReadySilently(bool value) {
    _ready = value;
  }

  @override
  Future<void> ensureAuthenticated() async {
    ensureAuthenticatedCalls++;
    setReady(true);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ControllableWfwApiService implements WfwApiService {
  final profileRequests = <Completer<Map<String, dynamic>?>>[];
  final labelRequests = <Completer<List<Map<String, dynamic>>>>[];

  @override
  Future<Map<String, dynamic>?> fetchUserProfile() {
    final request = Completer<Map<String, dynamic>?>();
    profileRequests.add(request);
    return request.future;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchProfileLabels() {
    final request = Completer<List<Map<String, dynamic>>>();
    labelRequests.add(request);
    return request.future;
  }

  void complete(int index, {required String name, required String number}) {
    profileRequests[index].complete({
      'realname': name,
      'role': {'number': number},
    });
    labelRequests[index].complete([
      {'owner': number},
    ]);
  }

  void fail(int index, Object error) {
    profileRequests[index].completeError(error);
    labelRequests[index].completeError(error);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeScuAuthProvider implements ScuAuthProvider {
  @override
  void setUserInfo(String? realname, String? number) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
