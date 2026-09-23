import 'dart:convert';
import 'dart:typed_data';

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

  test('sent binary attachments keep their original bytes', () {
    final imageBytes = Uint8List.fromList([0xff, 0xd8, 0xff, 0x00, 0x91]);
    final headers = utf8.encode(
      'Content-Type: image/jpeg\r\n'
      'Content-Transfer-Encoding: binary\r\n'
      '\r\n',
    );
    final part = MimePart()
      ..mimeData = BinaryMimeData(
        Uint8List.fromList([...headers, ...imageBytes, 0x0d, 0x0a]),
        containsHeader: true,
      )
      ..parse();

    expect(EmailService.decodeAttachmentBytes(part), imageBytes);
  });

  test('double-base64 sent attachment is decoded once more', () {
    final imageBytes = Uint8List.fromList([0xff, 0xd8, 0xff, 0x00, 0x91]);
    final encoded = base64Encode(base64Encode(imageBytes).codeUnits);
    final part = MimePart()
      ..mimeData = TextMimeData(encoded, containsHeader: false)
      ..setHeader('Content-Type', 'image/jpeg')
      ..setHeader('Content-Transfer-Encoding', 'base64')
      ..parse();

    expect(EmailService.decodeAttachmentBytes(part), imageBytes);
  });
}
