import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/services/auth/auth_state.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/services/auth/subsystem_auth.dart';
import 'package:bugaoshan/utils/auth_logger.dart';
import 'package:bugaoshan/utils/constants.dart';
import 'package:bugaoshan/utils/secure_storage.dart';
import 'package:bugaoshan/utils/storage_keys.dart';
import 'package:bugaoshan/utils/zhhq_crypto.dart';
import 'package:flutter/foundation.dart';

/// 智慧后勤（zhhq）认证（第2层）
///
/// zhhq 走 SCU 统一身份认证（id.scu.edu.cn 的 `scdxplugin_jwt31` SSO 链），
/// 与 zhjw 的 `scdxplugin_jwt23` 同构。登录态为 zhhq 域下的 tokenKey
/// （`ITSOFT-WILAB-SESSION`），与办事大厅/后勤的 cookie 体系相互独立。
///
/// # 认证流程（已通过抓包确认）
///
/// 1. 用 SCU Bearer token 访问 casUrl（`id.scu.edu.cn/enduser/sp/sso/...`）
///    → 跟随 SSO 重定向链，最终回跳到 `zhhq.scu.edu.cn/account/login`，
///    回跳 URL 携带 `userinfo`（AES 加密的用户信息）。
/// 2. 用 `userinfo` 调 `POST /api/auth/login/auto` 换取 **tokenKey**。
/// 3. 后续业务请求头带 `Token`（每次新生成，AES 加密
///    `{tokenKey, clientId, timestamp, GUID}`）+ `TokenKey`。
///
/// tokenKey 持久化到 FlutterSecureStorage：[init] 时恢复（若 SCU 已登录则
/// 直接复用，跳过慢速 SSO）；失效重试时由 [invalidate] 清空并重新走 SSO。
class ZhhqAuth extends ChangeNotifier implements SubsystemAuth {
  static const String _tag = 'ZhhqAuth';

  /// zhhq 的 CAS 登录入口（来自 account/config.json 的 casUrl）。
  static const String casUrl =
      'https://id.scu.edu.cn/enduser/sp/sso/scdxplugin_jwt31'
      '?enterpriseId=scdx';

  static const String _loginAutoUrl =
      'https://zhhq.scu.edu.cn/api/auth/login/auto';

  final ScuAuth _scuAuth;
  final AuthLogger _log;

  bool _ready = false;
  bool _authFailed = false;
  String? _tokenKey;
  Future<void>? _warmUpFuture;

  ZhhqAuth(this._scuAuth, {AuthLogger? logger})
    : _log = logger ?? getIt<AuthLogger>() {
    _scuAuth.addListener(_onScuAuthChanged);
  }

  /// 从安全存储恢复 tokenKey。
  ///
  /// 无条件恢复（不等待 SCU 就绪）：tokenKey 是 zhhq 域的会话标识，
  /// 业务请求只依赖它，与 SCU 会话独立。冷启动时 SCU 可能还在自动登录，
  /// 但 tokenKey 已恢复即可走快速路径秒发业务请求；SCU 登出时
  /// [_onScuAuthChanged] 会同步清除持久化的 tokenKey，不会残留脏数据。
  ///
  /// 已知边界：冷启动时 SCU 会话已过期（storage 尚未被登出回调清理）且
  /// 本方法恢复了 tokenKey，`isReady=true` 会走一次快速路径请求，由 API
  /// 层 4010-4017 自愈（invalidate → 完整认证），不会永久卡在脏状态。
  ///
  /// 若 SCU 已登录且本地存有 tokenKey，直接复用（跳过慢速 SSO ——
  /// id.scu.edu.cn 响应可能需 5-8s），加速冷启动进入报修页。
  Future<void> init() async {
    try {
      final saved = await SecureStorageProvider.instance
          .read(key: kZhhqTokenKey)
          .catchError((_) => null);
      if (saved == null || saved.isEmpty) return;
      _tokenKey = saved;
      _ready = true;
      _log.i(_tag, 'init: restored tokenKey, ready');
      notifyListeners();
    } catch (e) {
      _log.w(_tag, 'init: failed to restore session: $e');
    }
  }

  void _onScuAuthChanged() {
    if (_scuAuth.state == AuthState.unknown) {
      if (_ready) _log.d(_tag, 'scu logged out, marking not ready');
      _ready = false;
      _tokenKey = null;
      _warmUpFuture = null;
      _authFailed = false;
      // 登出时清除持久化的 tokenKey
      SecureStorageProvider.instance.delete(key: kZhhqTokenKey);
    }
    notifyListeners();
  }

