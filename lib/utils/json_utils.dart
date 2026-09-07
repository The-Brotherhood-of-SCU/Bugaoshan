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

// ── 手写 JSON 解析的安全取值 helper ─────────────────────────────────
//
// 统一手写 fromJson 中的宽松取值模式，替代各模型里重复的
// `(json['x'] as num?)?.toDouble() ?? 0.0` 样板。这些 helper 对
// null / 类型不符 / 可解析字符串一律回退到 fallback，杜绝强转崩溃。

/// 宽松取 double：num 直接转换；数字字符串尝试解析；其余回退 [fallback]。
double safeDouble(Object? value, {double fallback = 0.0}) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim()) ?? fallback;
  return fallback;
}

/// 宽松取 int：num 直接转换（double 截断）；数字字符串尝试解析；
/// 其余回退 [fallback]。
int safeInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value.trim()) ?? fallback;
  return fallback;
}

/// 宽松取 String：null 回退 [fallback]，其余 `toString()`。
String safeString(Object? value, {String fallback = ''}) =>
    value?.toString() ?? fallback;

/// 宽松取 bool：仅接受 bool；数字 1/0 与 'true'/'false' 字符串可识别；
/// 其余回退 [fallback]。
bool safeBool(Object? value, {bool fallback = false}) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    final s = value.trim().toLowerCase();
    if (s == 'true' || s == '1') return true;
    if (s == 'false' || s == '0') return false;
  }
  return fallback;
}
