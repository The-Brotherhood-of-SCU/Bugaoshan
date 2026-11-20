import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/course.dart';
import 'package:bugaoshan/models/graduate_grades.dart';
import 'package:bugaoshan/models/graduate_train_plan.dart';
import 'package:bugaoshan/pages/graduate/graduate_grades_page.dart';
import 'package:bugaoshan/pages/graduate/graduate_train_plan_page.dart';
import 'package:bugaoshan/pages/graduate/schedule_import_page.dart';
import 'package:bugaoshan/providers/graduate_grades_provider.dart';
import 'package:bugaoshan/providers/graduate_train_plan_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/scu_backend/gs/gs_api_service.dart';
import 'package:bugaoshan/scu_backend/core/scu_auth.dart';
import 'package:bugaoshan/scu_backend/core/scu_exceptions.dart';
import 'package:bugaoshan/widgets/route/router_utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// #331：宽屏 / 横屏下 [popupOrNavigate] 用 `Dialog` + 内层 `Navigator` 承载
/// 页面，页面里的关闭按钮必须关闭整个弹窗，而不是只弹掉内层路由留下遮罩。
void main() {
  setUp(() async {
    await getIt.reset();
  });

  tearDown(() async {
    await getIt.reset();
  });

  /// 横屏尺寸（1200×800）触发 `popupOrNavigate` 的弹窗分支。
  Future<void> pumpHost(WidgetTester tester, {required Widget page}) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => popupOrNavigate(context, page),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('研究生成绩页：弹窗内点关闭会关掉整个弹窗（#331）', (tester) async {
    getIt.registerSingleton<GraduateGradesProvider>(
      GraduateGradesProvider(_EmptyGradesApi()),
    );
    getIt.registerSingleton<ScuAuthProvider>(_LoggedInAuth());

    await pumpHost(tester, page: const GraduateGradesPage());

    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('研究生培养进度页：弹窗内点关闭会关掉整个弹窗（#331）', (tester) async {
    getIt.registerSingleton<GraduateTrainPlanProvider>(
      GraduateTrainPlanProvider(_FailingTrainPlanApi()),
    );
    getIt.registerSingleton<ScuAuthProvider>(_LoggedInAuth());

    await pumpHost(tester, page: const GraduateTrainPlanPage());

    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('研究生课表导入页：弹窗内点关闭会关掉整个弹窗（#331）', (tester) async {
    getIt.registerSingleton<GsApiService>(_FailingScheduleApi());

    await pumpHost(tester, page: const GraduateScheduleImportPage());

    expect(find.byType(Dialog), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('手机竖屏直接 push 的页面：关闭仍然正常返回', (tester) async {
    getIt.registerSingleton<GraduateGradesProvider>(
      GraduateGradesProvider(_EmptyGradesApi()),
    );
    getIt.registerSingleton<ScuAuthProvider>(_LoggedInAuth());

    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () =>
                    popupOrNavigate(context, const GraduateGradesPage()),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(GraduateGradesPage), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    expect(find.byType(GraduateGradesPage), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('弹窗内还压着上一页时：只退出当前页，保留弹窗与下层页面', (tester) async {
    // 复现场景：课表页的导入方式 sheet 打开 ImportSchedulePage（占住弹窗
    // 初始路由），再从中进入研究生导入页。此时关闭研究生页应回到
    // ImportSchedulePage，而不是把整个 Dialog 弹掉、连它的状态一起丢。
    getIt.registerSingleton<GraduateGradesProvider>(
      GraduateGradesProvider(_EmptyGradesApi()),
    );
    getIt.registerSingleton<ScuAuthProvider>(_LoggedInAuth());

    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigatorKey,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => popupOrNavigate(
                  context,
                  Builder(
                    builder: (inner) => Scaffold(
                      body: Center(
                        child: TextButton(
                          onPressed: () => popupOrNavigate(
                            inner,
                            const GraduateGradesPage(),
                          ),
                          child: const Text('open-graduate'),
                        ),
                      ),
                    ),
                  ),
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(Dialog), findsOneWidget);

    await tester.tap(find.text('open-graduate'));
    await tester.pumpAndSettle();
    expect(find.byType(GraduateGradesPage), findsOneWidget);

    await tester.tap(find.byIcon(Icons.close));
    await tester.pumpAndSettle();

    // 只退回弹窗内的上一层，Dialog 仍在。
    expect(find.byType(GraduateGradesPage), findsNothing);
    expect(find.text('open-graduate'), findsOneWidget);
    expect(find.byType(Dialog), findsOneWidget);
  });
}

// ── 假实现（不发网络请求）──────────────────────────────────────────────

class _EmptyGradesApi implements GsApiService {
  @override
  Future<List<GraduateGradeRow>> fetchGrades() async => const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingTrainPlanApi implements GsApiService {
  @override
  Future<GraduateTrainPlanInfo> fetchTrainPlanInfo() async =>
      throw const ServiceException('测试失败');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FailingScheduleApi implements GsApiService {
  @override
  Future<({List<Course> courses, List<TimeSlot>? timeSlots})> fetchSchedule({
    String? xnxqdm,
  }) async => throw const UnauthenticatedException('研教务会话已过期');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 显式实现 [ScuAuthProvider] 的全部成员。
///
/// 刻意不用 `noSuchMethod` 兜底：页面将来多读一个成员时，这里会编译失败，
/// 而不是等到运行时才抛 `NoSuchMethodError`。
class _LoggedInAuth extends ChangeNotifier implements ScuAuthProvider {
  @override
  bool get isLoggedIn => true;

  @override
  bool get isAutoLoggingIn => false;

  @override
  bool get isExpired => false;

  @override
  String? get accessToken => 'test-token';

  @override
  String? get userRealname => '测试用户';

  @override
  String? get userNumber => '202600000';

  @override
  void setUserInfo(String? realname, String? number) {}

  @override
  Future<void> init() async {}

  @override
  Future<void> login({
    required String username,
    required String password,
    required String captchaCode,
    required String captchaText,
  }) async {}

  @override
  Future<void> logout() async {}

  @override
  Future<CaptchaResult> fetchCaptcha() async =>
      const CaptchaResult(code: '', captchaBase64: '');

  @override
  Future<Map<String, String>?> getSavedCredentials() async => null;

  @override
  Future<void> saveCredentials(String username, String password) async {}

  @override
  Future<void> clearCredentials() async {}

  @override
  Future<bool> isAutoLoginEnabled() async => false;

  @override
  Future<void> setAutoLogin(bool enabled) async {}

  @override
  Future<bool> autoLogin() async => false;
}
