import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/pages/campus/ccyl/models/ccyl_models.dart';
import 'package:bugaoshan/services/api/ccyl_api_service.dart';
import 'package:bugaoshan/services/auth/ccyl_auth.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/ccyl/ccyl_service.dart';
import 'package:bugaoshan/utils/auth_logger.dart';

void main() {
  late SharedPreferences prefs;
  late AuthLogger logger;

  setUp(() async {
    await getIt.reset();
    logger = AuthLogger();
    getIt.registerSingleton<AuthLogger>(logger);
    FlutterSecureStorage.setMockInitialValues({});
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await getIt.reset();
  });

  test('only CCYL business code 401 is classified as auth expiry', () {
    expect(isCcylAuthExpiredCode(401), isTrue);
    expect(isCcylAuthExpiredCode('401'), isTrue);
    expect(isCcylAuthExpiredCode(400), isFalse);
    expect(isCcylAuthExpiredCode(500), isFalse);
    expect(isCcylAuthExpiredCode(null), isFalse);
  });

  test('ordinary business failure does not replay a write operation', () async {
    var loginCalls = 0;
    var oauthCalls = 0;
    final auth = await _authenticatedCcylAuth(
      prefs,
      logger,
      onLogin: () => loginCalls++,
      onOAuth: () => oauthCalls++,
    );
    var operationCalls = 0;

    await expectLater(
      retryOnCcylAuthError(auth, () async {
        operationCalls++;
        throw const CcylException('报名人数已满');
      }),
      throwsA(isA<CcylException>()),
    );

    expect(operationCalls, 1);
    expect(loginCalls, 1);
    expect(oauthCalls, 0);
  });

  test(
    'explicit auth expiry reauthenticates and retries exactly once',
    () async {
      var loginCalls = 0;
      var oauthCalls = 0;
      final auth = await _authenticatedCcylAuth(
        prefs,
        logger,
        onLogin: () => loginCalls++,
        onOAuth: () => oauthCalls++,
      );
      var operationCalls = 0;

      final result = await retryOnCcylAuthError(auth, () async {
        operationCalls++;
        if (operationCalls == 1) {
          throw const CcylAuthExpiredException('token失效，请重新登录');
        }
        return 'ok';
      });

      expect(result, 'ok');
      expect(operationCalls, 2);
      expect(loginCalls, 2);
      expect(oauthCalls, 1);
    },
  );
}

Future<CcylAuth> _authenticatedCcylAuth(
  SharedPreferences prefs,
  AuthLogger logger, {
  required void Function() onLogin,
  required void Function() onOAuth,
}) async {
  final scuAuth = _PrincipalScuAuth(prefs, logger: logger);
  final auth = CcylAuth(
    scuAuth,
    logger: logger,
    oauthCodeProvider: () async {
      onOAuth();
      return 'refresh-code';
    },
    login: (_) async {
      onLogin();
      return (
        token: 'token',
        user: CcylUser(
          id: 'ccyl-user',
          userName: 'student-a',
          realname: 'Student A',
          orgName: 'SCU',
        ),
      );
    },
  );
  await auth.loginWithCode('initial-code');
  return auth;
}

class _PrincipalScuAuth extends ScuAuth {
  _PrincipalScuAuth(super.prefs, {required super.logger});

  @override
  String? get principal => 'student-a';
}
