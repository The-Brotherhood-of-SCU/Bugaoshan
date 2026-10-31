import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/scu_backend/core/api_session.dart';
import 'package:bugaoshan/scu_backend/core/cookie_client.dart';
import 'package:bugaoshan/scu_backend/core/scu_exceptions.dart';
import 'package:bugaoshan/utils/app_logger.dart';

void main() {
  late AppLogger logger;

  setUp(() async {
    await getIt.reset();
    logger = AppLogger();
    getIt.registerSingleton<AppLogger>(logger);
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('ApiSession URL resolution', () {
    test('resolves relative paths with and without leading slash', () {
      final session = ApiSession(
        getClient: () async => CookieClient(),
        baseUrl: Uri.parse('https://example.com/api'),
        logTag: 'Test',
      );

      expect(
        session.resolveUri('user').toString(),
        'https://example.com/api/user',
      );
      expect(
        session.resolveUri('/user').toString(),
        'https://example.com/api/user',
      );
      expect(
        session.resolveUri('https://other.com/foo').toString(),
        'https://other.com/foo',
      );
    });

    test('preserves and appends query parameters', () {
      final session = ApiSession(
        getClient: () async => CookieClient(),
        baseUrl: Uri.parse('https://example.com/api'),
        logTag: 'Test',
      );

      final uri = session.resolveUri('user?active=1', {
        'id': 123,
        'role': 'admin',
      });
      expect(uri.queryParameters, {
        'active': '1',
        'id': '123',
        'role': 'admin',
      });
    });
  });

  group('ApiSession execution and retry', () {
    test('successful GET request returns response', () async {
      final client = CookieClient(
        inner: MockClient((req) async {
          expect(req.url.toString(), 'https://example.com/api/test');
          expect(req.headers['X-Custom'], 'hello');
          return http.Response('{"ok":true}', 200);
        }),
      );

      final session = ApiSession(
        getClient: () async => client,
        baseUrl: Uri.parse('https://example.com/api'),
        logTag: 'Test',
        defaultHeaders: {'X-Custom': 'hello'},
      );

      final resp = await session.get('test');
      expect(resp.statusCode, 200);
      expect(resp.body, '{"ok":true}');
    });

    test(
      'retries once on UnauthenticatedException after calling invalidate',
      () async {
        var invalidateCount = 0;
        var attempts = 0;

        final client = CookieClient(
          inner: MockClient((req) async {
            attempts++;
            if (attempts == 1) {
              return http.Response('Unauthorized', 401);
            }
            return http.Response('{"status":"recovered"}', 200);
          }),
        );

        final session = ApiSession(
          getClient: () async => client,
          invalidate: () => invalidateCount++,
          baseUrl: Uri.parse('https://example.com/api'),
          logTag: 'Test',
        );

        final json = await session.getJsonMap('test');
        expect(attempts, 2);
        expect(invalidateCount, 1);
        expect(json['status'], 'recovered');
      },
    );

    test(
      'detects login page HTML and throws UnauthenticatedException',
      () async {
        final loginHtml = '''
        <html>
          <head><title>四川大学统一身份认证 登录</title></head>
          <body><form action="/j_spring_security_check"></form></body>
        </html>
      ''';

        final client = CookieClient(
          inner: MockClient((req) async {
            return http.Response.bytes(
              utf8.encode(loginHtml),
              200,
              headers: {'content-type': 'text/html; charset=utf-8'},
            );
          }),
        );

        final session = ApiSession(
          getClient: () async => client,
          baseUrl: Uri.parse('https://example.com/api'),
          logTag: 'Test',
        );

        await expectLater(
          session.get('protected'),
          throwsA(isA<UnauthenticatedException>()),
        );
      },
    );

    test('custom sessionExpiryChecker takes precedence', () async {
      final client = CookieClient(
        inner: MockClient((req) async {
          return http.Response('custom error', 200);
        }),
      );

      final session = ApiSession(
        getClient: () async => client,
        baseUrl: Uri.parse('https://example.com/api'),
        logTag: 'Test',
        sessionExpiryChecker: (body, status) {
          if (body.contains('custom error')) {
            throw const UnauthenticatedException('custom auth expired');
          }
        },
      );

      await expectLater(
        session.get('test'),
        throwsA(
          isA<UnauthenticatedException>().having(
            (e) => e.message,
            'message',
            'custom auth expired',
          ),
        ),
      );
    });

    test('non-2xx response throws ServiceException with statusCode', () async {
      final client = CookieClient(
        inner: MockClient((req) async {
          return http.Response('gateway error', 500);
        }),
      );
      final session = ApiSession(
        getClient: () async => client,
        baseUrl: Uri.parse('https://example.com/api'),
        logTag: 'Test',
      );

      await expectLater(
        session.getJsonMap('failing'),
        throwsA(
          isA<ServiceException>()
              .having((e) => e.statusCode, 'statusCode', 500)
              .having((e) => e.message, 'message', contains('failing')),
        ),
      );
    });

    test(
      'empty body is a ServiceException when not treated as expiry',
      () async {
        final client = CookieClient(
          inner: MockClient((req) async => http.Response('', 200)),
        );
        final session = ApiSession(
          getClient: () async => client,
          baseUrl: Uri.parse('https://example.com/api'),
          logTag: 'Test',
          emptyBodyThrowsUnauthenticated: false,
        );

        await expectLater(
          session.getJsonMap('empty'),
          throwsA(
            isA<ServiceException>().having(
              (e) => e.message,
              'message',
              contains('空响应'),
            ),
          ),
        );
      },
    );

    test('empty body triggers UnauthenticatedException by default', () async {
      var attempts = 0;
      final client = CookieClient(
        inner: MockClient((req) async {
          attempts++;
          return http.Response('', 200);
        }),
      );
      final session = ApiSession(
        getClient: () async => client,
        baseUrl: Uri.parse('https://example.com/api'),
        logTag: 'Test',
      );

      await expectLater(
        session.getJsonMap('empty'),
        throwsA(isA<UnauthenticatedException>()),
      );
      // 会话失效会重试一次，第二次仍为空才上抛。
      expect(attempts, 2);
    });
  });

  group('ApiSession typed methods', () {
    test('getHtml returns trimmed body', () async {
      final client = CookieClient(
        inner: MockClient((req) async {
          expect(req.headers['Accept'], contains('text/html'));
          return http.Response('  <div>Hello</div>  ', 200);
        }),
      );
      final session = ApiSession(
        getClient: () async => client,
        baseUrl: Uri.parse('https://example.com/api'),
        logTag: 'Test',
      );

      final html = await session.getHtml('page');
      expect(html, '<div>Hello</div>');
    });

    test(
      'postFormForJsonMap sends encoded form body and parses response',
      () async {
        final client = CookieClient(
          inner: MockClient((req) async {
            expect(req.body, 'name=test&action=save');
            return http.Response('{"success": true, "id": 42}', 200);
          }),
        );
        final session = ApiSession(
          getClient: () async => client,
          baseUrl: Uri.parse('https://example.com/api'),
          logTag: 'Test',
        );

        final json = await session.postFormForJsonMap('save', {
          'name': 'test',
          'action': 'save',
        });
        expect(json['success'], isTrue);
        expect(json['id'], 42);
      },
    );

    test('postJsonForJsonMap sends json body and parses response', () async {
      final client = CookieClient(
        inner: MockClient((req) async {
          final decoded = jsonDecode(req.body);
          expect(decoded['score'], 99);
          return http.Response('{"code": 0, "msg": "ok"}', 200);
        }),
      );
      final session = ApiSession(
        getClient: () async => client,
        baseUrl: Uri.parse('https://example.com/api'),
        logTag: 'Test',
      );

      final json = await session.postJsonForJsonMap('submit', {'score': 99});
      expect(json['code'], 0);
    });

    test('getJsonList parses json arrays', () async {
      final client = CookieClient(
        inner: MockClient((req) async => http.Response('[1, 2, 3]', 200)),
      );
      final session = ApiSession(
        getClient: () async => client,
        baseUrl: Uri.parse('https://example.com/api'),
        logTag: 'Test',
      );

      expect(await session.getJsonList('list'), [1, 2, 3]);
    });

    test(
      'postFormForJsonList sends form body and parses json arrays',
      () async {
        final client = CookieClient(
          inner: MockClient((req) async {
            expect(req.body, 'name=test&type=list');
            return http.Response('[{"id": 1}, {"id": 2}]', 200);
          }),
        );
        final session = ApiSession(
          getClient: () async => client,
          baseUrl: Uri.parse('https://example.com/api'),
          logTag: 'Test',
        );

        final list = await session.postFormForJsonList('list', {
          'name': 'test',
          'type': 'list',
        });
        expect(list, hasLength(2));
        expect(list.first['id'], 1);
      },
    );

    test('followRedirects follows 302 to the final response', () async {
      final client = CookieClient(
        inner: MockClient((req) async {
          if (req.url.path.endsWith('/start')) {
            return http.Response('', 302, headers: {'location': '/api/final'});
          }
          return http.Response('done', 200);
        }),
      );
      final session = ApiSession(
        getClient: () async => client,
        baseUrl: Uri.parse('https://example.com/api'),
        logTag: 'Test',
      );

      final resp = await session.followRedirects('start');
      expect(resp.statusCode, 200);
      expect(resp.body, 'done');
    });

    test('jsonValidator receives both map and list payloads', () async {
      final client = CookieClient(
        inner: MockClient((req) async {
          return req.url.path.endsWith('/list')
              ? http.Response('[1, 2]', 200)
              : http.Response('{"e": 10013}', 200);
        }),
      );
      final session = ApiSession(
        getClient: () async => client,
        baseUrl: Uri.parse('https://example.com/api'),
        logTag: 'Test',
        jsonValidator: (json) {
          if (json is Map<String, dynamic> &&
              json['e']?.toString() == '10013') {
            throw const UnauthenticatedException('session expired');
          }
          if (json is List<dynamic>) {
            throw const ServiceException('list business error');
          }
        },
      );

      await expectLater(
        session.getJsonMap('map'),
        throwsA(isA<UnauthenticatedException>()),
      );
      await expectLater(
        session.getJsonList('list'),
        throwsA(
          isA<ServiceException>().having(
            (e) => e.message,
            'message',
            'list business error',
          ),
        ),
      );
    });
  });

  group('ApiEnvelope', () {
    test('unwrapWfw successfully extracts d on e == 0', () {
      final json = {
        'e': 0,
        'm': '',
        'd': {'name': 'Alice'},
      };
      final data = ApiEnvelope.unwrapWfw(json);
      expect(data, {'name': 'Alice'});
    });

    test('unwrapWfw throws UnauthenticatedException on e == 10013', () {
      final json = {'e': 10013, 'm': 'Session expired'};
      expect(
        () => ApiEnvelope.unwrapWfw(json),
        throwsA(isA<UnauthenticatedException>()),
      );
    });

    test('unwrapWfw throws ServiceException on non-zero e', () {
      final json = {'e': 1, 'm': 'Permission denied'};
      expect(
        () => ApiEnvelope.unwrapWfw(json),
        throwsA(
          isA<ServiceException>().having(
            (e) => e.message,
            'message',
            'Permission denied',
          ),
        ),
      );
    });

    test('validateWfw skips non-map payloads', () {
      expect(() => ApiEnvelope.validateWfw(const [1, 2]), returnsNormally);
    });
  });
}
