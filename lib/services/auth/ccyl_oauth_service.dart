import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/utils/auth_logger.dart';
import 'package:bugaoshan/utils/constants.dart';

class CcylOAuthService {
  static const String _tag = 'CcylOAuth';
  static const _idBase = 'https://id.scu.edu.cn';
  final ScuAuth _scuAuth;
  final AuthLogger _log;

  CcylOAuthService(this._scuAuth, {AuthLogger? logger})
    : _log = logger ?? getIt<AuthLogger>();

  Future<String?> getOAuthCode() async {
    final accessToken = _scuAuth.accessToken;
    if (accessToken == null) {
      _log.w(_tag, 'getOAuthCode: no access token');
      return null;
    }

    final client = await _scuAuth.getClient();

    final spLoggedUrl = Uri.parse(
      '$_idBase/api/bff/v1.2/commons/sp_logged'
      '?access_token=$accessToken'
      '&sp_code=$kCcylSpCode'
      '&application_key=scdxplugin_cas_apereo17',
    );

    _log.d(_tag, 'getOAuthCode: fetching sp_logged');
    try {
      final response = await client.followRedirects(
        spLoggedUrl,
        headers: {
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*',
          'User-Agent': kDefaultUserAgent,
        },
      );

      final finalUrl = response.request?.url.toString() ?? '';
      if (finalUrl.contains('code=')) {
        final uri = Uri.parse(finalUrl);
        final code = uri.queryParameters['code'];
        _log.i(_tag, 'getOAuthCode: ok (from final url, len=${code?.length})');
        return code;
      }

      // 兜底：从响应 body 里找 code（部分情况下重定向 URL 不在 request.url 里）
      final body = response.body;
      final bodyUri = _extractRedirectUri(body);
      if (bodyUri != null && bodyUri.contains('code=')) {
        final code = Uri.parse(bodyUri).queryParameters['code'];
        _log.i(_tag, 'getOAuthCode: ok (from body, len=${code?.length})');
        return code;
      }
      _log.w(_tag, 'getOAuthCode: no code in response');
      return null;
    } catch (e) {
      _log.e(_tag, 'getOAuthCode: error $e');
      return null;
    } finally {
      client.close();
    }
  }

  String? _extractRedirectUri(String body) {
    final metaMatch = RegExp(
      r"""<meta[^>]+http-equiv=["']refresh["'][^>]+content=["'][^;]+;\s*url=([^"'>\s]+)""",
      caseSensitive: false,
    ).firstMatch(body);
    if (metaMatch != null) return metaMatch.group(1);

    final jsMatch = RegExp(
      r"""window\.location(?:\.href)?\s*=\s*["']([^"']+)["']""",
    ).firstMatch(body);
    if (jsMatch != null) return jsMatch.group(1);

    return null;
  }
}
