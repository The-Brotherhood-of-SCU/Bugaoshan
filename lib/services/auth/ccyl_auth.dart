import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:bugaoshan/providers/secure_storage_provider.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/ccyl_oauth_service.dart';
import 'package:bugaoshan/services/ccyl/ccyl_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';

const _keyCcylToken = 'ccyl_token';
const _keyCcylUserId = 'ccyl_user_id';

/// 第二课堂认证（第2层）
///
/// CCYL 拥有独立于 SCU 的 OAuth token 体系，不共享 session cookie。
/// 初始登录时通过 [CcylOAuthService] 从 SCU 获取 OAuth code，后续完全独立。
class CcylAuth extends ChangeNotifier {
  final CcylService _service = CcylService();

  String? _token;

  CcylAuth(ScuAuth scuAuth); // scuAuth 保留参数签名，CcylOAuthService 内部通过 getIt 获取

  CcylService get service => _service;
  String? get token => _token;
  bool get isLoggedIn => _service.isLoggedIn;

  /// 从安全存储恢复 token（应用启动时调用）。
  Future<void> init() async {
    final secure = SecureStorageProvider.instance;
    _token = await secure.read(key: _keyCcylToken);
    final userId = await secure.read(key: _keyCcylUserId);
    if (_token != null) {
      _service.restoreToken(_token!, userId);
    }
  }

  /// 获取已认证的 CcylService。
  ///
  /// 如果未登录，自动尝试通过 SCU OAuth 重新登录。
  /// 失败时抛 [UnauthenticatedException]。
  Future<CcylService> getService() async {
    if (!_service.isLoggedIn) {
      final success = await _reLogin();
      if (!success) {
        throw const UnauthenticatedException('第二课堂未登录');
      }
    }
    return _service;
  }

  /// 获取已认证的 HTTP Client（自动注入 token 头）。
  ///
  /// 如果未登录，自动尝试通过 SCU OAuth 重新登录。
  /// 失败时抛 [UnauthenticatedException]。
  Future<http.Client> getClient() async {
    if (!_service.isLoggedIn) {
      final success = await _reLogin();
      if (!success) {
        throw const UnauthenticatedException('第二课堂未登录');
      }
    }
    return _CcylAuthClient(_token!);
  }

  /// 使用 OAuth code 登录。
  Future<void> loginWithCode(String code) async {
    await _service.login(code);
    _token = _service.token;
    await _saveToSecure();
    notifyListeners();
  }

  /// 通过 SCU 自动恢复 CCYL 登录（OAuth 静默绑定）。
  Future<bool> _reLogin() async {
    try {
      final oauth = CcylOAuthService();
      final oauthCode = await oauth.getOAuthCode();
      if (oauthCode == null) return false;
      await _service.login(oauthCode);
      _token = _service.token;
      await _saveToSecure();
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('CcylAuth.reLogin error: $e');
      return false;
    }
  }

  Future<void> _saveToSecure() async {
    final secure = SecureStorageProvider.instance;
    await secure.write(key: _keyCcylToken, value: _token!);
    final user = _service.currentUser;
    if (user != null) {
      await secure.write(key: _keyCcylUserId, value: user.id);
    }
  }

  Future<void> logout() async {
    _service.logout();
    _token = null;
    final secure = SecureStorageProvider.instance;
    await secure.delete(key: _keyCcylToken);
    await secure.delete(key: _keyCcylUserId);
    notifyListeners();
  }
}

/// 自动注入 CCYL token 请求头的 HTTP Client 包装。
class _CcylAuthClient extends http.BaseClient {
  final String token;
  final http.Client _inner = http.Client();

  _CcylAuthClient(this.token);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['token'] = token;
    return _inner.send(request);
  }

  @override
  void close() => _inner.close();
}
