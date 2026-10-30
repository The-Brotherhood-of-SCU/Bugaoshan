import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/pages/campus/plan_completion/models/plan_completion.dart';
import 'package:bugaoshan/providers/plan_completion_provider.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';

part 'plan_completion_pods.g.dart';

@Riverpod(keepAlive: true)
class PlanCompletionNotifier extends _$PlanCompletionNotifier {
  @override
  bool updateShouldNotify(
    PlanCompletionProvider previous,
    PlanCompletionProvider next,
  ) =>
      true;

  @override
  PlanCompletionProvider build() {
    final PlanCompletionProvider provider;
    if (getIt.isRegistered<PlanCompletionProvider>()) {
      provider = getIt<PlanCompletionProvider>();
    } else {
      final prefs = ref.watch(sharedPreferencesBridge);
      final zhjwApi = ref.watch(zhjwApiServiceBridge);
      provider = PlanCompletionProvider(prefs, zhjwApi);
      ref.onDispose(provider.dispose);
    }

    void listener() {
      state = provider;
    }

    provider.addListener(listener);
    ref.onDispose(() => provider.removeListener(listener));

    return provider;
  }

  void selectPlan(int index) => state.selectPlan(index);
  Future<void> fetchPlanCompletion({bool forceRefresh = false}) =>
      state.fetchPlanCompletion(forceRefresh: forceRefresh);
  Future<void> clearCache() => state.clearCache();
}

// ── 常用便捷 Provider ─────────────────────────────────────────────────────────

@Riverpod(keepAlive: true)
List<PlanCompletionPlan> planCompletionPlans(Ref ref) {
  return ref.watch(planCompletionProvider).plans;
}

@Riverpod(keepAlive: true)
int planCompletionCurrentIndex(Ref ref) {
  return ref.watch(planCompletionProvider).currentPlanIndex;
}

@Riverpod(keepAlive: true)
List<PlanCompletionNode> planCompletionNodes(Ref ref) {
  return ref.watch(planCompletionProvider).nodes;
}
