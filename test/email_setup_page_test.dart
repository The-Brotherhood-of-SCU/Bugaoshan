import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/email/email_page_native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

void main() {
  testWidgets('mail setup shows username suffix and hides server settings', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: EmailPage(),
      ),
    );
    await tester.pumpAndSettle();

    final username = tester.widget<TextField>(find.byType(TextField).first);
    expect(username.decoration?.suffixText, '@stu.scu.edu.cn');
    expect(find.text('收件服务器（IMAP）'), findsNothing);

    await tester.tap(find.text('服务器设置（高级）'));
    await tester.pumpAndSettle();
    expect(find.text('收件服务器（IMAP）'), findsOneWidget);
  });
}
