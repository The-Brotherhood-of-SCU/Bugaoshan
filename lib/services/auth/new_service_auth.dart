import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/sso_relay_auth.dart';

/// 智慧线上服务平台（后勤 newservice）认证（第2层）
///
/// service.scu.edu.cn/newservice（一网通办新门户）通过 SCU 统一身份认证
/// （id.scu.edu.cn CAS plugin）跳转，回跳后下发会话 cookie。复用
/// [SsoRelayAuth] 手动跟随重定向链收集 cookie 的机制，与办事大厅 /
/// PayApp / 体测保持一致。
///
/// # 登录态 cookie（已通过真实抓包确认）
///
/// 登录后 service.scu.edu.cn 域下持有（与办事大厅的 vjuid 会话**相互独立**）：
/// - `process_uid` —— 用户 uid（无感认证相关接口的会话判据）
/// - `process_number` —— 学工号
///
/// SSO 链：`/newservice/api/login/cas`（302）→ id.scu.edu.cn CAS plugin
/// （带 Bearer token）→ 回跳 newservice 时 `Set-Cookie` 下发上述会话 cookie。
/// [getClient] 返回的 CookieClient 已收集这些 cookie，后续业务请求自动携带。
class NewServiceAuth extends SsoRelayAuth {
  NewServiceAuth(ScuAuth scuAuth)
    : super(
        scuAuth,
        'https://service.scu.edu.cn/newservice/api/login/cas'
        '?redirect_url=https%3A%2F%2Fservice.scu.edu.cn%2Fnewservice%2F'
        'fe%2Fsite%2Fm_passpoint%3Fplatform_id%3D31%26platform_id%3D31',
      );

  @override
  String get moduleId => 'newservice';
}
