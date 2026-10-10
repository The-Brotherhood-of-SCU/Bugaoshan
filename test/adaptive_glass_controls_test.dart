import 'dart:async';

import 'package:bugaoshan/injection/injector.dart';
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

Widget _button({
  String label = 'Save',
  VoidCallback? onPressed,
  VoidCallback? fallbackCallback,
  bool loading = false,
}) => AdaptiveGlassButton(
  label: label,
  onPressed: onPressed,
  loading: loading,
  fallback: FilledButton(
    onPressed: fallbackCallback ?? onPressed,
    child: Text(label),
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
    'macOS controls use AppKit and retain controlled values and disabled guards',
    (tester) async {
      bridge.install();
      var presses = 0;
      final changes = <bool>[];
      await tester.pumpWidget(
        _host(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _button(onPressed: () => presses++),
              AdaptiveGlassSwitch(
                value: false,
                onChanged: changes.add,
                semanticLabel: 'Reminders',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(AppKitView), findsNWidgets(2));
      expect(find.byType(UiKitView), findsNothing);
      expect(bridge.supportChecks, 1);
      final buttonId = bridge.creations.entries
          .firstWhere((entry) => entry.value['kind'] == 'button')
          .key;
      final switchId = bridge.creations.entries
          .firstWhere((entry) => entry.value['kind'] == 'switch')
          .key;
      await bridge.send(buttonId, 'activate');
      await bridge.send(switchId, 'change', true);
      await tester.pumpAndSettle();
      expect(presses, 1);
      expect(changes, [true]);
      expect(bridge.updates[switchId]!.last['value'], false);
      await tester.pumpWidget(
        _host(
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _button(onPressed: null),
              AdaptiveGlassSwitch(
                value: false,
                onChanged: null,
                semanticLabel: 'Reminders',
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      await bridge.send(buttonId, 'activate');
      await bridge.send(switchId, 'change', true);
      expect(presses, 1);
      expect(changes, [true]);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  for (final platform in [TargetPlatform.android, TargetPlatform.linux]) {
    testWidgets(
      '$platform controls keep working without contacting native code',
      (tester) async {
        bridge.install();
        var presses = 0;
        final changes = <bool>[];
        await tester.pumpWidget(
          _host(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _button(onPressed: () => presses++),
                AdaptiveGlassSwitchListTile(
                  value: false,
                  onChanged: changes.add,
                  title: const Text('Notifications'),
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(bridge.supportChecks, 0);
        expect(bridge.creations, isEmpty);
        expect(find.byType(UiKitView), findsNothing);
        expect(find.byType(SwitchListTile), findsOneWidget);
        await tester.tap(find.text('Save'));
        await tester.tap(find.text('Notifications'));
        expect(presses, 1);
        expect(changes, [true]);
      },
      variant: TargetPlatformVariant.only(platform),
    );
  }

  for (final missing in [false, true]) {
    testWidgets(
      'iOS ${missing ? 'missing bridge' : 'old system'} shares fallback capability',
      (tester) async {
        bridge.install(supported: false, missing: missing);
        var presses = 0;
        final changes = <bool>[];
        await tester.pumpWidget(
          _host(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _button(onPressed: () => presses++),
                AdaptiveGlassSwitch(
                  value: false,
                  onChanged: changes.add,
                  semanticLabel: 'Reminders',
                ),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(bridge.supportChecks, 1);
        expect(bridge.creations, isEmpty);
        expect(find.byType(UiKitView), findsNothing);
        await tester.tap(find.text('Save'));
        await tester.tap(find.byType(Switch));
        expect(presses, 1);
        expect(changes, [true]);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  testWidgets(
    'button sends native appearance and current callback without recreation',
    (tester) async {
      bridge.install();
      var oldPresses = 0;
      var newPresses = 0;
      await tester.pumpWidget(_host(_button(onPressed: () => oldPresses++)));
      await tester.pumpAndSettle();
      final id = bridge.onlyId;
      final theme = ThemeData.dark();
      await tester.pumpWidget(
        _host(
          AdaptiveGlassButton(
            label: 'Continue',
            symbol: 'arrow.right',
            prominent: true,
            tint: Colors.orange,
            onPressed: () => newPresses++,
            fallback: FilledButton(
              onPressed: () => newPresses++,
              child: const Text('Continue'),
            ),
          ),
          theme: theme,
          direction: TextDirection.rtl,
          media: const MediaQueryData(
            size: Size(800, 600),
            disableAnimations: true,
            highContrast: true,
            textScaler: TextScaler.linear(1.5),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(bridge.creations, hasLength(1));
      expect(bridge.supportChecks, 1);
      expect(bridge.updates[id]!.last, {
        'kind': 'button',
        'label': 'Continue',
        'symbol': 'arrow.right',
        'value': false,
        'enabled': true,
        'loading': false,
        'style': 'prominent',
        'tint': Colors.orange.toARGB32(),
        'brightness': 'dark',
        'reduceMotion': true,
        'highContrast': true,
        'textScale': 1.5,
        'direction': 'rtl',
      });
      expect(
        tester.getSize(find.byType(UiKitView)).height,
        greaterThanOrEqualTo(44),
      );
      await bridge.send(id, 'activate');
      await bridge.send(id, 'activate', true);
      await bridge.send(id, 'change', true);
      await bridge.send(id, 'unknown');
      expect(oldPresses, 0);
      expect(newPresses, 1);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'large native button label and symbol outgrow the small Material fallback',
    (tester) async {
      bridge.install();
      const label = 'Save settings';
      const referenceLabelKey = Key('native-label-size-reference');
      Future<void> showAtScale(double scale) async {
        await tester.pumpWidget(
          _host(
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Independently laid out reference for the native Swift font.
                const Text(
                  label,
                  key: referenceLabelKey,
                  style: TextStyle(
                    inherit: false,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                AdaptiveGlassButton(
                  label: label,
                  symbol: 'checkmark',
                  onPressed: () {},
                  fallback: SizedBox(
                    width: 120,
                    height: 44,
                    child: FilledButton(
                      onPressed: () {},
                      child: const Text(
                        label,
                        style: TextStyle(fontSize: 14),
                        textScaler: TextScaler.noScaling,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            media: MediaQueryData(
              size: const Size(800, 600),
              textScaler: TextScaler.linear(scale),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      await showAtScale(1);
      final normalSize = tester.getSize(find.byType(UiKitView));
      await showAtScale(2);
      final largeSize = tester.getSize(find.byType(UiKitView));
      final labelSize = tester.getSize(find.byKey(referenceLabelKey));

      // UIKit needs 12pt at each side, plus a 24pt symbol and 8pt image gap.
      expect(largeSize.width, greaterThanOrEqualTo(labelSize.width + 56));
      expect(largeSize.height, greaterThanOrEqualTo(labelSize.height + 16));
      expect(largeSize.height, greaterThan(44));
      expect(largeSize.width, greaterThan(normalSize.width));
      expect(largeSize.height, greaterThan(normalSize.height));
      expect(bridge.creations, hasLength(1));
      expect(bridge.updates[bridge.onlyId]!.last['textScale'], 2);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  for (final native in [false, true]) {
    testWidgets(
      '${native ? 'native' : 'fallback'} button ignores disabled and loading input',
      (tester) async {
        bridge.install(supported: native);
        var presses = 0;
        for (final loading in [false, true]) {
          await tester.pumpWidget(
            _host(
              _button(
                onPressed: loading ? () => presses++ : null,
                loading: loading,
                // Deliberately active fallback proves wrapper blocks input.
                fallbackCallback: () => presses++,
              ),
            ),
          );
          await tester.pumpAndSettle();
          if (native) {
            await bridge.send(bridge.onlyId, 'activate');
            expect(bridge.updates[bridge.onlyId]!.last['enabled'], false);
            expect(bridge.updates[bridge.onlyId]!.last['loading'], loading);
          } else {
            await tester.tap(find.text('Save'), warnIfMissed: false);
          }
        }
        expect(presses, 0);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

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
      var presses = 0;
      await tester.pumpWidget(_host(_button(onPressed: () => presses++)));
      await tester.pumpAndSettle();
      final id = bridge.onlyId;
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(await bridge.send(id, 'activate'), isNull);
      expect(presses, 0);
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
      await tester.pumpWidget(_host(_button(onPressed: () {})));
      await tester.pumpWidget(const SizedBox.shrink());
      support.complete(true);
      await tester.pumpAndSettle();
      expect(bridge.creations, isEmpty);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );
}
