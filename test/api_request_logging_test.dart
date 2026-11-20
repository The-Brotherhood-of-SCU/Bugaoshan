import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/scu_backend/core/api_request.dart';
import 'package:bugaoshan/scu_backend/core/scu_exceptions.dart';
import 'package:bugaoshan/utils/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppLogger logger;
  setUp(() async {
    await getIt.reset();
    logger = AppLogger();
    getIt.registerSingleton<AppLogger>(logger);
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
    expect(logger.entries.single.category, LogCategory.business);
    expect(logger.entries.single.level, LogLevel.error);
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
    expect(logger.entries.single.level, LogLevel.warn);
    expect(logger.entries.single.stackTrace, isNull);
    logger.clear();
    await expectLater(
      retryOnUnauthenticated(
        () async => 1,
        (_) async => throw const UnauthenticatedException(),
        logTag: 'TestApi',
      ),
      throwsA(isA<UnauthenticatedException>()),
    );
    expect(logger.entries.last.level, LogLevel.error);
  });

  test('HTML 标题仅提取短诊断线索，先解码实体并脱敏', () {
    final title = responseTitleForLog(
      '<HTML><TITLE>WAF blocked password&#61;private-secret</TITLE><body>private response</body></HTML>',
    );
    expect(title, contains('WAF blocked'));
    expect(title, isNot(contains('private-secret')));
    expect(title, isNot(contains('private response')));
    expect(
      responseTitleForLog('<title>${'x' * 500}</title>')!.length,
      lessThanOrEqualTo(160),
    );
    expect(responseTitleForLog('{"value":"<title>private</title>"}'), isNull);
  });
}
