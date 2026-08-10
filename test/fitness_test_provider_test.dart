import 'dart:async';

import 'package:bugaoshan/providers/fitness_test_provider.dart';
import 'package:bugaoshan/services/api/fitness_api_service.dart';
import 'package:bugaoshan/services/auth/scu_exceptions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('ensureLoaded 合并并发请求并复用已加载资源', () async {
    SharedPreferences.setMockInitialValues({kFitnessTestSelectedYearKey: 2025});
    final prefs = await SharedPreferences.getInstance();
    final api = _FakeFitnessApi()
      ..notices = [
        {'title': '通知'},
      ]
      ..scores[2025] = {'total_score': 90};
    final provider = FitnessTestProvider(prefs, api);

    await Future.wait([provider.ensureLoaded(), provider.ensureLoaded()]);
    await provider.ensureLoaded();

    expect(api.noticeCalls, 1);
    expect(api.scoreCalls, [2025]);
    expect(provider.notices.single['title'], '通知');
    expect(provider.scoreData?['total_score'], 90);
  });

  test('切换年份时旧成绩请求不能回写新年份', () async {
    SharedPreferences.setMockInitialValues({kFitnessTestSelectedYearKey: 2025});
    final prefs = await SharedPreferences.getInstance();
    final api = _FakeFitnessApi()..notices = const [];
    final oldScore = Completer<Map<String, dynamic>?>();
    final newScore = Completer<Map<String, dynamic>?>();
    api.pendingScores[2025] = oldScore;
    api.pendingScores[2024] = newScore;
    final provider = FitnessTestProvider(prefs, api);

    final oldRequest = provider.ensureScore();
    final newRequest = provider.selectYear(2024);
    await Future<void>.delayed(Duration.zero);
    newScore.complete({'total_score': 88});
    await newRequest;

    oldScore.complete({'total_score': 59});
    await oldRequest;

    expect(provider.selectedYear, 2024);
    expect(provider.scoreData?['total_score'], 88);
    expect(prefs.getInt(kFitnessTestSelectedYearKey), 2024);
  });

  test('clear 后飞行中的结果不会恢复已登出会话状态', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final api = _FakeFitnessApi();
    final pending = Completer<List<Map<String, dynamic>>>();
    api.pendingNotices = pending;
    final provider = FitnessTestProvider(prefs, api);

    final request = provider.ensureNotices();
    provider.clear();
    pending.complete([
      {'title': '旧账号通知'},
    ]);
    await request;

    expect(provider.notices, isEmpty);
    expect(provider.noticesState, FitnessTestLoadState.idle);
  });

  test('业务错误保留成绩错误文案，刷新可以恢复', () async {
    SharedPreferences.setMockInitialValues({kFitnessTestSelectedYearKey: 2025});
    final prefs = await SharedPreferences.getInstance();
    final api = _FakeFitnessApi()
      ..scoreFailures = 1
      ..scores[2025] = {'total_score': 100};
    final provider = FitnessTestProvider(prefs, api);

    await provider.ensureScore();
    expect(provider.scoreState, FitnessTestLoadState.error);
    expect(provider.scoreError, '暂未公布成绩');

    await provider.refreshScore();
    expect(provider.scoreState, FitnessTestLoadState.loaded);
    expect(provider.scoreData?['total_score'], 100);
  });
}

class _FakeFitnessApi implements FitnessTestApi {
  int noticeCalls = 0;
  final scoreCalls = <int>[];
  List<Map<String, dynamic>> notices = const [];
  final scores = <int, Map<String, dynamic>?>{};
  final pendingScores = <int, Completer<Map<String, dynamic>?>>{};
  Completer<List<Map<String, dynamic>>>? pendingNotices;
  int scoreFailures = 0;

  @override
  Future<List<Map<String, dynamic>>> fetchNotices() {
    noticeCalls++;
    final pending = pendingNotices;
    if (pending != null) return pending.future;
    return Future.value(notices);
  }

  @override
  Future<Map<String, dynamic>?> fetchScore(int year) {
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
