class SCUUserInfo {
  final String majorName; // 培养方案名称
  final String majorCode; // 培养方案代码
  final String photoUrl; // 头像 URL（需要带 cookie 请求）

  const SCUUserInfo({
    required this.majorName,
    required this.majorCode,
    required this.photoUrl,
  });
}
