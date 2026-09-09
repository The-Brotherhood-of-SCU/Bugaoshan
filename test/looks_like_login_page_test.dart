import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/services/api/api_request.dart';

void main() {
  group('looksLikeLoginPage: 正常业务页不应误判（issue #282）', () {
    test('含 loginStatus / clientLogin 等子串的选课页不命中', () {
      const body = '''
<html>
<head><title>学期理论课表</title></head>
<body>
  <script>var loginStatus = 1; function clientLogin() {}</script>
  <a href="/login?refer=%2Fstudent" class="login-link">登录</a>
  <select name="xnxdm"><option value="2025-2026-2-1">2025-2026学年2学期</option></select>
</body>
</html>
''';
      expect(looksLikeLoginPage(body), isFalse);
    });

    test('跳转到非登录路径（含 login 子串的变量/URL）不命中', () {
      const body = '''
<script>var loginUrl = '/student/loginStatus'; location.href = '?refer=loginPage';</script>
''';
      expect(looksLikeLoginPage(body), isFalse);
    });

    test('JSON 业务响应不命中', () {
      expect(looksLikeLoginPage('{"e":0,"m":"","d":{"labels":[]}}'), isFalse);
    });
  });

  group('looksLikeLoginPage: 登录页强特征应命中', () {
    test('Spring Security 登录表单端点命中（真实 zhjw 登录页特征）', () {
      const body = '''
<html><head><title>欢迎使用</title></head><body>
<form class="form-signin" action="/j_spring_security_check" method="post">
  <input type="text" name="j_username" placeholder="学号"/>
  <input type="password" name="j_password" placeholder="密码"/>
</form></body></html>
''';
      expect(looksLikeLoginPage(body), isTrue);
    });

    test('标题为「登录」命中', () {
      expect(
        looksLikeLoginPage('<html><head><title>登录超时</title></head></html>'),
        isTrue,
      );
    });

    test('标题含 login（大小写不敏感）命中', () {
      expect(
        looksLikeLoginPage('<TITLE>Login - Educational System</TITLE>'),
        isTrue,
      );
    });

    test('meta refresh 到登录路径命中', () {
      expect(
        looksLikeLoginPage(
          '<meta http-equiv="refresh" content="0;url=/login?new=true">',
        ),
        isTrue,
      );
    });

    test('JS location.href / location.replace 到登录路径命中', () {
      expect(
        looksLikeLoginPage(
          "<script>location.href = 'https://zhjw.scu.edu.cn/login?refer=x'</script>",
        ),
        isTrue,
      );
      expect(
        looksLikeLoginPage(
          "<script>document.location.replace('/cas/login?service=abc')</script>",
        ),
        isTrue,
      );
    });

    test('表单提交到登录路径命中', () {
      expect(
        looksLikeLoginPage(
          '<html><body><form action="/login">请登录</form></body></html>',
        ),
        isTrue,
      );
    });
  });

  group('looksLikeLoginPage: 含密码框的业务页不应误判', () {
    test('修改密码页（含多个密码输入框）不命中', () {
      // 密码输入框不是登录页特征：修改密码等业务页同样有（issue #282 反馈）。
      const body = '''
<html>
<head><title>修改密码</title></head>
<body>
  <form action="/student/personalInfo/passwordModify" method="post">
    <input type="password" name="oldPassword" placeholder="原密码"/>
    <input type="password" name="newPassword" placeholder="新密码"/>
    <input type="password" name="confirmPassword" placeholder="确认新密码"/>
  </form>
</body>
</html>
''';
      expect(looksLikeLoginPage(body), isFalse);
    });
  });
}
