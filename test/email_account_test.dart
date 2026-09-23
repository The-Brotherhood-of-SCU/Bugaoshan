import 'package:bugaoshan/services/email/email_account.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mail username is converted to the complete student address', () {
    expect(
      EmailAccount.addressForUsername(' 2026123456 '),
      '2026123456@stu.scu.edu.cn',
    );
  });

  test('saved student addresses display only their username', () {
    expect(
      EmailAccount.usernameFromAddress('2026123456@stu.scu.edu.cn'),
      '2026123456',
    );
    expect(
      EmailAccount.usernameFromAddress('2026123456@STU.SCU.EDU.CN'),
      '2026123456',
    );
  });
}
