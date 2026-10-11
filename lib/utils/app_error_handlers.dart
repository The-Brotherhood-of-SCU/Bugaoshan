import 'package:flutter/foundation.dart';
import 'package:bugaoshan/utils/app_log.dart';

/// 框架错误与未捕获异步错误的最后一道记录入口。
/// 本地 catch 仍需记录上下文；这里只处理已经逃逸的异常。
class AppErrorHandlers {
  AppErrorHandlers._();

  static bool _reporting = false;

  static void install() {
    final previousFlutterHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      _report(
        'Flutter',
        details.context?.toDescription() ?? '框架错误',
        details.exception,
        details.stack,
      );
      if (previousFlutterHandler != null) {
        previousFlutterHandler(details);
      } else {
        FlutterError.presentError(details);
      }
    };
    final previousAsyncHandler = PlatformDispatcher.instance.onError;
    PlatformDispatcher.instance.onError = (error, stackTrace) {
      _report('Async', '未捕获的异步错误', error, stackTrace);
      if (previousAsyncHandler != null) {
        return previousAsyncHandler(error, stackTrace);
      }
      FlutterError.presentError(
        FlutterErrorDetails(exception: error, stack: stackTrace),
      );
      return true;
    };
  }

  static void _report(
    String tag,
    String operation,
    Object error,
    StackTrace? stackTrace,
  ) {
    // 日志订阅者自身报错时防止递归记录。
    if (_reporting) return;
    _reporting = true;
    try {
      AppLog.e(tag, operation, error: error, stackTrace: stackTrace);
    } finally {
      _reporting = false;
    }
  }
}
