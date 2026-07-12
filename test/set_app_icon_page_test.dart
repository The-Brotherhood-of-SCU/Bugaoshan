import 'dart:async';

import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/settings/set_app_icon_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('bugaoshan/dynamic_icon');

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('ignores a successful icon load after disposal', (tester) async {
    final icons = Completer<List<dynamic>>();
    final currentIcon = Completer<String?>();
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          calls.add(call.method);
          return switch (call.method) {
            'getAvailableIcons' => icons.future,
            'getCurrentIconName' => currentIcon.future,
            _ => throw MissingPluginException(call.method),
          };
        });

    await tester.pumpWidget(_testApp(const SetAppIconPage()));
    await tester.pump();
    icons.complete(<dynamic>['old']);
    await tester.pump();
    expect(calls, ['getAvailableIcons', 'getCurrentIconName']);

    await tester.pumpWidget(_testApp(const SizedBox.shrink()));
    currentIcon.complete('old');
    await tester.pump();

    expect(tester.takeException(), isNull);
  });

  testWidgets('ignores an icon loading error after disposal', (tester) async {
    final icons = Completer<List<dynamic>>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) {
          if (call.method == 'getAvailableIcons') return icons.future;
          throw MissingPluginException(call.method);
        });

    await tester.pumpWidget(_testApp(const SetAppIconPage()));
    await tester.pump();
    await tester.pumpWidget(_testApp(const SizedBox.shrink()));

    icons.completeError(StateError('load failed'));
    await tester.pump();

    expect(tester.takeException(), isNull);
  });
}

Widget _testApp(Widget home) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}
