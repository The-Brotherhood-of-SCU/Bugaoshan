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

  test('fetchPlanCompletion: single plan from index page zNodes', () async {
    final helper = _buildRoutingApi(
      {
        '/student/integratedQuery/planCompletion/index':
            '<html><script>var zNodes = [${_nodeJson('1', '-1', '公共基础课')}];</script></html>',
      },
      prefs,
      logger,
    );
    addTearDown(helper.auth.dispose);

    final plans = await helper.api.fetchPlanCompletion();
    expect(plans, hasLength(1));
    expect(plans.single.id, '');
    expect(plans.single.nodes.single.name, '公共基础课');
  });

  test('fetchPlanCompletion: multiple plans follow getPyfaIndex links', () async {
    final helper = _buildRoutingApi(
      {
        '/student/integratedQuery/planCompletion/index': '''
          <html>
            <ul class="plan-list">
              <li><a href="/student/integratedQuery/planCompletion/getPyfaIndex/10101">2023级-软件工程-主修</a></li>
              <li><a href="/student/integratedQuery/planCompletion/getPyfaIndex/10102">2023级-软件工程-辅修</a></li>
            </ul>
            <script>var zNodes = [];</script>
          </html>
        ''',
        '/student/integratedQuery/planCompletion/getPyfaIndex/10101':
            '<html><script>var zNodes = [${_nodeJson('a', '-1', '主修方案')}];</script></html>',
        '/student/integratedQuery/planCompletion/getPyfaIndex/10102':
            '<html><script>var zNodes = [${_nodeJson('b', '-1', '辅修方案')}];</script></html>',
      },
      prefs,
      logger,
    );
    addTearDown(helper.auth.dispose);

    final plans = await helper.api.fetchPlanCompletion();
    expect(plans, hasLength(2));
    expect(plans[0].id, '10101');
    expect(plans[0].name, '2023级-软件工程-主修');
    expect(plans[0].nodes.single.name, '主修方案');
    expect(plans[1].id, '10102');
    expect(plans[1].name, '2023级-软件工程-辅修');
    expect(plans[1].nodes.single.name, '辅修方案');
  });

  test(
    'fetchPlanCompletion: no plan (empty zNodes and no links) returns empty',
    () async {
      final helper = _buildRoutingApi(
        {
          '/student/integratedQuery/planCompletion/index':
              '<html><script>var zNodes = [];</script></html>',
        },
        prefs,
        logger,
      );
      addTearDown(helper.auth.dispose);

      final plans = await helper.api.fetchPlanCompletion();
      expect(plans, isEmpty);
    },
  );

  test('fetchPlanCompletion: malformed page without zNodes and links throws '
      '(never silently returns empty)', () async {
    final helper = _buildRoutingApi(
      {
        '/student/integratedQuery/planCompletion/index':
            '<html><body>页面异常</body></html>',
      },
      prefs,
      logger,
    );
    addTearDown(helper.auth.dispose);

    // 核心诉求（issue #246）：解析失败必须抛可诊断错误，不能静默返回 []。
    // 页面既无 zNodes 也无链接 → 被视为非业务页，抛 UnauthenticatedException
    // 触发重认证；测试环境无真实 SSO，重认证失败表现为 ServiceException。
    // 两者都属于 ScuException，这里只验证"不会静默返回空列表"。
    await expectLater(
      helper.api.fetchPlanCompletion(),
      throwsA(isA<ScuException>()),
    );
  });

  test(
    'fetchPlanCompletion: broken zNodes JSON throws ServiceException',
    () async {
      final helper = _buildRoutingApi(
        {
          '/student/integratedQuery/planCompletion/index':
              '<html><script>var zNodes = [{"id": 1, broken]};</script></html>',
        },
        prefs,
        logger,
      );
      addTearDown(helper.auth.dispose);

      await expectLater(
        helper.api.fetchPlanCompletion(),
        throwsA(isA<ServiceException>()),
      );
    },
  );
}

String _nodeJson(String id, String pId, String name) => _jsonEncodeNode({
  'id': id,
  'pId': pId,
  'flagId': id,
  'flagType': '001',
  'name': name,
  'sfwc': '否',
  'yxxf': '0',
  'zsxf': '1',
});

String _jsonEncodeNode(Map<String, dynamic> node) => jsonEncode(node);

/// 构建按 URL 路径路由响应的 MockClient。
({ZhjwApiService api, ZhjwAuth auth}) _buildRoutingApi(
  Map<String, String> routes,
  SharedPreferences prefs,
  AuthLogger logger,
) {
  var requests = 0;
  final client = CookieClient(
    inner: MockClient((request) async {
      requests++;
      // 第一个请求是 CookieClient 的域隔离探测请求（不在路由内）
      if (requests == 1) return http.Response('ok', 200, request: request);
      final path = request.url.path;
      final body = routes[path];
      if (body == null) {
        return http.Response('route not found: $path', 404, request: request);
      }
      return http.Response.bytes(
        utf8.encode(body),
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
