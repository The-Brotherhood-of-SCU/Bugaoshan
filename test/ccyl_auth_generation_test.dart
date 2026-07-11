import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/pages/campus/ccyl/models/ccyl_models.dart';
import 'package:bugaoshan/services/auth/ccyl_auth.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/utils/auth_logger.dart';
import 'package:bugaoshan/utils/secure_storage.dart';

void main() {
  late SharedPreferences prefs;
  late AuthLogger logger;

  setUp(() async {
    await getIt.reset();
    logger = AuthLogger();
    getIt.registerSingleton<AuthLogger>(logger);
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await getIt.reset();
  });

  test('invalidate prevents a pending reLogin from restoring token', () async {
    final started = Completer<void>();
    final response = Completer<CcylLoginResult>();
    final auth = _pendingAuth(prefs, logger, started, response);

    final pending = auth.reLogin();
    await started.future;
    auth.invalidate();
    response.complete(_loginResult('old-token'));

    expect(await pending, isFalse);
    expect(auth.isLoggedIn, isFalse);
    expect(auth.token, isNull);
  });

  test('logout prevents a pending reLogin from restoring storage', () async {
    final started = Completer<void>();
    final response = Completer<CcylLoginResult>();
    final auth = _pendingAuth(prefs, logger, started, response);

    final pending = auth.reLogin();
    await started.future;
    await auth.logout();
    response.complete(_loginResult('old-token'));

    expect(await pending, isFalse);
    expect(auth.isLoggedIn, isFalse);
    expect(
      await SecureStorageProvider.instance.read(key: 'ccyl_session_v2'),
      isNull,
    );
  });

  test('an old reLogin cannot overwrite a newer successful login', () async {
    final oldStarted = Completer<void>();
    final newStarted = Completer<void>();
    final oldResponse = Completer<CcylLoginResult>();
    final newResponse = Completer<CcylLoginResult>();
    var loginCalls = 0;
    final auth = CcylAuth(
      _PrincipalScuAuth(prefs, logger: logger),
      logger: logger,
      oauthCodeProvider: () async => 'oauth-code',
      login: (_) {
        loginCalls++;
        if (loginCalls == 1) {
          oldStarted.complete();
          return oldResponse.future;
        }
        newStarted.complete();
        return newResponse.future;
      },
    );

    final oldLogin = auth.reLogin();
    await oldStarted.future;
    auth.invalidate();
    final newLogin = auth.reLogin();
    await newStarted.future;
    newResponse.complete(_loginResult('new-token'));
    expect(await newLogin, isTrue);

    oldResponse.complete(_loginResult('old-token'));
    expect(await oldLogin, isFalse);
    expect(auth.token, 'new-token');
  });
}

CcylAuth _pendingAuth(
  SharedPreferences prefs,
  AuthLogger logger,
  Completer<void> started,
  Completer<CcylLoginResult> response,
) {
  return CcylAuth(
    _PrincipalScuAuth(prefs, logger: logger),
    logger: logger,
    oauthCodeProvider: () async => 'oauth-code',
    login: (_) {
      started.complete();
      return response.future;
    },
  );
}

CcylLoginResult _loginResult(String token) => (
  token: token,
  user: CcylUser(
    id: 'ccyl-user',
    userName: 'student-a',
    realname: 'Student A',
    orgName: 'SCU',
  ),
);

class _PrincipalScuAuth extends ScuAuth {
  _PrincipalScuAuth(super.prefs, {required super.logger});

  @override
  String? get principal => 'student-a';
}
