import 'dart:async';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/graduate_grades.dart';
import 'package:bugaoshan/pages/graduate/graduate_grades_page.dart';
import 'package:bugaoshan/providers/graduate_grades_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/api/gs_api_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await getIt.reset();
  });

  tearDown(() async {
    await getIt.reset();
  });

  group('GraduateGradesProvider', () {
    test('成功且非空：落 rows 与统计', () async {
      final provider = GraduateGradesProvider(_FakeGsApi(const [
        {'KCMC': '学术英语（中级）', 'XF': 2.0, 'DYBFZCJ': 80.0, 'SFJG': 1, 'SFYX': 1},
      ]));

      await provider.refresh();

      expect(provider.state, GraduateGradesLoadState.loaded);
      expect(provider.rows, hasLength(1));
      expect(provider.rows.single.courseName, '学术英语（中级）');
      expect(provider.stats?.courseCount, 1);
      expect(provider.stats?.weightedAverage, 80.0);
      expect(provider.errorKind, isNull);
    });

    test('成功但无成绩：loaded + stats 为 null（页面空态）', () async {
      final provider = GraduateGradesProvider(const _FakeGsApi([]));

      await provider.refresh();

      expect(provider.state, GraduateGradesLoadState.loaded);
      expect(provider.rows, isEmpty);
      expect(provider.stats, isNull);
    });

    test('未登录 / 研教务会话过期 → unauthenticated', () async {
      final provider = GraduateGradesProvider(_FakeGsApi(
        null,
        error: const UnauthenticatedException('研教务会话已过期'),
      ));

      await provider.refresh();

      expect(provider.state, GraduateGradesLoadState.error);
      expect(provider.errorKind, GraduateGradesErrorKind.unauthenticated);
      expect(provider.errorMessage, isNull);
    });

    test('接口异常 → failed 且带接口原文', () async {
      final provider = GraduateGradesProvider(_FakeGsApi(
        null,
        error: const ServiceException('研教务返回了无法解析的数据'),
      ));

      await provider.refresh();

      expect(provider.state, GraduateGradesLoadState.error);
      expect(provider.errorKind, GraduateGradesErrorKind.failed);
      expect(provider.errorMessage, '研教务返回了无法解析的数据');
    });

    test('未知错误 → failed 且无原文', () async {
      final provider = GraduateGradesProvider(
        _FakeGsApi(null, rawError: Exception('boom')),
      );

      await provider.refresh();

      expect(provider.errorKind, GraduateGradesErrorKind.failed);
      expect(provider.errorMessage, isNull);
    });

    test('loading 中重复 refresh 不重入，仅一轮状态通知', () async {
      final api = _ControllableGsApi();
      final provider = GraduateGradesProvider(api);
      var notifications = 0;
      provider.addListener(() => notifications++);

      final first = provider.refresh();
      expect(api.requests, hasLength(1));
      await provider.refresh();
      api.requests.single.complete(_gradedRows(const [
        {'KCMC': '课程A', 'XF': 2.0, 'SFJG': 1, 'SFYX': 1},
      ]));
      await first;

      expect(api.requests, hasLength(1));
      expect(provider.state, GraduateGradesLoadState.loaded);
      expect(notifications, 2);
    });

    test('clear 复位为 idle', () async {
      final provider = GraduateGradesProvider(_FakeGsApi(const [
        {'KCMC': '课程A', 'XF': 2.0, 'SFJG': 1, 'SFYX': 1},
      ]));
      await provider.refresh();

      provider.clear();

      expect(provider.state, GraduateGradesLoadState.idle);
      expect(provider.rows, isEmpty);
      expect(provider.stats, isNull);
    });

    test('ensureLoaded 与 refresh 等价', () async {
      final provider = GraduateGradesProvider(_FakeGsApi(const [
        {'KCMC': '课程A', 'XF': 2.0, 'SFJG': 1, 'SFYX': 1},
      ]));

      await provider.ensureLoaded();

      expect(provider.state, GraduateGradesLoadState.loaded);
    });

    test('debugSeedStats 注入统计视图', () {
      final provider = GraduateGradesProvider(const _FakeGsApi([]));

      provider.debugSeedStats(
        const GraduateGradesStats(
          courseCount: 8,
          totalCredit: 24,
          passedCount: 7,
          weightedAverage: 85.5,
        ),
      );

      expect(provider.state, GraduateGradesLoadState.loaded);
      expect(provider.stats?.courseCount, 8);
    });
  });

  testWidgets('已登录、接口返回空 → 空态文案', (tester) async {
    getIt.registerSingleton<GraduateGradesProvider>(
      GraduateGradesProvider(const _FakeGsApi([])),
    );
    getIt.registerSingleton<ScuAuthProvider>(_FakeScuAuthProvider());

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const GraduateGradesPage(),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(GraduateGradesPage)),
    )!;
    expect(find.text(l10n.graduateGrades), findsOneWidget);
    expect(find.text(l10n.graduateGradesEmpty), findsOneWidget);
  });

  testWidgets('注入统计后渲染四指标', (tester) async {
    final provider = GraduateGradesProvider(const _FakeGsApi([]));
    getIt.registerSingleton<GraduateGradesProvider>(provider);
    getIt.registerSingleton<ScuAuthProvider>(_FakeScuAuthProvider());

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const GraduateGradesPage(),
      ),
    );
    provider.debugSeedStats(
      const GraduateGradesStats(
        courseCount: 8,
        totalCredit: 24,
        passedCount: 7,
        weightedAverage: 85.5,
      ),
    );
    await tester.pump();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(GraduateGradesPage)),
    )!;
    expect(find.text(l10n.graduateGradesStats), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('24.0'), findsOneWidget);
    expect(find.text('85.50'), findsOneWidget);
    expect(find.text('87.5%'), findsOneWidget);
    expect(find.text(l10n.graduateStatsCourseCount), findsOneWidget);
    expect(find.text(l10n.graduateStatsTotalCredit), findsOneWidget);
    expect(find.text(l10n.graduateStatsAverage), findsOneWidget);
    expect(find.text(l10n.graduateStatsPassRate), findsOneWidget);
  });

  testWidgets('接口返回成绩行：按学期分组渲染课程明细', (tester) async {
    getIt.registerSingleton<GraduateGradesProvider>(
      GraduateGradesProvider(
        _FakeGsApi(const [
          {
            'KCMC': '学术英语（中级）',
            'KCMCYW': 'English for Academic Purpose (Intermediate)',
            'XNXQDM': '20261',
            'XNXQDM_DISPLAY': '2026年 秋季学期',
            'KCLBMC': '必修课',
            'CJ': '008',
            'CJXSZ': '免修通过',
            'CJFZDM_DISPLAY': '免修通过制',
            'DYBFZCJ': 80.0,
            'XF': 2.0,
            'SFJG': 1,
            'SFYX': 1,
            'BZSM': '免修合格',
          },
          {
            'KCMC': '自然辩证法',
            'XNXQDM': '20252',
            'XNXQDM_DISPLAY': '2025年 春季学期',
            'CJXSZ': '85',
            'XF': 3.0,
            'SFJG': 1,
            'SFYX': 1,
          },
        ]),
      ),
    );
    getIt.registerSingleton<ScuAuthProvider>(_FakeScuAuthProvider());

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const GraduateGradesPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('2026年 秋季学期'), findsOneWidget);
    expect(find.text('2025年 春季学期'), findsOneWidget);
    expect(find.text('学术英语（中级）'), findsOneWidget);
    expect(find.text('自然辩证法'), findsOneWidget);
    expect(find.text('免修通过'), findsOneWidget);
    expect(find.text('85'), findsOneWidget);
    // 备注与显示值冗余（免修合格 vs 免修通过）不重复展示；改放百分成绩。
    expect(find.text('免修合格'), findsNothing);
    expect(find.text('免修通过制'), findsNothing);
    expect(find.text('80'), findsOneWidget);
    expect(find.text('必修课'), findsOneWidget);
  });

  testWidgets('非冗余备注照常显示', (tester) async {
    getIt.registerSingleton<GraduateGradesProvider>(
      GraduateGradesProvider(
        _FakeGsApi(const [
          {
            'KCMC': '矩阵论',
            'XNXQDM': '20261',
            'XNXQDM_DISPLAY': '2026年 秋季学期',
            'CJXSZ': '85',
            'DYBFZCJ': 85.0,
            'XF': 3.0,
            'SFJG': 1,
            'SFYX': 1,
            'BZSM': '缓考',
          },
        ]),
      ),
    );
    getIt.registerSingleton<ScuAuthProvider>(_FakeScuAuthProvider());

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const GraduateGradesPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('缓考'), findsOneWidget);
    // 百分成绩与显示值相同（85 vs 85）→ 无副显示小字。
    expect(find.text('85'), findsOneWidget);
  });
}

