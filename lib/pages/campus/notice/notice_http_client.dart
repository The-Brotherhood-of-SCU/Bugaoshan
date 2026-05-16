part of 'campus_notice_page.dart';

/// Shared HTTP client with cookie jar for notice requests.
class _NoticeHttp {
  static final _cookieJar = <String, String>{};
  static http.Client? _client;

  static http.Client _getClient() {
    _client ??= http.Client();
    return _client!;
  }

  static Map<String, String> _buildHeaders([String? referer]) {
    final headers = <String, String>{
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'User-Agent': _noticeUserAgent,
    };
    if (referer != null) {
      headers['Referer'] = referer;
    }
    if (_cookieJar.isNotEmpty) {
      headers['Cookie'] = _cookieJar.entries
          .map((e) => '${e.key}=${e.value}')
          .join('; ');
    }
    return headers;
  }

  static void _collectCookies(http.BaseResponse response) {
    // Use lowercase 'set-cookie' for case-insensitive header lookup.
    // The http package normalizes header keys to lowercase.
    final value = response.headers['set-cookie'];
    if (value == null) {
      return;
    }
    // The http package joins multiple Set-Cookie headers with ', '.
    // Split on ', ' only when it acts as a header separator, not inside
    // cookie attribute values like Expires.
    // RFC 6265 §4.1.1: cookie-name is a token; cookie-value may contain
    // separators but we extract until the first ';'.
    for (final cookie in value.split(RegExp(r', (?=[a-zA-Z0-9_.-]+=)'))) {
      final eq = cookie.indexOf('=');
      final semi = cookie.indexOf(';');
      if (eq <= 0) {
        continue;
      }
      final key = cookie.substring(0, eq).trim();
      final val = semi > eq
          ? cookie.substring(eq + 1, semi).trim()
          : cookie.substring(eq + 1).trim();
      if (key.isNotEmpty && val.isNotEmpty) {
        _cookieJar[key] = val;
      }
    }
  }

  static Future<http.Response> get(String url, {String? referer}) async {
    final client = _getClient();
    final resp = await client.get(
      Uri.parse(url),
      headers: _buildHeaders(referer ?? url),
    );
    _collectCookies(resp);
    return resp;
  }

  static Future<http.Response> post(
    String url, {
    String? referer,
    Map<String, String>? body,
  }) async {
    final client = _getClient();
    final resp = await client.post(
      Uri.parse(url),
      headers: {
        ..._buildHeaders(referer ?? url),
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: body,
    );
    _collectCookies(resp);
    return resp;
  }

  static void clearCookies() {
    _cookieJar.clear();
  }
}

/// Decodes response bytes to UTF-8, logging any encoding errors instead of
/// silently replacing malformed data.
String _decodeBody(List<int> bytes) {
  try {
    return utf8.decode(bytes);
  } on FormatException catch (e) {
    debugPrint('Body encoding error: $e, falling back with allowMalformed');
    return utf8.decode(bytes, allowMalformed: true);
  }
}
