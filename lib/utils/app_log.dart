import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/utils/app_logger.dart';

/// 业务层通用日志门面。
///
/// 与 `AppLogger` 共享同一个内存缓冲 / 脱敏 / 文件落盘机制（Dev 页日志查看器
/// 能看到全部来源的日志），但提供静态入口，避免业务代码在每个调用点都写
/// `getIt<AppLogger>()`，降低认知负担。
///
/// 用法：
/// ```dart
/// AppLog.e('GradesProvider', 'cache decode failed: $e');
/// AppLog.i('UpdateService', 'download started');
/// ```
///
/// 约定：
/// - 错误路径（catch 分支、失败状态）用 [e] / [w]；
/// - 生命周期 / 关键里程碑用 [i]；
/// - [d] 仅供本地调试，生产构建静默（与 [AppLogger] 行为一致）。
/// - 消息中出现的 access_token / password / 学号等敏感字段会被
///   [LogRedactor] 自动脱敏，无需手动处理。
class AppLog {
  AppLog._();

  /// 启动期日志缓冲：DI 装配完成前的日志先落在这里。
  ///
  /// 生产环境**必须**让 `injector.dart` 注册的就是这一个实例，
  /// 否则启动期的错误会写进一个无人观察的临时实例——而启动失败恰恰是
  /// 最需要留痕的时刻。这条约束由[AppLog.bootstrapLogger] 承接
  /// （移植自 PR #369，moranfanhua）。
  static final AppLogger bootstrapLogger = AppLogger();

  static AppLogger? _cached;

  /// 延迟获取单例：避免在 DI 装配完成前访问 getIt 抛错。
  /// 一旦拿到实例即缓存，避免热路径反复查表。
  ///
  /// 未注册时退化为 [bootstrapLogger]（而非新建实例），保证同一进程内
  /// 始终只有一个缓冲；部分单元测试未初始化 GetIt 也因此不必关心该细节。
  static AppLogger get _logger {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final instance = getIt<AppLogger>();
      _cached = instance;
      return instance;
    } on Object {
      return bootstrapLogger;
    }
  }

  static void d(String tag, String message) => _logger.d(tag, message);
  static void i(String tag, String message) => _logger.i(tag, message);

  /// [w] / [e] 接受 [error] 与 [stackTrace]，作为独立字段存入日志条目
  ///（见 [LogEntry.error] / [LogEntry.stackTrace]），查看器可分别渲染，
  /// 不必把堆栈拼进 message 字符串。
  static void w(
    String tag,
    String message, {
    Object? error,
    Object? stackTrace,
  }) => _logger.w(tag, message, error: error, stackTrace: stackTrace);
  static void e(
    String tag,
    String message, {
    Object? error,
    Object? stackTrace,
  }) => _logger.e(tag, message, error: error, stackTrace: stackTrace);

  /// 在没有本地 catch 的异步操作边界记录错误，并保持原有异常传播。
  ///
  /// 供「调用了会失败的 await，却没有 catch」的场景使用——这类位置此前只能
  /// 靠人肉审查找出，改用 [guard] 后异常既进入日志、又不改变控制流。
  static Future<T> guard<T>(
    String tag,
    String operation,
    Future<T> Function() action,
  ) async {
    try {
      return await action();
    } catch (error, stackTrace) {
      e(tag, '$operation 失败', error: error, stackTrace: stackTrace);
      rethrow;
    }
  }
}
