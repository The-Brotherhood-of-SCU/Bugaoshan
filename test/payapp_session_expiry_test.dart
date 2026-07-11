import 'dart:convert';

import 'package:bugaoshan/services/api/api_request.dart';
import 'package:bugaoshan/services/api/balance_query_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  const loginTimeoutHtml = '''
    <!doctype html>
    <html>
      <head><title>登录超时</title></head>
      <body>
        <form action="/eleFees/oauth/airWarrant"></form>
        <form action="/eleFees/oauth/lightWarrant"></form>
      </body>
    </html>
  ''';
  const campusJson =
      '{"respCode":"00","data":{"datas":[{"name":"江安","code":"01"}]}}';

  test('known PayApp login redirect is treated as unauthenticated', () async {
    final client = MockClient(
      (request) async => http.Response(
        '',
        302,
        headers: {'location': 'http://payapp.scu.edu.cn/eleFees/index.html'},
        request: request,
      ),
    );

    await expectLater(
      BalanceQueryService().getCampus(client),
      throwsA(isA<UnauthenticatedException>()),
    );
  });

  test('login timeout page triggers one authentication recovery', () async {
    final clients = <http.Client>[
      _responseClient(loginTimeoutHtml, contentType: 'text/html;charset=UTF-8'),
      _responseClient(campusJson, contentType: 'application/json'),
    ];
    var getClientCalls = 0;
    var invalidations = 0;
    final service = BalanceQueryService();

    final campus = await retryOnUnauthenticated(
      () async => clients[getClientCalls++],
      service.getCampus,
      invalidate: () => invalidations++,
    );

    expect(campus.single.code, '01');
    expect(getClientCalls, 2);
    expect(invalidations, 1);
  });

  test('a second login timeout page is not retried indefinitely', () async {
    final clients = <http.Client>[
      _responseClient(loginTimeoutHtml, contentType: 'text/html'),
      _responseClient(loginTimeoutHtml, contentType: 'text/html'),
    ];
    var getClientCalls = 0;
    var invalidations = 0;
    final service = BalanceQueryService();

    await expectLater(
      retryOnUnauthenticated(
        () async => clients[getClientCalls++],
        service.getCampus,
        invalidate: () => invalidations++,
      ),
      throwsA(isA<UnauthenticatedException>()),
    );
    expect(getClientCalls, 2);
    expect(invalidations, 1);
  });

  test('ordinary business HTML is not mistaken for session expiry', () async {
    final client = _responseClient(
      '<html><title>系统维护</title><body>请稍后再试</body></html>',
      contentType: 'text/html',
    );
    var getClientCalls = 0;
    var invalidations = 0;
    final service = BalanceQueryService();

    await expectLater(
      retryOnUnauthenticated(
        () async {
          getClientCalls++;
          return client;
        },
        service.getCampus,
        invalidate: () => invalidations++,
      ),
      throwsA(isA<BalanceQueryException>()),
    );
    expect(getClientCalls, 1);
    expect(invalidations, 0);
  });
}

MockClient _responseClient(String body, {required String contentType}) {
  return MockClient(
    (request) async => http.Response.bytes(
      utf8.encode(body),
      200,
      headers: {'content-type': contentType},
      request: request,
    ),
  );
}
