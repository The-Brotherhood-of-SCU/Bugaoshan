import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/pages/campus/ccyl/models/ccyl_models.dart';
import 'package:bugaoshan/utils/secure_storage.dart';
import 'package:bugaoshan/services/auth/ccyl_oauth_service.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/ccyl/ccyl_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/auth/subsystem_auth.dart';
import 'package:bugaoshan/utils/auth_logger.dart';

const _keyCcylToken = 'ccyl_token';
const _keyCcylUserId = 'ccyl_user_id';
const _keyCcylSession = 'ccyl_session_v2';

typedef CcylLoginResult = ({String token, CcylUser user});
typedef CcylLoginCallback = Future<CcylLoginResult> Function(String code);
typedef CcylOAuthCodeProvider = Future<String?> Function();

/// 第二课堂认证（第2层）
///
/// 管理 CCYL 的 token、用户信息、登录/登出。
/// CCYL 拥有独立于 SCU 的 OAuth token 体系，不共享 session cookie。
/// reLogin 时通过 [CcylOAuthService] 从 SCU 获取 OAuth code。
class CcylAuth extends ChangeNotifier implements SubsystemAuth {
  static const String _tag = 'CcylAuth';

  final ScuAuth _scuAuth;
  final AuthLogger _log;
  final CcylLoginCallback _login;
  final CcylOAuthCodeProvider? _oauthCodeProvider;
  String? _token;
  CcylUser? _currentUser;
  String? _boundScuPrincipal;
  Future<bool>? _reLoginFuture;

  CcylAuth(
    this._scuAuth, {
    AuthLogger? logger,
    CcylLoginCallback? login,
    CcylOAuthCodeProvider? oauthCodeProvider,
  }) : _log = logger ?? getIt<AuthLogger>(),
       _login = login ?? CcylService.login,
       _oauthCodeProvider = oauthCodeProvider;

  @override
  String get moduleId => 'ccyl';

  @override
  List<SubsystemAuth> get dependencies => const [];

  bool get _isBoundToCurrentPrincipal =>
      _token != null &&
      _boundScuPrincipal != null &&
      _boundScuPrincipal == _scuAuth.principal;

  String? get token => _isBoundToCurrentPrincipal ? _token : null;
  bool get isLoggedIn => _isBoundToCurrentPrincipal;
  CcylUser? get currentUser => _isBoundToCurrentPrincipal ? _currentUser : null;

  /// 从安全存储恢复 token（应用启动时调用）。
  Future<void> init() async {
    final secure = SecureStorageProvider.instance;
    final raw = await secure.read(key: _keyCcylSession);
    await secure.delete(key: _keyCcylToken);
    await secure.delete(key: _keyCcylUserId);
    if (raw == null) {
      _log.d(_tag, 'init: no saved token');
      return;
    }

    try {
      final session = jsonDecode(raw) as Map<String, dynamic>;
      final token = session['token']?.toString();
      final userId = session['userId']?.toString();
      final principal = session['scuPrincipal']?.toString();
      final currentPrincipal = _scuAuth.principal;
      if (token == null ||
          userId == null ||
          principal == null ||
          currentPrincipal == null ||
          principal != currentPrincipal) {
        _log.w(_tag, 'init: principal mismatch, discarding saved token');
        await _clearPersistedSession();
        return;
      }

      _token = token;
      _boundScuPrincipal = principal;
      _currentUser = CcylUser(
        id: userId,
        userName: '',
        realname: '',
        orgName: '',
      );
      _log.i(_tag, 'init: token restored');
    } catch (_) {
      _log.w(_tag, 'init: malformed saved session, discarding');
      await _clearPersistedSession();
    }
  }

  /// 获取当前 token，未登录时抛 [UnauthenticatedException]。
  String requireToken() {
    final currentToken = token;
    if (currentToken == null) {
      throw const UnauthenticatedException('第二课堂未登录');
    }
    return currentToken;
  }

