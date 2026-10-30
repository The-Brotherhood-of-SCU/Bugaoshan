import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/providers/riverpod/campus/user_info_pods.dart';
import 'package:bugaoshan/scu_backend/core/auth_state.dart';
import 'package:bugaoshan/scu_backend/wfw/wfw_api_service.dart';
import 'package:bugaoshan/scu_backend/wfw/wfw_auth.dart';
import 'package:bugaoshan/utils/storage_keys.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;

  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    getIt.registerSingleton<SharedPreferences>(prefs);
  });

  tearDown(() async {
    await getIt.reset();
  });

  test('UserInfoNotifier returns empty state when WfwAuth is not ready', () async {
    final auth = _FakeWfwAuth(ready: false, state: AuthState.ready);
    final api = _ControllableWfwApiService();
    final container = ProviderContainer(
      overrides: [
        wfwAuthBridge.overrideWithValue(auth),
        wfwApiServiceBridge.overrideWithValue(api),
        sharedPreferencesBridge.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(userInfoProvider.future);
    expect(state.hasData, isFalse);
    expect(state.userRealname, isNull);
    expect(api.profileRequests, isEmpty);
  });

  test('UserInfoNotifier loads profile and persists info when ready', () async {
    final auth = _FakeWfwAuth(ready: true, state: AuthState.ready);
    final api = _ControllableWfwApiService();
    final container = ProviderContainer(
      overrides: [
        wfwAuthBridge.overrideWithValue(auth),
        wfwApiServiceBridge.overrideWithValue(api),
        sharedPreferencesBridge.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    final future = container.read(userInfoProvider.future);
    expect(api.profileRequests, hasLength(1));

    api.complete(0, name: '张三', number: '20240001');
    final state = await future;

    expect(state.hasData, isTrue);
    expect(state.userRealname, '张三');
    expect(state.userNumber, '20240001');
    expect(prefs.getString(kScuUserRealname), '张三');
    expect(prefs.getString(kScuUserNumber), '20240001');
  });

  test('UserInfoNotifier clears storage on unknown auth state', () async {
    await prefs.setString(kScuUserRealname, 'old-name');
    await prefs.setString(kScuUserNumber, 'old-number');

    final auth = _FakeWfwAuth(ready: false, state: AuthState.unknown);
    final api = _ControllableWfwApiService();
    final container = ProviderContainer(
      overrides: [
        wfwAuthBridge.overrideWithValue(auth),
        wfwApiServiceBridge.overrideWithValue(api),
        sharedPreferencesBridge.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    final state = await container.read(userInfoProvider.future);
    expect(state.hasData, isFalse);
    await Future<void>.delayed(Duration.zero);
    expect(prefs.getString(kScuUserRealname), isNull);
    expect(prefs.getString(kScuUserNumber), isNull);
  });

  test('UserInfoNotifier retry triggers re-fetch', () async {
    final auth = _FakeWfwAuth(ready: true, state: AuthState.ready);
    final api = _ControllableWfwApiService();
    final container = ProviderContainer(
      overrides: [
        wfwAuthBridge.overrideWithValue(auth),
        wfwApiServiceBridge.overrideWithValue(api),
        sharedPreferencesBridge.overrideWithValue(prefs),
      ],
    );
    addTearDown(container.dispose);

    final initial = container.read(userInfoProvider.future);
    api.complete(0, name: '张三', number: '20240001');
    await initial;

    final retry = container.read(userInfoProvider.notifier).retry();
    expect(api.profileRequests, hasLength(2));
    api.complete(1, name: '李四', number: '20240002');
    await retry;

    final updated = await container.read(userInfoProvider.future);
    expect(updated.userRealname, '李四');
    expect(updated.userNumber, '20240002');
  });
}

class _FakeWfwAuth implements WfwAuth {
  _FakeWfwAuth({required this.ready, this.state = AuthState.ready});

  final bool ready;
  @override
  final AuthState state;

  @override
  bool get isReady => ready;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ControllableWfwApiService implements WfwApiService {
  final profileRequests = <Completer<Map<String, dynamic>?>>[];
  final labelsRequests = <Completer<List<Map<String, dynamic>>>>[];

  @override
  Future<Map<String, dynamic>?> fetchUserProfile() {
    final request = Completer<Map<String, dynamic>?>();
    profileRequests.add(request);
    return request.future;
  }

  @override
  Future<List<Map<String, dynamic>>> fetchProfileLabels() {
    final request = Completer<List<Map<String, dynamic>>>();
    labelsRequests.add(request);
    return request.future;
  }

  void complete(int index, {required String name, required String number}) {
    profileRequests[index].complete({
      'realname': name,
      'role': {'number': number},
    });
    labelsRequests[index].complete([
      {'label': '学生', 'owner': number},
    ]);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
