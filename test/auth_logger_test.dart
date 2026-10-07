import 'dart:io';

import 'package:bugaoshan/utils/auth_logger.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await getIt.reset();
  });
  tearDown(() async {
    await getIt.reset();
  });

  test('认证与业务日志分类，并保留脱敏后的异常和堆栈', () {
    final logger = AuthLogger();
    getIt.registerSingleton<AuthLogger>(logger);
    logger.i('ScuAuth', '登录开始');
    AppLog.e(
      'GradesProvider',
      '读取成绩失败',
      error: StateError('tokenKey=secret'),
      stackTrace: StackTrace.fromString('https://example.test/?token=secret'),
    );
    expect(logger.entries.first.category, AuthLogCategory.authentication);
    final entry = logger.entries.last;
    expect(entry.category, AuthLogCategory.business);
    expect(entry.level, AuthLogLevel.error);
    expect(entry.error, contains('<redacted>'));
    expect(logger.exportToText(), isNot(contains('secret')));
    expect(logger.exportToText(), contains('[business] [GradesProvider]'));
  });

  test('切换注册实例后业务日志进入新的实例', () async {
    final first = AuthLogger();
    getIt.registerSingleton<AuthLogger>(first);
    AppLog.i('Test', 'first');
    await getIt.reset();
    final second = AuthLogger();
    getIt.registerSingleton<AuthLogger>(second);
    AppLog.i('Test', 'second');
    expect(first.entries.single.message, 'first');
    expect(second.entries.single.message, 'second');
  });

  test('异步操作失败留下日志，并保留原异常及堆栈传播', () async {
    final logger = AuthLogger();
    getIt.registerSingleton<AuthLogger>(logger);
    final failure = StateError('failed');
    await expectLater(
      AppLog.guard<void>('Test', '加载', () async => throw failure),
      throwsA(same(failure)),
    );
    expect(logger.entries.single.stackTrace, isNotEmpty);
    expect(logger.entries.single.message, '加载 失败');
  });

  test('解析异常不导出原响应正文', () {
    final logger = AuthLogger();
    logger.e(
      'Parse',
      '解析失败',
      error: const FormatException(
        'invalid JSON',
        'private response payload',
        3,
      ),
    );
    expect(logger.exportToText(), contains('invalid JSON'));
    expect(logger.exportToText(), isNot(contains('private response payload')));
  });

  test('无法开启文件输出时错误仍记录到内存', () async {
    final directory = await Directory.systemTemp.createTemp(
      'bugaoshan-logger-test-',
    );
    addTearDown(() => directory.delete(recursive: true));
    final file = await File(
      '${directory.path}/not-a-directory',
    ).writeAsString('test');
    final logger = AuthLogger();
    await logger.enableFileSink(overridePath: file.path);
    expect(logger.fileSinkEnabled, isFalse);
    expect(logger.entries.single.category, AuthLogCategory.business);
    expect(logger.entries.single.level, AuthLogLevel.error);
    expect(logger.entries.single.stackTrace, isNotEmpty);
    logger.dispose();
  });

  test('认证操作 guard 记录后保持原异常传播', () async {
    final logger = AuthLogger();
    final failure = StateError('login failed');
    await expectLater(
      logger.guard<void>('Auth', '登录', () async => throw failure),
      throwsA(same(failure)),
    );
    expect(logger.entries.single.category, AuthLogCategory.authentication);
    expect(logger.entries.single.stackTrace, isNotEmpty);
  });

  test('早期日志可被 DI 沿用，缓冲区按容量淘汰旧记录', () {
    AppLog.bootstrapLogger.clear();
    AppLog.e('Startup', 'early failure');
    getIt.registerSingleton<AuthLogger>(AppLog.bootstrapLogger);
    expect(getIt<AuthLogger>().entries.single.message, 'early failure');
    AppLog.bootstrapLogger.clear();
    final logger = AuthLogger(capacity: 2);
    logger.i('Test', '1');
    logger.i('Test', '2');
    logger.i('Test', '3');
    expect(logger.entries.map((entry) => entry.message), ['2', '3']);
  });

  group('AuthLogRedactor', () {
    test('脱敏日志中的账号和用户标识', () {
      final redacted = AuthLogRedactor.apply(
        'login user=202612345678 userId=ccyl-user-42 username=alice',
      );

      expect(redacted, isNot(contains('202612345678')));
      expect(redacted, isNot(contains('ccyl-user-42')));
      expect(redacted, isNot(contains('alice')));
      expect(redacted, contains('user=<redacted>'));
      expect(redacted, contains('userId=<redacted>'));
      expect(redacted, contains('username=<redacted>'));
    });

    test('保留原有凭据脱敏行为', () {
      final redacted = AuthLogRedactor.apply(
        'Authorization: Bearer secret.token "password":"plain"',
      );

      expect(redacted, contains('Bearer <redacted>'));
      expect(redacted, contains('"password":"<redacted>"'));
      expect(redacted, isNot(contains('secret.token')));
      expect(redacted, isNot(contains('plain')));
    });

    test('脱敏重置凭据、会话参数和非 JWT Bearer token', () {
      final redacted = AuthLogRedactor.apply(
        'https://example.test/?sToken=reset-secret&jsessionid=session-secret '
        'Authorization: Bearer opaque+token/with=padding '
        '"newPassword":"new-secret" token=raw-secret',
      );
      for (final secret in [
        'reset-secret',
        'session-secret',
        'opaque+token/with=padding',
        'new-secret',
        'raw-secret',
      ]) {
        expect(redacted, isNot(contains(secret)));
      }
    });
  });
}
