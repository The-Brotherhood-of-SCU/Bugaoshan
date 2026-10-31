import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:bugaoshan/scu_backend/core/api_request.dart';
import 'package:bugaoshan/scu_backend/core/cookie_client.dart';

export 'package:bugaoshan/scu_backend/core/api_request.dart'
    show looksLikeLoginPage;
import 'package:bugaoshan/scu_backend/core/scu_exceptions.dart';
import 'package:bugaoshan/scu_backend/core/subsystem_auth.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/utils/json_utils.dart';

/// 会话失效检查器签名。
///
/// 若识别为未登录或会话过期，应抛出 [UnauthenticatedException]；
/// 若抛出其他异常（如 [ServiceException]），将穿透并中断请求；
/// 若会话正常，正常返回即可。
typedef SessionExpiryChecker = void Function(String body, int statusCode);

/// JSON 业务响应校验器签名。
///
/// 在请求重试保护上下文中执行。若检测到业务层面的未登录或会话过期
/// （如微服务的 `e == 10013`、预约系统的 `e == 'UN_AUTH'`），
/// 抛出 [UnauthenticatedException] 以便触发自动重认证与重试。
typedef JsonValidator = void Function(Map<String, dynamic> json);

/// 面向业务 API 的高阶会话客户端。
///
/// 封装各子系统的认证生命周期（[SubsystemAuth]）、统一重试与自愈（[retryOnUnauthenticated]）、
/// 默认 Header 拼装、Base URL 路径合并、状态码与会话失效判定，以及 JSON / HTML 数据解析。
class ApiSession {
  final Future<CookieClient> Function() _getClient;
  final VoidCallback? _invalidate;

  /// 该会话关联的基础请求 URL。
  final Uri baseUrl;

  /// 日志 Tag。
  final String logTag;

  /// 该会话的默认 Headers。
  final Map<String, String> defaultHeaders;

  /// 自定义会话失效检查器。若为空则执行默认规则。
  final SessionExpiryChecker? sessionExpiryChecker;

  /// JSON 业务响应校验器。
  final JsonValidator? jsonValidator;

  /// 遇到空响应 body 时是否抛出 [UnauthenticatedException]。
  ///
  /// 默认 `true`（大多数子系统如 zhjw/wfw 在会话过期时表现为空响应）；
  /// 个别系统（如预约系统在网关波动时可能返回空 body）可置为 `false`。
  final bool emptyBodyThrowsUnauthenticated;

  ApiSession({
    required Future<CookieClient> Function() getClient,
    VoidCallback? invalidate,
    required this.baseUrl,
    required this.logTag,
    this.defaultHeaders = const {},
    this.sessionExpiryChecker,
    this.jsonValidator,
    this.emptyBodyThrowsUnauthenticated = true,
  }) : _getClient = getClient,
       _invalidate = invalidate;

  /// 在带有认证重试机制的上下文中执行底层 [CookieClient] 操作。
  ///
  /// 遇到 [UnauthenticatedException] 时会自动调用 `invalidate()` 并重试一次。
  Future<T> run<T>(Future<T> Function(CookieClient client) action) {
    return retryOnUnauthenticated(
      _getClient,
      action,
      invalidate: _invalidate,
      logTag: logTag,
    );
  }

  /// 将相对路径或绝对路径解析为完整的 [Uri]。
  Uri resolveUri(String path, [Map<String, dynamic>? query]) {
    final parsed = Uri.parse(path);
    Uri resolved;
    if (parsed.hasScheme) {
      resolved = parsed;
    } else {
      final basePath = baseUrl.path.endsWith('/')
          ? baseUrl.path.substring(0, baseUrl.path.length - 1)
          : baseUrl.path;
      final normalizedPath = parsed.path.startsWith('/')
          ? parsed.path
          : '/${parsed.path}';
      final fullPath = basePath.isEmpty
          ? normalizedPath
          : '$basePath$normalizedPath';
      resolved = baseUrl.replace(
        path: fullPath,
        queryParameters: parsed.queryParameters.isEmpty
            ? (baseUrl.queryParameters.isEmpty ? null : baseUrl.queryParameters)
            : {...baseUrl.queryParameters, ...parsed.queryParameters},
      );
    }

    if (query == null || query.isEmpty) return resolved;

    final params = Map<String, dynamic>.from(resolved.queryParameters);
    query.forEach((key, value) {
      if (value != null) {
        params[key] = value.toString();
      }
    });
    return resolved.replace(queryParameters: params);
  }

