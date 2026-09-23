import 'package:bugaoshan/services/email/email_service.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('HTML-only mail is converted to safe plain text', () {
    final message = MimeMessage.parseFromText(
      'From: sender@example.com\r\n'
      'Subject: HTML mail\r\n'
      'MIME-Version: 1.0\r\n'
      'Content-Type: text/html; charset=utf-8\r\n'
      '\r\n'
      '<html><body><script>secret()</script><style>body{display:none}</style>'
      '<p>Visible &amp; readable</p><p>Second paragraph</p></body></html>',
    );

    final text = EmailService.plainText(message);
    expect(text, contains('Visible & readable'));
    expect(text, contains('Visible & readable\nSecond paragraph'));
    expect(text, isNot(contains('secret()')));
    expect(text, isNot(contains('display:none')));
  });
}
