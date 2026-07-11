import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/pages/campus/ccyl/models/ccyl_models.dart';
import 'package:bugaoshan/services/auth/ccyl_auth.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/utils/auth_logger.dart';
import 'package:bugaoshan/utils/secure_storage.dart';

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

  test('does not restore principal A CCYL token for principal B', () async {
    final scuAuth = _PrincipalScuAuth(
      prefs,
      logger: logger,
      currentPrincipal: 'student-a',
    );
    final authForA = CcylAuth(
      scuAuth,
      logger: logger,
      login: (_) async => (
        token: 'token-a',
        user: CcylUser(
          id: 'ccyl-a',
          userName: 'student-a',
          realname: 'Student A',
          orgName: 'SCU',
        ),
      ),
    );

    await authForA.loginWithCode('code-a');
    expect(authForA.token, 'token-a');

    scuAuth.currentPrincipal = 'student-b';
    expect(authForA.isLoggedIn, isFalse);
    expect(authForA.token, isNull);
    expect(authForA.currentUser, isNull);

    final authForB = CcylAuth(scuAuth, logger: logger);
    await authForB.init();

    expect(authForB.isLoggedIn, isFalse);
    expect(authForB.token, isNull);
    expect(
      await SecureStorageProvider.instance.read(key: 'ccyl_session_v2'),
      isNull,
    );
  });
}

class _PrincipalScuAuth extends ScuAuth {
  String? currentPrincipal;

  _PrincipalScuAuth(
    super.prefs, {
    required super.logger,
    required this.currentPrincipal,
  });

  @override
  String? get principal => currentPrincipal;
}