  @override
  String get moduleId => 'zhhq';

  @override
  List<SubsystemAuth> get dependencies => const [];

  bool get isReady => _ready;

  /// 最近一次认证是否失败（用于页面区分「认证中」与「认证失败」）。
  bool get authFailed => _authFailed;

  /// 当前 tokenKey（`ITSOFT-WILAB-SESSION` 值）；未认证时为 null。
  String? get tokenKey => _tokenKey;

  @override
  Future<void> ensureAuthenticated() async {
    // 快速路径：tokenKey 已就绪（含从安全存储恢复的）即视为认证完成，
    // 无需再等 SCU 会话（5-8s）。AuthCoordinator 登录后预热时命中该分支。
    if (_tokenKey != null) return;
    final client = await _scuAuth.getClient();
    await _ensureTokenKey(client);
  }

  /// 获取已认证的 CookieClient 并确保 tokenKey 已建立。
  Future<CookieClient> getClient() async {
    final client = await _scuAuth.getClient();
    await _ensureTokenKey(client);
    return client;
  }

  /// 快速获取业务请求可用的 CookieClient（不依赖 SCU 会话）。
  ///
  /// zhhq 业务请求（如 `getCommonAddress`）只携带 `Token`/`TokenKey` 头，
  /// **不需要** SCU 的 cookie/session。若 [tokenKey] 已就绪（含从安全存储
  /// 恢复的），直接返回独立的 [CookieClient] —— 冷启动时 SCU token 过期
  /// 也无需等待其 5-8s 的 refresh，秒发业务请求。
  ///
  /// 返回 `null` 表示 tokenKey 未就绪，调用方应走完整认证 [getClient]。
  CookieClient? getClientFast() {
    if (_tokenKey == null || _tokenKey!.isEmpty) return null;
    // 独立 client，不携带任何 cookie（zhhq 业务请求不需要）
    final client = CookieClient();
    return client;
  }

  /// 确保 tokenKey 已建立（已恢复/已有则直接返回，无则走 SSO 换取）。
  ///
  /// 注意：**不会**因 SCU 换 client 而清空已有 tokenKey —— tokenKey 与
  /// SCU 会话独立，只有 [invalidate]（业务请求 4010-4017）或 SCU 登出
  /// （[_onScuAuthChanged]）才会使它失效。这让 AuthCoordinator 后台预热
  /// 和页面请求都能直接复用持久化的 tokenKey，不重复走慢速 SSO。
  Future<void> _ensureTokenKey(CookieClient client) async {
    if (_tokenKey != null) return;
    final existing = _warmUpFuture;
    if (existing != null) {
      await existing;
      return;
    }

    _authFailed = false;
    final future = _acquireTokenKey(client);
    _warmUpFuture = future;
    try {
      await future;
    } catch (e) {
      // 认证失败（超时/SSO 失败等）：标记失败并通知页面显示错误重试，
      // 避免页面因 isReady 恒为 false 而无限转圈。
      _authFailed = true;
      _log.w(_tag, 'authenticate failed: $e');
      notifyListeners();
      rethrow;
    } finally {
      if (identical(_warmUpFuture, future)) {
        _warmUpFuture = null;
      }
    }
  }

  /// 走 SSO 链拿 `userinfo`，再调 `login/auto` 换 tokenKey。
  Future<void> _acquireTokenKey(CookieClient client) async {
    final auth = _scuAuth.accessToken;
    if (auth == null) throw const UnauthenticatedException();

    _log.i(_tag, 'acquireTokenKey: starting SSO');
    final response = await client.followRedirects(
      Uri.parse(casUrl),
      headers: {
        'Accept': 'text/html,application/xhtml+xml,*/*',
        'User-Agent': kDefaultUserAgent,
        'Authorization': 'Bearer $auth',
      },
    );
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const UnauthenticatedException();
    }
    if (response.statusCode < 200 || response.statusCode >= 400) {
      throw ServiceException('zhhq SSO 中继失败', statusCode: response.statusCode);
    }