/// rows 原始 JSON → 成绩行模型（给 Completer 放行用）。
List<GraduateGradeRow> _gradedRows(List<Map<String, dynamic>> rows) =>
    rows.map(GraduateGradeRow.fromJson).toList();

/// 一次性给固定结果的假 GsApiService：rows 传 null 时改抛 [error]。
class _FakeGsApi implements GsApiService {
  const _FakeGsApi(
    this.rows, {
    this.error,
    this.rawError,
  });

  final List<Map<String, dynamic>>? rows;
  final Object? error;
  final Object? rawError;

  @override
  Future<List<GraduateGradeRow>> fetchGrades() async {
    final error = this.error;
    if (error != null) throw error;
    final rawError = this.rawError;
    if (rawError != null) throw rawError;
    return rows!.map(GraduateGradeRow.fromJson).toList();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// 挂起式假 GsApiService：请求挂在 Completer 上由测试放行。
class _ControllableGsApi implements GsApiService {
  final requests = <Completer<List<GraduateGradeRow>>>[];

  @override
  Future<List<GraduateGradeRow>> fetchGrades() {
    final request = Completer<List<GraduateGradeRow>>();
    requests.add(request);
    return request.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeScuAuthProvider extends ChangeNotifier implements ScuAuthProvider {
  @override
  bool get isLoggedIn => true;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
