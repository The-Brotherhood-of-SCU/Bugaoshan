import 'dart:async';

import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/settings/set_app_icon_page.dart';
import 'package:flutter/foundation.dart'
    show TargetPlatform, debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/utils/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = kDynamicIconMethodChannel;

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  testWidgets('ignores a successful icon load after disposal', (tester) async {
    // 动态图标仅在 Android 实现；测试宿主需强制为 Android 才会走 MethodChannel。
    // 注意：必须在测试体内恢复（try/finally），因为框架在 testBody 返回后
    // 立即校验 foundation debug 变量，任何 tearDown 回调都晚于该校验。
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
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
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('ignores an icon loading error after disposal', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
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
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}

Widget _testApp(Widget home) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}
