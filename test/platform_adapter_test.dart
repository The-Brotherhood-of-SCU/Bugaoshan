import 'package:bugaoshan/models/widget_appearance.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/course/export/schedule_image_export.dart';
import 'package:bugaoshan/platform/platform_adapter.dart';
import 'package:bugaoshan/services/reminder/reminder_transport.dart';
import 'package:bugaoshan/services/widget_update_service.dart';
import 'package:bugaoshan/utils/open_file.dart';
import 'package:bugaoshan/utils/platform_utils.dart';
import 'package:bugaoshan/widgets/adaptive/adaptive_glass_controls.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

class _OhosAdapter extends PlatformAdapter {
  int nativeViews = 0;
  String? openedPath;
  Uint8List? savedImage;

  @override
  bool get isOhos => true;

  @override
  bool get supportsNativeControls => true;

  @override
  Future<bool> saveImage(Uint8List bytes, {String? name}) async {
    savedImage = bytes;
    return true;
  }

  @override
  Future<OpenResult> openFile(String path) async {
    openedPath = path;
    return OpenResult(type: ResultType.done, message: 'done');
  }

  @override
  Widget createNativeControl({
    required String viewType,
    required TextDirection layoutDirection,
    required Map<String, Object> creationParams,
    required ValueChanged<int> onPlatformViewCreated,
    required Set<Factory<OneSequenceGestureRecognizer>> gestureRecognizers,
  }) {
    nativeViews++;
    return const SizedBox(key: ValueKey('ohos-control'));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const capabilities = MethodChannel('bugaoshan/liquid_glass');
  const widgets = MethodChannel('bugaoshan/update');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late PlatformAdapter original;

  setUp(() {
    original = PlatformAdapter.instance;
    LiquidGlassCapabilities.resetForTesting();
  });

  tearDown(() {
    PlatformAdapter.instance = original;
    debugDefaultTargetPlatformOverride = null;
    LiquidGlassCapabilities.resetForTesting();
    messenger.setMockMethodCallHandler(capabilities, null);
    messenger.setMockMethodCallHandler(widgets, null);
  });

  test('standard Flutter keeps platform defaults without OHOS plugins', () {
    PlatformAdapter.instance = PlatformAdapter();
    expect(isOhos, isFalse);
    expect(PlatformAdapter.instance.supportsNativeControls, isFalse);
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    expect(createReminderTransport(), isA<NoopReminderTransport>());
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    expect(createReminderTransport(), isA<MethodChannelReminderTransport>());
    expect(createReminderTransport().pendingLimit, isNull);
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    expect(createReminderTransport().pendingLimit, 64);
  });

  test('OHOS bootstrap selects reminder transport and 30-entry budget', () {
    PlatformAdapter.instance = _OhosAdapter();
    // A standard Flutter SDK can test the OHOS contract without its enum.
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    expect(isOhos, isTrue);
    expect(createReminderTransport(), isA<MethodChannelReminderTransport>());
    expect(createReminderTransport().pendingLimit, 30);
  });

  test('shared file opening dispatches to the selected host', () async {
    final adapter = _OhosAdapter();
    PlatformAdapter.instance = adapter;
    final result = await openFile('/example/course.ics');
    expect(result.type, ResultType.done);
    expect(adapter.openedPath, '/example/course.ics');
  });

  testWidgets(
    'OHOS enables schedule image export and routes gallery saving to its host',
    (tester) async {
      final adapter = _OhosAdapter();
      PlatformAdapter.instance = adapter;
      expect(isScheduleImageExportSupported, isTrue);
      await tester.pumpWidget(
        const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(),
        ),
      );
      await tester.pumpAndSettle();
      final context = tester.element(find.byType(Scaffold));
      final bytes = Uint8List.fromList([0x89, 0x50, 0x4e, 0x47]);
      final result = await saveScheduleImageToGallery(
        context: context,
        l10n: AppLocalizations.of(context)!,
        artifact: ScheduleImageArtifact(
          pngBytes: bytes,
          baseName: 'course',
          pixelWidth: 1,
          pixelHeight: 1,
          effectiveDpr: 1,
        ),
      );
      expect(result, ScheduleImageOutputStatus.success);
      expect(adapter.savedImage, same(bytes));
    },
  );

  test('OHOS card manager and appearance use the native card bridge', () async {
    PlatformAdapter.instance = _OhosAdapter();
    debugDefaultTargetPlatformOverride = TargetPlatform.linux;
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(widgets, (call) async {
      calls.add(call);
      return call.method == 'openCourseFormManager' ? true : null;
    });
    final service = WidgetUpdateService();
    addTearDown(service.dispose);
    expect(await service.openCourseFormManager(), isTrue);
    await service.syncWidgetShowTomorrow(true);
    await service.syncWidgetAppearance(
      colorStyle: WidgetColorStyle.values[1],
      density: WidgetDensity.values[1],
    );
    await service.updateWidgetData(force: true);
    expect(calls.map((call) => call.method), [
      'openCourseFormManager',
      'syncWidgetShowTomorrow',
      'syncWidgetAppearance',
      'updateWidget',
    ]);
    expect(calls[1].arguments, {'value': true});
    expect(calls[2].arguments, {'colorStyle': 1, 'density': 1});
  });

  testWidgets('OHOS switch uses injected view; slider keeps Flutter fallback', (
    tester,
  ) async {
    final adapter = _OhosAdapter();
    PlatformAdapter.instance = adapter;
    messenger.setMockMethodCallHandler(capabilities, (call) async => true);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              AdaptiveGlassSwitch(
                value: true,
                onChanged: (_) {},
                semanticLabel: 'Switch',
              ),
              AdaptiveGlassSlider(
                value: 0.5,
                onChanged: (_) {},
                semanticLabel: 'Slider',
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ohos-control')), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(adapter.nativeViews, greaterThan(0));
  });
}
