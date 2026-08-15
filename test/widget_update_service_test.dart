import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_async/fake_async.dart';
import 'package:bugaoshan/models/widget_appearance.dart';
import 'package:bugaoshan/services/widget_update_service.dart';
import 'package:bugaoshan/utils/constants.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kUpdateMethodChannel, null);
  });

  test('debounce collapses repeated calls', () {
    fakeAsync((fa) {
      int calls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(kUpdateMethodChannel, (
            MethodCall call,
          ) async {
            calls++;
            return null;
          });

      final service = WidgetUpdateService(
        debounceDuration: Duration(milliseconds: 40),
        platformChecker: () => true,
      );
      service.updateWidgetData();
      service.updateWidgetData();

      // Advance time past debounce
      fa.elapse(Duration(milliseconds: 120));
      fa.flushMicrotasks();

      expect(calls, 1);
      service.dispose();
    });
  });

  test('force triggers immediate run', () async {
    int calls = 0;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kUpdateMethodChannel, (
          MethodCall call,
        ) async {
          calls++;
          return null;
        });

    final service = WidgetUpdateService(platformChecker: () => true);
    final future = service.updateWidgetData(force: true);
    await future;
    expect(calls, 1);
    service.dispose();
  });

  test('in-flight triggers exactly one follow-up run', () async {
    int calls = 0;
    final block = Completer<void>();
    final started = Completer<void>();

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kUpdateMethodChannel, (
          MethodCall call,
        ) async {
          calls++;
          if (!started.isCompleted) started.complete();
          if (calls == 1) {
            // block the first invocation until we schedule the follow-up
            await block.future;
          }
          return null;
        });

    final service = WidgetUpdateService(platformChecker: () => true);
    final first = service.updateWidgetData(force: true);

    // Wait until the native handler has started so _inFlight is true
    await started.future;

    // Request another update while in-flight (force immediate path sets _needsRunAgain)
    service.updateWidgetData(force: true);

    // Unblock the first native call
    block.complete();

    // Wait for the first to finish
    await first;

    // Wait a little to allow follow-up run to execute
    await Future.delayed(Duration(milliseconds: 50));

    expect(calls, 2);
    service.dispose();
  });

  test('errors complete waiting callers', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kUpdateMethodChannel, (
          MethodCall call,
        ) async {
          throw PlatformException(code: 'ERR', message: 'failed');
        });

    final service = WidgetUpdateService(platformChecker: () => true);
    final future = service.updateWidgetData(force: true);
    try {
      await future;
      fail('Expected exception');
    } catch (e) {
      expect(e, isA<PlatformException>());
    }
    service.dispose();
  });

  test('dispose completes pending futures with StateError', () async {
    final block = Completer<void>();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kUpdateMethodChannel, (
          MethodCall call,
        ) async {
          // never completes to simulate long-running native call
          await block.future;
          return null;
        });

    final service = WidgetUpdateService(
      debounceDuration: Duration(milliseconds: 50),
      platformChecker: () => true,
    );
    final future = service.updateWidgetData();

    // Dispose before debounce timer fires
    await Future.delayed(Duration(milliseconds: 10));
    service.dispose();

    try {
      await future;
      fail('Expected StateError');
    } catch (e) {
      expect(e, isA<StateError>());
    }
  });

  test('onWidgetPinned forwards native callback events', () async {
    final service = WidgetUpdateService(platformChecker: () => true);
    final events = <String>[];
    final sub = service.onWidgetPinned.listen(events.add);

    // 模拟原生侧通过 channel 推送 pin 成功事件
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          kUpdateMethodChannel.name,
          const StandardMethodCodec().encodeMethodCall(
            const MethodCall('onWidgetPinned', {'size': 'small'}),
          ),
          (data) {},
        );
    await pumpEventQueue();

    expect(events, ['small']);
    await sub.cancel();
    service.dispose();
  });

  test('syncWidgetAppearance forwards both iOS style settings', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    MethodCall? receivedCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(kUpdateMethodChannel, (call) async {
          receivedCall = call;
          return null;
        });

    final service = WidgetUpdateService(platformChecker: () => true);
    await service.syncWidgetAppearance(
      colorStyle: WidgetColorStyle.monochrome,
      density: WidgetDensity.compact,
    );

    expect(receivedCall?.method, 'syncWidgetAppearance');
    expect(receivedCall?.arguments, {
      'colorStyle': WidgetColorStyle.monochrome.index,
      'density': WidgetDensity.compact.index,
    });
    service.dispose();
  });
}
