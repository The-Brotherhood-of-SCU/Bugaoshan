/// 认证会话状态
enum AuthState {
  /// 初始状态，尚未进行鉴权
  unknown,

  /// 鉴权就绪，可正常使用
  ready,

  /// 鉴权已过期，需要刷新
  expired,

  /// 鉴权失败（非过期原因）
  error,
}
