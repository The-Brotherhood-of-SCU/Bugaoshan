import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/services/api/wfw_api_service.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/auth/wfw_auth.dart';
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

  test('warms WFW again when ScuAuth returns a new client', () async {
    var firstWarmUps = 0;
    var secondWarmUps = 0;
    final firstClient = CookieClient(
      inner: MockClient((request) async {
        firstWarmUps++;
        return http.Response(
          '{"e":0,"d":{"base":{}}}',
          200,
          headers: {'set-cookie': 'eai-sess=first; Path=/'},
          request: request,
        );
      }),
    );
    final secondClient = CookieClient(
      inner: MockClient((request) async {
        secondWarmUps++;
        return http.Response(
          '{"e":0,"d":{"base":{}}}',
          200,
          headers: {'set-cookie': 'eai-sess=second; Path=/'},
          request: request,
        );
      }),
    );
    final scuAuth = _SwitchableScuAuth(
      prefs,
      logger: logger,
      client: firstClient,
    );
    final wfwAuth = WfwAuth(scuAuth, logger: logger);

    expect(await wfwAuth.getClient(), same(firstClient));
    expect(firstWarmUps, 1);
    expect(wfwAuth.isReady, isTrue);

    scuAuth.client = secondClient;
    expect(await wfwAuth.getClient(), same(secondClient));
    expect(secondWarmUps, 1);
    expect(wfwAuth.isReady, isTrue);

    wfwAuth.dispose();
  });

  test('e=10013 invalidates, re-warms WFW, and retries once', () async {
    // 预热与业务请求访问同一 get-info，按调用顺序区分：
    // 预热(e=0) → 业务(e=10013) → 再预热(e=0) → 业务重试(e=0)
    var getInfoRequests = 0;
    final client = CookieClient(
      inner: MockClient((request) async {
        expect(request.url.path, '/uc/wap/user/get-info');
        getInfoRequests++;
        return switch (getInfoRequests) {
          1 => http.Response('{"e":0,"d":{"base":{}}}', 200, request: request),
          2 => http.Response(
            '{"e":10013,"m":"session expired"}',
            200,
            request: request,
          ),
          3 => http.Response('{"e":0,"d":{"base":{}}}', 200, request: request),
          _ => http.Response(
            '{"e":0,"d":{"base":{"realname":"Test User"}}}',
            200,
            request: request,
          ),
        };
      }),
    );
    final scuAuth = _SwitchableScuAuth(prefs, logger: logger, client: client);
    final wfwAuth = WfwAuth(scuAuth, logger: logger);
    final api = WfwApiService(wfwAuth);

    final profile = await api.fetchUserProfile();

    expect(profile?['realname'], 'Test User');
    expect(getInfoRequests, 4); // 预热、业务、再预热、业务重试

    wfwAuth.dispose();
  });

  test('warm-up landing on a login page is not treated as ready', () async {
    var warmUps = 0;
    final client = CookieClient(
      inner: MockClient((request) async {
        warmUps++;
        // id session 失效时 SSO 链终点是登录 HTML（如 id.scu.edu.cn/login）。
        // 不得视为就绪：否则业务请求必然失效，「invalidate → 预热误报
        // ready → 监听方重新取数 → 再失效」会无限循环。
        return http.Response('<html>login</html>', 200, request: request);
      }),
    );
    final scuAuth = _SwitchableScuAuth(prefs, logger: logger, client: client);
    final wfwAuth = WfwAuth(scuAuth, logger: logger);

    await expectLater(
      wfwAuth.getClient(),
      throwsA(isA<UnauthenticatedException>()),
    );
    expect(wfwAuth.isReady, isFalse);
    expect(warmUps, 1); // 有界：失败即停，不自旋

    wfwAuth.dispose();
  });

  test('warm-up returning e!=0 is not treated as ready', () async {
    var warmUps = 0;
    final client = CookieClient(
      inner: MockClient((request) async {
        warmUps++;
        // 匿名 session（首页 200 下发的匿名 eai-sess）走完 SSO 链仍可能
        // 拿到 e=10013：cookie 存在不代表 session 已绑定用户。
        return http.Response(
          '{"e":10013,"m":"session expired"}',
          200,
          headers: {'set-cookie': 'eai-sess=anonymous; Path=/'},
          request: request,
        );
      }),
    );
    final scuAuth = _SwitchableScuAuth(prefs, logger: logger, client: client);
    final wfwAuth = WfwAuth(scuAuth, logger: logger);

    await expectLater(
      wfwAuth.getClient(),
      throwsA(isA<UnauthenticatedException>()),
    );
    expect(wfwAuth.isReady, isFalse);
    expect(warmUps, 1);

    wfwAuth.dispose();
  });
}

class _SwitchableScuAuth extends ScuAuth {
  CookieClient client;

  _SwitchableScuAuth(
    super.prefs, {
    required super.logger,
    required this.client,
  });

  @override
  Future<CookieClient> getClient() async => client;
}
