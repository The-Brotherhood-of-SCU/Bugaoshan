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
import 'package:bugaoshan/utils/storage_keys.dart';

void main() {
  late SharedPreferences prefs;
  late AuthLogger logger;

  setUp(() async {
    await getIt.reset();
    logger = AuthLogger();
    getIt.registerSingleton<AuthLogger>(logger);
    FlutterSecureStorage.setMockInitialValues({kScuAccessToken: 'stale-token'});
    SharedPreferences.setMockInitialValues({
      kScuLoginTimestamp: DateTime.now().millisecondsSinceEpoch ~/ 1000,
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

  group('extractTokenErrorMessage', () {
    test('extracts message from business format', () {
      expect(
        extractTokenErrorMessage('{"success":false,"message":"密码错误"}'),
        '密码错误',
      );
    });

    test('extracts msg field', () {
      expect(extractTokenErrorMessage('{"msg":"账号或密码错误"}'), '账号或密码错误');
    });

    test('prefers message over OAuth error code', () {
      expect(
        extractTokenErrorMessage('{"message":"密码错误","error":"invalid_grant"}'),
        '密码错误',
      );
    });

    test('extracts OAuth error_description', () {
      expect(
        extractTokenErrorMessage(
          '{"error":"invalid_grant","error_description":"用户名或密码错误"}',
        ),
        '用户名或密码错误',
      );
    });

    test('falls back to OAuth error code', () {
      expect(
        extractTokenErrorMessage('{"error":"invalid_grant"}'),
        'invalid_grant',
      );
    });

    test('returns null for non-JSON body', () {
      expect(extractTokenErrorMessage('<html>gateway error</html>'), isNull);
    });

    test('returns null for empty or missing error fields', () {
      expect(extractTokenErrorMessage('{}'), isNull);
      expect(extractTokenErrorMessage('{"success":false}'), isNull);
      expect(extractTokenErrorMessage('{"message":""}'), isNull);
    });

    test('returns null for non-map JSON', () {
      expect(extractTokenErrorMessage('[1,2,3]'), isNull);
    });
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
