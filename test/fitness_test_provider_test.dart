import 'dart:async';

import 'package:bugaoshan/pages/campus/fitness_test/models/fitness_models.dart';
import 'package:bugaoshan/providers/fitness_test_provider.dart';
import 'package:bugaoshan/services/api/fitness_api_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  totalGrade: '优秀',
  studentName: '张三',
  studentNum: '20240001',
  sex: '男',
  studentYear: '2024',
  reportType: '-',
  reportStatus: '-',
  bmi: const FitnessScoreItem(
    rawScore: '-',
    gradedScore: '-',
    grade: '-',
    colorClass: 'green',
  ),
  vitalCapacity: const FitnessScoreItem(
    rawScore: '-',
    gradedScore: '-',
    grade: '-',
    colorClass: 'green',
  ),
  jump: const FitnessScoreItem(
    rawScore: '-',
    gradedScore: '-',
    grade: '-',
    colorClass: 'green',
  ),
  sitAndReach: const FitnessScoreItem(
    rawScore: '-',
    gradedScore: '-',
    grade: '-',
    colorClass: 'green',
  ),
  pullAndSit: const FitnessScoreItem(
    rawScore: '-',
    gradedScore: '-',
    grade: '-',
    colorClass: 'green',
  ),
  fiftyM: const FitnessScoreItem(
    rawScore: '-',
    gradedScore: '-',
    grade: '-',
    colorClass: 'green',
  ),
  run: const FitnessScoreItem(
    rawScore: '-',
    gradedScore: '-',
    grade: '-',
    colorClass: 'green',
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ensureLoaded 合并并发请求并复用已加载资源', () async {
    SharedPreferences.setMockInitialValues({kFitnessTestSelectedYearKey: 2025});
    final prefs = await SharedPreferences.getInstance();
    final api = _FakeFitnessApi()
      ..notices = [_notice('通知')]
      ..scores[2025] = _score(90);
    final provider = FitnessTestProvider(prefs, api);

    await Future.wait([provider.ensureLoaded(), provider.ensureLoaded()]);
    await provider.ensureLoaded();

    expect(api.noticeCalls, 1);
    expect(api.scoreCalls, [2025]);
    expect(provider.notices.single.title, '通知');
    expect(provider.scoreData?.totalScore, 90);
  });

  test('切换年份时旧成绩请求不能回写新年份', () async {
    SharedPreferences.setMockInitialValues({kFitnessTestSelectedYearKey: 2025});
    final prefs = await SharedPreferences.getInstance();
    final api = _FakeFitnessApi()..notices = const [];
    final oldScore = Completer<FitnessScore?>();
    final newScore = Completer<FitnessScore?>();
    api.pendingScores[2025] = oldScore;
    api.pendingScores[2024] = newScore;
    final provider = FitnessTestProvider(prefs, api);

    final oldRequest = provider.ensureScore();
    final newRequest = provider.selectYear(2024);
    await Future<void>.delayed(Duration.zero);
    newScore.complete(_score(88));
    await newRequest;

    oldScore.complete(_score(59));
    await oldRequest;

    expect(provider.selectedYear, 2024);
    expect(provider.scoreData?.totalScore, 88);
    expect(prefs.getInt(kFitnessTestSelectedYearKey), 2024);
  });

  test('clear 后飞行中的结果不会恢复已登出会话状态', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = _FakeFitnessApi();
    final pending = Completer<List<FitnessNotice>>();
    api.pendingNotices = pending;
    final provider = FitnessTestProvider(prefs, api);

    final request = provider.ensureNotices();
    provider.clear();
    pending.complete([_notice('旧账号通知')]);
    await request;

    expect(provider.notices, isEmpty);
    expect(provider.noticesState, FitnessTestLoadState.idle);
  });

  test('业务错误保留成绩错误文案，刷新可以恢复', () async {
    SharedPreferences.setMockInitialValues({kFitnessTestSelectedYearKey: 2025});
    final prefs = await SharedPreferences.getInstance();
    final api = _FakeFitnessApi()
      ..scoreFailures = 1
      ..scores[2025] = _score(100);
    final provider = FitnessTestProvider(prefs, api);

    await provider.ensureScore();
    expect(provider.scoreState, FitnessTestLoadState.error);
    expect(provider.scoreError, '暂未公布成绩');

    await provider.refreshScore();
    expect(provider.scoreState, FitnessTestLoadState.loaded);
    expect(provider.scoreData?.totalScore, 100);
  });
}

class _FakeFitnessApi implements FitnessTestApi {
  int noticeCalls = 0;
  final scoreCalls = <int>[];
  List<FitnessNotice> notices = const [];
  final scores = <int, FitnessScore?>{};
  final pendingScores = <int, Completer<FitnessScore?>>{};
  Completer<List<FitnessNotice>>? pendingNotices;
  int scoreFailures = 0;

  @override
  Future<List<FitnessNotice>> fetchNotices() {
    noticeCalls++;
    final pending = pendingNotices;
    if (pending != null) return pending.future;
    return Future.value(notices);
  }

  @override
  Future<FitnessScore?> fetchScore(int year) {
    scoreCalls.add(year);
    final pending = pendingScores[year];
    if (pending != null) return pending.future;
    if (scoreFailures > 0) {
      scoreFailures--;
      return Future.error(const ServiceException('暂未公布成绩'));
    }
    return Future.value(scores[year]);
  }
}
