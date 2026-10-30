// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'theme_color_pods.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ThemeColorNotifier)
final themeColorProvider = ThemeColorNotifierProvider._();

final class ThemeColorNotifierProvider
    extends $NotifierProvider<ThemeColorNotifier, ThemeColorState> {
  ThemeColorNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'themeColorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$themeColorNotifierHash();

  @$internal
  @override
  ThemeColorNotifier create() => ThemeColorNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ThemeColorState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ThemeColorState>(value),
    );
  }
}

String _$themeColorNotifierHash() =>
    r'527de396b46e47e7853a19aaaadf25dcde55c774';

abstract class _$ThemeColorNotifier extends $Notifier<ThemeColorState> {
  ThemeColorState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<ThemeColorState, ThemeColorState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<ThemeColorState, ThemeColorState>,
              ThemeColorState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
