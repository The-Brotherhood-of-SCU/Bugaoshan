import 'dart:async';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/providers/user_info_provider.dart';
import 'package:bugaoshan/services/api/wfw_api_service.dart';
import 'package:bugaoshan/services/auth/auth_state.dart';
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
}

class _FakeWfwAuth extends ChangeNotifier implements WfwAuth {
  _FakeWfwAuth({required bool ready}) : _ready = ready;

  bool _ready;

  @override
  bool get isReady => _ready;

  @override
  AuthState get state => _ready ? AuthState.ready : AuthState.unknown;

  void setReady(bool value) {
    _ready = value;
    notifyListeners();
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

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeScuAuthProvider implements ScuAuthProvider {
  @override
  void setUserInfo(String? realname, String? number) {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
