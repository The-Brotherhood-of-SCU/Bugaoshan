import 'package:bugaoshan/utils/app_logger.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LogRedactor', () {
    test('脱敏日志中的账号和用户标识', () {
      final redacted = LogRedactor.apply(
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
      final redacted = LogRedactor.apply(
        'Authorization: Bearer secret.token "password":"plain"',
      );

      expect(redacted, contains('Bearer <redacted>'));
      expect(redacted, contains('"password":"<redacted>"'));
      expect(redacted, isNot(contains('secret.token')));
      expect(redacted, isNot(contains('plain')));
    });
  });
}
