import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/dev/logs/log_persistence_tile.dart';
import 'package:bugaoshan/providers/app_config_provider.dart';
import 'package:bugaoshan/utils/app_logger.dart';

void main() {
  testWidgets('落盘故障和丢弃计数实时显示并使用英文翻译', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await getIt.reset();
    final config = AppConfigProvider(await SharedPreferences.getInstance());
    await config.init();
    final logger = _DiagnosticLogger();
    getIt.registerSingleton<AppConfigProvider>(config);
    getIt.registerSingleton<AppLogger>(logger);
    addTearDown(() async {
      await getIt.reset();
      logger.dispose();
    });
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: LogPersistenceTile()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Keep diagnostic logs on device'), findsOneWidget);
    expect(find.textContaining('Queued log entries dropped'), findsNothing);
    logger.dropped = 7;
    logger.unavailable = true;
    logger.e('Test', 'storage failed');
    await tester.pump();
    expect(
      find.textContaining('Queued log entries dropped: 7'),
      findsOneWidget,
    );
    expect(find.textContaining('storage denied'), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber), findsOneWidget);
  });
}

class _DiagnosticLogger extends AppLogger {
  int dropped = 0;
  bool unavailable = false;

  @override
  int get droppedWriteLines => dropped;

  @override
  bool get fileSinkUnavailable => unavailable;

  @override
  String? get fileSinkError => unavailable ? 'storage denied' : null;
}
