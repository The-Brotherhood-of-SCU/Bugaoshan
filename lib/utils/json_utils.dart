import 'dart:convert';

/// 安全解析 JSON，失败时通过 [exceptionFactory] 抛出带上下文的异常。
Map<String, dynamic> parseJson(
  String body,
  String api,
  Exception Function(String message) exceptionFactory,
) {
  try {
    return jsonDecode(body) as Map<String, dynamic>;
  } catch (e) {
    throw exceptionFactory('[$api] JSON 解析失败: $body');
  }
}
