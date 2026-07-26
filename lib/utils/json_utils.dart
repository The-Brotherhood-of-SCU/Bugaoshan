import 'dart:convert';

import 'package:flutter/foundation.dart';

/// 安全解析 JSON，失败时通过 [exceptionFactory] 抛出带上下文的异常。
///
/// 异常 message 只记录响应长度与前 200 字符摘要，避免把整页 HTML/网关错误页
/// 原样带入日志或 UI。
Map<String, dynamic> parseJson(
  String body,
  String api,
  Exception Function(String message) exceptionFactory,
) {
  try {
    return jsonDecode(body) as Map<String, dynamic>;
  } catch (e) {
    final preview = body.length > 200
        ? '${body.substring(0, 200)}…(${body.length}B)'
        : body;
    debugPrint('[$api] JSON 解析失败(len=${body.length}): $preview');
    throw exceptionFactory('[$api] 响应解析失败');
  }
}
