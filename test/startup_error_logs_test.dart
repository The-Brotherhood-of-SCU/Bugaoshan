import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/pages/startup_error_app.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/app_logger.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    await AppLog.bootstrapLogger.disableFileSink();
    AppLog.bootstrapLogger.clear();
    AppLog.e('Main', 'boot-failure', error: StateError('token=private-secret'));
  });
  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/share'),
          null,
        );
    await AppLog.bootstrapLogger.disableFileSink();
    AppLog.bootstrapLogger.clear();
    await getIt.reset();
  });

  testWidgets('DI 未装配时可复制脱敏的启动日志', (tester) async {
    tester.platformDispatcher.localeTestValue = const Locale('en');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    String? copied;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
    await tester.pumpWidget(
      const StartupErrorApp(errorMessage: 'startup stack'),
    );
    await tester.pumpAndSettle();
    expect(getIt.isRegistered<AppLogger>(), isFalse);
    await tester.tap(find.text('Copy logs'));
    await tester.pumpAndSettle();
    expect(copied, contains('boot-failure'));
    expect(copied, isNot(contains('private-secret')));
    expect(find.text('Logs copied to clipboard'), findsOneWidget);
    expect(find.text('Save logs'), findsOneWidget);
    expect(find.text('Share logs'), findsOneWidget);
  });

  for (final share in [false, true]) {
    testWidgets('DI 未装配时${share ? '分享失败仍保留已保存的日志' : '可保存历史与启动日志'}', (
      tester,
    ) async {
      tester.platformDispatcher.localeTestValue = const Locale('en');
      addTearDown(tester.platformDispatcher.clearLocaleTestValue);
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('startup_logs_test'),
      ))!;
      addTearDown(() => directory.delete(recursive: true));
      await tester.runAsync(
        () => File(
          '${directory.path}/bugaoshan.log',
        ).writeAsString('previous-failure token=old-secret'),
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('dev.fluttercommunity.plus/share'),
            (_) async {
              throw PlatformException(code: 'share-failed');
            },
          );
      await tester.pumpWidget(StartupErrorApp(logExportDirectory: directory));
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => tester.tap(find.text(share ? 'Share logs' : 'Save logs')),
      );
      for (var i = 0; i < 100; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
        if (find
            .textContaining(
              share ? 'Could not share logs' : 'Log snapshot saved',
            )
            .evaluate()
            .isNotEmpty) {
          break;
        }
      }
      expect(
        find.textContaining(
          share ? 'Could not share logs' : 'Log snapshot saved',
        ),
        findsOneWidget,
      );
      final content = await tester.runAsync(() async {
        final files = await directory
            .list()
            .where(
              (file) => file is File && file.path.contains('bugaoshan-export-'),
            )
            .toList();
        expect(files, hasLength(1));
        return (files.single as File).readAsString();
      });
      expect(content, contains('previous-failure'));
      expect(content, contains('boot-failure'));
      expect(content, isNot(contains('old-secret')));
      expect(content, isNot(contains('private-secret')));
      expect(getIt.isRegistered<AppLogger>(), isFalse);
    });
  }
}
