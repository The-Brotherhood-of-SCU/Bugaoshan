import 'package:flutter/foundation.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/cookie_client.dart';

/// 微服务认证（第2层）
///
/// wfw.scu.edu.cn 通过 SCU SSO session 认证（CookieClient），
/// 与教务系统共享同一个 SSO session。
///
/// 监听 [ScuAuth] 状态变化并转发通知，Provider 可通过 addListener 感知。
class WfwAuth extends ChangeNotifier {
  final ScuAuth _scuAuth;
  WfwAuth(this._scuAuth) {
    _scuAuth.addListener(notifyListeners);
  }

  bool get isReady => _scuAuth.isReady;
  bool get isExpired => _scuAuth.isExpired;

  /// 获取已认证的 CookieClient（SSO session）。
  Future<CookieClient> getClient() => _scuAuth.getClient();

  @override
  void dispose() {
    _scuAuth.removeListener(notifyListeners);
    super.dispose();
  }
}
