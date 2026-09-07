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
/// - [d] 仅供本地调试，生产构建静默（与 [AuthLogger] 行为一致）。
/// - 消息中出现的 access_token / password / 学号等敏感字段会被
///   [AuthLogRedactor] 自动脱敏，无需手动处理。
class AppLog {
  AppLog._();

  static AuthLogger? _cached;
  static AuthLogger? _fallback;

  /// 延迟获取单例：避免在 DI 装配完成前访问 getIt 抛错。
  /// 一旦拿到实例即缓存，避免热路径反复查表。
  ///
  /// 在未注册 AuthLogger 的环境（如部分单元测试直接构造被测对象、
  /// 不初始化 GetIt）下退化为独立裸实例，保证日志调用不抛异常；
  /// 生产环境始终命中已注册的单例，行为不变。
  static AuthLogger get _logger {
    final cached = _cached;
    if (cached != null) return cached;
    try {
      final instance = getIt<AuthLogger>();
      _cached = instance;
      return instance;
    } on Object {
      return _fallback ??= AuthLogger();
    }
  }

  static void d(String tag, String message) => _logger.d(tag, message);
  static void i(String tag, String message) => _logger.i(tag, message);
  static void w(String tag, String message) => _logger.w(tag, message);
  static void e(String tag, String message) => _logger.e(tag, message);
}
