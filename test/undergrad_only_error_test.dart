import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/widgets/common/retryable_error_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 线 A 回归：本科教务在统一认证已建立仍踢回登录页（undergradOnly）时，
/// 错误映射与渲染给出针对性提示、不放永远无效的重试按钮。
void main() {
  group('zhjwAuthErrorType 映射', () {
    test('带 undergradOnly 标记 → undergradOnly', () {
      expect(
        zhjwAuthErrorType(
          const UnauthenticatedException('本科教务会话未建立', true),
        ),
        LoadErrorType.undergradOnly,
      );
    });

    test('普通未登录异常沿用调用方原分类（默认 sessionExpired）', () {
      expect(
        zhjwAuthErrorType(const UnauthenticatedException()),
        LoadErrorType.sessionExpired,
      );
    });

    test('exam_plan 场景：未标记时回落 notLoggedIn', () {
      expect(
        zhjwAuthErrorType(
          const UnauthenticatedException(),
          fallback: LoadErrorType.notLoggedIn,
        ),
        LoadErrorType.notLoggedIn,
      );
      expect(
        zhjwAuthErrorType(
          const UnauthenticatedException('本科教务会话未建立', true),
          fallback: LoadErrorType.notLoggedIn,
        ),
        LoadErrorType.undergradOnly,
      );
    });
  });

  group('classifyZhjwSessionFailure 打标证据规则', () {
    test('空 body 不打标（夜间关站/偶发空响应不能误导本科账号）', () {
      final failure = ZhjwApiService.classifyZhjwSessionFailure('', 200);
      expect(failure, isNotNull);
      expect(failure!.undergradOnly, isFalse);
      expect(failure.message, '教务系统返回了空响应');
    });

    test('空白 body 同样不打标', () {
      final failure = ZhjwApiService.classifyZhjwSessionFailure(
        '  \n\t',
        200,
      );
      expect(failure, isNotNull);
      expect(failure!.undergradOnly, isFalse);
    });

    test('302 重定向与登录页 HTML 是打标强证据', () {
      expect(
        ZhjwApiService.classifyZhjwSessionFailure('', 302)!.undergradOnly,
        isTrue,
      );
      final loginPage = ZhjwApiService.classifyZhjwSessionFailure(
        '<html><body><form action="/login">请登录</form></body></html>',
        200,
      );
      expect(loginPage, isNotNull);
      expect(loginPage!.undergradOnly, isTrue);
    });

    test('正常业务页返回 null', () {
      expect(
        ZhjwApiService.classifyZhjwSessionFailure(
          '<html><body>第 1 周</body></html>',
          200,
        ),
        isNull,
      );
    });
  });

  group('refreshFailureMessage（有缓存刷新失败提示文案）', () {
    final l10n = lookupAppLocalizations(const Locale('zh'));

    test('undergradOnly → 针对性指引而非通用刷新失败', () {
      expect(
        refreshFailureMessage(
          LoadErrorType.undergradOnly,
          l10n,
          fallback: l10n.gradesRefreshFailed,
        ),
        l10n.undergradDataOnly,
      );
    });

    test('sessionExpired → 会话过期', () {
      expect(
        refreshFailureMessage(
          LoadErrorType.sessionExpired,
          l10n,
          fallback: l10n.gradesRefreshFailed,
        ),
        l10n.sessionExpired,
      );
    });

    test('其余类型一律走调用方通用文案', () {
      expect(
        refreshFailureMessage(
          LoadErrorType.loadFailed,
          l10n,
          fallback: '通用失败',
        ),
        '通用失败',
      );
      expect(
        refreshFailureMessage(
          LoadErrorType.networkError,
          l10n,
          fallback: l10n.gradesRefreshFailed,
        ),
        l10n.gradesRefreshFailed,
      );
    });
  });

  group('RetryableErrorWidget 渲染', () {
    Widget wrap(Widget child) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('zh'),
      home: Scaffold(body: child),
    );

    testWidgets('undergradOnly 显示针对性提示，重试与前往登录按钮齐备', (tester) async {
      await tester.pumpWidget(
        wrap(
          const RetryableErrorWidget(
            errorType: LoadErrorType.undergradOnly,
            onRetry: _noRetry,
          ),
        ),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(RetryableErrorWidget)),
      )!;
      expect(find.text(l10n.undergradDataOnly), findsOneWidget);
      expect(find.text(l10n.retry), findsOneWidget);
      expect(find.text(l10n.goToLogin), findsOneWidget);
    });

    testWidgets('其它错误类型仍显示重试按钮', (tester) async {
      await tester.pumpWidget(
        wrap(
          const RetryableErrorWidget(
            errorType: LoadErrorType.sessionExpired,
            onRetry: _noRetry,
          ),
        ),
      );
      final l10n = AppLocalizations.of(
        tester.element(find.byType(RetryableErrorWidget)),
      )!;
      expect(find.text(l10n.retry), findsOneWidget);
    });
  });
}

void _noRetry() {}
