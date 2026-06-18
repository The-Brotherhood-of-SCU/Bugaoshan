import 'package:http/http.dart' as http;
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/utils/auth_logger.dart';
import 'package:bugaoshan/utils/constants.dart';

/// Cookie 感知的 http.Client，按域名隔离存储，发送时只带当前请求域的 cookie。
class CookieClient extends http.BaseClient {
  static const String _tag = 'CookieClient';
  http.Client _inner = http.Client();

  // 按域名存 cookie：host -> {name: value}
  final _jar = <String, Map<String, String>>{};

  bool reusable = false;

  AuthLogger get _log => getIt<AuthLogger>();

  /// 返回所有域 cookie 拼接的字符串（仅用于调试日志）
  String get cookieHeader {
    final all = <String, String>{};
    for (final m in _jar.values) {
      all.addAll(m);
    }
    return all.entries.map((e) => '${e.key}=${e.value}').join('; ');
  }

  /// 获取适合发送给 [uri] 的 cookie（域名匹配：精确 host 或父域）
  Map<String, String> _cookiesFor(Uri uri) {
    final host = uri.host;
    final result = <String, String>{};
    for (final entry in _jar.entries) {
      final jarHost = entry.key;
      if (host == jarHost || host.endsWith('.$jarHost')) {
        result.addAll(entry.value);
      }
    }
    return result;
  }

  /// 解析并存储响应中的 Set-Cookie
  void _storeCookies(Uri uri, http.BaseResponse response) {
    final raw = response.headers['set-cookie'];
    if (raw == null) return;

    final host = uri.host;
    _jar.putIfAbsent(host, () => {});

    final stored = <String>[];
    for (final part in raw.split(RegExp(r',\s*(?=[A-Za-z][^,=\s]*\s*=)'))) {
      final kv = part.split(';').first.trim();
      final eq = kv.indexOf('=');
      if (eq > 0) {
        final name = kv.substring(0, eq).trim();
        final value = kv.substring(eq + 1).trim();
        _jar[host]![name] = value;
        stored.add(name);
      }
    }
    if (stored.isNotEmpty) {
      _log.d(
        _tag,
        'set-cookie host=$host count=${stored.length} [${stored.join(',')}]',
      );
    }
  }

  /// 手动跟随重定向，每跳都：
  ///   1. 只带当前跳目标域的 cookie
  ///   2. 收集响应的 Set-Cookie 存回对应域
  Future<http.Response> followRedirects(
    Uri url, {
    Map<String, String>? headers,
    int maxRedirects = 10,
  }) async {
    Uri current = url;
    http.Response? lastResponse;

    _log.d(_tag, 'followRedirects: start url=$url maxRedirects=$maxRedirects');
    for (int i = 0; i <= maxRedirects; i++) {
      final cookies = _cookiesFor(current);
      final reqHeaders = <String, String>{
        ...?headers,
        if (cookies.isNotEmpty)
          'Cookie': cookies.entries
              .map((e) => '${e.key}=${e.value}')
              .join('; '),
      };

      final request = http.Request('GET', current)
        ..followRedirects = false
        ..headers.addAll(reqHeaders);

      final streamed = await sendWithClientExceptionRetry(request);
      final response = await http.Response.fromStream(streamed);
      _storeCookies(current, response);

      if (response.statusCode >= 300 && response.statusCode < 400) {
        final location = response.headers['location'];
        String nextHost = '?';
        if (location != null) {
          try {
            nextHost = Uri.parse(location).host;
          } catch (_) {
            nextHost = location;
          }
        }
        _log.d(
          _tag,
          'redirect hop=$i ${response.statusCode} ${current.host} -> $nextHost',
        );
        if (location == null) break;
        current = current.resolve(location);
        lastResponse = response;
      } else {
        _log.d(
          _tag,
          'followRedirects: end hop=$i status=${response.statusCode} url=$current',
        );
        return response;
      }
    }
    _log.e(
      _tag,
      'followRedirects: max redirects exceeded, last url=$current status=${lastResponse?.statusCode}',
    );
    throw ServiceException(
      'SSO 重定向链超过上限',
      statusCode: lastResponse?.statusCode,
    );
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final cookies = _cookiesFor(request.url);
    if (cookies.isNotEmpty) {
      request.headers['Cookie'] = cookies.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; ');
    }
    final response = await sendWithClientExceptionRetry(request);
    _storeCookies(request.url, response);
    _log.d(
      _tag,
      '${request.method} ${request.url.host}${request.url.path} -> ${response.statusCode}',
    );
    return response;
  }

  /// 带 http.ClientException 错误重试的请求发送函数
  Future<http.StreamedResponse> sendWithClientExceptionRetry(
    http.BaseRequest request,
  ) async {
    try {
      return await _inner.send(request).timeout(kHttpTimeout);
    } on http.ClientException catch (e) {
      _log.w(_tag, 'send: ClientException, retrying: $e');
      _inner.close();
      _inner = http.Client();
      final retryRequest = http.Request(request.method, request.url)
        ..followRedirects = request.followRedirects
        ..maxRedirects = request.maxRedirects
        ..persistentConnection = true
        ..headers.addAll(request.headers);
      if (request is http.Request) {
        retryRequest.body = request.body;
      }
      final result = await _inner.send(retryRequest).timeout(kHttpTimeout);
      _log.d(_tag, 'send: retry ok ${request.method} ${request.url}');
      return result;
    }
  }

  @override
  void close() {
    if (reusable) return;
    _inner.close();
    super.close();
  }
}
