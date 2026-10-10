/// 统一异常体系
///
/// 三层架构中异常从下往上冒泡：
///   第3层 ScuAuth → 第2层 子系统Auth → 第1层 API Service → Provider
sealed class ScuException implements Exception {
  final String message;
  const ScuException(this.message);
  @override
  String toString() => message;
}

/// 认证失败（token 过期 + 自动刷新失败）
///
/// 从第2/3层产生，穿透到第1层 API Service 的 `_request()` 重试一次后仍失败时，
/// 抛到 Provider 层，UI 捕获后显示"前往登录"。
class UnauthenticatedException extends ScuException {
  /// 统一认证会话已建立、但子系统（本科教务）在重认证自愈后仍将请求踢回
  /// 登录页——多半意味着该子系统没有此账号（如研究生账号），与「未登录」
  /// 不同：重新登录统一认证也无法解决。Provider 层据此给出针对性指引。
  final bool undergradOnly;

  const UnauthenticatedException([
    super.message = '未登录或登录已过期',
    this.undergradOnly = false,
  ]);
}

/// 业务错误（网络错误、解析错误、非 200 响应等）
///
/// 由第1层 API Service 产生，Provider 捕获后显示错误信息。
class ServiceException extends ScuException {
  final int? statusCode;
  const ServiceException(super.message, {this.statusCode});
}

/// 频率限制（请求过于频繁）
///
/// 由 API Service 在检测到服务端限流时产生。
class RateLimitedException extends ServiceException {
  const RateLimitedException() : super('rateLimited');
}

/// 登录过程错误（验证码错误、账号密码错误等）。
///
/// 主要由 ScuAuth.login() 中产生；bindSession 的非鉴权失败应使用 [ServiceException]，
/// 以被 API Service 的重试与 Provider 的错误处理正确捕获。
class ScuLoginException extends ScuException {
  const ScuLoginException(super.message);
}

/// 忘记密码流程业务错误（图形验证码错误/过期、账号不存在、
/// 短信/邮件验证码错误、密码不满足策略等）。
class ForgotPasswordException extends ScuException {
  /// 服务端业务错误码（如 400 验证码错误、439 验证码过期）。
  final int? businessCode;

  const ForgotPasswordException(super.message, {this.businessCode});
}
