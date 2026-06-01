import 'package:http/http.dart' as http;
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/scu_auth_service.dart';

class ScuMicroserviceAuthService {
  /// 获取已认证的 http Client。
  ///
  /// - 未登录 → 返回 `null`
  /// - token 已过期 → 抛出 [ScuLoginException]（携带 `sessionExpired: true`）
  /// - 正常 → 返回已绑定 session 的 [http.Client]
  Future<http.Client?> getAuthenticatedClient() async {
    final auth = getIt<ScuAuthProvider>();
    if (auth.accessToken == null) return null;

    // 检查 token 是否已过期
    if (auth.isExpired) {
      throw ScuLoginException('登录已过期，请重新登录', sessionExpired: true);
    }

    return await auth.service.bindSession();
  }
}
