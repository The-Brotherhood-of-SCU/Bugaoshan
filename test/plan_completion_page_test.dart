import 'dart:async';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/plan_completion/models/plan_completion.dart';
import 'package:bugaoshan/pages/campus/plan_completion/plan_completion_page.dart';
import 'package:bugaoshan/providers/plan_completion_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    await getIt.reset();
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('多方案：顶部显示方案名与计数，滑动切换方案内容', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = _ControllablePlanApi();
    final provider = PlanCompletionProvider(prefs, api);

    final future = provider.fetchPlanCompletion(forceRefresh: true);
    api.completeWith([
      PlanCompletionPlan(
        id: '10101',
        name: '主修培养方案',
        nodes: [PlanCompletionNode.fromJson(_rootNodeJson('主修公共课'))],
      ),
      PlanCompletionPlan(
        id: '10102',
        name: '辅修培养方案',
        nodes: [PlanCompletionNode.fromJson(_rootNodeJson('辅修公共课'))],
      ),
    ]);
    await future;

    getIt.registerSingleton<PlanCompletionProvider>(provider);
    getIt.registerSingleton<ScuAuthProvider>(_FakeScuAuthProvider());

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const PlanCompletionPage(),
      ),
    );
    await tester.pumpAndSettle();

    // 顶部指示栏显示当前方案名与页码
    expect(find.text('主修培养方案'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    // 第一页内容
    expect(find.text('主修公共课'), findsOneWidget);

    // 左滑切换到第二个方案
    await tester.fling(find.byType(PageView), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();

    expect(find.text('辅修培养方案'), findsOneWidget);
    expect(find.text('2/2'), findsOneWidget);
    expect(find.text('辅修公共课'), findsOneWidget);
  });

  testWidgets('单方案：显示方案名但不显示计数', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = _ControllablePlanApi();
    final provider = PlanCompletionProvider(prefs, api);

    final future = provider.fetchPlanCompletion(forceRefresh: true);
    api.completeWith([
      PlanCompletionPlan(
        id: '',
        name: '唯一培养方案',
        nodes: [PlanCompletionNode.fromJson(_rootNodeJson('唯一公共课'))],
      ),
    ]);
    await future;

    getIt.registerSingleton<PlanCompletionProvider>(provider);
    getIt.registerSingleton<ScuAuthProvider>(_FakeScuAuthProvider());

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const PlanCompletionPage(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('唯一培养方案'), findsOneWidget);
    // 单方案不显示 1/1 计数
    expect(find.text('1/1'), findsNothing);
    expect(find.text('唯一公共课'), findsOneWidget);
  });
}

Map<String, dynamic> _rootNodeJson(String name) => {
  'id': 'root-1',
  'pId': '-1',
  'flagId': 'root-1',
  'flagType': '001',
  'name': name,
  'sfwc': '否',
  'yxxf': '0',
  'zsxf': '1',
};

class _ControllablePlanApi implements ZhjwApiService {
  final _completers = <Completer<List<PlanCompletionPlan>>>[];

  @override
  Future<List<PlanCompletionPlan>> fetchPlanCompletion() {
    final completer = Completer<List<PlanCompletionPlan>>();
    _completers.add(completer);
    return completer.future;
  }

  void completeWith(List<PlanCompletionPlan> plans) {
    _completers.single.complete(plans);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeScuAuthProvider extends ChangeNotifier implements ScuAuthProvider {
  @override
  bool get isLoggedIn => true;

  @override
  bool get isAutoLoggingIn => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
