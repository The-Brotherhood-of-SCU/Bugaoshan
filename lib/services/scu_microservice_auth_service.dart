import 'package:bugaoshan/services/scu_auth_service.dart';

class ScuMicroserviceAuthService {
  Future<CookieClient?> getAuthenticatedClient({
    required String accessToken,
    required CookieClient? bindSessionResult,
  }) async {
    if (accessToken.isEmpty) return null;
    return bindSessionResult;
  }
}