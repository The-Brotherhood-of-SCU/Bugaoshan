import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/utils/auth_logger.dart';

/// 业务层通用日志门面。
///
/// 与 `AuthLogger` 共享同一个内存缓冲 / 脱敏 / 文件落盘机制（Dev 页日志查看器
/// 能看到全部来源的日志），但提供「业务语义」的静态入口，避免业务代码直接依赖
/// 名字里带 Auth 的类，降低认知负担。
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
/// - 所有级别在生产构建也进入缓冲；仅 debug 构建同时输出控制台。
/// - 消息中出现的 access_token / password / 学号等敏感字段会被
///   [AuthLogRedactor] 自动脱敏，无需手动处理。
class AppLog {
  AppLog._();

  static final AuthLogger bootstrapLogger = AuthLogger();

  /// 延迟获取单例：避免在 DI 装配完成前访问 getIt 抛错。
  /// 启动前的日志写入 bootstrapLogger，DI 使用同一实例，避免早期错误丢失。
  ///
  /// 在未注册 AuthLogger 的环境（如部分单元测试直接构造被测对象、
  /// 不初始化 GetIt）下退化为独立裸实例，保证日志调用不抛异常；
  /// 生产环境始终命中已注册的单例，行为不变。
  static AuthLogger get _logger {
    return getIt.isRegistered<AuthLogger>()
        ? getIt<AuthLogger>()
        : bootstrapLogger;
  }

  static void d(String tag, String message) => _logger.log(
    AuthLogLevel.debug,
    tag,
    message,
    category: AuthLogCategory.business,
  );
  static void i(String tag, String message) => _logger.log(
    AuthLogLevel.info,
    tag,
    message,
    category: AuthLogCategory.business,
  );
  static void w(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => _logger.log(
    AuthLogLevel.warn,
    tag,
    message,
    category: AuthLogCategory.business,
    error: error,
    stackTrace: stackTrace,
  );
  static void e(
    String tag,
    String message, {
    Object? error,
    StackTrace? stackTrace,
  }) => _logger.log(
    AuthLogLevel.error,
    tag,
    message,
    category: AuthLogCategory.business,
    error: error,
    stackTrace: stackTrace,
  );

  /// 在没有本地 catch 的异步操作边界记录错误，并保持原有异常传播。
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
