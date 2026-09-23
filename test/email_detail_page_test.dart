import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/email/email_detail_page.dart';
import 'package:bugaoshan/services/email/email_service.dart';
import 'package:enough_mail/enough_mail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeEmailService extends EmailService {
  _FakeEmailService(this.fullMessage);

  final MimeMessage fullMessage;

  @override
  Future<MimeMessage> readMessage(MimeMessage message) async => fullMessage;
}

void main() {
  testWidgets('detail keeps the decoded envelope subject', (tester) async {
    const subject = '转发操作通知信/Auto-forward operation notification';
    final summary = MimeMessage.parseFromText(
      'From: postmaster@uni-edu.icoremail.net\r\n'
      'Subject: =?UTF-8?B?6L2s5Y+R5pON5L2c6YCa55+l5L+hL0F1dG8tZm9yd2FyZCBvcGVyYXRpb24gbm90aWZpY2F0aW9u?=\r\n'
      '\r\n',
    );
    final fullMessage = MimeMessage.parseFromText(
      'From: postmaster@uni-edu.icoremail.net\r\n'
      'Subject: garbled full-message header\r\n'
      'Content-Type: text/plain; charset=utf-8\r\n'
      '\r\n'
      'Message body',
    );

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: EmailDetailPage(
          service: _FakeEmailService(fullMessage),
          message: summary,
          subject: summary.decodeSubject()!,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(subject), findsOneWidget);
    expect(find.text('garbled full-message header'), findsNothing);
    expect(find.text('Message body'), findsOneWidget);
  });
}
