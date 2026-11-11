import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/utils/app_logger.dart';

/// 可统计 close 次数的假 client，用于验证退役时序。
class _CountingClient extends http.BaseClient {
  int closeCount = 0;
  final Future<http.StreamedResponse> Function(http.BaseRequest request)
  handler;

  _CountingClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      handler(request);

  @override
  void close() {
    closeCount++;
  }
}

void main() {
  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<AppLogger>(AppLogger());
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

  group('CookieClient.sendWithClientExceptionRetry', () {
    test('retries once on a fresh client and retires the broken one', () async {
      final broken = _CountingClient((request) async {
        throw http.ClientException('boom', request.url);
      });
      final client = CookieClient(
        inner: broken,
        innerFactory: () => MockClient((request) async {
          return http.Response('ok', 200);
        }),
      );

      final response = await http.Response.fromStream(
        await client.send(http.Request('GET', Uri.parse('https://a.test/x'))),
      );

      expect(response.statusCode, 200);
      // 请求结束后，被换下的旧 client 才被关闭
      expect(broken.closeCount, 1);
    });

    test(
      'does not close the shared client while a request is in flight',
      () async {
        final hangCompleter = Completer<void>();
        final shared = _CountingClient((request) async {
          if (request.url.path == '/hang') {
            await hangCompleter.future;
            return http.StreamedResponse(Stream.value(utf8.encode('ok')), 200);
          }
          throw http.ClientException('boom', request.url);
        });
        var factoryCalls = 0;
        final client = CookieClient(
          inner: shared,
          innerFactory: () {
            factoryCalls++;
            return MockClient((request) async => http.Response('ok', 200));
          },
        );

        // 请求 B 在旧 client 上挂起（模拟其他子系统的并发 SSO 请求）
        final hangFuture = client.send(
          http.Request('GET', Uri.parse('https://a.test/hang')),
        );
        await Future<void>.delayed(Duration.zero);

        // 请求 A 抛 ClientException，触发换 client 重试
        final retryResponse = await http.Response.fromStream(
          await client.send(
            http.Request('GET', Uri.parse('https://a.test/fail')),
          ),
        );
        expect(retryResponse.statusCode, 200);

        // B 仍在飞：旧 client 不能被关闭，否则会连坐取消 B
        expect(factoryCalls, 1);
        expect(shared.closeCount, 0);

        hangCompleter.complete();
        final hangResponse = await http.Response.fromStream(await hangFuture);
        expect(hangResponse.statusCode, 200);

        // 全部请求结束后，退役 client 统一关闭
        expect(shared.closeCount, 1);
      },
    );
  });
}
