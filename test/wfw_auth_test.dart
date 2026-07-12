import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/services/api/wfw_api_service.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
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
        return http.Response('first ready', 200, request: request);
      }),
    );
    final secondClient = CookieClient(
      inner: MockClient((request) async {
        secondWarmUps++;
        return http.Response('second ready', 200, request: request);
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

  test('e=10013 invalidates, warms WFW, and retries once', () async {
    var warmUps = 0;
    var profileRequests = 0;
    final client = CookieClient(
      inner: MockClient((request) async {
        if (request.url.path == '/') {
          warmUps++;
          return http.Response('ready', 200, request: request);
        }
        if (request.url.path == '/uc/wap/user/get-info') {
          profileRequests++;
          if (profileRequests == 1) {
            return http.Response(
              '{"e":10013,"m":"session expired"}',
              200,
              request: request,
            );
          }
          return http.Response(
            '{"e":0,"d":{"base":{"realname":"Test User"}}}',
            200,
            request: request,
          );
        }
        return http.Response('not found', 404, request: request);
      }),
    );
    final scuAuth = _SwitchableScuAuth(prefs, logger: logger, client: client);
    final wfwAuth = WfwAuth(scuAuth, logger: logger);
    final api = WfwApiService(wfwAuth);

    final profile = await api.fetchUserProfile();

    expect(profile?['realname'], 'Test User');
    expect(profileRequests, 2);
    expect(warmUps, 2);

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
