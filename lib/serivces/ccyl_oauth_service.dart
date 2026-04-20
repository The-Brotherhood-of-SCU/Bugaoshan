import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:bugaoshan/serivces/scu_auth_service.dart';

class CcylOAuthService {
  static const _idBase = 'https://id.scu.edu.cn';
  Future<String?> getOAuthCode() async {
    final auth = getIt<ScuAuthProvider>();
    if (auth.accessToken == null) return null;

    final client = await auth.service.bindSession();

    final spLoggedUrl = Uri.parse(
      '$_idBase/api/bff/v1.2/commons/sp_logged'
      '?access_token=${auth.accessToken}'
      '&sp_code=${CcylSpCode.value}'
      '&application_key=scdxplugin_cas_apereo17',
    );

    try {
      final response = await client.followRedirects(
        spLoggedUrl,
        headers: {
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*',
          'User-Agent':
              'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 '
              '(KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36 Edg/131.0.0.0',
        },
      );

      final finalUrl = response.request?.url.toString() ?? '';
      if (finalUrl.contains('code=')) {
        final uri = Uri.parse(finalUrl);
        final code = uri.queryParameters['code'];
        return code;
      }

      // 兜底：从响应 body 里找 code（部分情况下重定向 URL 不在 request.url 里）
      final body = response.body;
      final bodyUri = _extractRedirectUri(body);
      if (bodyUri != null && bodyUri.contains('code=')) {
        final code = Uri.parse(bodyUri).queryParameters['code'];
        return code;
      }
      return null;
    } catch (e) {
      debugPrint('CCYL OAuth] Error: $e');
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
