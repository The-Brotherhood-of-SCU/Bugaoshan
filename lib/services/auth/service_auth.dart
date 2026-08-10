import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/sso_relay_auth.dart';

/// 网上办事大厅认证（第2层）
///
/// service.scu.edu.cn 通过 SCU 统一身份认证（id.scu.edu.cn CAS）跳转，
/// 回跳后下发会话 cookie。复用 [SsoRelayAuth] 手动跟随重定向链收集
/// cookie 的机制，与 PayApp / 体测保持一致。
///
/// # 登录态 cookie（已通过真实抓包确认）
///
/// 登录后 service.scu.edu.cn 域下持有：
/// - `PHPSESSID=ST-<ticket>` —— CAS 票据直接作为 PHP 会话 id
/// - `vjuid` —— 用户 uid（`checkLogin()` 判据）
/// - `vjvd` —— 校验值
/// - `vt` —— 时间戳
///
/// SSO 链：`/api/login/main`（301）→ `/site/login/cas-login`（302）→
/// id.scu.edu.cn CAS plugin（带 Bearer token）→ 回跳 service 时
/// `Set-Cookie` 下发上述会话 cookie。[getClient] 返回的 CookieClient
/// 已收集这些 cookie，后续业务请求自动携带。
class ServiceAuth extends SsoRelayAuth {
  ServiceAuth(ScuAuth scuAuth)
    : super(
        scuAuth,
        'https://service.scu.edu.cn/api/login/main'
        '?redirect_url=https%3A%2F%2Fservice.scu.edu.cn%2Fv2%2Fmatter%2F',
      );

  @override
  String get moduleId => 'service';
}
