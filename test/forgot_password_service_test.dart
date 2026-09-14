import 'dart:convert';

import 'package:bugaoshan/services/api/forgot_password_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('ForgotPasswordService.fetchCaptcha', () {
    test('解析验证码图片与 code，请求携带 _enterprise_id', () async {
      Uri? capturedUrl;
      final service = ForgotPasswordService(
        clientFactory: () => MockClient((request) async {
          capturedUrl = request.url;
          return http.Response(
            jsonEncode({
              'code': 200,
              'data': {
                'captcha': 'data:image/png;base64,iVBORw0KGgo=',
                'code': 'cap-code-9',
              },
            }),
            200,
          );
        }),
      );

      final captcha = await service.fetchCaptcha();

      expect(captcha.code, 'cap-code-9');
      expect(captcha.captchaBase64, contains('base64'));
      expect(capturedUrl!.host, 'id.scu.edu.cn');
      expect(capturedUrl!.path, '/api/public/bff/v1.2/one_time_login/captcha');
      expect(capturedUrl!.queryParameters['_enterprise_id'], 'scdx');
    });

    test('缺少 data 字段时抛出业务异常', () async {
      final service = ForgotPasswordService(
        clientFactory: () => MockClient(
          (request) async => http.Response(jsonEncode({'code': 200}), 200),
        ),
      );

      await expectLater(
        service.fetchCaptcha(),
        throwsA(isA<ForgotPasswordException>()),
      );
    });
  });

  group('ForgotPasswordService.verifyUser', () {
    test('成功响应解析联系方式与 sToken，请求体携带图形验证码字段', () async {
      Uri? capturedUrl;
      Map<String, dynamic>? capturedBody;
      final service = ForgotPasswordService(
        clientFactory: () => MockClient((request) async {
          capturedUrl = request.url;
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            jsonEncode({
              'code': 200,
              'message': 'success',
              'data': {
                'phone': '18512341418',
                'email': '30xxxxxx@qq.com',
                'sToken': 'stoken-abc',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );

      final info = await service.verifyUser(
        username: '2023123456',
        captchaText: 'ab12',
        captchaCode: 'cap-code-1',
      );

      expect(info.phone, '18512341418');
      expect(info.email, '30xxxxxx@qq.com');
      expect(info.sToken, 'stoken-abc');
      expect(info.hasPhone, isTrue);
      expect(info.hasEmail, isTrue);
      expect(capturedUrl!.host, 'id.scu.edu.cn');
      expect(
        capturedUrl!.path,
        '/api/public/bff/v1.2/forgot_password/verify_user',
      );
      expect(capturedUrl!.queryParameters['_enterprise_id'], 'scdx');
      expect(capturedBody!['username'], '2023123456');
      expect(capturedBody!['captcha'], 'ab12');
      expect(capturedBody!['captchaCode'], 'cap-code-1');
    });

    test('success 字段格式的响应同样视为成功', () async {
      final service = ForgotPasswordService(
        clientFactory: () => MockClient((request) async {
          return http.Response(
            jsonEncode({
              'success': true,
              'data': {'phone': '18512341418', 'sToken': 'st'},
            }),
            200,
          );
        }),
      );

      final info = await service.verifyUser(
        username: 'u',
        captchaText: '1',
        captchaCode: 'c',
      );
      expect(info.sToken, 'st');
    });

    test('业务错误码（400 验证码错误）抛出 ForgotPasswordException', () async {
      final service = ForgotPasswordService(
        clientFactory: () => MockClient((request) async {
          return http.Response(
            jsonEncode({'code': 400, 'message': '验证码错误'}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      await expectLater(
        service.verifyUser(username: 'u', captchaText: 'bad', captchaCode: 'c'),
        throwsA(
          isA<ForgotPasswordException>()
              .having((e) => e.message, 'message', '验证码错误')
              .having((e) => e.businessCode, 'businessCode', 400),
        ),
      );
    });

    test('HTTP 500 且响应非 JSON 时抛出带状态码的异常', () async {
      final service = ForgotPasswordService(
        clientFactory: () => MockClient(
          (request) async => http.Response('<html>gateway error</html>', 500),
        ),
      );

      await expectLater(
        service.verifyUser(username: 'u', captchaText: '1', captchaCode: 'c'),
        throwsA(
          isA<ForgotPasswordException>().having(
            (e) => e.businessCode,
            'businessCode',
            500,
          ),
        ),
      );
    });

    test('账户未绑定任何联系方式时报错', () async {
      final service = ForgotPasswordService(
        clientFactory: () => MockClient((request) async {
          return http.Response(
            jsonEncode({
              'code': 200,
              'data': {'sToken': 'st'},
            }),
            200,
          );
        }),
      );

      await expectLater(
        service.verifyUser(username: 'u', captchaText: '1', captchaCode: 'c'),
        throwsA(isA<ForgotPasswordException>()),
      );
    });
  });

  group('ForgotPasswordService 验证码步骤', () {
    test('sendVerifyCode 短信渠道请求体 type=phone 且携带 sToken', () async {
      Map<String, dynamic>? capturedBody;
      final service = ForgotPasswordService(
        clientFactory: () => MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'code': 200}), 200);
        }),
      );

      await service.sendVerifyCode(
        username: 'u',
        channel: ResetChannel.sms,
        sToken: 'st',
      );
      expect(capturedBody!['type'], 'phone');
      expect(capturedBody!['sToken'], 'st');
      expect(capturedBody!['username'], 'u');
    });

    test('sendVerifyCode 邮件渠道请求体 type=email', () async {
      Map<String, dynamic>? capturedBody;
      final service = ForgotPasswordService(
        clientFactory: () => MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'code': 200}), 200);
        }),
      );

      await service.sendVerifyCode(
        username: 'u',
        channel: ResetChannel.email,
        sToken: 'st',
      );
      expect(capturedBody!['type'], 'email');
    });

    test('verifyCode 返回重置 token', () async {
      final service = ForgotPasswordService(
        clientFactory: () => MockClient((request) async {
          return http.Response(
            jsonEncode({
              'code': 200,
              'data': {'token': 'reset-token-1'},
            }),
            200,
          );
        }),
      );

      final token = await service.verifyCode(
        username: 'u',
        channel: ResetChannel.sms,
        code: '123456',
        sToken: 'st',
      );
      expect(token, 'reset-token-1');
    });
  });

  group('ForgotPasswordService.submitNewPassword', () {
    test('短信渠道按 phone 字段回传账户名，携带 password/rePassword/token', () async {
      Map<String, dynamic>? capturedBody;
      final service = ForgotPasswordService(
        clientFactory: () => MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'code': 200}), 200);
        }),
      );

      await service.submitNewPassword(
        username: '18512341418',
        channel: ResetChannel.sms,
        token: 't',
        password: 'NewPass@123',
      );
      expect(capturedBody!['phone'], '18512341418');
      expect(capturedBody!.containsKey('email'), isFalse);
      expect(capturedBody!['password'], 'NewPass@123');
      expect(capturedBody!['rePassword'], 'NewPass@123');
      expect(capturedBody!['token'], 't');
    });

    test('邮件渠道按 email 字段回传账户名', () async {
      Map<String, dynamic>? capturedBody;
      final service = ForgotPasswordService(
        clientFactory: () => MockClient((request) async {
          capturedBody = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(jsonEncode({'code': 200}), 200);
        }),
      );

      await service.submitNewPassword(
        username: '30@qq.com',
        channel: ResetChannel.email,
        token: 't',
        password: 'NewPass@123',
      );
      expect(capturedBody!['email'], '30@qq.com');
      expect(capturedBody!.containsKey('phone'), isFalse);
    });

    test('密码策略错误透出服务端 message', () async {
      final service = ForgotPasswordService(
        clientFactory: () => MockClient((request) async {
          return http.Response(
            jsonEncode({'code': 400, 'message': 'password.policy'}),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      await expectLater(
        service.submitNewPassword(
          username: 'u',
          channel: ResetChannel.sms,
          token: 't',
          password: 'weak',
        ),
        throwsA(
          isA<ForgotPasswordException>().having(
            (e) => e.message,
            'message',
            'password.policy',
          ),
        ),
      );
    });
  });

  group('ResetAccountInfo 脱敏', () {
    test('maskedPhone 保留前3后4', () {
      expect(ResetAccountInfo.maskedPhone('18512341418'), '185****1418');
      expect(ResetAccountInfo.maskedPhone('123456'), '123456');
    });

    test('maskedEmail 保留@前前2位与域名', () {
      expect(
        ResetAccountInfo.maskedEmail('3012345678@qq.com'),
        '30****@qq.com',
      );
      expect(ResetAccountInfo.maskedEmail('ab@qq.com'), 'ab****@qq.com');
      expect(ResetAccountInfo.maskedEmail('a@qq.com'), 'a****@qq.com');
      expect(ResetAccountInfo.maskedEmail('not-an-email'), 'not-an-email');
    });
  });
}
