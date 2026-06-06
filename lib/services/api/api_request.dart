import 'package:bugaoshan/services/auth/scu_exceptions.dart';

/// API 请求自动重试包装。
///
/// 如果 [getClient] 或 [fn] 抛出 [UnauthenticatedException]（认证失败），
/// 重试一次。getClient 内部会检查 TTL，过期时触发 refresh（并发互斥）；
/// 如果服务端在 TTL 窗口内踢掉 session，getClient 只重做 bindSession，不主动 refresh。
/// 第二次仍失败 → UnauthenticatedException 穿透到调用方。
Future<T> retryOnUnauthenticated<T, C>(
  Future<C> Function() getClient,
  Future<T> Function(C client) fn, {
  void Function()? invalidate,
}) async {
  try {
    final client = await getClient();
    return await fn(client);
  } on UnauthenticatedException {
    invalidate?.call();
    final client = await getClient();
    return await fn(client);
  }
}