  @override
  Future<void> ensureAuthenticated() async {
    if (_isBoundToCurrentPrincipal) return;
    if (_token != null || _currentUser != null || _boundScuPrincipal != null) {
      _clearMemorySession();
      await _clearPersistedSession();
    }
    final ok = await reLogin();
    if (!ok) throw const UnauthenticatedException('第二课堂未登录');
  }

  /// 获取当前用户 ID，未登录时抛 [UnauthenticatedException]。
  String requireUserId() {
    final user = currentUser;
    if (user == null) throw const UnauthenticatedException('第二课堂未登录');
    return user.id;
  }

  /// 使用 OAuth code 登录。
  Future<void> loginWithCode(String code) async {
    _log.i(_tag, 'loginWithCode: start');
    final principal = _scuAuth.principal;
    if (principal == null) {
      throw const UnauthenticatedException('无法确认当前校园账号，请重新登录');
    }
    final result = await _login(code);
    if (_scuAuth.principal != principal) {
      throw const UnauthenticatedException('校园账号已切换，请重新授权');
    }
    _token = result.token;
    _currentUser = result.user;
    _boundScuPrincipal = principal;
    await _saveToSecure();
    _log.i(_tag, 'loginWithCode: ok');
    notifyListeners();
  }

  /// 通过 SCU 自动恢复 CCYL 登录（OAuth 静默绑定）。
  Future<bool> reLogin() async {
    if (_reLoginFuture != null) return _reLoginFuture!;
    _log.i(_tag, 'reLogin: starting');
    _reLoginFuture = _doReLogin();
    try {
      return await _reLoginFuture!;
    } finally {
      _reLoginFuture = null;
    }
  }

  Future<bool> _doReLogin() async {
    try {
      final principal = _scuAuth.principal;
      if (principal == null) {
        _log.w(_tag, 'reLogin: current principal unavailable');
        return false;
      }
      final oauthCode = _oauthCodeProvider != null
          ? await _oauthCodeProvider!()
          : await CcylOAuthService(_scuAuth).getOAuthCode();
      if (oauthCode == null) {
        _log.w(_tag, 'reLogin: oauth code missing');
        return false;
      }
      final result = await _login(oauthCode);
      if (_scuAuth.principal != principal) {
        _log.w(_tag, 'reLogin: principal changed, discarding response');
        return false;
      }
      _token = result.token;
      _currentUser = result.user;
      _boundScuPrincipal = principal;
      await _saveToSecure();
      _log.i(_tag, 'reLogin: ok');
      notifyListeners();
      return true;
    } catch (e) {
      _log.e(_tag, 'reLogin: error $e');
      return false;
    }
  }

  @override
  void invalidate() {
    _log.d(_tag, 'invalidate');
    _reLoginFuture = null;
  }

  Future<void> _saveToSecure() async {
    final token = _token;
    final user = _currentUser;
    final principal = _boundScuPrincipal;
    if (token == null || user == null || principal == null) {
      throw StateError('Cannot persist an incomplete CCYL session');
    }
    final secure = SecureStorageProvider.instance;
    await secure.write(
      key: _keyCcylSession,
      value: jsonEncode({
        'token': token,
        'userId': user.id,
        'scuPrincipal': principal,
      }),
    );
    await secure.delete(key: _keyCcylToken);
    await secure.delete(key: _keyCcylUserId);
  }

  Future<void> logout() async {
    _log.i(_tag, 'logout');
    _clearMemorySession();
    _reLoginFuture = null;
    await _clearPersistedSession();
    notifyListeners();
  }

  void _clearMemorySession() {
    _token = null;
    _currentUser = null;
    _boundScuPrincipal = null;
  }

  Future<void> _clearPersistedSession() async {
    final secure = SecureStorageProvider.instance;
    await secure.delete(key: _keyCcylSession);
    await secure.delete(key: _keyCcylToken);
    await secure.delete(key: _keyCcylUserId);
  }
}
