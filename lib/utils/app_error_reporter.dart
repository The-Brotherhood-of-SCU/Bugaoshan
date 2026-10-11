import 'dart:isolate';

import 'package:flutter/foundation.dart';

import 'package:bugaoshan/utils/app_log.dart';

/// 单条异常日志的最大字符数，防止 stack trace 过长挤占环形缓冲。
///
/// 1000 条的容量在平均每条 ~200 字符时最健康；未截断的 stack trace
/// 轻易上百行，单条就能顶掉几十条正常日志。
const int _kMaxExceptionChars = 2000;

/// context 占位后仍留给异常本身的最小预算。
const int _kMinExceptionChars = 200;

/// 把异常与堆栈拼成一条适合放进日志 message 的文本（超长则截断）。
String formatExceptionForLog(
  Object error,
  StackTrace? stack, {
  int maxChars = _kMaxExceptionChars,
}) {
  final buffer = StringBuffer()..writeln(error);
  if (stack != null) {
    buffer.writeln(stack);
  }
  final text = buffer.toString().trimRight();
  // 防御非法预算：本函数会在错误处理路径上被调用，此处抛异常会掩盖真实错误。
  if (maxChars <= 0) return text;
  if (text.length <= maxChars) return text;
  // 保留头部：异常类型与消息在开头，排障价值最高。
  final kept = text.substring(0, maxChars);
  final omittedLines = '\n'.allMatches(text.substring(maxChars)).length + 1;
  return '$kept\n… [truncated, $omittedLines more lines]';
}

/// 安装全局异常接管，使崩溃现场进入 [AppLog]。
///
/// 覆盖三类此前完全无人接管的异常：
/// - [FlutterError.onError]：框架构建 / 布局 / 绘制异常（debug 下红屏的来源）。
/// - [PlatformDispatcher.onError]：引擎层未捕获的异步异常。
/// - [Isolate.current] 错误监听：非 main isolate 内的未捕获错误。
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
    // context 是 DiagnosticsNode，toString() 可能输出整棵组件树而远长于
    // 上限；必须给 maxChars 留出正数余量，否则 formatExceptionForLog 内部
    // substring 会抛 RangeError —— 错误处理器自己在处理异常时崩溃，
    // 会把真实错误信息一并掩盖。
    //
    // context 作为独立 message 传入（而非拼进异常文本）：它是定位线索而非
    // 异常本身，混在一起会让「异常消息」被组件树冲淡。
    final context = details.context?.toString() ?? '';
    final budget = (_kMaxExceptionChars - context.length).clamp(
      _kMinExceptionChars,
      _kMaxExceptionChars,
    );
    AppLog.e(
      tag,
      context.isEmpty ? '未捕获的框架异常' : '未捕获的框架异常\ncontext: $context',
      error: details.exception,
      stackTrace: formatExceptionForLog(
        details.exception,
        details.stack,
        maxChars: budget,
      ),
    );
    // 保留默认行为：debug 下红屏、release 下打印，否则会静默掩盖框架错误。
    previousFlutterOnError?.call(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    AppLog.e('PlatformDispatcher', '未捕获的异步异常', error: error, stackTrace: stack);
    // 返回 true 表示已处理，避免引擎把进程直接杀掉。
    // 进程被杀则内存中的日志随进程消失，用户将完全拿不到崩溃现场——
    // 这正是「生产环境拿不到日志」问题的另一面。
    return true;
  };

  // 持有引用防止端口被 GC 关闭；非 main isolate 的错误会送到这里。
  final port = RawReceivePort((dynamic pair) {
    if (pair is! List || pair.length < 2) return;
    AppLog.e('Isolate', formatExceptionForLog(pair[0], pair[1] as StackTrace?));
  });
  Isolate.current.addErrorListener(port.sendPort);
}
