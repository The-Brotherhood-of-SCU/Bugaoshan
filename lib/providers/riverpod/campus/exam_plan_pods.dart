import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bugaoshan/pages/campus/exam_plan/models/exam_info.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';

part 'exam_plan_pods.g.dart';

@riverpod
class ExamPlanNotifier extends _$ExamPlanNotifier {
  @override
  Future<List<ExamInfo>> build() async {
    final api = ref.watch(zhjwApiServiceBridge);
    return api.fetchExamPlan();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final api = ref.read(zhjwApiServiceBridge);
      return api.fetchExamPlan();
    });
  }
}
