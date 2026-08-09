import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/auth/zhjw_auth.dart';
import 'package:bugaoshan/utils/auth_logger.dart';

void main() {
  late SharedPreferences prefs;
  late AuthLogger logger;

  setUp(() async {
    await getIt.reset();
    logger = AuthLogger();
    getIt.registerSingleton<AuthLogger>(logger);
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await getIt.reset();
  });

  test('fetchCurrentWeek parses teaching week from home page', () async {
    final helper = _buildApi('<html>第12周</html>', prefs, logger);
    addTearDown(helper.auth.dispose);
    expect(await helper.api.fetchCurrentWeek(), 12);
  });

  test('fetchCurrentWeek returns null on vacation home page', () async {
    final helper = _buildApi('<html>当前处于假期时间</html>', prefs, logger);
    addTearDown(helper.auth.dispose);
    expect(await helper.api.fetchCurrentWeek(), isNull);
  });

  test(
    'fetchCurrentWeek throws when week is unavailable outside vacation',
    () async {
      final helper = _buildApi('<html>教务系统</html>', prefs, logger);
      addTearDown(helper.auth.dispose);
      await expectLater(
        helper.api.fetchCurrentWeek(),
        throwsA(isA<ServiceException>()),
      );
    },
  );
}

({ZhjwApiService api, ZhjwAuth auth}) _buildApi(
  String homeBody,
  SharedPreferences prefs,
  AuthLogger logger,
) {
  var requests = 0;
  final client = CookieClient(
    inner: MockClient((request) async {
      requests++;
      if (requests == 1) return http.Response('ok', 200, request: request);
      return http.Response.bytes(
        utf8.encode(homeBody),
        200,
        headers: const {'content-type': 'text/html; charset=utf-8'},
        request: request,
      );
    }),
  );
  final scuAuth = _TestScuAuth(prefs, logger: logger, client: client);
  final auth = ZhjwAuth(scuAuth, logger: logger);
  return (api: ZhjwApiService(auth), auth: auth);
}

class _TestScuAuth extends ScuAuth {
  final CookieClient client;

  _TestScuAuth(super.prefs, {required super.logger, required this.client});

  @override
  Future<CookieClient> getClient() async => client;

  @override
  String? get accessToken => 'test-token';
}
