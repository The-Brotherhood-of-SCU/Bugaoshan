import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/models/graduate_train_plan.dart';
import 'package:bugaoshan/pages/campus/train_program/models/train_program.dart';
import 'package:bugaoshan/pages/campus/train_program/models/train_program_model.dart';
import 'package:bugaoshan/providers/graduate_train_plan_provider.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';
import 'package:bugaoshan/providers/train_program_provider.dart';
import 'package:bugaoshan/utils/graduate_train_plan_progress.dart';

part 'train_program_pods.g.dart';

@Riverpod(keepAlive: true)
class TrainProgramNotifier extends _$TrainProgramNotifier {
  @override
  bool updateShouldNotify(
    TrainProgramProvider previous,
    TrainProgramProvider next,
  ) =>
      true;

  @override
  TrainProgramProvider build() {
    final TrainProgramProvider provider;
    if (getIt.isRegistered<TrainProgramProvider>()) {
      provider = getIt<TrainProgramProvider>();
    } else {
      final zhjwApi = ref.watch(zhjwApiServiceBridge);
      provider = TrainProgramProvider(zhjwApi);
      ref.onDispose(provider.dispose);
    }

    void listener() {
      state = provider;
    }

    provider.addListener(listener);
    ref.onDispose(() => provider.removeListener(listener));

    return provider;
  }

  void setSelectedCollege(String? value) => state.setSelectedCollege(value);
  void setSelectedGrade(String? value) => state.setSelectedGrade(value);
  Future<void> fetchCollegesAndGrades() => state.fetchCollegesAndGrades();
  Future<void> searchPrograms() => state.searchPrograms();
  Future<void> fetchProgramDetail(String fajhh) =>
      state.fetchProgramDetail(fajhh);
  void clearDetail() => state.clearDetail();
  Future<void> fetchCourseDetail(String urlPath) =>
      state.fetchCourseDetail(urlPath);
  void clearCourseDetail() => state.clearCourseDetail();
}

@Riverpod(keepAlive: true)
class GraduateTrainPlanNotifier extends _$GraduateTrainPlanNotifier {
  @override
  bool updateShouldNotify(
    GraduateTrainPlanProvider previous,
    GraduateTrainPlanProvider next,
  ) =>
      true;

  @override
  GraduateTrainPlanProvider build() {
    final GraduateTrainPlanProvider provider;
    if (getIt.isRegistered<GraduateTrainPlanProvider>()) {
      provider = getIt<GraduateTrainPlanProvider>();
    } else {
      final gsApi = ref.watch(gsApiServiceBridge);
      provider = GraduateTrainPlanProvider(gsApi);
      ref.onDispose(provider.dispose);
    }

    void listener() {
      state = provider;
    }

    provider.addListener(listener);
    ref.onDispose(() => provider.removeListener(listener));

    return provider;
  }

  Future<void> ensureLoaded() => state.ensureLoaded();
  Future<void> refresh() => state.refresh();
  void clear() => state.clear();
}

// ── 常用便捷 Provider ─────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
List<College> trainProgramColleges(Ref ref) {
  return ref.watch(trainProgramProvider).colleges;
}

@Riverpod(keepAlive: true)
List<Grade> trainProgramGrades(Ref ref) {
  return ref.watch(trainProgramProvider).grades;
}

@Riverpod(keepAlive: true)
List<TrainProgram> trainPrograms(Ref ref) {
  return ref.watch(trainProgramProvider).programs;
}

@Riverpod(keepAlive: true)
TrainProgramDetail? trainProgramDetail(Ref ref) {
  return ref.watch(trainProgramProvider).currentDetail;
}

@Riverpod(keepAlive: true)
GraduateTrainPlanInfo? graduateTrainPlanInfo(Ref ref) {
  return ref.watch(graduateTrainPlanProvider).info;
}

@Riverpod(keepAlive: true)
GraduateTrainPlanCreditStats? graduateTrainPlanCreditStats(Ref ref) {
  return ref.watch(graduateTrainPlanProvider).creditStats;
}

@Riverpod(keepAlive: true)
List<TrainPlanProgressSection> graduateTrainPlanSectionsList(Ref ref) {
  return ref.watch(graduateTrainPlanProvider).sections;
}

@Riverpod(keepAlive: true)
double graduateTrainPlanEarnedInPlan(Ref ref) {
  return ref.watch(graduateTrainPlanProvider).earnedInPlan;
}
