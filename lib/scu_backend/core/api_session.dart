import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:bugaoshan/scu_backend/core/api_request.dart';
import 'package:bugaoshan/scu_backend/core/cookie_client.dart';

export 'package:bugaoshan/scu_backend/core/api_request.dart'
    show looksLikeLoginPage;
import 'package:bugaoshan/scu_backend/core/scu_exceptions.dart';
import 'package:bugaoshan/scu_backend/core/subsystem_auth.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/utils/json_utils.dart';

/// 会话失效检查器签名。
///
/// 若识别为未登录或会话过期，应抛出 [UnauthenticatedException]；
/// 若抛出其他异常（如 [ServiceException]），将穿透并中断请求；
/// 若会话正常，正常返回即可。
typedef SessionExpiryChecker = void Function(String body, int statusCode);

/// 任意 JSON 值（object / array / string / number / bool / null）。
typedef JsonValue = Object?;

/// JSON 业务响应校验器签名。
///
/// 在请求重试保护上下文中执行，覆盖 Map 与 List 两种顶层响应。
/// 若检测到业务层面的未登录或会话过期（如微服务的 `e == 10013`、
/// 预约系统的 `e == 'UN_AUTH'`），抛出 [UnauthenticatedException]
/// 以便触发自动重认证与重试。
///
/// 只关心 Map 信封的校验器应先做类型收窄：
/// `if (json is! Map<String, dynamic>) return;`
typedef JsonValidator = void Function(JsonValue json);

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
  /// 重试会重新执行 [action]；非幂等请求（如 multipart 上传）必须保证
  /// 闭包能安全重建请求，且不要依赖 [CookieClient] 对 multipart 的
  /// `ClientException` 传输层重试（该重试只对普通 `http.Request` 生效）。
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
  ///
  /// `X-Requested-With` 不是标准头，默认不注入；需要的调用方自行在
  /// `headers` 里加。
  Map<String, String> _buildHeaders(Map<String, String>? headers) {
    final map = <String, String>{
      'User-Agent': kDefaultUserAgent,
      'Accept': 'application/json, text/plain, */*',
      ...defaultHeaders,
    };
    if (headers != null && headers.isNotEmpty) {
      map.addAll(headers);
    }
    return map;
  }

  /// 检查响应是否为未登录、会话过期或网关异常。
  ///
  /// 会话失效统一转为 [UnauthenticatedException]（触发自动重认证）；
  /// 其余非 2xx/3xx 状态统一转为带 `statusCode` 的 [ServiceException]，
  /// 避免落到「响应解析失败」这类误导性文案。
  void checkResponse(http.Response resp, {String? apiName}) {
    final body = resp.body;
    final statusCode = resp.statusCode;

    if (sessionExpiryChecker != null) {
      sessionExpiryChecker!(body, statusCode);
    } else {
      _defaultSessionCheck(body, statusCode);
    }

    if (statusCode < 200 || statusCode >= 400) {
      throw ServiceException(
        apiName != null ? '[$apiName] 请求失败' : '请求失败',
        statusCode: statusCode,
      );
    }
  }

  /// 默认会话失效判定：重定向/未授权/空响应/登录页。
  void _defaultSessionCheck(String body, int statusCode) {
    if (statusCode == 302 || statusCode == 401 || statusCode == 403) {
      throw const UnauthenticatedException('会话已失效或已重定向至认证页');
    }

    final trimmed = body.trim();
    if (trimmed.isEmpty) {
      if (emptyBodyThrowsUnauthenticated) {
        throw const UnauthenticatedException('服务返回空响应，会话可能已过期');
      }
      throw const ServiceException('服务器返回了空响应');
    }

    if (looksLikeLoginPage(trimmed)) {
      throw const UnauthenticatedException('检测到登录页，会话已过期');
    }
  }

  static const String _formContentType =
      'application/x-www-form-urlencoded; charset=UTF-8';
  static const String _jsonContentType = 'application/json; charset=UTF-8';

  /// 统一的 GET 执行骨架：解析 URL、注入 Header、会话校验后交给调用方解码。
  Future<T> _get<T>(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? apiName,
    required T Function(http.Response resp, String apiName) decode,
  }) {
    final name = apiName ?? path;
    return run((client) async {
      final uri = resolveUri(path, query);
      final resp = await client.get(uri, headers: _buildHeaders(headers));
      checkResponse(resp, apiName: name);
      return decode(resp, name);
    });
  }

  /// 统一的 POST 执行骨架。
  Future<T> _post<T>(
    String path, {
    Object? body,
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? apiName,
    required T Function(http.Response resp, String apiName) decode,
  }) {
    final name = apiName ?? path;
    return run((client) async {
      final uri = resolveUri(path, query);
      final resp = await client.post(
        uri,
        headers: _buildHeaders(headers),
        body: body,
      );
      checkResponse(resp, apiName: name);
      return decode(resp, name);
    });
  }

  Map<String, dynamic> _decodeJsonMap(http.Response resp, String apiName) {
    final json = parseJson(resp.body, apiName, (m) => ServiceException(m));
    jsonValidator?.call(json);
    return json;
  }

  List<dynamic> _decodeJsonList(http.Response resp, String apiName) {
    final json = parseJsonList(resp.body, apiName, (m) => ServiceException(m));
    jsonValidator?.call(json);
    return json;
  }

  /// 发送 GET 请求并返回原始 [http.Response]。
  Future<http.Response> get(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? apiName,
  }) {
    return _get(
      path,
      query: query,
      headers: headers,
      apiName: apiName,
      decode: (resp, _) => resp,
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
  ///
  /// 默认发送 HTML 优先的 `Accept`；`X-Requested-With` 等非标准头默认不注入，
  /// 需要时由调用方通过 `headers` 自行添加。
  Future<String> getHtml(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? apiName,
  }) {
    final mergedHeaders = {
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      ...?headers,
    };
    return _get(
      path,
      query: query,
      headers: mergedHeaders,
      apiName: apiName,
      decode: (resp, _) => resp.body.trim(),
    );
  }

  /// 发送 GET 请求并解析为 JSON Map。
  Future<Map<String, dynamic>> getJsonMap(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? apiName,
  }) {
    return _get(
      path,
      query: query,
      headers: headers,
      apiName: apiName,
      decode: _decodeJsonMap,
    );
  }

  /// 发送 GET 请求并解析为 JSON 数组。
  Future<List<dynamic>> getJsonList(
    String path, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? apiName,
  }) {
    return _get(
      path,
      query: query,
      headers: headers,
      apiName: apiName,
      decode: _decodeJsonList,
    );
  }

  /// 发送 POST 表单请求并解析为 JSON 数组。
  Future<List<dynamic>> postFormForJsonList(
    String path,
    Map<String, String> fields, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? apiName,
  }) {
    return _post(
      path,
      body: fields,
      query: query,
      headers: {'Content-Type': _formContentType, ...?headers},
      apiName: apiName,
      decode: _decodeJsonList,
    );
  }

  /// 发送 POST 表单请求并解析为 JSON Map。
  Future<Map<String, dynamic>> postFormForJsonMap(
    String path,
    Map<String, String> fields, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? apiName,
  }) {
    return _post(
      path,
      body: fields,
      query: query,
      headers: {'Content-Type': _formContentType, ...?headers},
      apiName: apiName,
      decode: _decodeJsonMap,
    );
  }

  /// 发送 POST JSON 请求并解析为 JSON Map。
  ///
  /// [jsonBody] 为 `null` 时发送无 body 请求，但仍保留
  /// `Content-Type: application/json`（用于 `get-index` 这类参数化空 POST）。
  Future<Map<String, dynamic>> postJsonForJsonMap(
    String path,
    Object? jsonBody, {
    Map<String, dynamic>? query,
    Map<String, String>? headers,
    String? apiName,
  }) {
    final encoded = jsonBody == null
        ? null
        : (jsonBody is String ? jsonBody : jsonEncode(jsonBody));
    return _post(
      path,
      body: encoded,
      query: query,
      headers: {'Content-Type': _jsonContentType, ...?headers},
      apiName: apiName,
      decode: _decodeJsonMap,
    );
  }
}

/// 常用子系统响应信封辅助类。
abstract final class ApiEnvelope {
  /// 校验微服务响应，若 `e == 10013` 抛出 [UnauthenticatedException]。
  ///
  /// 接受任意 JSON 值；数组等非 Map 响应直接跳过。
  static void validateWfw(JsonValue json) {
    if (json is! Map<String, dynamic>) return;
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
}
