import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';

class CcylOAuthService {
  static const _idBase = 'https://id.scu.edu.cn';

  /// 获取 CCYL OAuth code。
  ///
  /// 流程：
  ///   1. bindSession() 已在内部预热了 cas_apereo17 SP（见 ScuAuthService.bindSession）
  ///   2. 直接用同一个 client 再走一次 sp_logged，此时服务端 session 已有授权，
  ///      会正确下发 CAS ticket 并重定向到目标 URL，从中提取 code。
  Future<String?> getOAuthCode() async {
    final auth = getIt<ScuAuthProvider>();
    if (auth.accessToken == null) return null;

    // bindSession() 内部已预热 cas_apereo17，直接复用同一个带 cookie 的 client
    final client = await auth.service.bindSession();

    final spLoggedUrl = Uri.parse(
      '$_idBase/api/bff/v1.2/commons/sp_logged'
      '?access_token=${auth.accessToken}'
      '&sp_code=${_spCode()}'
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
      return null;
    } finally {
      // client 是 reusable 的，close() 是空操作，不会真正关闭底层连接
      client.close();
    }
  }

  /// 从 HTML body 里提取 meta refresh 或 window.location 里的 URL（兜底用）
  String? _extractRedirectUri(String body) {
    // <meta http-equiv="refresh" content="0;url=...">
    // 用双引号包裹 raw string，这样内部的单引号不会终止字符串
    final metaMatch = RegExp(
      r"""<meta[^>]+http-equiv=["']refresh["'][^>]+content=["'][^;]+;\s*url=([^"'>\s]+)""",
      caseSensitive: false,
    ).firstMatch(body);
    if (metaMatch != null) return metaMatch.group(1);

    // window.location = "..." 或 window.location.href = '...'
    final jsMatch = RegExp(
      r"""window\.location(?:\.href)?\s*=\s*["']([^"']+)["']""",
    ).firstMatch(body);
    if (jsMatch != null) return jsMatch.group(1);

    return null;
  }

  /// sp_code 与 ScuAuthService._CcylSpCode.value 保持一致
  static String _spCode() =>
      'bDBhREE1WDMzK3llSzZyVFZNeE81czRDd1hESTI4NWxGaFdsTnlvcGt3eVdTb2cxSjN5a1FJTDVMWTBEQkFFd2k1bWZRMy82OXN6V21ZYzFLd2NlSDdUaWlVcVJ1emxVVnF4Q3RZNWxjWlVoTEZqUktVSWVmY1ZaKzBLYUlBWDYvaU5MS1E5Y25nT1BoSzRIM0FIOWVCQjMxMXd5b0JrenNuWDBDM1BKU0FwUVVnZHdoSWYrc0hKZmEwSHRQbFZDV1o2dzFtQ3Nuci9wV1ExZHRMMytueHpLZVg5djJJcGFRbkJxZFJCQWJZWHI2dlpQNHVxNFNhcHM3Y3RkK2g1dWFuUEtNT1JZblFXRFBLUEdrcGdxNHR5eEcxclh5YXQ5a2FXN3JSZ2g2OTAxWCt0TUdTNXJDRVdNeDNTU3duTk1nNW9RSyt4WkdzSjNkR3NvVEFDMzFCQmJHUVcrVitybmszQVd0djFpUUJ5dDJySlRTajZIem1qZFYwMjVWcVpEaUtKd1AwQzI3TUpZd3FyY1hqdkxUZkFCd3JwL3ltczdXcmlTUzhZYVJPR0QwOXk2aDJIdUlCUTAvbEJWd0xzcUZXSElxaENpR0pseG1XYTZRbWlFaklERTd6TlhBQkJLdTZGUS8rNTBBYWRkcDVrRXdBM0tqejMvd1AvTklkZW5oNll4MllINlFiNVRucXNhZWtzUlh3d1BOQzBrMERSM0tId3dyS1hONkF6VDZwRGl3S3h1aDNLSGVmcTBRTktXUXMxTTZxeW1lcmgzYVlGWDNmVHdvUnJkWXVhbHN0aEtHKzU5TnFuVm1NbXU4dnhZQk8zKzQrdnV3aTJEaGY4VXRnV3lHeTVBcFFnWlUyQTFsWjdsR1RyNHh1TjV5dUlVc1VNNTRlbEtETTVVYWZoYnFPTXFrM2MxUHVNSHVHLzRtUFk4cmZzaXNUVkovWlhuSkhWWXpYQUJ4UDE4bGt2NXJkMFlXZHM0cFlYVVduKy9ZWGNKTlBDNEVrSzE3R0NVWDNxcCtiQkVyaXMzaTRXam1wWTFzYkpWZTAxYzZ0VGlxcGkvcEYyLzJPND0=';
}
