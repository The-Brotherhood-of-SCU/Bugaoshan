import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/utils/auth_logger.dart';
import 'package:bugaoshan/widgets/common/session_expired_listener.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late ScuAuth auth;
  late AuthLogger logger;
  late ValueNotifier<Locale> locale;

  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    logger = AuthLogger();
    auth = ScuAuth(prefs, logger: logger);
    getIt.registerSingleton<ScuAuth>(auth);
    locale = ValueNotifier(const Locale('zh'));
  });

  tearDown(() async {
    await getIt.reset();
    auth.dispose();
    logger.dispose();
    locale.dispose();
  });

  Widget buildApp() => ValueListenableBuilder<Locale>(
    valueListenable: locale,
    builder: (context, value, _) => MaterialApp(
      navigatorKey: navigatorKey,
      locale: value,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) =>
          SessionExpiredListener(child: child ?? const SizedBox()),
      home: const Scaffold(body: Text('page')),
    ),
  );

  testWidgets('英文界面的过期提示和登录按钮使用英文', (tester) async {
    locale.value = const Locale('en');
    await tester.pumpWidget(buildApp());
    auth.onSessionExpired!();
    await tester.pumpAndSettle();

    expect(find.text('Session expired'), findsOneWidget);
    expect(find.text('Go to Login'), findsOneWidget);
    expect(find.text('登录会话已过期'), findsNothing);
    expect(find.text('前往登录'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('已显示的过期提示随语言切换更新正文和按钮', (tester) async {
    await tester.pumpWidget(buildApp());
    auth.onSessionExpired!();
    await tester.pumpAndSettle();
    expect(find.text('登录会话已过期'), findsOneWidget);
    expect(find.text('前往登录'), findsOneWidget);

    locale.value = const Locale('en');
    await tester.pumpAndSettle();
    expect(find.text('Session expired'), findsOneWidget);
    expect(find.text('Go to Login'), findsOneWidget);
    expect(find.text('登录会话已过期'), findsNothing);
    expect(find.text('前往登录'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);

    // 语言切换不受认证事件的 5 秒冷却限制。
    locale.value = const Locale('zh');
    await tester.pumpAndSettle();
    expect(find.text('登录会话已过期'), findsOneWidget);
    expect(find.text('前往登录'), findsOneWidget);
    expect(find.text('Session expired'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('尚在队列中的过期提示也使用切换后的语言', (tester) async {
    await tester.pumpWidget(buildApp());
    final messenger = ScaffoldMessenger.of(navigatorKey.currentContext!);
    messenger.showSnackBar(const SnackBar(content: Text('previous notice')));
    await tester.pumpAndSettle();

    auth.onSessionExpired!();
    locale.value = const Locale('en');
    await tester.pumpAndSettle();
    expect(find.text('Session expired'), findsOneWidget);
    expect(find.text('Go to Login'), findsOneWidget);
    expect(find.text('登录会话已过期'), findsNothing);
    expect(find.byType(SnackBar), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('过期提示关闭后切换语言不替换其它提示', (tester) async {
    await tester.pumpWidget(buildApp());
    auth.onSessionExpired!();
    await tester.pumpAndSettle();
    final messenger = ScaffoldMessenger.of(navigatorKey.currentContext!);
    messenger.removeCurrentSnackBar();
    await tester.pumpAndSettle();
    messenger.showSnackBar(const SnackBar(content: Text('other notice')));
    await tester.pumpAndSettle();

    locale.value = const Locale('en');
    await tester.pumpAndSettle();
    expect(find.text('other notice'), findsOneWidget);
    expect(find.text('Session expired'), findsNothing);
    expect(find.text('登录会话已过期'), findsNothing);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('监听器卸载后解除认证回调', (tester) async {
    await tester.pumpWidget(buildApp());
    expect(auth.onSessionExpired, isNotNull);

    await tester.pumpWidget(const SizedBox());
    expect(auth.onSessionExpired, isNull);
  });
}
