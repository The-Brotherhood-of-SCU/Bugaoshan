import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:bugaoshan/providers/secure_storage_provider.dart';
import 'package:bugaoshan/services/auth/auth_session.dart';
import 'package:bugaoshan/services/auth/auth_state.dart';
import 'package:bugaoshan/services/ccyl_oauth_service.dart';
import 'package:bugaoshan/services/ccyl_service.dart';

const _keyCcylToken = 'ccyl_token';
const _keyCcylUserId = 'ccyl_user_id';

/// 第二课堂（CCYL）认证会话。
///
/// CCYL 拥有独立于 SCU 的 OAuth token 体系，不共享 session cookie。
/// 初始登录时需要依赖 [ScuAuthSession] 获取 OAuth code，后续完全独立。
class CcylAuthSession extends AuthSession<http.Client> {
  final CcylService _service = CcylService();

  String? _token;

  @override
  String get serviceName => '第二课堂';

  CcylService get service => _service;
  String? get token => _token;

  /// 从安全存储恢复 token（应用启动时调用）。
  Future<void> init() async {
    final secure = SecureStorageProvider.instance;
    _token = await secure.read(key: _keyCcylToken);
    final userId = await secure.read(key: _keyCcylUserId);
    if (_token != null) {
      _service.restoreToken(_token!, userId);
      state = AuthState.ready;
    }
  }

  @override
  Future<http.Client> getClient() async {
    if (isExpired) {
      final refreshed = await refresh();
      if (!refreshed) {
        throw CcylException('第二课堂登录已过期');
      }
    }

    if (!_service.isLoggedIn) {
      throw CcylException('第二课堂未登录');
    }

    // 返回自动注入 Authorization 头的包装 Client
    return _CcylAuthClient(_token!);
  }

  /// 使用 OAuth code 登录。
  Future<void> loginWithCode(String code) async {
    await _service.login(code);
    _token = _service.token;
    await _saveToSecure();
    state = AuthState.ready;
  }

  /// 尝试通过 SCU 自动恢复 CCYL 登录（OAuth 静默绑定）。
  Future<bool> reLogin() async {
    try {
      final oauth = CcylOAuthService();
      final oauthCode = await oauth.getOAuthCode();
      if (oauthCode == null) return false;
      await _service.login(oauthCode);
      _token = _service.token;
      await _saveToSecure();
      state = AuthState.ready;
      return true;
    } catch (e) {
      debugPrint('CcylSession.reLogin error: $e');
      return false;
    }
  }

  @override
  Future<bool> refresh() async {
    final success = await reLogin();
    if (!success) {
      state = AuthState.expired;
    }
    return success;
  }

  Future<void> _saveToSecure() async {
    final secure = SecureStorageProvider.instance;
    await secure.write(key: _keyCcylToken, value: _token!);
    final user = _service.currentUser;
    if (user != null) {
      await secure.write(key: _keyCcylUserId, value: user.id);
    }
  }

  @override
  Future<void> logout() async {
    _service.logout();
    _token = null;
    final secure = SecureStorageProvider.instance;
    await secure.delete(key: _keyCcylToken);
    await secure.delete(key: _keyCcylUserId);
    state = AuthState.unknown;
  }
}

/// 自动注入 CCYL token 请求头的 HTTP Client 包装。
/// 使用与 [CcylService._authHeaders] 一致的 `token` 头。
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
