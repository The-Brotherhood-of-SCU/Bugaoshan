import 'dart:async';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/utils/auth_logger.dart';

void main() {
  late SharedPreferences prefs;
  late AuthLogger logger;

  setUp(() async {
    await getIt.reset();
    logger = AuthLogger();
    getIt.registerSingleton<AuthLogger>(logger);
    FlutterSecureStorage.setMockInitialValues({
      'scu_access_token': 'stale-token',
    });
    SharedPreferences.setMockInitialValues({
      'scu_login_timestamp': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await getIt.reset();
  });

  for (final statusCode in [401, 403]) {
    test(
      'session/save $statusCode within local TTL uses one refresh for concurrent callers',
      () async {
        var sessionSaveCalls = 0;
        final inner = MockClient((request) async {
          sessionSaveCalls++;
          if (sessionSaveCalls <= 2) {
            return http.Response(
              '{"error":"unauthorized"}',
              statusCode,
              request: request,
            );
          }
          return http.Response('{"success":true}', 200, request: request);
        });
        final auth = _TestScuAuth(
          prefs,
          logger: logger,
          cookieClientFactory: () => CookieClient(inner: inner),
        );
        await auth.init();

        final first = auth.getClient();
        final second = auth.getClient();
        await auth.autoLoginStarted.future;
        expect(auth.autoLoginCalls, 1);
        auth.allowAutoLoginToFinish.complete();

        final clients = await Future.wait([first, second]);
        expect(identical(clients[0], clients[1]), isTrue);
        expect(auth.autoLoginCalls, 1);
        expect(sessionSaveCalls, 3);
      },
    );
  }

  test('invalid_token payload triggers refresh even with HTTP 200', () async {
    var sessionSaveCalls = 0;
    final inner = MockClient((request) async {
      sessionSaveCalls++;
      if (sessionSaveCalls <= 2) {
        return http.Response(
          '{"error":"invalid_token"}',
          200,
          request: request,
        );
      }
      return http.Response('{"success":true}', 200, request: request);
    });
    final auth = _TestScuAuth(
      prefs,
      logger: logger,
      cookieClientFactory: () => CookieClient(inner: inner),
    );
    await auth.init();

    final clientFuture = auth.getClient();
    await auth.autoLoginStarted.future;
    auth.allowAutoLoginToFinish.complete();
    await clientFuture;

    expect(auth.autoLoginCalls, 1);
    expect(sessionSaveCalls, 3);
  });
}

class _TestScuAuth extends ScuAuth {
  final autoLoginStarted = Completer<void>();
  final allowAutoLoginToFinish = Completer<void>();
  int autoLoginCalls = 0;

  _TestScuAuth(
    super.prefs, {
    required super.logger,
    required super.cookieClientFactory,
  });

  @override
  Future<bool> autoLogin() async {
    autoLoginCalls++;
    if (!autoLoginStarted.isCompleted) autoLoginStarted.complete();
    await allowAutoLoginToFinish.future;
    return true;
  }
}
