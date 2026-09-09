import 'package:bugaoshan/services/auth/scu_exceptions.dart';

/// 登录页强特征（对大小写不敏感，body 需先转小写后再匹配）。
final RegExp _titlePattern = RegExp(r'<title[^>]*>([^<]*)</title>');
final RegExp _springSecurityLoginPattern = RegExp('/j_spring_security_check');
final RegExp _metaRefreshPattern = RegExp(
  r'''content\s*=\s*["'][^"']*url=([^"'>\s]+)''',
);
final RegExp _jsLocationRedirectPattern = RegExp(
  r'''location(?:\.(?:href|replace|assign))?\s*=?\s*\(?\s*["']([^"']+)["']''',
);
final RegExp _formActionPattern = RegExp(
  r'''<form[^>]+action\s*=\s*["']([^"']*)["']''',
);

/// URL 里的 login 必须是独立路径段/文件名（`\blogin\b`）：
/// `/login`、`/cas/login?service=…`、`login.aspx` 命中；
/// `loginStatus`、`clientLogin` 这类子串刻意不命中（issue #282）。
final RegExp _loginUrlPattern = RegExp(r'\blogin\b');

/// 判断响应 body 是否为「被踢到登录页」的落点页。
///
/// 特征按 **真实 zhjw 登录页**（2026-09 抓取样本）校准，该页具备：
/// `<title>登录</title>`、`<form action="/j_spring_security_check">`、
/// `j_username` / `j_password` 字段。任一强特征命中即视为登录页：
///
/// 1. `<title>` 明确是登录页（含「登录」或独立 login 词）；
/// 2. Spring Security 登录端点 `/j_spring_security_check`（教务系统登录表单）；
/// 3. meta refresh / JS `location` 跳转目标指向登录 URL；
/// 4. `<form action="…">` 提交到登录 URL。
///
/// 刻意 **不用** `type="password"` 做特征：修改密码等业务页同样含密码输入框。
/// 也不做裸 login 子串匹配：`loginStatus`、`clientLogin` 等业务 JS
/// 变量/链接会误伤（issue #282）。
///
/// 用于 zhjw / wfw / newservice 等服务的会话过期判定（wfw / newservice 的
/// 登录落点页尚未抓样，共用本套通用特征，其过期主信号仍是 302/401/403
/// 状态码与 JSON 业务错误码）；
/// PayApp 的登录超时页判断（`balance_query_service.dart`）带站点白名单，
/// 仍保持各自的强特征实现。
bool looksLikeLoginPage(String body) {
  final lower = body.toLowerCase();

  // 1) 标题明确是登录页（「登录」不受 toLowerCase 影响）
  final title = _titlePattern.firstMatch(lower)?.group(1);
  if (title != null &&
      (title.contains('登录') || _loginUrlPattern.hasMatch(title))) {
    return true;
  }

  // 2) Spring Security 登录表单端点（真实 zhjw 登录页的 form action）
  if (_springSecurityLoginPattern.hasMatch(lower)) {
    return true;
  }

  // 3) meta refresh / JS location 跳转到登录 URL 的短跳转页
  for (final pattern in [_metaRefreshPattern, _jsLocationRedirectPattern]) {
    for (final match in pattern.allMatches(lower)) {
      final url = match.group(1);
      if (url != null && _loginUrlPattern.hasMatch(url)) {
        return true;
      }
    }
  }

  // 4) 表单提交到登录 URL
  for (final match in _formActionPattern.allMatches(lower)) {
    final action = match.group(1);
    if (action != null &&
        action.isNotEmpty &&
        _loginUrlPattern.hasMatch(action)) {
      return true;
    }
  }

  return false;
}

/// API 请求自动重试包装。
///
/// 如果 [getClient] 或 [fn] 抛出 [UnauthenticatedException]（认证失败），
/// 重试一次。getClient 内部会检查 TTL，过期时触发 refresh（并发互斥）；
/// 如果服务端在 TTL 窗口内踢掉 session，getClient 只重做 bindSession，不主动 refresh。
/// 第二次仍失败 → UnauthenticatedException 穿透到调用方。
Future<T> retryOnUnauthenticated<T, C>(
  Future<C> Function() getClient,
  Future<T> Function(C client) fn, {
  void Function()? invalidate,
}) async {
  try {
    final client = await getClient();
    return await fn(client);
  } on UnauthenticatedException {
    invalidate?.call();
    final client = await getClient();
    return await fn(client);
  }
}
