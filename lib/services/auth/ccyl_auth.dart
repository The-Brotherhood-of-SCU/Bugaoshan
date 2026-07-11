import 'dart:async';
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
  int _authGeneration = 0;
  Future<void> _storageTail = Future.value();

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
      await invalidateSession();
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
    final generation = ++_authGeneration;
    _reLoginFuture = null;
    final principal = _scuAuth.principal;
    if (principal == null) {
      throw const UnauthenticatedException('无法确认当前校园账号，请重新登录');
    }
    final result = await _login(code);
    if (!_isCurrentAttempt(generation, principal)) {
      throw const UnauthenticatedException('校园账号已切换，请重新授权');
    }
    final committed = await _commitLogin(result, principal, generation);
    if (!committed) {
      throw const UnauthenticatedException('第二课堂授权已取消');
    }
    _log.i(_tag, 'loginWithCode: ok');
    notifyListeners();
  }

  /// 通过 SCU 自动恢复 CCYL 登录（OAuth 静默绑定）。
  Future<bool> reLogin() async {
    if (_reLoginFuture != null) return _reLoginFuture!;
    _log.i(_tag, 'reLogin: starting');
    final generation = _authGeneration;
    final future = _doReLogin(generation);
    _reLoginFuture = future;
    try {
      return await future;
    } finally {
      if (identical(_reLoginFuture, future)) {
        _reLoginFuture = null;
      }
    }
  }

  Future<bool> _doReLogin(int generation) async {
    try {
      final principal = _scuAuth.principal;
      if (principal == null || !_isCurrentAttempt(generation, principal)) {
        _log.w(_tag, 'reLogin: current principal unavailable');
        return false;
      }
      final oauthCode = _oauthCodeProvider != null
          ? await _oauthCodeProvider!()
          : await CcylOAuthService(_scuAuth).getOAuthCode();
      if (!_isCurrentAttempt(generation, principal)) return false;
      if (oauthCode == null) {
        _log.w(_tag, 'reLogin: oauth code missing');
        return false;
      }
      final result = await _login(oauthCode);
      if (!_isCurrentAttempt(generation, principal)) {
        _log.w(_tag, 'reLogin: attempt superseded, discarding response');
        return false;
      }
      final committed = await _commitLogin(result, principal, generation);
      if (!committed) return false;
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
    _cancelCurrentAuthentication();
    unawaited(_clearPersistedSession());
  }

  Future<void> invalidateSession() async {
    _log.d(_tag, 'invalidateSession');
    _cancelCurrentAuthentication();
    await _clearPersistedSession();
  }

  Future<bool> _commitLogin(
    CcylLoginResult result,
    String principal,
    int generation,
  ) async {
    if (!_isCurrentAttempt(generation, principal)) return false;

    final persisted = await _serializeStorage(() async {
      if (!_isCurrentAttempt(generation, principal)) return false;
      final secure = SecureStorageProvider.instance;
      await secure.write(
        key: _keyCcylSession,
        value: jsonEncode({
          'token': result.token,
          'userId': result.user.id,
          'scuPrincipal': principal,
        }),
      );
      await secure.delete(key: _keyCcylToken);
      await secure.delete(key: _keyCcylUserId);
      return _isCurrentAttempt(generation, principal);
    });
    if (!persisted || !_isCurrentAttempt(generation, principal)) return false;

    _token = result.token;
    _currentUser = result.user;
    _boundScuPrincipal = principal;
    return true;
  }

  Future<void> logout() async {
    _log.i(_tag, 'logout');
    _cancelCurrentAuthentication();
    await _clearPersistedSession();
    notifyListeners();
  }

  void _cancelCurrentAuthentication() {
    _authGeneration++;
    _reLoginFuture = null;
    _clearMemorySession();
  }

  bool _isCurrentAttempt(int generation, String principal) {
    return generation == _authGeneration && _scuAuth.principal == principal;
  }

  void _clearMemorySession() {
    _token = null;
    _currentUser = null;
    _boundScuPrincipal = null;
  }

  Future<void> _clearPersistedSession() async {
    await _serializeStorage(() async {
      final secure = SecureStorageProvider.instance;
      await secure.delete(key: _keyCcylSession);
      await secure.delete(key: _keyCcylToken);
      await secure.delete(key: _keyCcylUserId);
    });
  }

  Future<T> _serializeStorage<T>(Future<T> Function() action) {
    final run = _storageTail.then((_) => action());
    _storageTail = run.then<void>((_) {}, onError: (_, _) {});
    return run;
  }
}
