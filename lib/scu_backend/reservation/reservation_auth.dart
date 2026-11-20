import 'package:bugaoshan/scu_backend/core/scu_auth.dart';
import 'package:bugaoshan/scu_backend/core/sso_relay_auth.dart';
import 'package:bugaoshan/utils/constants.dart';

/// 预约系统认证（第2层）。
///
/// `service.scu.edu.cn/reservation` 与办事大厅同域但**会话独立**：
/// 它走自己的 CAS 入口 `/reservation/api/login/main`，回跳
/// `/reservation/api/login/cas` 后下发 `reservation_uid`（办事大厅是
/// `vjuid`）。因此不能复用 [ServiceAuth] 的会话，必须单独中继一次。
///
/// 复用 [SsoRelayAuth] 的「跟随重定向链、按域收集 Set-Cookie」机制，
/// 返回的 CookieClient 已带上 `reservation_uid`，后续业务请求自动携带。
class ReservationAuth extends SsoRelayAuth {
  ReservationAuth(ScuAuth scuAuth) : super(scuAuth, kReservationSsoUrl);

  @override
  String get moduleId => 'reservation';
}
