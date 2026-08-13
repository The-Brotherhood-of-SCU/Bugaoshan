import 'dart:async';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/exam_plan/exam_plan_page.dart';
import 'package:bugaoshan/pages/campus/exam_plan/models/exam_info.dart';
import 'package:bugaoshan/providers/exam_plan_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/api/zhjw_api_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() async {
    await getIt.reset();
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('shows export action after exams finish loading', (tester) async {
    final api = _ControllableExamApi();
    final provider = ExamPlanProvider(api);
    getIt.registerSingleton<ExamPlanProvider>(provider);
    getIt.registerSingleton<ScuAuthProvider>(_FakeScuAuthProvider());

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ExamPlanPage(),
      ),
    );
    await tester.pump();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(ExamPlanPage)),
    )!;
    expect(api.requests, hasLength(1));
    expect(find.byTooltip(l10n.exportExamPlan), findsNothing);

    api.requests.single.complete([_exam]);
    await tester.pump();

    expect(find.byTooltip(l10n.exportExamPlan), findsOneWidget);
  });
}

const _exam = ExamInfo(
  courseName: '测试课程',
  week: '第 1 周',
  date: '2030-01-01',
  weekday: '星期二',
  timeRange: '09:00-11:00',
  location: '一教 A101',
  seatNumber: '1',
  ticketNumber: '',
  tip: '无',
);

class _ControllableExamApi implements ZhjwApiService {
  final requests = <Completer<List<ExamInfo>>>[];

  @override
  Future<List<ExamInfo>> fetchExamPlan() {
    final request = Completer<List<ExamInfo>>();
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
  bool get isAutoLoggingIn => false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
