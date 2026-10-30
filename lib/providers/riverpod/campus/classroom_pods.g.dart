// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'classroom_pods.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ClassroomIndexNotifier)
final classroomIndexProvider = ClassroomIndexNotifierProvider._();

final class ClassroomIndexNotifierProvider
    extends $AsyncNotifierProvider<ClassroomIndexNotifier, ClassroomIndexData> {
  ClassroomIndexNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'classroomIndexProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$classroomIndexNotifierHash();

  @$internal
  @override
  ClassroomIndexNotifier create() => ClassroomIndexNotifier();
}

String _$classroomIndexNotifierHash() =>
    r'401323fc66d930e0930f14a9c28b3d256d68a684';

abstract class _$ClassroomIndexNotifier
    extends $AsyncNotifier<ClassroomIndexData> {
  FutureOr<ClassroomIndexData> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<ClassroomIndexData>, ClassroomIndexData>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ClassroomIndexData>, ClassroomIndexData>,
              AsyncValue<ClassroomIndexData>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(ClassroomAvailabilityNotifier)
final classroomAvailabilityProvider = ClassroomAvailabilityNotifierFamily._();

final class ClassroomAvailabilityNotifierProvider
    extends
        $AsyncNotifierProvider<
          ClassroomAvailabilityNotifier,
          ClassroomQueryResult
        > {
  ClassroomAvailabilityNotifierProvider._({
    required ClassroomAvailabilityNotifierFamily super.from,
    required ({String campusNumber, String buildingNumber, String searchDate})
    super.argument,
  }) : super(
         retry: null,
         name: r'classroomAvailabilityProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$classroomAvailabilityNotifierHash();

  @override
  String toString() {
    return r'classroomAvailabilityProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  ClassroomAvailabilityNotifier create() => ClassroomAvailabilityNotifier();

  @override
  bool operator ==(Object other) {
    return other is ClassroomAvailabilityNotifierProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$classroomAvailabilityNotifierHash() =>
    r'b3690be01bd8f74c6d9bd30b4a328908a3ed860b';

final class ClassroomAvailabilityNotifierFamily extends $Family
    with
        $ClassFamilyOverride<
          ClassroomAvailabilityNotifier,
          AsyncValue<ClassroomQueryResult>,
          ClassroomQueryResult,
          FutureOr<ClassroomQueryResult>,
          ({String campusNumber, String buildingNumber, String searchDate})
        > {
  ClassroomAvailabilityNotifierFamily._()
    : super(
        retry: null,
        name: r'classroomAvailabilityProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ClassroomAvailabilityNotifierProvider call({
    required String campusNumber,
    required String buildingNumber,
    required String searchDate,
  }) => ClassroomAvailabilityNotifierProvider._(
    argument: (
      campusNumber: campusNumber,
      buildingNumber: buildingNumber,
      searchDate: searchDate,
    ),
    from: this,
  );

  @override
  String toString() => r'classroomAvailabilityProvider';
}

abstract class _$ClassroomAvailabilityNotifier
    extends $AsyncNotifier<ClassroomQueryResult> {
  late final _$args =
      ref.$arg
          as ({String campusNumber, String buildingNumber, String searchDate});
  String get campusNumber => _$args.campusNumber;
  String get buildingNumber => _$args.buildingNumber;
  String get searchDate => _$args.searchDate;

  FutureOr<ClassroomQueryResult> build({
    required String campusNumber,
    required String buildingNumber,
    required String searchDate,
  });
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref
            as $Ref<AsyncValue<ClassroomQueryResult>, ClassroomQueryResult>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                AsyncValue<ClassroomQueryResult>,
                ClassroomQueryResult
              >,
              AsyncValue<ClassroomQueryResult>,
              Object?,
              Object?
            >;
    return element.handleCreate(
      ref,
      () => build(
        campusNumber: _$args.campusNumber,
        buildingNumber: _$args.buildingNumber,
        searchDate: _$args.searchDate,
      ),
    );
  }
}
