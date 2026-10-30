// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'class_schedule_inquiry_pods.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ClassScheduleInquiryNotifier)
final classScheduleInquiryProvider = ClassScheduleInquiryNotifierProvider._();

final class ClassScheduleInquiryNotifierProvider
    extends
        $NotifierProvider<
          ClassScheduleInquiryNotifier,
          ClassScheduleInquiryState
        > {
  ClassScheduleInquiryNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'classScheduleInquiryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$classScheduleInquiryNotifierHash();

  @$internal
  @override
  ClassScheduleInquiryNotifier create() => ClassScheduleInquiryNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ClassScheduleInquiryState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ClassScheduleInquiryState>(value),
    );
  }
}

String _$classScheduleInquiryNotifierHash() =>
    r'c416551fdb9c54e2e1238267c2b1a9fc5ad25fa7';

abstract class _$ClassScheduleInquiryNotifier
    extends $Notifier<ClassScheduleInquiryState> {
  ClassScheduleInquiryState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<ClassScheduleInquiryState, ClassScheduleInquiryState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ClassScheduleInquiryState, ClassScheduleInquiryState>,
              ClassScheduleInquiryState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(ClassScheduleInquiryScheduleNotifier)
final classScheduleInquiryScheduleProvider =
    ClassScheduleInquiryScheduleNotifierFamily._();

final class ClassScheduleInquiryScheduleNotifierProvider
    extends
        $AsyncNotifierProvider<
          ClassScheduleInquiryScheduleNotifier,
          List<ClassScheduleInquiryItem>
        > {
  ClassScheduleInquiryScheduleNotifierProvider._({
    required ClassScheduleInquiryScheduleNotifierFamily super.from,
    required ({String planCode, String classCode}) super.argument,
  }) : super(
         retry: null,
         name: r'classScheduleInquiryScheduleProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() =>
      _$classScheduleInquiryScheduleNotifierHash();

  @override
  String toString() {
    return r'classScheduleInquiryScheduleProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  ClassScheduleInquiryScheduleNotifier create() =>
      ClassScheduleInquiryScheduleNotifier();

  @override
  bool operator ==(Object other) {
    return other is ClassScheduleInquiryScheduleNotifierProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$classScheduleInquiryScheduleNotifierHash() =>
    r'681adb03fc49609263b5920f481652c52d59c493';

final class ClassScheduleInquiryScheduleNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          ClassScheduleInquiryScheduleNotifier,
          AsyncValue<List<ClassScheduleInquiryItem>>,
          List<ClassScheduleInquiryItem>,
          FutureOr<List<ClassScheduleInquiryItem>>,
          ({String planCode, String classCode})
        > {
  ClassScheduleInquiryScheduleNotifierFamily._()
    : super(
        retry: null,
        name: r'classScheduleInquiryScheduleProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ClassScheduleInquiryScheduleNotifierProvider call({
    required String planCode,
    required String classCode,
  }) => ClassScheduleInquiryScheduleNotifierProvider._(
    argument: (planCode: planCode, classCode: classCode),
    from: this,
  );

  @override
  String toString() => r'classScheduleInquiryScheduleProvider';
}

abstract class _$ClassScheduleInquiryScheduleNotifier
    extends $AsyncNotifier<List<ClassScheduleInquiryItem>> {
  late final _$args = ref.$arg as ({String planCode, String classCode});
  String get planCode => _$args.planCode;
  String get classCode => _$args.classCode;

  FutureOr<List<ClassScheduleInquiryItem>> build({
    required String planCode,
    required String classCode,
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
      () => build(planCode: _$args.planCode, classCode: _$args.classCode),
    );
  }
}
