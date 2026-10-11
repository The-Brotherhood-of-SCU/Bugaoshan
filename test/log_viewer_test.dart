import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/pages/dev/auth_log/auth_log_viewer_page.dart';
import 'package:bugaoshan/utils/app_log.dart';
import 'package:bugaoshan/utils/auth_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AuthLogger logger;
  setUp(() async {
    await getIt.reset();
    logger = AuthLogger();
    getIt.registerSingleton<AuthLogger>(logger);
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
    await tester.pumpWidget(const MaterialApp(home: AuthLogViewerPage()));
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
    await tester.pumpWidget(const MaterialApp(home: AuthLogViewerPage()));
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
  });
}
