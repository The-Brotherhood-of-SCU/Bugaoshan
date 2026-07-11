import 'dart:async';

import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/academic_calendar.dart';
import 'package:bugaoshan/pages/campus/academic_calendar/academic_calendar_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

void main() {
  testWidgets('ignores list and interactive responses after disposal', (
    tester,
  ) async {
    final listResponse = Completer<http.Response>();
    final interactiveResponse = Completer<AcademicCalendarData>();
    final errors = <FlutterErrorDetails>[];
    final previousOnError = FlutterError.onError;
    FlutterError.onError = errors.add;
    addTearDown(() => FlutterError.onError = previousOnError);

    await tester.pumpWidget(
      _testApp(
        AcademicCalendarPage(
          httpGet: (_) => listResponse.future,
          interactiveDataLoader: () => interactiveResponse.future,
        ),
      ),
    );
    await tester.pump();

    await tester.pumpWidget(_testApp(const SizedBox.shrink()));
    listResponse.complete(
      http.Response('<a href="info/1101/123.htm">2025-2026</a>', 200),
    );
    interactiveResponse.complete(AcademicCalendarData(semesters: const []));
    await tester.pump();

    expect(errors, isEmpty);
  });
}

Widget _testApp(Widget home) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}
