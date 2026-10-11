import 'dart:async';

import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/pages/auth/scu_login_button.dart';
import 'package:bugaoshan/widgets/adaptive/adaptive_glass_controls.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _capabilities = MethodChannel('bugaoshan/liquid_glass');
const _viewType = 'bugaoshan/liquid_glass_control';

Widget _host(
  Widget child, {
  ThemeData? theme,
  MediaQueryData media = const MediaQueryData(size: Size(800, 600)),
  TextDirection direction = TextDirection.ltr,
}) => MaterialApp(
  theme: theme,
  home: MediaQuery(
    data: media,
    child: Directionality(
      textDirection: direction,
      child: Scaffold(body: Center(child: child)),
    ),
  ),
);

class _NativeControlsBridge {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final creations = <int, Map<Object?, Object?>>{};
  final updates = <int, List<Map<Object?, Object?>>>{};
  final disposed = <int>[];
  int supportChecks = 0;
  bool failUpdates = false;

  int get onlyId => creations.keys.single;

  void install({
    bool supported = true,
    bool missing = false,
    Completer<bool>? delayedSupport,
  }) {
    messenger.setMockMethodCallHandler(_capabilities, (call) async {
      expect(call.method, 'isSupported');
      supportChecks++;
      if (missing) throw MissingPluginException();
      return delayedSupport == null ? supported : await delayedSupport.future;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final arguments = call.arguments as Map<Object?, Object?>;
        expect(arguments['viewType'], _viewType);
        final id = arguments['id'] as int;
        creations[id] =
            const StandardMessageCodec().decodeMessage(
                  ByteData.sublistView(arguments['params'] as Uint8List),
                )
                as Map<Object?, Object?>;
        updates[id] = [];
        messenger.setMockMethodCallHandler(MethodChannel('$_viewType/$id'), (
          call,
        ) async {
          expect(call.method, 'update');
          if (failUpdates) throw PlatformException(code: 'view_unavailable');
          updates[id]!.add(call.arguments as Map<Object?, Object?>);
          return null;
        });
      } else if (call.method == 'dispose') {
        disposed.add(call.arguments as int);
      }
      return null;
    });
  }

  Future<ByteData?> send(int id, String method, [Object? arguments]) async {
    ByteData? response;
    await messenger.handlePlatformMessage(
      '$_viewType/$id',
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(method, arguments),
      ),
      (data) => response = data,
    );
    return response;
  }

  void uninstall() {
    messenger.setMockMethodCallHandler(_capabilities, null);
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, null);
    for (final id in creations.keys) {
      messenger.setMockMethodCallHandler(MethodChannel('$_viewType/$id'), null);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _NativeControlsBridge bridge;

  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    LiquidGlassCapabilities.resetForTesting();
    bridge = _NativeControlsBridge();
  });

  tearDown(() async {
    bridge.uninstall();
    LiquidGlassCapabilities.resetForTesting();
    await getIt.reset();
  });

  testWidgets(
    'switch uses current value and callback and restores rejected changes',
    (tester) async {
      bridge.install();
      final oldChanges = <bool>[];
      final changes = <bool>[];
      await tester.pumpWidget(
        _host(
          AdaptiveGlassSwitch(
            value: false,
            onChanged: oldChanges.add,
            semanticLabel: 'Old label',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final id = bridge.onlyId;
      await tester.pumpWidget(
        _host(
          AdaptiveGlassSwitch(
            value: true,
            onChanged: changes.add,
            semanticLabel: 'New label',
            activeColor: Colors.green,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(bridge.creations, hasLength(1));
      expect(bridge.updates[id]!.last['value'], true);
      expect(bridge.updates[id]!.last['label'], 'New label');
      expect(bridge.updates[id]!.last['tint'], Colors.green.toARGB32());
      await bridge.send(id, 'change', true);
      await bridge.send(id, 'change', 'false');
      await bridge.send(id, 'activate');
      expect(changes, isEmpty);
      await bridge.send(id, 'change', false);
      await tester.pumpAndSettle();
      expect(changes, [false]);
      expect(oldChanges, isEmpty);
      // Parent did not accept false: native must receive authoritative true.
      expect(bridge.updates[id]!.last['value'], true);
      await tester.pumpWidget(
        _host(
          AdaptiveGlassSwitch(
            value: false,
            onChanged: changes.add,
            semanticLabel: 'New label',
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(bridge.updates[id]!.last['value'], false);
      await bridge.send(id, 'change', false);
      expect(changes, [false]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'native switch tap does not also activate the containing tile',
    (tester) async {
      bridge.install();
      final changes = <bool>[];
      await tester.pumpWidget(
        _host(
          AdaptiveGlassSwitchListTile(
            value: false,
            onChanged: changes.add,
            title: const Text('Notifications'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final id = bridge.onlyId;
      expect(bridge.creations[id]!['label'], 'Notifications');
      await tester.tap(find.byType(UiKitView));
      await tester.pumpAndSettle();
      expect(
        changes,
        isEmpty,
        reason: 'UIKit owns the switch tap; ListTile must not toggle too',
      );
      await bridge.send(id, 'change', true);
      expect(changes, [true]);
      await tester.tap(find.text('Notifications'));
      expect(changes, [true, true], reason: 'A separate row tap still works');
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'vertical drag beginning on native switch still scrolls its settings list',
    (tester) async {
      bridge.install();
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final changes = <bool>[];
      await tester.pumpWidget(
        _host(
          ListView(
            controller: controller,
            children: [
              const SizedBox(height: 240),
              AdaptiveGlassSwitchListTile(
                value: false,
                onChanged: changes.add,
                title: const Text('Notifications'),
              ),
              const SizedBox(height: 1000),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(UiKitView), const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(100));
      expect(changes, isEmpty);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'disabled native switch and tile ignore pending native and row events',
    (tester) async {
      bridge.install();
      final changes = <bool>[];
      await tester.pumpWidget(
        _host(
          AdaptiveGlassSwitchListTile(
            value: false,
            onChanged: changes.add,
            title: const Text('Notifications'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final id = bridge.onlyId;
      await tester.pumpWidget(
        _host(
          const AdaptiveGlassSwitchListTile(
            value: false,
            onChanged: null,
            title: Text('Notifications'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(bridge.updates[id]!.last['enabled'], false);
      await bridge.send(id, 'change', true);
      await tester.tap(find.text('Notifications'));
      expect(changes, isEmpty);
      expect(bridge.creations, hasLength(1));
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'native update failure restores a working fallback and detaches events',
    (tester) async {
      bridge.install();
      final changes = <bool>[];
      await tester.pumpWidget(
        _host(
          AdaptiveGlassSwitchListTile(
            value: false,
            onChanged: changes.add,
            title: const Text('Notifications'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final id = bridge.onlyId;
      bridge.failUpdates = true;
      await tester.pumpWidget(
        _host(
          AdaptiveGlassSwitchListTile(
            value: true,
            onChanged: changes.add,
            title: const Text('Notifications'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(UiKitView), findsNothing);
      expect(find.byType(SwitchListTile), findsOneWidget);
      expect(
        tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        true,
      );
      expect(await bridge.send(id, 'change', false), isNull);
      await tester.tap(find.text('Notifications'));
      expect(changes, [false]);
      expect(bridge.disposed, [id]);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'disposed controls detach native callbacks',
    (tester) async {
      bridge.install();
      final changes = <bool>[];
      await tester.pumpWidget(
        _host(
          AdaptiveGlassSwitch(
            value: false,
            onChanged: changes.add,
            semanticLabel: 'Switch',
          ),
        ),
      );
      await tester.pumpAndSettle();
      final id = bridge.onlyId;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(await bridge.send(id, 'change', true), isNull);
      expect(changes, isEmpty);
      expect(bridge.disposed, [id]);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'late support response cannot create a disposed platform view',
    (tester) async {
      final support = Completer<bool>();
      bridge.install(delayedSupport: support);
      await tester.pumpWidget(
        _host(
          AdaptiveGlassSwitch(
            value: false,
            onChanged: (_) {},
            semanticLabel: 'Switch',
          ),
        ),
      );
      await tester.pumpWidget(const SizedBox.shrink());
      support.complete(true);
      await tester.pumpAndSettle();
      expect(bridge.creations, isEmpty);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
  for (final platform in [TargetPlatform.iOS, TargetPlatform.macOS]) {
    testWidgets(
      'native slider preserves discrete values and gesture callbacks on $platform',
      (tester) async {
        bridge.install();
        final changes = <double>[];
        final starts = <double>[];
        final ends = <double>[];
        var value = 0.5;
        await tester.pumpWidget(
          _host(
            StatefulBuilder(
              builder: (context, setState) => AdaptiveGlassSlider(
                value: value,
                min: 0.3,
                max: 1,
                divisions: 14,
                semanticLabel: 'Opacity',
                onChanged: (v) {
                  changes.add(v);
                  setState(() => value = v);
                },
                onChangeStart: starts.add,
                onChangeEnd: ends.add,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final id = bridge.onlyId;
        expect(bridge.creations[id]!['kind'], 'slider');
        expect(bridge.creations[id]!['divisions'], 14);
        expect(find.byType(Slider), findsNothing);
        expect(
          find.byType(platform == TargetPlatform.iOS ? UiKitView : AppKitView),
          findsOneWidget,
        );
        await bridge.send(id, 'changeStart', 0.5);
        await bridge.send(id, 'changeStart', 0.5);
        await bridge.send(id, 'change', 0.699999988);
        await tester.pumpAndSettle();
        expect(changes, hasLength(1));
        expect(value, closeTo(0.7, 0.000001));
        await bridge.send(id, 'change', 0.699999988);
        await bridge.send(id, 'changeEnd', 0.699999988);
        await bridge.send(id, 'changeEnd', 0.699999988);
        await tester.pumpAndSettle();
        expect(
          changes,
          hasLength(1),
          reason: 'Accepted echo must not replay callbacks',
        );
        expect(starts, [0.5]);
        expect(ends.single, closeTo(0.7, 0.000001));
        expect(bridge.creations, hasLength(1));
        expect(bridge.updates[id]!.last['value'], closeTo(0.7, 0.000001));
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }

  testWidgets(
    'slider rejects malformed events, restores declined values and ignores disabled input',
    (tester) async {
      bridge.install();
      final changes = <double>[];
      final starts = <double>[];
      final ends = <double>[];
      Future<void> show(bool enabled) async {
        await tester.pumpWidget(
          _host(
            AdaptiveGlassSlider(
              value: 12,
              min: 8,
              max: 20,
              divisions: 12,
              semanticLabel: 'Font size',
              onChanged: enabled ? changes.add : null,
              onChangeStart: starts.add,
              onChangeEnd: ends.add,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(true);
      final id = bridge.onlyId;
      for (final bad in <Object>[
        double.nan,
        double.infinity,
        -1,
        30,
        true,
        '14',
      ]) {
        await bridge.send(id, 'change', bad);
      }
      await bridge.send(id, 'activate', 14);
      expect(changes, isEmpty);
      await bridge.send(id, 'change', 14.0000001);
      await tester.pumpAndSettle();
      expect(changes, [14]);
      expect(bridge.updates[id]!.last['value'], 12);
      await show(false);
      await bridge.send(id, 'changeStart', 12);
      await bridge.send(id, 'change', 15);
      await bridge.send(id, 'changeEnd', 15);
      expect(changes, [14]);
      expect(starts, isEmpty);
      expect(ends, isEmpty);
      expect(bridge.updates[id]!.last['enabled'], false);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final platform in [
    TargetPlatform.android,
    TargetPlatform.linux,
    TargetPlatform.iOS,
  ]) {
    testWidgets(
      'unavailable native controls keep Material behavior on $platform',
      (tester) async {
        bridge.install(supported: false);
        final changes = <double>[];
        final toggles = <bool>[];
        await tester.pumpWidget(
          _host(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AdaptiveGlassSlider(
                  value: 0.5,
                  semanticLabel: 'Opacity',
                  onChanged: changes.add,
                ),
                AdaptiveGlassSwitchListTile(
                  value: false,
                  onChanged: toggles.add,
                  title: const Text('Reminders'),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(bridge.creations, isEmpty);
        expect(bridge.supportChecks, platform == TargetPlatform.iOS ? 1 : 0);
        expect(find.byType(Slider), findsOneWidget);
        await tester.tap(find.text('Reminders'));
        await tester.drag(find.byType(Slider), const Offset(100, 0));
        expect(toggles, [true]);
        expect(changes, isNotEmpty);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }

  testWidgets(
    'slider update failure falls back with its latest controlled value',
    (tester) async {
      bridge.install();
      final changes = <double>[];
      Future<void> show(double value) async {
        await tester.pumpWidget(
          _host(
            AdaptiveGlassSlider(
              value: value,
              semanticLabel: 'Opacity',
              onChanged: changes.add,
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await show(0.3);
      final id = bridge.onlyId;
      bridge.failUpdates = true;
      await show(0.8);
      expect(tester.widget<Slider>(find.byType(Slider)).value, 0.8);
      expect(await bridge.send(id, 'change', 0.2), isNull);
      expect(changes, isEmpty);
      expect(bridge.disposed, [id]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'vertical drag on slider scrolls the list without changing settings',
    (tester) async {
      bridge.install();
      final controller = ScrollController();
      addTearDown(controller.dispose);
      final changes = <double>[];
      await tester.pumpWidget(
        _host(
          ListView(
            controller: controller,
            children: [
              const SizedBox(height: 240),
              AdaptiveGlassSlider(
                value: 0.5,
                semanticLabel: 'Opacity',
                onChanged: changes.add,
              ),
              const SizedBox(height: 1000),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(UiKitView), const Offset(0, -180));
      await tester.pumpAndSettle();
      expect(controller.offset, greaterThan(100));
      expect(changes, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'login action remains a normal full-width button even when glass is supported',
    (tester) async {
      bridge.install();
      var presses = 0;
      Future<void> show(bool loading) async {
        await tester.pumpWidget(
          _host(
            ScuLoginButton(
              loading: loading,
              onPressed: () => presses++,
              brandColor: Colors.blue,
              label: 'Login',
            ),
          ),
        );
        await tester.pumpAndSettle(
          const Duration(milliseconds: 100),
          EnginePhase.sendSemanticsUpdate,
          const Duration(seconds: 1),
        );
      }

      await show(false);
      expect(find.byType(FilledButton), findsOneWidget);
      expect(bridge.creations, isEmpty);
      expect(bridge.supportChecks, 0);
      await tester.tap(find.text('Login'));
      expect(presses, 1);
      await tester.pumpWidget(
        _host(
          ScuLoginButton(
            loading: true,
            onPressed: () => presses++,
            brandColor: Colors.blue,
            label: 'Login',
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull,
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
