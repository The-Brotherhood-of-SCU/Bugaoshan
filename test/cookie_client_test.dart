import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/utils/auth_logger.dart';

void main() {
  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<AuthLogger>(AuthLogger());
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('CookieClient.followRedirects sensitive headers', () {
    test('keeps Authorization on relative same-origin redirects', () async {
      final requests = <http.Request>[];
      final client = CookieClient(
        inner: MockClient((request) async {
          requests.add(request);
          if (request.url.path == '/start') {
            return http.Response(
              '',
              302,
              headers: {'location': '/next'},
              request: request,
            );
          }
          return http.Response('ok', 200, request: request);
        }),
      );

      await client.followRedirects(
        Uri.parse('https://id.scu.edu.cn/start'),
        headers: {'Authorization': 'Bearer secret'},
      );

      expect(requests, hasLength(2));
      expect(requests[0].headers['Authorization'], 'Bearer secret');
      expect(requests[1].headers['Authorization'], 'Bearer secret');
    });

    test('drops Authorization on cross-origin redirects', () async {
      final requests = <http.Request>[];
      final client = CookieClient(
        inner: MockClient((request) async {
          requests.add(request);
          if (request.url.host == 'id.scu.edu.cn') {
            return http.Response(
              '',
              302,
              headers: {'location': 'https://wfw.scu.edu.cn/oauth'},
              request: request,
            );
          }
          return http.Response('ok', 200, request: request);
        }),
      );

      await client.followRedirects(
        Uri.parse('https://id.scu.edu.cn/start'),
        headers: {'Authorization': 'Bearer secret'},
      );

      expect(requests, hasLength(2));
      expect(requests[0].headers['Authorization'], 'Bearer secret');
      expect(requests[1].headers, isNot(contains('Authorization')));
    });

    test('drops Authorization on HTTPS to HTTP redirects', () async {
      final requests = <http.Request>[];
      final client = CookieClient(
        inner: MockClient((request) async {
          requests.add(request);
          if (request.url.scheme == 'https') {
            return http.Response(
              '',
              302,
              headers: {'location': 'http://id.scu.edu.cn/next'},
              request: request,
            );
          }
          return http.Response('ok', 200, request: request);
        }),
      );

      await client.followRedirects(
        Uri.parse('https://id.scu.edu.cn/start'),
        headers: {'Authorization': 'Bearer secret'},
      );

      expect(requests, hasLength(2));
      expect(requests[1].headers, isNot(contains('Authorization')));
    });

    test('keeps Authorization for an explicitly allowed origin', () async {
      final requests = <http.Request>[];
      final client = CookieClient(
        inner: MockClient((request) async {
          requests.add(request);
          if (request.url.host == 'id.scu.edu.cn') {
            return http.Response(
              '',
              302,
              headers: {'location': 'https://trusted.scu.edu.cn/next'},
              request: request,
            );
          }
          return http.Response('ok', 200, request: request);
        }),
      );

      await client.followRedirects(
        Uri.parse('https://id.scu.edu.cn/start'),
        headers: {'Authorization': 'Bearer secret'},
        sensitiveHeaderAllowedOrigins: {
          Uri.parse('https://trusted.scu.edu.cn'),
        },
      );

      expect(requests, hasLength(2));
      expect(requests[1].headers['Authorization'], 'Bearer secret');
    });
  });
}
