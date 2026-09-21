import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/graduate/graduate_train_plan_page.dart';
import 'package:bugaoshan/providers/graduate_train_plan_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/widgets/common/login_required_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await getIt.reset();
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('GraduateTrainPlanProvider', () {
    test('refresh：idle → loading → loaded，骨架落空态不发请求', () async {
      final provider = GraduateTrainPlanProvider();
      expect(provider.state, GraduateTrainPlanLoadState.idle);

      await provider.refresh();

      expect(provider.state, GraduateTrainPlanLoadState.loaded);
      expect(provider.errorKind, isNull);
      expect(provider.errorMessage, isNull);
    });

    test('骨架阶段连续两次 refresh 各完成一轮状态通知', () async {
      final provider = GraduateTrainPlanProvider();
      var notifications = 0;
      provider.addListener(() => notifications++);

      // 骨架 refresh 无真实 await，同步完成一轮（loading+loaded）；
      // 接线后重入守卫生效，届时补可控 Completer 版本的重入测试。
      await provider.refresh();
      await provider.refresh();

      expect(provider.state, GraduateTrainPlanLoadState.loaded);
      expect(notifications, 4);
    });

    test('clear 复位为 idle', () async {
      final provider = GraduateTrainPlanProvider();
      await provider.refresh();

      provider.clear();

      expect(provider.state, GraduateTrainPlanLoadState.idle);
    });

    test('ensureLoaded 与 refresh 等价', () async {
      final provider = GraduateTrainPlanProvider();

      await provider.ensureLoaded();

      expect(provider.state, GraduateTrainPlanLoadState.loaded);
    });
  });

  testWidgets('页面骨架：已登录、无数据显示空态', (tester) async {
    getIt.registerSingleton<GraduateTrainPlanProvider>(
      GraduateTrainPlanProvider(),
    );
    getIt.registerSingleton<ScuAuthProvider>(_FakeScuAuthProvider());

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const GraduateTrainPlanPage(),
      ),
    );
    await tester.pump();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(GraduateTrainPlanPage)),
    )!;
    expect(find.text(l10n.graduateTrainPlan), findsOneWidget);
    expect(find.text(l10n.graduateTrainPlanEmpty), findsOneWidget);
  });

  testWidgets('会话自愈失败：不抛未捕获异常，落到「请先登录」引导', (tester) async {
    // token 还在但统一认证会话过期（isLoggedIn=false、accessToken 非空、
    // 非自动登录中）→ 页面走 ScuAuth.refresh() 自愈分支；refresh 抛异常时
    // 必须被页面接住，否则 fire-and-forget 的 Future 会变成 unhandled error。
    getIt.registerSingleton<GraduateTrainPlanProvider>(
      GraduateTrainPlanProvider(),
    );
    getIt.registerSingleton<ScuAuthProvider>(_ExpiredSessionAuthProvider());
    getIt.registerSingleton<ScuAuth>(_FailingRefreshScuAuth());

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const GraduateTrainPlanPage(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.byType(LoginRequiredWidget), findsOneWidget);
  });
}

class _FakeScuAuthProvider extends ChangeNotifier implements ScuAuthProvider {
  @override
  bool get isLoggedIn => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// token 还在但统一认证会话已过期：触发页面的会话自愈分支。
class _ExpiredSessionAuthProvider extends ChangeNotifier
    implements ScuAuthProvider {
  @override
  bool get isLoggedIn => false;

  @override
  bool get isAutoLoggingIn => false;

  @override
  String? get accessToken => 'expired-token';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 自愈刷新总是失败的 ScuAuth（会话过期 + 重登失败）。
class _FailingRefreshScuAuth extends ChangeNotifier implements ScuAuth {
  @override
  Future<bool> refresh() async {
    throw const UnauthenticatedException('refresh failed');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
