import 'dart:async';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/utils/json_utils.dart';

import 'native_bridge.dart';

/// 只替换传输层；Cookie jar、认证和手动重定向仍由 CookieClient 管理。
class ArkWebHttpClient extends http.BaseClient {
  static int _nextId = 0;
  static final String _sessionId = DateTime.now().microsecondsSinceEpoch
      .toString();

  final String _clientId = '$_sessionId-${_nextId++}';
  bool _closed = false;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (_closed) throw http.ClientException('Client is closed.', request.url);
    // finalize 同时支持表单、二进制和 MultipartRequest，并补全 multipart 头。
    final body = await request.finalize().toBytes();
    if (_closed) throw http.ClientException('Client is closed.', request.url);

    Object? result;
    try {
      result = await invokeArkWeb('http.request', {
        'clientId': _clientId,
        'url': request.url.toString(),
        'method': request.method,
        'headers': request.headers,
        'body': body,
        'followRedirects': request.followRedirects,
        'maxRedirects': request.maxRedirects,
        'persistentConnection': request.persistentConnection,
        'timeoutMs': kHttpTimeout.inMilliseconds,
      }).timeout(kHttpTimeout);
    } on ArkWebNativeException catch (error) {
      // 仅传输错误沿用 CookieClient 的重试；协议/权限/业务错误不自动重放。
      if (error.code == 'http_transport' || error.code == 'http_closed') {
        throw http.ClientException(error.message, request.url);
      }
      if (error.code == 'http_timeout') {
        throw TimeoutException(error.message, kHttpTimeout);
      }
      rethrow;
    }
    if (_closed) throw http.ClientException('Client is closed.', request.url);
    if (result is! Map) {
      throw const FormatException('Invalid ArkWeb HTTP response.');
    }
    final status = safeInt(result['statusCode']);
    final bytes = result['body'];
    if (status < 100 || status > 599 || bytes is! Uint8List) {
      throw const FormatException('Invalid ArkWeb HTTP status or body.');
    }
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      status,
      headers: _decodeHeaders(result['headers']),
      contentLength: bytes.length,
      request: request,
      isRedirect: safeBool(result['isRedirect']),
      persistentConnection: request.persistentConnection,
      reasonPhrase: result['reasonPhrase'] == null
          ? null
          : safeString(result['reasonPhrase']),
    );
  }

  Map<String, String> _decodeHeaders(Object? value) {
    if (value is! Map) {
      throw const FormatException('Invalid ArkWeb HTTP headers.');
    }
    final headers = <String, String>{};
    for (final entry in value.entries) {
      final name = entry.key;
      final values = entry.value;
      if (name is! String ||
          values is! List ||
          values.any((item) => item is! String)) {
        throw const FormatException(
          'ArkWeb headers must contain string lists.',
        );
      }
      final key = name.toLowerCase();
      final text = values.join(', ');
      headers.update(key, (old) => '$old, $text', ifAbsent: () => text);
    }
    return headers;
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    unawaited(_closeNative());
    super.close();
  }

  Future<void> _closeNative() async {
    try {
      await invokeArkWeb('http.close', {
        'clientId': _clientId,
      }).timeout(kHttpTimeout);
    } catch (error) {
      AppLog.w('ArkWebHttpClient', '关闭原生 HTTP 客户端失败: $error');
    }
  }
}
