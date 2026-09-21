import 'package:flutter/foundation.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/auth/subsystem_auth.dart';
import 'package:bugaoshan/utils/auth_logger.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:http/http.dart' as http;

/// 研教务系统认证（第2层）。
///
/// 原生平台：通过 SCU 统一认证 cookie + 研教务 SSO 跳转建立 gsapp 与 ehall
/// 两域的 session（课表接口实测在 ehall 域，见 kGsScheduleEndpointPath）。
///
/// Web 端：手动 cookie 罐不可用（浏览器不暴露 Set-Cookie），改用独立
/// withCredentials 客户端由浏览器自动携带 ehall 会话；会话由用户在浏览器
/// 里登录 ehall 获得（导入页提供「打开登录页」引导），过期表现为接口返回
/// 登录页 HTML，由调用方引导重试。
class GsAuth extends ChangeNotifier implements SubsystemAuth {
  static const String _tag = 'GsAuth';

  final ScuAuth _scuAuth;
  final AuthLogger _log;
  CookieClient? _cachedClient;
  CookieClient? _lastScuClient;
  Future<CookieClient>? _loginFuture;
  CookieClient? _webClient;

  GsAuth(this._scuAuth, {AuthLogger? logger})
    : _log = logger ?? getIt<AuthLogger>() {
    _scuAuth.addListener(notifyListeners);
  }

  @override
  String get moduleId => 'gs';

  @override
  List<SubsystemAuth> get dependencies => const [];

  @override
  Future<void> ensureAuthenticated() async {
    _log.d(_tag, 'ensureAuthenticated');
    await getClient();
  }

  /// 获取已认证的研教务 CookieClient。
  ///
  /// 如果 SCU 认证失败，[UnauthenticatedException] 自动穿透。
  Future<CookieClient> getClient() async {
    // Web 端：浏览器自动管理 cookie（需 withCredentials），手动 cookie 罐
    // 与跨域 SSO 重定向链都不可用。ehall 会话由用户在浏览器里登录获得；
    // 会话失效时接口返回登录页 HTML，业务层识别为空数据并引导重试。
    if (kIsWeb) {
      return _webClient ??= _buildWebClient();
    }

    final scuClient = await _scuAuth.getClient();

    if (!identical(scuClient, _lastScuClient)) {
      _log.d(_tag, 'scu client changed, clearing cache');
      _lastScuClient = scuClient;
      _cachedClient = null;
      _loginFuture = null;
    }

    if (_cachedClient != null) {
      _log.d(_tag, 'getClient: cache hit');
      return _cachedClient!;
    }
    if (_loginFuture != null) {
      _log.d(_tag, 'getClient: awaiting existing login');
      return _loginFuture!;
    }

    _log.i(_tag, 'getClient: starting SSO login');
    _loginFuture = _login(scuClient);
    try {
      return await _loginFuture!;
    } finally {
      _loginFuture = null;
    }
  }

  /// Web 端专用客户端：启用 withCredentials，让浏览器自动携带
  /// ehall.scu.edu.cn 的会话 cookie（登录动作发生在浏览器标签页里）。
  CookieClient _buildWebClient() {
    final inner = http.Client();
    try {
      // 只有 Web 端的 BrowserClient 有该属性；动态设置避免平台分支的
      // 类型依赖。原生平台不会走到这里。
      (inner as dynamic).withCredentials = true;
    } catch (_) {}
    return CookieClient(inner: inner);
  }

  Future<CookieClient> _login(CookieClient client) async {
    final auth = _scuAuth.accessToken;
    if (auth == null) throw const UnauthenticatedException();

    final ssoHeaders = {
      'Accept': 'text/html,application/xhtml+xml,*/*',
      'User-Agent': kDefaultUserAgent,
      'Authorization': 'Bearer $auth',
    };

    // gsapp 域 SSO 预热（成绩 / 培养计划等未来模块）。注意：kGsSsoUrl 当前
    // 是占位地址（真实域名待定案），2026-09-20 实测该域在公网/校园网均不
    // 可达——而当前研究生功能（课表）全部在 ehall 域。因此此步 **best-
    // effort**：任何失败只记日志，不得打断下面的 ehall 登录主链路。
    try {
      final gsappResponse = await client.followRedirects(
        Uri.parse(kGsSsoUrl),
        headers: ssoHeaders,
      );
      _log.d(_tag, 'gsapp SSO: status=${gsappResponse.statusCode}');
    } catch (e) {
      _log.w(_tag, 'gsapp 域 SSO 预热失败（占位域名，忽略）：$e');
    }

    // ehall 域会话预热：课表接口实测部署在 ehall 域（kGsScheduleEndpointPath，
    // 2026-09-15 抓包确认），CookieClient 按 host 隔离 cookie，需单独跳一次
    // SSO。若统一认证没有自动放行（落到登录页），直连不可用——调用方应
    // 回退到 WebView 手动登录方案。
    final ehallResponse = await client.followRedirects(
      Uri.parse(kGsSchedulePageUrl),
      headers: ssoHeaders,
    );
    final ehallBody = ehallResponse.body;
    final landedOnLogin =
        ehallBody.contains('统一身份认证') || ehallBody.contains('frontend/login');
    if (landedOnLogin) {
      _log.w(_tag, 'ehall SSO 落到登录页（需手动登录），直连不可用');
      throw const UnauthenticatedException('ehall 会话未建立');
    }
    _log.i(_tag, 'ehall SSO: ok (status=${ehallResponse.statusCode})');

    // 其余 EMAP 应用会话预热：EMAP 各应用可能有独立的应用会话，课表
    // （wdkbapp）能直接 .do 成功不代表其它应用不需要先访各自 index。与
    // gsapp 预热同策略：失败仅记日志，不阻断主链路（真正失败由 .do 的
    // 自愈重试兜底）。新增研究生模块时在 constants 的
    // [kGsExtraAppIndexUrls] 追加 index 即可，无需改这里。
    for (final appIndex in kGsExtraAppIndexUrls) {
      try {
        final appIndexResponse = await client.followRedirects(
          Uri.parse(appIndex),
          headers: ssoHeaders,
        );
        _log.d(_tag, 'app index: $appIndex -> ${appIndexResponse.statusCode}');
      } catch (e) {
        _log.w(_tag, 'app index 预热失败（忽略）：$appIndex $e');
      }
    }

    _cachedClient = client;
    _log.i(_tag, 'SSO login: ok');
    return client;
  }

  @override
  void invalidate() {
    if (_cachedClient != null || _loginFuture != null) {
      _log.d(_tag, 'invalidate');
    }
    _cachedClient = null;
    _loginFuture = null;
  }

  @override
  void dispose() {
    _scuAuth.removeListener(notifyListeners);
    super.dispose();
  }
}
