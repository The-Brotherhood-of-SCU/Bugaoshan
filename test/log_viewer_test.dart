import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/dev/logs/log_viewer_page.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/app_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap({Locale locale = const Locale('zh')}) => MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const LogViewerPage(),
  );
  late AppLogger logger;
  setUp(() async {
    await getIt.reset();
    logger = AppLogger();
    getIt.registerSingleton<AppLogger>(logger);
  });
  tearDown(() async => getIt.reset());

  testWidgets('分类切换可分别查看认证链和业务错误', (tester) async {
    logger.i('Auth', '认证成功');
    AppLog.i('App', '业务成功');
    AppLog.e(
      'App',
      '业务失败',
      error: StateError('失败详情'),
      stackTrace: StackTrace.fromString('test stack'),
    );
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    await tester.tap(find.text('业务错误'));
    await tester.pump();
    expect(find.text('业务失败'), findsOneWidget);
    expect(find.text('认证成功'), findsNothing);
    expect(find.text('业务成功'), findsNothing);
    await tester.tap(find.text('错误堆栈'));
    await tester.pumpAndSettle();
    expect(find.text('test stack'), findsOneWidget);
    await tester.tap(find.text('认证日志'));
    await tester.pump();
    expect(find.text('认证成功'), findsOneWidget);
    expect(find.text('业务失败'), findsNothing);
  });

  testWidgets('新 tag 实时更新，缓冲清空不会造成下拉框异常', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    AppLog.e('NewTag', '新错误');
    await tester.pump();
    expect(find.text('新错误'), findsOneWidget);
    final dropdown = tester.widget<DropdownButton<String?>>(
      find.byType(DropdownButton<String?>),
    );
    expect(dropdown.items!.any((item) => item.value == 'NewTag'), isTrue);
    dropdown.onChanged!('NewTag');
    await tester.pump();
    logger.clear();
    await tester.pump();
    expect(tester.takeException(), isNull);
    AppLog.e('AnotherTag', '清空后的错误');
    await tester.pump();
    expect(find.text('清空后的错误'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButton<String?>>(find.byType(DropdownButton<String?>))
          .value,
      isNull,
    );
  });

  testWidgets('选中 tag 被环形缓冲淘汰后显示其余新日志', (tester) async {
    await getIt.unregister<AppLogger>();
    logger = AppLogger(capacity: 2);
    getIt.registerSingleton<AppLogger>(logger);
    logger.e('Old', '旧错误');
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();
    tester
        .widget<DropdownButton<String?>>(find.byType(DropdownButton<String?>))
        .onChanged!('Old');
    await tester.pump();
    logger.e('New', '新错误 1');
    logger.e('New', '新错误 2');
    await tester.pump();
    expect(find.text('新错误 1'), findsOneWidget);
    expect(find.text('新错误 2'), findsOneWidget);
    expect(
      tester
          .widget<DropdownButton<String?>>(find.byType(DropdownButton<String?>))
          .value,
      isNull,
    );
  });

  testWidgets('英文界面包含筛选、操作和清空提示的翻译', (tester) async {
    await tester.pumpWidget(wrap(locale: const Locale('en')));
    await tester.pumpAndSettle();
    expect(find.text('Runtime logs'), findsOneWidget);
    expect(find.text('Authentication'), findsOneWidget);
    expect(find.text('Business errors'), findsOneWidget);
    expect(find.byTooltip('Save and share'), findsOneWidget);
    await tester.tap(find.byTooltip('Clear memory logs'));
    await tester.pumpAndSettle();
    expect(find.text('Clear logs in memory?'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}
