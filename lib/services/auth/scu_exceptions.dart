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
  const UnauthenticatedException([super.message = '未登录或登录已过期']);
}

/// 业务错误（网络错误、解析错误、非 200 响应等）
///
/// 由第1层 API Service 产生，Provider 捕获后显示错误信息。
class ServiceException extends ScuException {
  final int? statusCode;
  const ServiceException(super.message, {this.statusCode});
}

/// 登录过程错误（验证码错误、账号密码错误等）
///
/// 仅在 ScuAuth.login() 中产生，由登录页面直接捕获。
class ScuLoginException extends ScuException {
  const ScuLoginException(super.message);
}
