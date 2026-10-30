// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'course_curriculum_pods.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(CourseCurriculumNotifier)
final courseCurriculumProvider = CourseCurriculumNotifierProvider._();

final class CourseCurriculumNotifierProvider
    extends $NotifierProvider<CourseCurriculumNotifier, CourseCurriculumState> {
  CourseCurriculumNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'courseCurriculumProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$courseCurriculumNotifierHash();

  @$internal
  @override
  CourseCurriculumNotifier create() => CourseCurriculumNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(CourseCurriculumState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<CourseCurriculumState>(value),
    );
  }
}

String _$courseCurriculumNotifierHash() =>
    r'904c73678396ac140a8913620ed5004918e21b07';

abstract class _$CourseCurriculumNotifier
    extends $Notifier<CourseCurriculumState> {
  CourseCurriculumState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<CourseCurriculumState, CourseCurriculumState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<CourseCurriculumState, CourseCurriculumState>,
              CourseCurriculumState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(CourseCurriculumScheduleNotifier)
final courseCurriculumScheduleProvider =
    CourseCurriculumScheduleNotifierFamily._();

final class CourseCurriculumScheduleNotifierProvider
    extends
        $AsyncNotifierProvider<
          CourseCurriculumScheduleNotifier,
          List<ClassScheduleInquiryItem>
        > {
  CourseCurriculumScheduleNotifierProvider._({
    required CourseCurriculumScheduleNotifierFamily super.from,
    required ({String planCode, String courseCode, String courseSeq})
    super.argument,
  }) : super(
         retry: null,
         name: r'courseCurriculumScheduleProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$courseCurriculumScheduleNotifierHash();

  @override
  String toString() {
    return r'courseCurriculumScheduleProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  CourseCurriculumScheduleNotifier create() =>
      CourseCurriculumScheduleNotifier();

  @override
  bool operator ==(Object other) {
    return other is CourseCurriculumScheduleNotifierProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$courseCurriculumScheduleNotifierHash() =>
    r'6e67b57104015a5a1ded5ee3f0866b488806162c';

final class CourseCurriculumScheduleNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          CourseCurriculumScheduleNotifier,
          AsyncValue<List<ClassScheduleInquiryItem>>,
          List<ClassScheduleInquiryItem>,
          FutureOr<List<ClassScheduleInquiryItem>>,
          ({String planCode, String courseCode, String courseSeq})
        > {
  CourseCurriculumScheduleNotifierFamily._()
    : super(
        retry: null,
        name: r'courseCurriculumScheduleProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  CourseCurriculumScheduleNotifierProvider call({
    required String planCode,
    required String courseCode,
    required String courseSeq,
  }) => CourseCurriculumScheduleNotifierProvider._(
    argument: (
      planCode: planCode,
      courseCode: courseCode,
      courseSeq: courseSeq,
    ),
    from: this,
  );

  @override
  String toString() => r'courseCurriculumScheduleProvider';
}

abstract class _$CourseCurriculumScheduleNotifier
    extends $AsyncNotifier<List<ClassScheduleInquiryItem>> {
  late final _$args =
      ref.$arg as ({String planCode, String courseCode, String courseSeq});
  String get planCode => _$args.planCode;
  String get courseCode => _$args.courseCode;
  String get courseSeq => _$args.courseSeq;

  FutureOr<List<ClassScheduleInquiryItem>> build({
    required String planCode,
    required String courseCode,
    required String courseSeq,
  });
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<
              AsyncValue<List<ClassScheduleInquiryItem>>,
              List<ClassScheduleInquiryItem>
            >;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<List<ClassScheduleInquiryItem>>,
                List<ClassScheduleInquiryItem>
              >,
              AsyncValue<List<ClassScheduleInquiryItem>>,
              Object?,
              Object?
            >;
    return element.handleCreate(
      ref,
      () => build(
        planCode: _$args.planCode,
        courseCode: _$args.courseCode,
        courseSeq: _$args.courseSeq,
      ),
    );
  }
}