  /// 合并默认 Headers 与当前请求特定的 Headers。
  Map<String, String> _buildHeaders(Map<String, String>? headers) {
    final map = <String, String>{
      'User-Agent': kDefaultUserAgent,
      'Accept': 'application/json, text/plain, */*',
      'X-Requested-With': 'XMLHttpRequest',
      ...defaultHeaders,
    };
    if (headers != null && headers.isNotEmpty) {
      map.addAll(headers);
    }
    return map;
  }

  /// 检查响应是否为未登录、会话过期或网关异常。
  void checkResponse(http.Response resp, {String? apiName}) {
    if (sessionExpiryChecker != null) {
      sessionExpiryChecker!(resp.body, resp.statusCode);
      return;
    }

    final code = resp.statusCode;
    if (code == 401 || code == 403) {
      throw const UnauthenticatedException('会话已失效 (401/403)');
    }
    if (code == 302) {
      throw const UnauthenticatedException('会话重定向至认证页 (302)');
    }

    final trimmed = resp.body.trim();
    if (trimmed.isEmpty && emptyBodyThrowsUnauthenticated) {
      throw const UnauthenticatedException('服务返回空响应，会话可能已过期');
    }

    if (looksLikeLoginPage(trimmed)) {
      throw const UnauthenticatedException('检测到登录页，会话已过期');
    }
  }

  /// 发送 GET 请求并返回原始 [http.Response]。
  Future<http.Response> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? apiName,
  }) {
    return run((client) async {
      final uri = resolveUri(path, query);
      final resp = await client.get(uri, headers: _buildHeaders(headers));
      checkResponse(resp, apiName: apiName ?? path);
      return resp;
    });
  }

  /// 发送 POST 请求并返回原始 [http.Response]。
  Future<http.Response> post(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? apiName,
  }) {
    return run((client) async {
      final uri = resolveUri(path, query);
      final resp = await client.post(
        uri,
        headers: _buildHeaders(headers),
        body: body,
      );
      checkResponse(resp, apiName: apiName ?? path);
      return resp;
    });
  }

  /// 发送 POST 表单请求。
  Future<http.Response> postForm(
    String path,
    Map<String, String> fields, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? apiName,
  }) {
    final mergedHeaders = {
      'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
      ...?headers,
    };
    return post(
      path,
      body: fields,
      query: query,
      headers: mergedHeaders,
      apiName: apiName,
    );
  }

  /// 发送 POST JSON 请求。
  Future<http.Response> postJson(
    String path,
    Object jsonBody, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? apiName,
  }) {
    final mergedHeaders = {
      'Content-Type': 'application/json; charset=UTF-8',
      ...?headers,
    };
    final encoded = jsonBody is String ? jsonBody : jsonEncode(jsonBody);
    return post(
      path,
      body: encoded,
      query: query,
      headers: mergedHeaders,
      apiName: apiName,
    );
  }

  /// 手动跟随重定向请求。
  Future<http.Response> followRedirects(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    int maxRedirects = 10,
    String? apiName,
  }) {
    return run((client) async {
      final uri = resolveUri(path, query);
      final resp = await client.followRedirects(
        uri,
        headers: _buildHeaders(headers),
        maxRedirects: maxRedirects,
      );
      checkResponse(resp, apiName: apiName ?? path);
      return resp;
    });
  }

  /// 发送 GET 请求并返回经 trim 处理后的 HTML 字符串。
  Future<String> getHtml(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? apiName,
  }) async {
    final resp = await get(
      path,
      query: query,
      headers: headers,
      apiName: apiName,
    );
    return resp.body.trim();
  }

  /// 发送 GET 请求并解析为 JSON Map。
  Future<Map<String, dynamic>> getJsonMap(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? apiName,
  }) {
    return run((client) async {
      final uri = resolveUri(path, query);
      final resp = await client.get(uri, headers: _buildHeaders(headers));
      checkResponse(resp, apiName: apiName ?? path);
      final json = parseJson(
        resp.body,
        apiName ?? path,
        (m) => ServiceException(m),
      );
      jsonValidator?.call(json);
      return json;
    });
  }

  /// 发送 GET 请求并解析为 JSON 数组。
  Future<List<dynamic>> getJsonList(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? apiName,
  }) {
    return run((client) async {
      final uri = resolveUri(path, query);
      final resp = await client.get(uri, headers: _buildHeaders(headers));
      checkResponse(resp, apiName: apiName ?? path);
      return parseJsonList(
        resp.body,
        apiName ?? path,
        (m) => ServiceException(m),
      );
    });
  }

  /// 发送 GET 请求并返回任意 JSON 对象（Map 或 List 等）。
  Future<dynamic> getJson(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? apiName,
  }) {
    return run((client) async {
      final uri = resolveUri(path, query);
      final resp = await client.get(uri, headers: _buildHeaders(headers));
      checkResponse(resp, apiName: apiName ?? path);
      try {
        final decoded = jsonDecode(resp.body);
        if (decoded is Map<String, dynamic>) {
          jsonValidator?.call(decoded);
        }
        return decoded;
      } catch (e, stackTrace) {
        if (e is UnauthenticatedException) rethrow;
        AppLog.e(
          logTag,
          '[${apiName ?? path}] JSON 解析失败(len=${resp.body.length})',
          error: e,
          stackTrace: stackTrace,
        );
        throw ServiceException('[${apiName ?? path}] 响应解析失败');
      }
    });
  }

  /// 发送 POST 表单请求并解析为 JSON 数组。
  Future<List<dynamic>> postFormForJsonList(
    String path,
    Map<String, String> fields, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? apiName,
  }) {
    return run((client) async {
      final uri = resolveUri(path, query);
      final mergedHeaders = {
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        ...?headers,
      };
      final resp = await client.post(
        uri,
        headers: _buildHeaders(mergedHeaders),
        body: fields,
      );
      checkResponse(resp, apiName: apiName ?? path);
      return parseJsonList(
        resp.body,
        apiName ?? path,
        (m) => ServiceException(m),
      );
    });
  }

  /// 发送 POST 表单请求并解析为 JSON Map。
  Future<Map<String, dynamic>> postFormForJsonMap(
    String path,
    Map<String, String> fields, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? apiName,
  }) {
    return run((client) async {
      final uri = resolveUri(path, query);
      final mergedHeaders = {
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        ...?headers,
      };
      final resp = await client.post(
        uri,
        headers: _buildHeaders(mergedHeaders),
        body: fields,
      );
      checkResponse(resp, apiName: apiName ?? path);
      final json = parseJson(
        resp.body,
        apiName ?? path,
        (m) => ServiceException(m),
      );
      jsonValidator?.call(json);
      return json;
    });
  }

  /// 发送 POST JSON 请求并解析为 JSON Map。
  Future<Map<String, dynamic>> postJsonForJsonMap(
    String path,
    Object jsonBody, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? apiName,
  }) {
    return run((client) async {
      final uri = resolveUri(path, query);
      final mergedHeaders = {
        'Content-Type': 'application/json; charset=UTF-8',
        ...?headers,
      };
      final encoded = jsonBody is String ? jsonBody : jsonEncode(jsonBody);
      final resp = await client.post(
        uri,
        headers: _buildHeaders(mergedHeaders),
        body: encoded,
      );
      checkResponse(resp, apiName: apiName ?? path);
      final json = parseJson(
        resp.body,
        apiName ?? path,
        (m) => ServiceException(m),
      );
      jsonValidator?.call(json);
      return json;
    });
  }
}

