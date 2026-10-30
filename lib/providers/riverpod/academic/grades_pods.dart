import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/models/graduate_grades.dart';
import 'package:bugaoshan/models/scheme_score.dart';
import 'package:bugaoshan/providers/grades_provider.dart';
import 'package:bugaoshan/providers/graduate_grades_provider.dart';
import 'package:bugaoshan/providers/riverpod/bridge.dart';

part 'grades_pods.g.dart';

@Riverpod(keepAlive: true)
class GradesNotifier extends _$GradesNotifier {
  @override
  bool updateShouldNotify(GradesProvider previous, GradesProvider next) => true;

  @override
  GradesProvider build() {
    final GradesProvider provider;
    if (getIt.isRegistered<GradesProvider>()) {
      provider = getIt<GradesProvider>();
    } else {
      final prefs = ref.watch(sharedPreferencesBridge);
      final zhjwApi = ref.watch(zhjwApiServiceBridge);
      final scuAuthProvider = ref.watch(scuAuthProviderBridge);
      final scuAuthService = ref.watch(scuAuthBridge);
      final initialUserId = GradesProvider.confirmedUserIdentity(
        isLoggedIn: scuAuthProvider.isLoggedIn,
        principal: scuAuthService.principal,
      );
      provider = GradesProvider(prefs, zhjwApi, initialUserId: initialUserId);
      ref.listen(scuAuthProviderBridge, (prev, next) {
        provider.setUserIdentity(
          GradesProvider.confirmedUserIdentity(
            isLoggedIn: next.isLoggedIn,
            principal: ref.read(scuAuthBridge).principal,
          ),
        );
      });
      ref.onDispose(provider.dispose);
    }

    void listener() {
      state = provider;
    }

    provider.addListener(listener);
    ref.onDispose(() => provider.removeListener(listener));

    return provider;
  }

  Future<void> refreshSchemeScores() => state.refreshSchemeScores();
  Future<void> refreshPassingScores() => state.refreshPassingScores();
  void selectScheme(SchemeScoreSummary scheme) => state.selectScheme(scheme);
  void clearSchemeError() => state.clearSchemeError();
  void clearPassingError() => state.clearPassingError();
  void setUserIdentity(String? userId) => state.setUserIdentity(userId);
}

@Riverpod(keepAlive: true)
class GraduateGradesNotifier extends _$GraduateGradesNotifier {
  @override
  bool updateShouldNotify(
    GraduateGradesProvider previous,
    GraduateGradesProvider next,
  ) =>
      true;

  @override
  GraduateGradesProvider build() {
    final GraduateGradesProvider provider;
    if (getIt.isRegistered<GraduateGradesProvider>()) {
      provider = getIt<GraduateGradesProvider>();
    } else {
      final gsApi = ref.watch(gsApiServiceBridge);
      provider = GraduateGradesProvider(gsApi);
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
PassingScoreResult? passingScores(Ref ref) {
  return ref.watch(gradesProvider).passingScores;
}

@Riverpod(keepAlive: true)
SchemeScoreSummary? schemeScores(Ref ref) {
  return ref.watch(gradesProvider).schemeScores;
}

@Riverpod(keepAlive: true)
List<SchemeScoreSummary> schemeScoresList(Ref ref) {
  return ref.watch(gradesProvider).schemes;
}

@Riverpod(keepAlive: true)
GraduateGradesStats? graduateGradesStats(Ref ref) {
  return ref.watch(graduateGradesProvider).stats;
}

@Riverpod(keepAlive: true)
List<GraduateGradeRow> graduateGradeRows(Ref ref) {
  return ref.watch(graduateGradesProvider).rows;
}
