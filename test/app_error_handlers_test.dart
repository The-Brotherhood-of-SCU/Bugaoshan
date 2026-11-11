import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/utils/app_error_reporter.dart';
import 'package:bugaoshan/utils/app_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('全局记录框架和异步异常，同时保留原有处理器', () async {
    await getIt.reset();
    final logger = AppLogger();
    getIt.registerSingleton<AppLogger>(logger);
    final flutterHandler = FlutterError.onError;
    final asyncHandler = PlatformDispatcher.instance.onError;
    var flutterCalls = 0;
    var asyncCalls = 0;
    addTearDown(() async {
      FlutterError.onError = flutterHandler;
      PlatformDispatcher.instance.onError = asyncHandler;
      await getIt.reset();
    });
    FlutterError.onError = (_) => flutterCalls++;
    PlatformDispatcher.instance.onError = (_, _) {
      asyncCalls++;
      return true;
    };
    setupGlobalErrorHandlers();
    FlutterError.onError!(
      FlutterErrorDetails(
        exception: StateError('framework'),
        stack: StackTrace.current,
      ),
    );
    expect(
      PlatformDispatcher.instance.onError!(
        StateError('async'),
        StackTrace.current,
      ),
      isTrue,
    );
    expect(flutterCalls, 1);
    expect(asyncCalls, 1);
    expect(logger.entries.map((entry) => entry.tag), [
      'FlutterError.Flutter framework',
      'PlatformDispatcher',
    ]);
    expect(
      logger.entries.every(
        (entry) => entry.level == LogLevel.error && entry.stackTrace != null,
      ),
      isTrue,
    );
  });

  test('超长上下文、异常和堆栈共用上限，脱敏不会因截断失效', () async {
    await getIt.reset();
    final logger = AppLogger();
    getIt.registerSingleton<AppLogger>(logger);
    final flutterHandler = FlutterError.onError;
    final asyncHandler = PlatformDispatcher.instance.onError;
    addTearDown(() async {
      FlutterError.onError = flutterHandler;
      PlatformDispatcher.instance.onError = asyncHandler;
      await getIt.reset();
    });
    FlutterError.onError = (_) {};
    setupGlobalErrorHandlers();
    FlutterError.onError!(
      FlutterErrorDetails(
        exception: FormatException(
          'invalid ${'x' * 4000}',
          'private response source',
        ),
        context: ErrorDescription(
          'context {"password":"${'private-secret' * 400}"} ${'c' * 4000}',
        ),
        stack: StackTrace.fromString('#0 first-frame\n${'frame\n' * 2000}'),
      ),
    );
    final entry = logger.entries.single;
    expect(
      entry.message.length + entry.error!.length + entry.stackTrace!.length,
      lessThanOrEqualTo(2000),
    );
    expect(entry.stackTrace, startsWith('#0 first-frame'));
    expect(logger.exportToText(), isNot(contains('private-secret')));
    expect(logger.exportToText(), isNot(contains('private response source')));
    expect(
      formatExceptionForLog('', StackTrace.fromString('#0 frame')),
      '#0 frame',
    );
  });
}
