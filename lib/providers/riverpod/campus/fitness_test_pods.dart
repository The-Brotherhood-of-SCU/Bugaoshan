import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bugaoshan/pages/campus/fitness_test/models/fitness_models.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/providers/fitness_test_provider.dart';

part 'fitness_test_pods.g.dart';

@Riverpod(keepAlive: true)
class FitnessSelectedYear extends _$FitnessSelectedYear {
  @override
  int build() {
    final prefs = ref.watch(sharedPreferencesBridge);
    return prefs.getInt(kFitnessTestSelectedYearKey) ?? DateTime.now().year;
  }

  Future<void> selectYear(int year) async {
    state = year;
    final prefs = ref.read(sharedPreferencesBridge);
    await prefs.setInt(kFitnessTestSelectedYearKey, year);
  }
}

@riverpod
class FitnessNotices extends _$FitnessNotices {
  @override
  Future<List<FitnessNotice>> build() async {
    final api = ref.watch(fitnessApiServiceBridge);
    return api.fetchNotices();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(fitnessApiServiceBridge);
      return api.fetchNotices();
    });
  }
}

@riverpod
class FitnessScoreData extends _$FitnessScoreData {
  @override
  Future<FitnessScore?> build(int year) async {
    final api = ref.watch(fitnessApiServiceBridge);
    return api.fetchScore(year);
  }

  Future<void> refresh(int year) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(fitnessApiServiceBridge);
      return api.fetchScore(year);
    });
  }
}
