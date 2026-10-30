// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'export_schedule_pods.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(exportSchedule)
final exportScheduleProvider = ExportScheduleFamily._();

final class ExportScheduleProvider
    extends
        $FunctionalProvider<
          legacy.ExportScheduleProvider,
          legacy.ExportScheduleProvider,
          legacy.ExportScheduleProvider
        >
    with $Provider<legacy.ExportScheduleProvider> {
  ExportScheduleProvider._({
    required ExportScheduleFamily super.from,
    required ({ScheduleConfig? overrideConfig, List<Course>? overrideCourses})
    super.argument,
  }) : super(
         retry: null,
         name: r'exportScheduleProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$exportScheduleHash();

  @override
  String toString() {
    return r'exportScheduleProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $ProviderElement<legacy.ExportScheduleProvider> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  legacy.ExportScheduleProvider create(Ref ref) {
    final argument =
        this.argument
            as ({
              ScheduleConfig? overrideConfig,
              List<Course>? overrideCourses,
            });
    return exportSchedule(
      ref,
      overrideConfig: argument.overrideConfig,
      overrideCourses: argument.overrideCourses,
    );
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(legacy.ExportScheduleProvider value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<legacy.ExportScheduleProvider>(
        value,
      ),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ExportScheduleProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$exportScheduleHash() => r'0c5e96c1838f424c09499fb62abb219c8b1df3cf';

final class ExportScheduleFamily extends $Family
    with
        $FunctionalFamilyOverride<
          legacy.ExportScheduleProvider,
          ({ScheduleConfig? overrideConfig, List<Course>? overrideCourses})
        > {
  ExportScheduleFamily._()
    : super(
        retry: null,
        name: r'exportScheduleProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ExportScheduleProvider call({
    ScheduleConfig? overrideConfig,
    List<Course>? overrideCourses,
  }) => ExportScheduleProvider._(
    argument: (
      overrideConfig: overrideConfig,
      overrideCourses: overrideCourses,
    ),
    from: this,
  );

  @override
  String toString() => r'exportScheduleProvider';
}
