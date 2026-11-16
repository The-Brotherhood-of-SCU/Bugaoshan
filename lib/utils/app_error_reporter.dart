import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/app_logger.dart';

/// 全局异常的消息、详情与堆栈共用字符上限，控制单条诊断记录的内存占用。
const int _kMaxExceptionChars = 2000;

/// 上下文较长时仍留给堆栈的最小预算。
const int _kMinExceptionChars = 200;

bool _reporting = false;
RawReceivePort? _errorPort;

void _report(String tag, String operation, Object error, Object? stack) {
  // 日志订阅者自身报错时防止递归记录。
  if (_reporting) return;
  _reporting = true;
  try {
    final detail = formatExceptionForLog(
      error,
      null,
      maxChars: _kMaxExceptionChars ~/ 2,
    );
    final message = _truncate(
      LogRedactor.apply(operation),
      _kMaxExceptionChars -
          detail.length -
          (stack == null ? 0 : _kMinExceptionChars),
    );
    final trace = stack == null
        ? null
        : _truncate(
            LogRedactor.apply(stack.toString()),
            _kMaxExceptionChars - message.length - detail.length,
          );
    AppLog.e(tag, message, error: detail, stackTrace: trace);
  } finally {
    _reporting = false;
  }
}

/// 把异常与堆栈拼成一条适合放进日志 message 的文本（超长则截断）。
String formatExceptionForLog(
  Object error,
  StackTrace? stack, {
  int maxChars = _kMaxExceptionChars,
}) {
  final description = describeLogError(error);
  final buffer = StringBuffer();
  if (description.isNotEmpty) buffer.writeln(description);
  if (stack != null) {
    buffer.writeln(stack);
  }
  // 必须先脱敏再截断，避免截掉 JSON 引号后使凭据规则失效。
  final text = LogRedactor.apply(buffer.toString().trimRight());
  // 防御非法预算：本函数会在错误处理路径上被调用，此处抛异常会掩盖真实错误。
  if (maxChars <= 0) return text;
  return _truncate(text, maxChars);
}

String _truncate(String text, int maxChars) {
  if (text.length <= maxChars) return text;
  var kept = maxChars;
  var suffix = '';
  for (var i = 0; i < 3; i++) {
    final omittedLines = '\n'.allMatches(text.substring(kept)).length + 1;
    suffix = '\n… [truncated, $omittedLines more lines]';
    final next = (maxChars - suffix.length).clamp(0, maxChars);
    if (next == kept) break;
    kept = next;
  }
  if (kept == 0) return text.substring(0, maxChars);
  return '${text.substring(0, kept)}$suffix';
}

/// 安装全局异常接管，使崩溃现场进入 [AppLog]。
///
/// 覆盖三类此前完全无人接管的异常：
/// - [FlutterError.onError]：框架构建 / 布局 / 绘制异常（debug 下红屏的来源）。
/// - [PlatformDispatcher.onError]：引擎层未捕获的异步异常。
/// - [Isolate.current] 错误监听：当前 isolate 内的未捕获错误（仅原生平台）。
///
/// 必须在 `WidgetsFlutterBinding.ensureInitialized()` 之后调用——三者都需要
/// binding 就绪（[PlatformDispatcher.onError] 依赖 binding 提供的 dispatcher 实例）。
///
/// 启动早期（`getIt` 尚未注册 `AppLogger`）的异常同样会被记录：[AppLog] 在取不到
/// 单例时会退化为独立裸实例（见 `app_log.dart`），不会因此抛错。
void setupGlobalErrorHandlers() {
  final previousFlutterOnError = FlutterError.onError;
  FlutterError.onError = (FlutterErrorDetails details) {
    final tag = details.library == null || details.library!.isEmpty
        ? 'FlutterError'
        : 'FlutterError.${details.library}';
    // 上下文、异常和堆栈共享 _report 的字符预算，同时保留各自独立字段。
    final context = details.context?.toString() ?? '';
    _report(
      tag,
      context.isEmpty ? '未捕获的框架异常' : '未捕获的框架异常\ncontext: $context',
      details.exception,
      details.stack,
    );
    // 保留默认行为：debug 下红屏、release 下打印，否则会静默掩盖框架错误。
    if (previousFlutterOnError != null) {
      previousFlutterOnError(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  final previousAsyncHandler = PlatformDispatcher.instance.onError;
  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    _report('PlatformDispatcher', '未捕获的异步异常', error, stack);
    if (previousAsyncHandler != null) {
      return previousAsyncHandler(error, stack);
    }
    // 返回 true 表示已处理，避免引擎把进程直接杀掉。
    // 进程被杀则内存中的日志随进程消失，用户将完全拿不到崩溃现场——
    // 这正是「生产环境拿不到日志」问题的另一面。
    return true;
  };

  // Web 不支持 RawReceivePort / Isolate.current，仍保留上面的框架与异步处理器。
  if (kIsWeb || _errorPort != null) return;
  final port = RawReceivePort((dynamic pair) {
    if (pair is! List || pair.length < 2) return;
    if (pair[0] == null) return;
    _report('Isolate', '未捕获的 isolate 错误', pair[0] as Object, pair[1]);
  });
  Isolate.current.addErrorListener(port.sendPort);
  _errorPort = port;
}
