import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/fitness_test/fitness_test_page.dart';
import 'package:bugaoshan/pages/campus/fitness_test/models/fitness_models.dart';
import 'package:bugaoshan/providers/fitness_test_provider.dart';
import 'package:bugaoshan/providers/scu_auth_provider.dart';
import 'package:bugaoshan/services/api/fitness_api_service.dart';
import 'package:bugaoshan/utils/app_logger.dart';

import 'package:bugaoshan/widgets/common/login_required_widget.dart';

FitnessNotice _notice(String title) => FitnessNotice(
  title: title,
  content: '<p>$title</p>',
  plainContent: title,
  createTime: '2024-01-01',
  readNum: 10,
  isSticky: false,
);

FitnessScore _score(int totalScore, String name) => FitnessScore(
  totalScore: totalScore,
  totalGrade: '优秀',
  studentName: name,
  studentNum: '20240001',
  sex: '男',
  studentYear: '2024',
  reportType: '免测',
  reportStatus: '已审核',
  bmi: const FitnessScoreItem(rawScore: '21.5', gradedScore: '100', grade: '正常', colorClass: 'green'),
  vitalCapacity: const FitnessScoreItem(rawScore: '4500', gradedScore: '90', grade: '良好', colorClass: 'green'),
  jump: const FitnessScoreItem(rawScore: '260', gradedScore: '90', grade: '良好', colorClass: 'green'),
  sitAndReach: const FitnessScoreItem(rawScore: '20', gradedScore: '85', grade: '良好', colorClass: 'green'),
  pullAndSit: const FitnessScoreItem(rawScore: '16', gradedScore: '80', grade: '良好', colorClass: 'green'),
  fiftyM: const FitnessScoreItem(rawScore: '6.8', gradedScore: '90', grade: '优秀', colorClass: 'green'),
  run: const FitnessScoreItem(rawScore: '3:20', gradedScore: '95', grade: '优秀', colorClass: 'green'),
);

class _MockFitnessApi implements FitnessApiService {
  List<FitnessNotice> notices = [];
  Map<int, FitnessScore> scores = {};

  @override
  Future<List<FitnessNotice>> fetchNotices() async => notices;

  @override
  Future<FitnessScore?> fetchScore(int year) async => scores[year];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeAuth extends ChangeNotifier implements ScuAuthProvider {
  bool loggedIn = false;
  @override
  bool get isLoggedIn => loggedIn;
  @override
  bool get isAutoLoggingIn => false;

  void setLoggedIn(bool value) {
    loggedIn = value;
    notifyListeners();
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late _MockFitnessApi mockApi;
  late _FakeAuth fakeAuth;

  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({kFitnessTestSelectedYearKey: 2025});
    prefs = await SharedPreferences.getInstance();
    getIt.registerSingleton<SharedPreferences>(prefs);

    final logger = AppLogger();
    getIt.registerSingleton<AppLogger>(logger);

    mockApi = _MockFitnessApi();
    mockApi.notices = [_notice('2025体测开考通知')];
    mockApi.scores[2025] = _score(95, '张三');
    mockApi.scores[2024] = _score(88, '李四');
    getIt.registerSingleton<FitnessApiService>(mockApi);

    fakeAuth = _FakeAuth();
    getIt.registerSingleton<ScuAuthProvider>(fakeAuth);
  });

  tearDown(() async {
    await getIt.reset();
  });

  testWidgets('shows LoginRequiredWidget when not logged in', (tester) async {
    fakeAuth.setLoggedIn(false);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FitnessTestPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(LoginRequiredWidget), findsOneWidget);
  });

  testWidgets('renders scores and notices when logged in and reacts to year dropdown', (
    tester,
  ) async {
    fakeAuth.setLoggedIn(true);

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          locale: Locale('zh'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: FitnessTestPage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pumpAndSettle();

    // Verify 2025 score
    expect(find.text('95'), findsOneWidget);
    expect(find.text('2025'), findsOneWidget);

    // Switch to notices tab
    await tester.tap(find.text('通知公告'));
    await tester.pumpAndSettle();
    expect(find.text('2025体测开考通知'), findsOneWidget);
  });
}