    // 从回跳 URL 解析 userinfo（account/login?userinfo=<加密串>）
    // 注意：完整 URL 含加密 userinfo，日志只记录是否存在与长度，不打印 URL。
    final finalUrl = response.request?.url;
    final userinfo = finalUrl?.queryParameters['userinfo'];
    _log.i(
      _tag,
      'SSO 回跳: path=${finalUrl?.path} '
      'hasUserinfo=${userinfo != null && userinfo.isNotEmpty} '
      'userinfoLen=${userinfo?.length ?? 0}',
    );
    if (userinfo == null || userinfo.isEmpty) {
      _log.e(_tag, 'SSO 回跳缺少 userinfo');
      throw const UnauthenticatedException('zhhq 认证回跳缺少 userinfo');
    }

    final tokenKey = await _exchangeTokenKey(client, userinfo);
    _applyTokenKey(client, tokenKey);
  }

  /// 用 userinfo 调 `/auth/login/auto` 换 tokenKey。
  ///
  /// 响应体为 AES 加密的 JSON（`{data, errorCode, message, status}`），
  /// 成功时 `data` 即 tokenKey（`ITSOFT-WILAB-SESSION` 值）。
  Future<String> _exchangeTokenKey(CookieClient client, String userinfo) async {
    final timestamp = ZhhqCrypto.encrypt(
      DateTime.now().millisecondsSinceEpoch.toString(),
    );
    final body = {
      'userInfo': Uri.encodeComponent(userinfo),
      'clientId': ZhhqCrypto.clientId,
      'timestamp': timestamp,
      'schoolCode': '10610',
      'schoolName': '四川大学',
    };
    final resp = await client.post(
      Uri.parse(_loginAutoUrl),
      headers: {
        'Accept': 'application/json, text/plain, */*',
        'Content-Type': 'application/x-www-form-urlencoded; charset=UTF-8',
        'Origin': 'https://zhhq.scu.edu.cn',
        'Referer': 'https://zhhq.scu.edu.cn/account/login',
        'User-Agent': kDefaultUserAgent,
        'X-Requested-With': 'XMLHttpRequest',
      },
      body: body,
    );
    return _parseLoginAutoResponse(resp.body, resp.statusCode);
  }

  /// 解析 login/auto 的加密响应，返回 tokenKey；失败抛异常。
  String _parseLoginAutoResponse(String body, int statusCode) {
    if (statusCode == 302 ||
        statusCode == 401 ||
        statusCode == 403 ||
        body.trim().isEmpty) {
      throw const UnauthenticatedException();
    }
    final json = zhhqDecodeResponse(body);
    if (json == null) {
      _log.e(_tag, 'login/auto 响应解密失败');
      throw const UnauthenticatedException('zhhq tokenKey 获取失败');
    }
    final code = json['errorCode']?.toString() ?? '';
    final status = json['status']?.toString() ?? '';
    if (code != '0' && code.isNotEmpty && status == 'error') {
      _log.e(_tag, 'login/auto 失败: ${json['message']}');
      throw UnauthenticatedException('zhhq 登录失败: ${json['message']}');
    }
    final tokenKey = json['data']?.toString() ?? '';
    if (tokenKey.isEmpty || tokenKey.length < 16) {
      _log.e(_tag, 'login/auto 未返回有效 tokenKey');
      throw const UnauthenticatedException('zhhq tokenKey 获取失败');
    }
    _log.i(_tag, 'tokenKey acquired');
    return tokenKey;
  }

  void _applyTokenKey(CookieClient client, String tokenKey) {
    _tokenKey = tokenKey;
    // 持久化，避免下次进入/冷启动重复走慢速 SSO
    SecureStorageProvider.instance.write(key: kZhhqTokenKey, value: tokenKey);
    // 认证成功：清除失败标记，通知页面可恢复加载
    if (_authFailed) {
      _authFailed = false;
      _log.i(_tag, 'auth recovered, clearing failure flag');
    }
    if (!_ready) {
      _ready = true;
      _log.i(_tag, 'ready');
      notifyListeners();
    }
  }

  @override
  void invalidate() {
    if (_ready) _log.d(_tag, 'invalidate');
    _ready = false;
    _tokenKey = null;
    _warmUpFuture = null;
    _authFailed = false;
    // 会话失效：清除持久化 tokenKey，下次重新走 SSO
    SecureStorageProvider.instance.delete(key: kZhhqTokenKey);
  }

  @override
  void dispose() {
    _scuAuth.removeListener(_onScuAuthChanged);
    super.dispose();
  }
}
