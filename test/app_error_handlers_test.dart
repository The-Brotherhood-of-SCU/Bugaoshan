import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/utils/app_error_handlers.dart';
import 'package:bugaoshan/utils/auth_logger.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('全局记录框架和异步异常，同时保留原有处理器', () async {
    await getIt.reset();
    final logger = AuthLogger();
    getIt.registerSingleton<AuthLogger>(logger);
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
    AppErrorHandlers.install();
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
    expect(logger.entries.map((entry) => entry.tag), ['Flutter', 'Async']);
    expect(
      logger.entries.every(
        (entry) =>
            entry.level == AuthLogLevel.error && entry.stackTrace != null,
      ),
      isTrue,
    );
  });
}