/// 常用子系统响应信封辅助类。
abstract final class ApiEnvelope {
  /// 校验微服务响应，若 `e == 10013` 抛出 [UnauthenticatedException]。
  static void validateWfw(Map<String, dynamic> json) {
    final e = json['e'];
    if (e == 10013 || e?.toString() == '10013') {
      throw const UnauthenticatedException('微服务登录已失效');
    }
  }

  /// 解包微服务响应信封 `{ "e": 0, "m": "...", "d": ... }`。
  ///
  /// 若 `e == 10013` 抛出 [UnauthenticatedException]；
  /// 若 `e != 0` 抛出 [ServiceException]；
  /// 成功时返回 `json['d']`。
  static dynamic unwrapWfw(
    Map<String, dynamic> json, {
    String fallbackError = '微服务请求失败',
  }) {
    validateWfw(json);
    final e = json['e'];
    if (e != 0 && e?.toString() != '0') {
      final msg = json['m']?.toString();
      throw ServiceException(
        (msg != null && msg.isNotEmpty) ? msg : fallbackError,
      );
    }
    return json['d'];
  }

  /// 解包通用 `{ "status": ..., "message": ..., "data": ... }` 信封。
  static dynamic unwrapStatus(
    Map<String, dynamic> json, {
    dynamic successStatus = 'success',
    String statusKey = 'status',
    String messageKey = 'message',
    String dataKey = 'data',
    String fallbackError = '请求失败',
  }) {
    final status = json[statusKey];
    if (status?.toString() != successStatus?.toString()) {
      final msg = json[messageKey]?.toString();
      throw ServiceException(
        (msg != null && msg.isNotEmpty) ? msg : fallbackError,
      );
    }
    return json[dataKey];
  }
}
