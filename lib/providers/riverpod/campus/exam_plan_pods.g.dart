// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'exam_plan_pods.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ExamPlanNotifier)
final examPlanProvider = ExamPlanNotifierProvider._();

final class ExamPlanNotifierProvider
    extends $AsyncNotifierProvider<ExamPlanNotifier, List<ExamInfo>> {
  ExamPlanNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'examPlanProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$examPlanNotifierHash();

  @$internal
  @override
  ExamPlanNotifier create() => ExamPlanNotifier();
}

String _$examPlanNotifierHash() => r'2281d140b3b07ba2f72472602914a78cb8f14ec0';

abstract class _$ExamPlanNotifier extends $AsyncNotifier<List<ExamInfo>> {
  FutureOr<List<ExamInfo>> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AsyncValue<List<ExamInfo>>, List<ExamInfo>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<List<ExamInfo>>, List<ExamInfo>>,
              AsyncValue<List<ExamInfo>>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
