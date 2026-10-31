import 'dart:convert';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/scu_backend/core/api_session.dart';
import 'package:bugaoshan/scu_backend/core/cookie_client.dart';
import 'package:bugaoshan/scu_backend/core/scu_exceptions.dart';
import 'package:bugaoshan/scu_backend/wfw/wfw_api_service.dart';
import 'package:bugaoshan/scu_backend/wfw/wfw_auth.dart';
import 'package:bugaoshan/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<AppLogger>(AppLogger());
  });

  tearDown(() async {
    await getIt.reset();
  });

  Future<WfwApiService> buildApi(Map<String, dynamic> body) async {
    final client = CookieClient(
      inner: MockClient((request) async {
        return http.Response.bytes(
          utf8.encode(jsonEncode(body)),
          200,
          headers: const {'content-type': 'application/json; charset=utf-8'},
          request: request,
        );
      }),
    );
    final session = ApiSession(
      getClient: () async => client,
      baseUrl: Uri.parse('https://wfw.scu.edu.cn'),
      logTag: 'WfwApiServiceTest',
      jsonValidator: ApiEnvelope.validateWfw,
    );
    return WfwApiService(_FakeWfwAuth(client), session: session);
  }

  test('fetchUserProfile returns base on e == 0', () async {
    final api = await buildApi({
      'e': 0,
      'd': {
        'base': {'realname': '张三', 'number': '20230001'},
      },
    });

    final profile = await api.fetchUserProfile();
    expect(profile?['realname'], '张三');
  });

  test('fetchUserProfile returns null on business e != 0', () async {
    final api = await buildApi({'e': 1, 'm': '无档案'});

    expect(await api.fetchUserProfile(), isNull);
  });

  test(
    'fetchUserProfile throws UnauthenticatedException on e == 10013',
    () async {
      final api = await buildApi({'e': 10013, 'm': '登录已失效'});

      await expectLater(
        api.fetchUserProfile(),
        throwsA(isA<UnauthenticatedException>()),
      );
    },
  );
}

/// 只用于满足 WfwApiService 的构造签名；注入 session 时不会调用 auth。
class _FakeWfwAuth extends ChangeNotifier implements WfwAuth {
  _FakeWfwAuth(this.client);

  final CookieClient client;

  @override
  Future<CookieClient> getClient() async => client;

  @override
  void invalidate() {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
