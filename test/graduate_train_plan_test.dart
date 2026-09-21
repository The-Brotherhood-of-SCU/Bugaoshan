import 'dart:async';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/models/graduate_grades.dart';
import 'package:bugaoshan/models/graduate_train_plan.dart';
import 'package:bugaoshan/pages/graduate/graduate_train_plan_page.dart';
import 'package:bugaoshan/providers/graduate_train_plan_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/api/gs_api_service.dart';
import 'package:bugaoshan/services/auth/scu_auth.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:bugaoshan/utils/graduate_train_plan_progress.dart';
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

  group('GraduateTrainPlanProvider 数据链', () {
    test('refresh：四个接口依次完成 → loaded 且归并就位', () async {
      final api = _ImmediateGsApiService();
      final provider = GraduateTrainPlanProvider(api);
      expect(provider.state, GraduateTrainPlanLoadState.idle);

      await provider.refresh();

      expect(provider.state, GraduateTrainPlanLoadState.loaded);
      expect(provider.errorKind, isNull);
      expect(provider.errorMessage, isNull);
      expect(provider.info?.famc, '2026级学术学位0817 测试2026级研究生培养方案');
      expect(provider.creditStats?.requiredCredits, 24.0);
      // 已修：数理方法（必修课，方案内）3 + 化学反应工程进展（方案外）3 = 6
      expect(provider.earnedTotal, 6.0);
      expect(provider.sections, hasLength(4));
      final required = provider.sections.singleWhere((s) => s.title == '必修课');
      expect(required.earnedCredits, 3.0);
      expect(required.requiredCredits, 14.0);
      expect(required.rows.single.courseName, '数理方法');
      final outOfPlan = provider.sections.last;
      expect(outOfPlan.title, '方案外');
      expect(outOfPlan.earnedCredits, 3.0);
    });

    test('重入守卫：loading 中二次 refresh 不发新请求', () async {
      final api = _QueuedGsApiService();
      final provider = GraduateTrainPlanProvider(api);

      final first = provider.refresh();
      final second = provider.refresh();

      expect(api.infoCalls, 1);
      expect(api.statsCalls, 0);
      api.autoCompleteRest = true;
      api.completeHeldInfo();
      await first;
      await second;

      expect(provider.state, GraduateTrainPlanLoadState.loaded);
      expect(api.infoCalls, 1);
      expect(api.statsCalls, 1);
      expect(api.coursesCalls, 1);
      expect(api.gradesCalls, 1);
    });

    test('UnauthenticatedException → unauthenticated 态', () async {
      final api = _ThrowingGsApiService(
        infoError: const UnauthenticatedException('研教务会话已过期'),
      );
      final provider = GraduateTrainPlanProvider(api);

      await provider.refresh();

      expect(provider.state, GraduateTrainPlanLoadState.error);
      expect(provider.errorKind, GraduateTrainPlanErrorKind.unauthenticated);
      expect(provider.errorMessage, isNull);
    });

    test('其它异常 → failed 态且带原文', () async {
      final api = _ThrowingGsApiService(infoError: Exception('解析失败'));
      final provider = GraduateTrainPlanProvider(api);

      await provider.refresh();

      expect(provider.state, GraduateTrainPlanLoadState.error);
      expect(provider.errorKind, GraduateTrainPlanErrorKind.failed);
      expect(provider.errorMessage, contains('解析失败'));
    });

    test('clear 复位数据与状态', () async {
      final provider = GraduateTrainPlanProvider(_ImmediateGsApiService());
      await provider.refresh();

      provider.clear();

      expect(provider.state, GraduateTrainPlanLoadState.idle);
      expect(provider.info, isNull);
      expect(provider.creditStats, isNull);
      expect(provider.sections, isEmpty);
      expect(provider.earnedTotal, 0.0);
    });

    test('ensureLoaded 与 refresh 等价', () async {
      final provider = GraduateTrainPlanProvider(_ImmediateGsApiService());

      await provider.ensureLoaded();

      expect(provider.state, GraduateTrainPlanLoadState.loaded);
      expect(provider.info, isNotNull);
    });
  });

  group('graduateTrainPlanSections 归并口径', () {
    test('及格且有效才算已修；重修同课只计首条及格记录的学分', () {
      final sections = graduateTrainPlanSections(
        categories: [
          GraduateTrainPlanCategoryProgress.fromJson(const {
            'DM': '1',
            'MC': '必修课',
            'YXXF': 0.0,
            'ZDXF': 14.0,
          }),
        ],
        planCourses: [
          GraduateTrainPlanCourse.fromJson(const {
            'KCDM': 'S00000202',
            'KCMC': '数理方法',
            'KCLBDM': '1',
            'XF': 3.0,
          }),
        ],
        gradeRows: [
          // 同一门课两条通过记录（补考/重修）：只计首条 3.0。
          _gradeRow('S00000202', '数理方法', credit: 3.0),
          _gradeRow('S00000202', '数理方法', credit: 2.0),
          // 未及格行：不计入。
          _gradeRow('S99999999', '还没过', credit: 2.0, passed: false),
        ],
      );

      expect(sections, hasLength(1));
      expect(sections.first.earnedCredits, 3.0);
      expect(sections.first.rows, hasLength(1));
      expect(graduateTrainPlanEarnedTotal(sections), 3.0);
    });

    test('方案课程里找不到的成绩行落「方案外」区块', () {
      final sections = graduateTrainPlanSections(
        categories: [
          GraduateTrainPlanCategoryProgress.fromJson(const {
            'DM': '1',
            'MC': '必修课',
            'YXXF': 0.0,
            'ZDXF': 14.0,
          }),
        ],
        planCourses: const [],
        gradeRows: [_gradeRow('B08170004', '化学反应工程进展', credit: 3.0)],
      );

      expect(sections, hasLength(2));
      expect(sections.first.rows, isEmpty);
      expect(sections.last.title, '方案外');
      expect(sections.last.earnedCredits, 3.0);
      expect(graduateTrainPlanEarnedTotal(sections), 3.0);
    });
  });

  testWidgets('页面：已登录且数据加载完成，渲染总进度与分类进度', (tester) async {
    getIt.registerSingleton<GraduateTrainPlanProvider>(
      GraduateTrainPlanProvider(_ImmediateGsApiService()),
    );
    getIt.registerSingleton<ScuAuthProvider>(_FakeScuAuthProvider());

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const GraduateTrainPlanPage(),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(GraduateTrainPlanPage)),
    )!;
    expect(find.text(l10n.graduateTrainPlan), findsOneWidget);
    // 总进度卡：已修 6 / 要求 24 学分
    expect(
      find.text(l10n.graduateTrainPlanCreditText('6', '24')),
      findsOneWidget,
    );
    expect(find.text('2026级学术学位0817 测试2026级研究生培养方案'), findsOneWidget);
    // 分类卡：必修课已修 3/14（有课程列表）；选修课/必修环节无已修 → 空态文案
    expect(
      find.text(l10n.graduateTrainPlanModuleCredit('3', '14')),
      findsOneWidget,
    );
    expect(find.text('必修课'), findsOneWidget);
    expect(find.text('数理方法'), findsOneWidget);
    expect(find.text('2026年 秋季学期 · 88'), findsOneWidget);
    // 方案外区块与「无已修课程」空态在列表尾部，懒加载下需滚动到可见。
    await tester.scrollUntilVisible(
      find.text('方案外'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('方案外'), findsOneWidget);
    expect(find.text('化学反应工程进展'), findsOneWidget);
    expect(find.text(l10n.graduateTrainPlanNoCourses), findsNWidgets(2));
  });

  testWidgets('会话自愈失败：不抛未捕获异常，落到「请先登录」引导', (tester) async {
    // token 还在但统一认证会话过期（isLoggedIn=false、accessToken 非空、
    // 非自动登录中）→ 页面走 ScuAuth.refresh() 自愈分支；refresh 抛异常时
    // 必须被页面接住，否则 fire-and-forget 的 Future 会变成 unhandled error。
    getIt.registerSingleton<GraduateTrainPlanProvider>(
      GraduateTrainPlanProvider(_ImmediateGsApiService()),
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

// ── 脱敏 fixture（虚构数据，非真实账号）────────────────────────────────

GraduateTrainPlanInfo _info() => GraduateTrainPlanInfo.fromJson(const {
  'XH': '2026223070099',
  'FAMC': '2026级学术学位0817 测试2026级研究生培养方案',
  'FADM': '2026003307081799999',
  'ZYDM_DISPLAY': '0817 测试工程',
  'YXDM_DISPLAY': '测试学院',
  'NJDM_DISPLAY': '2026级',
  'PYCCDM_DISPLAY': '硕士',
  'SHZT_DISPLAY': '待院系审核',
});

(GraduateTrainPlanCreditStats, List<GraduateTrainPlanCategoryProgress>)
_stats() => (
  GraduateTrainPlanCreditStats.fromJson(const {
    'YXXF': 29.0,
    'ZDXF': 24.0,
    'FANYXXF': 22.0,
    'FAWYXXF': 7.0,
  }),
  [
    GraduateTrainPlanCategoryProgress.fromJson(const {
      'DM': '1',
      'MC': '必修课',
      'YXXF': 14.0,
      'ZDXF': 14.0,
      'YXMS': 6,
    }),
    GraduateTrainPlanCategoryProgress.fromJson(const {
      'DM': '2',
      'MC': '选修课',
      'YXXF': 13.0,
      'ZDXF': 5.0,
      'YXMS': 6,
    }),
    GraduateTrainPlanCategoryProgress.fromJson(const {
      'DM': '7',
      'MC': '必修环节',
      'YXXF': 2.0,
      'ZDXF': 2.0,
      'YXMS': 2,
    }),
  ],
);

List<GraduateTrainPlanCourse> _planCourses() => [
  GraduateTrainPlanCourse.fromJson(const {
    'KCDM': 'S00000202',
    'KCMC': '数理方法',
    'KCLBDM': '1',
    'KCLBDM_DISPLAY': '必修课',
    'XF': 3.0,
  }),
];

List<GraduateGradeRow> _grades() => [
  // 及格有效：已修，方案内必修课。
  _gradeRow('S00000202', '数理方法', credit: 3.0),
  // 及格但不在方案课程里：方案外。
  _gradeRow('B08170004', '化学反应工程进展', credit: 3.0),
];

GraduateGradeRow _gradeRow(
  String kcdm,
  String kcmc, {
  double credit = 3.0,
  bool passed = true,
}) => GraduateGradeRow.fromJson({
  'KCDM': kcdm,
  'KCMC': kcmc,
  'XNXQDM': '20261',
  'XNXQDM_DISPLAY': '2026年 秋季学期',
  'XF': credit,
  'SFJG': passed ? 1 : 0,
  'SFYX': 1,
  'CJXSZ': passed ? '88' : '55',
});

// ── 可控 GsApiService 假件 ────────────────────────────────────────────

/// 四个接口立即以 fixture 完成。
class _ImmediateGsApiService implements GsApiService {
  @override
  Future<GraduateTrainPlanInfo> fetchTrainPlanInfo() async => _info();

  @override
  Future<
    (GraduateTrainPlanCreditStats, List<GraduateTrainPlanCategoryProgress>)
  >
  fetchTrainPlanCreditStats() async => _stats();

  @override
  Future<List<GraduateTrainPlanCourse>> fetchTrainPlanCourses() async =>
      _planCourses();

  @override
  Future<List<GraduateGradeRow>> fetchGrades() async => _grades();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// info 请求被挂起、由测试控制何时完成；开启 [autoCompleteRest] 后，
/// 后续 stats/courses/grades 请求立即以 fixture 完成（info 完成后才发起）。
class _QueuedGsApiService implements GsApiService {
  int infoCalls = 0;
  int statsCalls = 0;
  int coursesCalls = 0;
  int gradesCalls = 0;

  bool autoCompleteRest = false;

  final _heldInfo = <Completer<GraduateTrainPlanInfo>>[];

  @override
  Future<GraduateTrainPlanInfo> fetchTrainPlanInfo() {
    infoCalls++;
    if (autoCompleteRest) return Future.value(_info());
    final completer = Completer<GraduateTrainPlanInfo>();
    _heldInfo.add(completer);
    return completer.future;
  }

  @override
  Future<
    (GraduateTrainPlanCreditStats, List<GraduateTrainPlanCategoryProgress>)
  >
  fetchTrainPlanCreditStats() async {
    statsCalls++;
    return _stats();
  }

  @override
  Future<List<GraduateTrainPlanCourse>> fetchTrainPlanCourses() async {
    coursesCalls++;
    return _planCourses();
  }

  @override
  Future<List<GraduateGradeRow>> fetchGrades() async {
    gradesCalls++;
    return _grades();
  }

  void completeHeldInfo() {
    for (final completer in _heldInfo) {
      if (!completer.isCompleted) completer.complete(_info());
    }
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// info 抛异常、其余不触达（unauthenticated / failed 分类测试）。
class _ThrowingGsApiService implements GsApiService {
  _ThrowingGsApiService({required this.infoError});

  final Object infoError;

  @override
  Future<GraduateTrainPlanInfo> fetchTrainPlanInfo() async => throw infoError;

  @override
  Future<
    (GraduateTrainPlanCreditStats, List<GraduateTrainPlanCategoryProgress>)
  >
  fetchTrainPlanCreditStats() async => _stats();

  @override
  Future<List<GraduateTrainPlanCourse>> fetchTrainPlanCourses() async =>
      _planCourses();

  @override
  Future<List<GraduateGradeRow>> fetchGrades() async => _grades();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
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
