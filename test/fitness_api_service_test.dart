import 'dart:convert';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/services/api/fitness_api_service.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/services/auth/fitness_auth.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/utils/auth_logger.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    await getIt.reset();
    getIt.registerSingleton<AuthLogger>(AuthLogger());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() => getIt.reset());

  (_FakeFitnessAuth, FitnessApiService) makeService(
    List<CookieClient> clients,
  ) {
    final scuAuth = _FakeScuAuth(prefs);
    final auth = _FakeFitnessAuth(scuAuth, clients);
    return (auth, FitnessApiService(auth));
  }

  test('体测服务 session 失效会 invalidate 并只重试一次', () async {
    final expired = _jsonClient({'status': 0, 'info': '登录信息失效'});
    final recovered = _jsonClient({
      'status': 1,
      'data': [
        {'title': '恢复后的通知'},
      ],
    });
    final (auth, service) = makeService([expired, recovered]);

    final notices = await service.fetchNotices();

    expect(notices.single.title, '恢复后的通知');
    expect(auth.getClientCalls, 2);
    expect(auth.invalidations, 1);
  });

  test('成绩查询保留年份参数并解析为 typed 模型', () async {
    http.Request? received;
    final client = CookieClient(
      inner: MockClient((request) async {
        received = request;
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'status': 1,
              'data': {'total_score': 95, 'student_name': '张三'},
            }),
          ),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
          request: request,
        );
      }),
    );
    final (_, service) = makeService([client]);

    final score = await service.fetchScore(2024);

    expect(score?.totalScore, 95);
    expect(score?.studentName, '张三');
    expect(received?.url.path, contains('getStudentScore'));
    expect(received?.body, 'year_num=2024');
  });

  test('非认证业务失败透传为 ServiceException，且不重试', () async {
    final client = _jsonClient({'status': 0, 'info': '暂未开放查询'});
    final (auth, service) = makeService([client]);

    await expectLater(
      service.fetchScore(2025),
      throwsA(isA<ServiceException>()),
    );
    expect(auth.getClientCalls, 1);
    expect(auth.invalidations, 0);
  });
}

CookieClient _jsonClient(Map<String, dynamic> body) {
  return CookieClient(
    inner: MockClient(
      (request) async => http.Response.bytes(
        utf8.encode(jsonEncode(body)),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
        request: request,
      ),
    ),
  );
}

class _FakeScuAuth extends ScuAuth {
  _FakeScuAuth(super.prefs);

  @override
  Future<CookieClient> getClient() async => CookieClient();
}

class _FakeFitnessAuth extends FitnessAuth {
  _FakeFitnessAuth(super.scuAuth, this._clients);

  final List<CookieClient> _clients;
  int getClientCalls = 0;
  int invalidations = 0;

  @override
  Future<CookieClient> getClient() async {
    final index = getClientCalls < _clients.length
        ? getClientCalls
        : _clients.length - 1;
    getClientCalls++;
    return _clients[index];
  }

  @override
  void invalidate() {
    invalidations++;
  }
}
