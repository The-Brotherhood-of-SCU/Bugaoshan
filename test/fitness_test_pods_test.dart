import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/pages/campus/fitness_test/models/fitness_models.dart';
import 'package:bugaoshan/providers/fitness_test_provider.dart';
import 'package:bugaoshan/providers/riverpod/campus/fitness_test_pods.dart';
import 'package:bugaoshan/scu_backend/fitness/fitness_api_service.dart';

FitnessNotice _notice(String title) => FitnessNotice(
  title: title,
  content: '<p>$title</p>',
  plainContent: title,
  createTime: '2024-01-01',
  readNum: 0,
  isSticky: false,
);

FitnessScore _score(int totalScore) => FitnessScore(
  totalScore: totalScore,
  totalGrade: '良好',
  studentName: '李四',
  studentNum: '20240002',
  sex: '女',
  studentYear: '2024',
  reportType: '-',
  reportStatus: '-',
  bmi: const FitnessScoreItem(rawScore: '-', gradedScore: '-', grade: '-', colorClass: 'green'),
  vitalCapacity: const FitnessScoreItem(rawScore: '-', gradedScore: '-', grade: '-', colorClass: 'green'),
  jump: const FitnessScoreItem(rawScore: '-', gradedScore: '-', grade: '-', colorClass: 'green'),
  sitAndReach: const FitnessScoreItem(rawScore: '-', gradedScore: '-', grade: '-', colorClass: 'green'),
  pullAndSit: const FitnessScoreItem(rawScore: '-', gradedScore: '-', grade: '-', colorClass: 'green'),
  fiftyM: const FitnessScoreItem(rawScore: '-', gradedScore: '-', grade: '-', colorClass: 'green'),
  run: const FitnessScoreItem(rawScore: '-', gradedScore: '-', grade: '-', colorClass: 'green'),
);

class _MockFitnessApi implements FitnessApiService {
  List<FitnessNotice> notices = [];
  Map<int, FitnessScore> scores = {};
  int noticeCalls = 0;
  List<int> scoreCalls = [];

  @override
  Future<List<FitnessNotice>> fetchNotices() async {
    noticeCalls++;
    return notices;
  }

  @override
  Future<FitnessScore?> fetchScore(int year) async {
    scoreCalls.add(year);
    return scores[year];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late SharedPreferences prefs;
  late _MockFitnessApi mockApi;

  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({kFitnessTestSelectedYearKey: 2025});
    prefs = await SharedPreferences.getInstance();
    getIt.registerSingleton<SharedPreferences>(prefs);

    mockApi = _MockFitnessApi();
    getIt.registerSingleton<FitnessApiService>(mockApi);
  });

  tearDown(() async {
    await getIt.reset();
  });

  test('FitnessSelectedYear loads from prefs and updates', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(fitnessSelectedYearProvider), 2025);

    await container.read(fitnessSelectedYearProvider.notifier).selectYear(2024);
    expect(container.read(fitnessSelectedYearProvider), 2024);
    expect(prefs.getInt(kFitnessTestSelectedYearKey), 2024);
  });

  test('FitnessNotices loads data through AsyncValue', () async {
    mockApi.notices = [_notice('体测通知')];
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final initial = container.read(fitnessNoticesProvider);
    expect(initial, isA<AsyncLoading>());

    final notices = await container.read(fitnessNoticesProvider.future);
    expect(notices.single.title, '体测通知');
    expect(mockApi.noticeCalls, 1);
  });

  test('FitnessScoreData caches score by year family', () async {
    mockApi.scores[2024] = _score(85);
    mockApi.scores[2025] = _score(92);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final score2024 = await container.read(fitnessScoreDataProvider(2024).future);
    expect(score2024?.totalScore, 85);

    final score2025 = await container.read(fitnessScoreDataProvider(2025).future);
    expect(score2025?.totalScore, 92);

    // Reading again reuses cache without re-fetching
    final cached2024 = await container.read(fitnessScoreDataProvider(2024).future);
    expect(cached2024?.totalScore, 85);
    expect(mockApi.scoreCalls, [2024, 2025]);
  });
}
