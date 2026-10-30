import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/ccyl/ccyl_page.dart';
import 'package:bugaoshan/providers/ccyl_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/widgets/common/swipe_page_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// CCYL 页的导航形态：正常态是顶部 TabBar 驱动 SwipePageView，不再自建底栏
/// （#376：页面底栏会与 Home 的全局 Dock 叠成两层底栏）。
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    await getIt.reset();
  });

  void register({required bool loggedIn}) {
    getIt.registerSingleton<ScuAuthProvider>(
      _FakeScuAuthProvider(loggedIn: loggedIn),
    );
    getIt.registerSingleton<CcylProvider>(
      _FakeCcylProvider(loggedIn: loggedIn),
    );
  }

  testWidgets('正常态：顶部 TabBar + SwipePageView，无自带底栏', (tester) async {
    register(loggedIn: true);

    // 页签内的子 Tab 会在挂载时各自发起加载；本测试只关心导航骨架，
    // 假 Provider 未提供 service，子 Tab 的加载失败会自行落入错误态并
    // 打一条 ERROR 日志，属预期，不影响断言。
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CcylPage(),
        ),
      ),
    );
    await tester.pump();

    final tabBar = tester.widget<TabBar>(find.byType(TabBar));
    expect(tabBar.controller!.length, 4);
    expect(find.byType(SwipePageView), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(BottomNavigationBar), findsNothing);
  });

  testWidgets('未登录：不渲染页签，也不渲染自带底栏', (tester) async {
    register(loggedIn: false);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CcylPage(),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(TabBar), findsNothing);
    expect(find.byType(SwipePageView), findsNothing);
    expect(find.byType(NavigationBar), findsNothing);
  });
}

class _FakeScuAuthProvider extends ChangeNotifier implements ScuAuthProvider {
  _FakeScuAuthProvider({required this.loggedIn});

  final bool loggedIn;

  @override
  bool get isLoggedIn => loggedIn;

  @override
  bool get isAutoLoggingIn => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCcylProvider extends ChangeNotifier implements CcylProvider {
  _FakeCcylProvider({required this.loggedIn});

  final bool loggedIn;

  @override
  bool get isLoggedIn => loggedIn;

  @override
  String? get token => null;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
