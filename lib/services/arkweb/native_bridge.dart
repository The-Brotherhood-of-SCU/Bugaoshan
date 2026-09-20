import 'dart:convert';
import 'dart:typed_data';

import 'package:bugaoshan/utils/json_utils.dart';

import 'native_transport.dart';

export 'native_transport.dart' show isArkWebNativeAvailable;

/// 原生侧明确返回的失败；HTTP 状态码 4xx/5xx 不属于桥接失败。
class ArkWebNativeException implements Exception {
  const ArkWebNativeException(this.code, this.message, [this.details]);

  final String code;
  final String message;
  final Object? details;

  @override
  String toString() => 'ArkWebNativeException($code): $message';
}

/// 只传 JSON 字符串，避免 ArkTS / Dart 对象及二进制类型不兼容。
/// 协议见 docs/architecture/arkweb-bridge.md。
Future<Object?> invokeArkWeb(String method, [Object? arguments]) async {
  final request = jsonEncode({
    'version': 1,
    'method': method,
    'arguments': _encodeValue(arguments),
  });
  final decoded = jsonDecode(await invokeArkWebNative(request));
  if (decoded is! Map<String, dynamic> || decoded['ok'] is! bool) {
    throw const FormatException('Invalid ArkWeb response envelope.');
  }
  if (!safeBool(decoded['ok'])) {
    final error = decoded['error'];
    if (error is! Map<String, dynamic>) {
      throw const FormatException('Invalid ArkWeb error envelope.');
    }
    throw ArkWebNativeException(
      safeString(error['code'], fallback: 'native_error'),
      safeString(error['message'], fallback: 'Native operation failed.'),
      _decodeValue(error['details']),
    );
  }
  return _decodeValue(decoded['result']);
}

Object? _encodeValue(Object? value) {
  if (value is Uint8List) {
    return {'\$bytes': base64Encode(value)};
  }
  if (value is List) return value.map(_encodeValue).toList();
  if (value is Map) {
    return value.map((key, item) {
      if (key is! String) {
        throw const FormatException('ArkWeb object keys must be strings.');
      }
      return MapEntry(key, _encodeValue(item));
    });
  }
  return value;
}

Object? _decodeValue(Object? value) {
  if (value is List) return value.map(_decodeValue).toList();
  if (value is Map<String, dynamic>) {
    if (value.length == 1 && value['\$bytes'] is String) {
      return base64Decode(safeString(value['\$bytes']));
    }
    return value.map((key, item) => MapEntry(key, _decodeValue(item)));
  }
  return value;
}
