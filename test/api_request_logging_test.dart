import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/services/api/api_request.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/utils/auth_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AuthLogger logger;
  setUp(() async {
    await getIt.reset();
    logger = AuthLogger();
    getIt.registerSingleton<AuthLogger>(logger);
  });
  tearDown(() => getIt.reset());

  test('API 最终失败记录业务错误并保持异常传播', () async {
    final failure = StateError('network failed');
    await expectLater(
      retryOnUnauthenticated(
        () async => 1,
        (_) async => throw failure,
        logTag: 'TestApi',
      ),
      throwsA(same(failure)),
    );
    expect(logger.entries.single.tag, 'TestApi');
    expect(logger.entries.single.category, AuthLogCategory.business);
    expect(logger.entries.single.level, AuthLogLevel.error);
    expect(logger.entries.single.stackTrace, isNotEmpty);
  });

  test('认证恢复成功只记录重试警告，第二次失败记录错误', () async {
    var attempts = 0;
    var invalidations = 0;
    final result = await retryOnUnauthenticated(
      () async => 1,
      (_) async {
        if (++attempts == 1) throw const UnauthenticatedException();
        return 42;
      },
      invalidate: () => invalidations++,
      logTag: 'TestApi',
    );
    expect(result, 42);
    expect(invalidations, 1);
    expect(logger.entries.single.level, AuthLogLevel.warn);
    logger.clear();
    await expectLater(
      retryOnUnauthenticated(
        () async => 1,
        (_) async => throw const UnauthenticatedException(),
        logTag: 'TestApi',
      ),
      throwsA(isA<UnauthenticatedException>()),
    );
    expect(logger.entries.last.level, AuthLogLevel.error);
  });
}
