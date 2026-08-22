import 'package:bugaoshan/utils/auth_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AuthLogRedactor', () {
    test('脱敏日志中的账号和用户标识', () {
      final redacted = AuthLogRedactor.apply(
        'login user=202612345678 userId=ccyl-user-42 username=alice',
      );

      expect(redacted, isNot(contains('202612345678')));
      expect(redacted, isNot(contains('ccyl-user-42')));
      expect(redacted, isNot(contains('alice')));
      expect(redacted, contains('user=<redacted>'));
      expect(redacted, contains('userId=<redacted>'));
      expect(redacted, contains('username=<redacted>'));
    });

    test('保留原有凭据脱敏行为', () {
      final redacted = AuthLogRedactor.apply(
        'Authorization: Bearer secret.token "password":"plain"',
      );

      expect(redacted, contains('Bearer <redacted>'));
      expect(redacted, contains('"password":"<redacted>"'));
      expect(redacted, isNot(contains('secret.token')));
      expect(redacted, isNot(contains('plain')));
    });

    test('截断 URL 查询参数中的 sp_code 和 state', () {
      final redacted = AuthLogRedactor.apply(
        'https://example.com/cb?sp_code=very-long-secret-sp-code'
        '&state=0123456789abcdef&code=shortcode',
      );

      expect(redacted, contains('sp_code=very…'));
      expect(redacted, contains('state=0123…'));
      expect(redacted, contains('code=shor…'));
      expect(redacted, isNot(contains('very-long-secret-sp-code')));
      expect(redacted, isNot(contains('0123456789abcdef')));
      expect(redacted, isNot(contains('shortcode')));
    });
  });
}
