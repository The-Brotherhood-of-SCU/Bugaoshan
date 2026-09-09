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

  test('fetchPlanCompletion: multiple plans follow getPyfaIndex buttons '
      '(real HTML form from 教务处选择页)', () async {
    final helper = _buildRoutingApi(
      {
        '/student/integratedQuery/planCompletion/index': '''
            <html>
              <button class="btn btn-success btn-round" title="广播电视编导培养方案(10692)" onclick="getPyfaIndex(&#39;10692&#39;);return false;">
                广播电视编导培养方案 (主修)
              </button>
              <button class="btn btn-success btn-round" title="生成式人工智能与影视工业化（微专业）教学计划(202601221181)" onclick="getPyfaIndex(&#39;202601221181&#39;);return false;">
                生成式人工智能与影视工业化（微专业）教学计划
              </button>
            </html>
          ''',
        '/student/integratedQuery/planCompletion/getPyfaIndex/10692':
            '<html><script>var zNodes = [${_nodeJson('a', '-1', '主修方案')}];</script></html>',
        '/student/integratedQuery/planCompletion/getPyfaIndex/202601221181':
            '<html><script>var zNodes = [${_nodeJson('b', '-1', '微专业方案')}];</script></html>',
      },
      prefs,
      logger,
    );
    addTearDown(helper.auth.dispose);

    final plans = await helper.api.fetchPlanCompletion();
    expect(plans, hasLength(2));
    expect(plans[0].id, '10692');
    expect(plans[0].name, '广播电视编导培养方案');
    expect(plans[0].nodes.single.name, '主修方案');
    expect(plans[1].id, '202601221181');
    expect(plans[1].name, '生成式人工智能与影视工业化（微专业）教学计划');
    expect(plans[1].nodes.single.name, '微专业方案');
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

  test('fetchPlanCompletion: login page triggers re-auth path', () async {
    final helper = _buildRoutingApi(
      {
        '/student/integratedQuery/planCompletion/index':
            '<html><body><form action="/login">请登录</form></body></html>',
      },
      prefs,
      logger,
    );
    addTearDown(helper.auth.dispose);

    // 入口页含登录页强特征（表单提交到 /login）→ _checkSessionExpiry 抛
    // UnauthenticatedException → retryOnUnauthenticated 触发重认证（SSO）。
    // 测试环境无真实 SSO，重认证失败表现为 ServiceException('教务 SSO 登录失败')——
    // 重点是与下方"格式异常"用例区分：会话过期走重认证而非格式错误提示。
    await expectLater(
      helper.api.fetchPlanCompletion(),
      throwsA(
        isA<ServiceException>().having(
          (e) => e.message,
          'message',
          contains('SSO'),
        ),
      ),
    );
  });

  test('fetchSemesters: business page containing login substrings must not '
      'trigger invalidate (issue #282)', () async {
    // issue #282 的真实场景：calendarSemesterCurriculum/index 正常返回 200，
    // 页面里的 loginStatus / clientLogin / 登录链接都是业务内容，
    // 旧判断 `startsWith('<') && contains('login')` 会误判为登录页，
    // 触发 invalidate + 重走 SSO。新判断应正常解析出学期列表。
    final helper = _buildRoutingApi(
      {
        '/student/courseSelect/calendarSemesterCurriculum/index': '''
<html>
<head><title>学期理论课表</title></head>
<body>
  <script>var loginStatus = 1; function clientLogin() {}</script>
  <a href="/login?refer=%2Fstudent" class="hidden">登录</a>
  <select name="xnxdm">
    <option value="2025-2026-2-1">2025-2026学年2学期</option>
  </select>
</body>
</html>
''',
      },
      prefs,
      logger,
    );
    addTearDown(helper.auth.dispose);

    final semesters = await helper.api.fetchSemesters();
    expect(semesters, hasLength(1));
    expect(semesters.single.value, '2025-2026-2-1');
  });

  test('fetchSemesters: real login page still triggers re-auth', () async {
    // fixture 按真实 zhjw 登录页（2026-09 抓取样本）裁剪：
    // <title>登录</title> + form action=/j_spring_security_check +
    // j_username/j_password 字段。
    final helper = _buildRoutingApi(
      {
        '/student/courseSelect/calendarSemesterCurriculum/index': '''
<html>
<head><title>登录</title></head>
<body>
  <h2>欢迎登录四川大学教务管理系统<br />学生端</h2>
  <form class="form-signin" action="/j_spring_security_check" method="post">
    <input type="text" id="input_username" name="j_username" maxlength="50" placeholder="学号"/>
    <input type="password" id="input_password" name="j_password" autocomplete="off" placeholder="密码"/>
    <input type="submit" id="loginButton" value="登 录"/>
  </form>
</body>
</html>
''',
      },
      prefs,
      logger,
    );
    addTearDown(helper.auth.dispose);

    // 真登录页 → UnauthenticatedException → 重认证（测试环境 SSO 失败
    // 表现为 '教务 SSO 登录失败'），而不是"无法获取学期列表"。
    await expectLater(
      helper.api.fetchSemesters(),
      throwsA(
        isA<ServiceException>().having(
          (e) => e.message,
          'message',
          contains('SSO'),
        ),
      ),
    );
  });

  test('fetchPlanCompletion: malformed page without zNodes and links throws '
      'ServiceException (never silently returns empty)', () async {
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
    // 页面既无 zNodes 也无链接、也不是登录页 → 抛 ServiceException('格式异常')，
    // 由 Provider 展示可诊断错误，且不会误走重认证路径。
    await expectLater(
      helper.api.fetchPlanCompletion(),
      throwsA(
        isA<ServiceException>().having(
          (e) => e.message,
          'message',
          contains('格式异常'),
        ),
      ),
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
