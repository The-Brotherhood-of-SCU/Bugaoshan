import 'package:bugaoshan/injection/injector.dart';
import 'package:bugaoshan/widgets/navigation/adaptive_home_dock.dart';
import 'package:bugaoshan/widgets/navigation/home_dock_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _capabilities = MethodChannel('bugaoshan/liquid_glass');
const _viewType = 'bugaoshan/liquid_glass_dock';
const _destinations = [
  HomeDockDestination(
    id: 'course',
    label: 'Courses',
    icon: Icons.calendar_today_outlined,
    selectedIcon: Icons.calendar_today,
    symbol: 'calendar',
    selectedSymbol: 'calendar',
  ),
  HomeDockDestination(
    id: 'campus',
    label: 'Campus',
    icon: Icons.school_outlined,
    selectedIcon: Icons.school,
    symbol: 'building.2',
    selectedSymbol: 'building.2.fill',
  ),
  HomeDockDestination(
    id: 'profile',
    label: 'Profile',
    icon: Icons.person_outline,
    selectedIcon: Icons.person,
    symbol: 'person',
    selectedSymbol: 'person.fill',
  ),
];

Widget _host({
  List<HomeDockDestination> destinations = _destinations,
  int selectedIndex = 0,
  Axis axis = Axis.horizontal,
  ValueChanged<int>? onSelected,
  ValueChanged<bool>? onNativeModeChanged,
  ThemeData? theme,
  MediaQueryData media = const MediaQueryData(size: Size(800, 600)),
  TextDirection direction = TextDirection.ltr,
}) => MaterialApp(
  theme: theme,
  home: MediaQuery(
    data: media,
    child: Directionality(
      textDirection: direction,
      child: Align(
        alignment: Alignment.bottomCenter,
        child: AdaptiveHomeDock(
          destinations: destinations,
          selectedIndex: selectedIndex,
          axis: axis,
          onDestinationSelected: onSelected ?? (_) {},
          onNativeModeChanged: onNativeModeChanged,
        ),
      ),
    ),
  ),
);

/// Exercises the real UiKitView creation and both directions of the channel.
class _NativeDockBridge {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final creations = <Map<Object?, Object?>>[];
  final updates = <Map<Object?, Object?>>[];
  final viewIds = <int>[];
  final disposedViewIds = <int>[];
  int supportChecks = 0;
  bool failUpdates = false;

  void install({bool supported = true, bool missing = false}) {
    messenger.setMockMethodCallHandler(_capabilities, (call) async {
      expect(call.method, 'isSupported');
      supportChecks++;
      if (missing) throw MissingPluginException();
      return supported;
    });
    messenger.setMockMethodCallHandler(SystemChannels.platform_views, (
      call,
    ) async {
      if (call.method == 'create') {
        final arguments = call.arguments as Map<Object?, Object?>;
        expect(arguments['viewType'], _viewType);
        final id = arguments['id'] as int;
        viewIds.add(id);
        creations.add(
          const StandardMessageCodec().decodeMessage(
                ByteData.sublistView(arguments['params'] as Uint8List),
              )
              as Map<Object?, Object?>,
        );
        messenger.setMockMethodCallHandler(MethodChannel('$_viewType/$id'), (
          call,
        ) async {
          expect(call.method, 'update');
          if (failUpdates) throw PlatformException(code: 'view_unavailable');
          updates.add(call.arguments as Map<Object?, Object?>);
          return null;
        });
      } else if (call.method == 'dispose') {
        disposedViewIds.add(call.arguments as int);
      }
      return null;
    });
  }

  Future<ByteData?> send(String method, Object? arguments) async {
    ByteData? response;
    await messenger.handlePlatformMessage(
      '$_viewType/${viewIds.last}',
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
    for (final id in viewIds) {
      messenger.setMockMethodCallHandler(MethodChannel('$_viewType/$id'), null);
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _NativeDockBridge bridge;

  setUp(() async {
    await getIt.reset();
    SharedPreferences.setMockInitialValues({});
    bridge = _NativeDockBridge();
  });

  tearDown(() async {
    bridge.uninstall();
    await getIt.reset();
  });

  for (final axis in Axis.values) {
    testWidgets(
      'macOS native navigation preserves stable IDs with $axis layout',
      (tester) async {
        bridge.install();
        final selected = <int>[];
        await tester.pumpWidget(_host(axis: axis, onSelected: selected.add));
        await tester.pumpAndSettle();
        expect(find.byType(AppKitView), findsOneWidget);
        expect(find.byType(UiKitView), findsNothing);
        expect(bridge.creations.single['axis'], axis.name);
        await bridge.send('select', 'profile');
        await bridge.send('select', 'removed-destination');
        expect(selected, [2]);
        bridge.failUpdates = true;
        await tester.pumpWidget(
          _host(axis: axis, selectedIndex: 1, onSelected: selected.add),
        );
        await tester.pumpAndSettle();
        expect(find.byType(AppKitView), findsNothing);
        expect(
          find.byType(axis == Axis.vertical ? NavigationRail : NavigationBar),
          findsOneWidget,
        );
        await tester.tap(find.text('Profile'));
        expect(selected, [2, 2]);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    );
  }

  testWidgets(
    'non-iOS navigation never contacts the native bridge',
    (tester) async {
      bridge.install();
      final selections = <int>[];
      await tester.pumpWidget(_host(onSelected: selections.add));
      await tester.pumpAndSettle();

      expect(bridge.supportChecks, 0);
      expect(bridge.viewIds, isEmpty);
      expect(find.byType(NavigationBar), findsOneWidget);
      await tester.tap(find.text('Campus'));
      expect(selections, [1]);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );

  for (final missing in [false, true]) {
    testWidgets(
      'iOS keeps working with ${missing ? 'a missing bridge' : 'unsupported glass'}',
      (tester) async {
        bridge.install(supported: false, missing: missing);
        final selections = <int>[];
        await tester.pumpWidget(_host(onSelected: selections.add));
        await tester.pumpAndSettle();

        expect(bridge.supportChecks, 1);
        expect(bridge.viewIds, isEmpty);
        expect(find.byType(UiKitView), findsNothing);
        await tester.tap(find.text('Profile'));
        expect(selections, [2]);
        expect(tester.takeException(), isNull);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  for (final missing in [false, true]) {
    testWidgets(
      'recreated dock clears native layout mode when support ${missing ? 'fails' : 'is unavailable'}',
      (tester) async {
        bridge.install();
        var nativeMode = false;
        await tester.pumpWidget(
          _host(onNativeModeChanged: (native) => nativeMode = native),
        );
        await tester.pumpAndSettle();
        expect(nativeMode, isTrue);

        // Home retains its mode while the dock is hidden by the keyboard/rail.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();
        bridge.install(supported: false, missing: missing);
        await tester.pumpWidget(
          _host(onNativeModeChanged: (native) => nativeMode = native),
        );
        await tester.pumpAndSettle();

        expect(nativeMode, isFalse);
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byType(UiKitView), findsNothing);
      },
      variant: TargetPlatformVariant.only(TargetPlatform.iOS),
    );
  }

  testWidgets(
    'native dock fills the bottom edge and receives theme and accessibility',
    (tester) async {
      bridge.install();
      final nativeModes = <bool>[];
      final theme = ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.purple,
          brightness: Brightness.dark,
        ),
      );
      await tester.pumpWidget(
        _host(
          theme: theme,
          selectedIndex: 1,
          onNativeModeChanged: nativeModes.add,
          direction: TextDirection.rtl,
          media: const MediaQueryData(
            size: Size(800, 600),
            padding: EdgeInsets.only(bottom: 34),
            viewPadding: EdgeInsets.only(bottom: 34),
            textScaler: TextScaler.linear(1.5),
            disableAnimations: true,
            highContrast: true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(NavigationBar), findsNothing);
      expect(nativeModes, [true]);
      expect(bridge.creations, hasLength(1));
      final parameters = bridge.creations.single;
      expect(parameters['selectedId'], 'campus');
      expect(parameters['tint'], theme.colorScheme.primary.toARGB32());
      expect(parameters['brightness'], 'dark');
      expect(parameters['reduceMotion'], true);
      expect(parameters['highContrast'], true);
      expect(parameters['textScale'], 1.5);
      expect(parameters['direction'], 'rtl');
      expect(parameters['items'], [
        {
          'id': 'course',
          'label': 'Courses',
          'symbol': 'calendar',
          'selectedSymbol': 'calendar',
          'badge': false,
          'badgeLabel': '',
        },
        {
          'id': 'campus',
          'label': 'Campus',
          'symbol': 'building.2',
          'selectedSymbol': 'building.2.fill',
          'badge': false,
          'badgeLabel': '',
        },
        {
          'id': 'profile',
          'label': 'Profile',
          'symbol': 'person',
          'selectedSymbol': 'person.fill',
          'badge': false,
          'badgeLabel': '',
        },
      ]);
      final bounds = tester.getRect(find.byType(UiKitView));
      expect(bounds.left, 0);
      expect(bounds.right, 800);
      expect(bounds.bottom, 600);
      expect(bounds.height, 122);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'updates selection, destinations and badge without recreating',
    (tester) async {
      bridge.install();
      await tester.pumpWidget(_host());
      await tester.pumpAndSettle();
      const updatedProfile = HomeDockDestination(
        id: 'profile',
        label: 'Me',
        icon: Icons.person_outline,
        selectedIcon: Icons.person,
        symbol: 'person',
        selectedSymbol: 'person.fill',
        showBadge: true,
        badgeLabel: 'Update available',
      );
      await tester.pumpWidget(
        _host(destinations: [updatedProfile, _destinations[0]]),
      );
      await tester.pumpAndSettle();

      expect(bridge.supportChecks, 1);
      expect(bridge.creations, hasLength(1));
      expect(bridge.updates.last['selectedId'], 'profile');
      final items = bridge.updates.last['items'] as List<Object?>;
      expect(items, hasLength(2));
      expect(items.first, {
        'id': 'profile',
        'label': 'Me',
        'symbol': 'person',
        'selectedSymbol': 'person.fill',
        'badge': true,
        'badgeLabel': 'Update available',
      });
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'native selection uses current IDs and stops after disposal',
    (tester) async {
      bridge.install();
      final selections = <int>[];
      await tester.pumpWidget(_host(onSelected: selections.add));
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        _host(
          destinations: [_destinations[2], _destinations[1], _destinations[0]],
          selectedIndex: 2,
          onSelected: selections.add,
        ),
      );
      await tester.pumpAndSettle();

      expect(await bridge.send('select', 'profile'), isNotNull);
      expect(selections, [0]);
      await tester.pumpWidget(
        _host(
          destinations: [_destinations[1], _destinations[0]],
          selectedIndex: 1,
          onSelected: selections.add,
        ),
      );
      await tester.pumpAndSettle();
      await bridge.send('select', 'profile');
      await bridge.send('select', 'unknown');
      await bridge.send('select', 'course');
      await bridge.send('select', 0);
      await bridge.send('unknown', 'campus');
      expect(selections, [0]);

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
      expect(await bridge.send('select', 'campus'), isNull);
      expect(selections, [0]);
      expect(bridge.disposedViewIds, bridge.viewIds);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'failed native update restores functioning Material navigation',
    (tester) async {
      bridge.install();
      final selections = <int>[];
      final nativeModes = <bool>[];
      await tester.pumpWidget(
        _host(onSelected: selections.add, onNativeModeChanged: nativeModes.add),
      );
      await tester.pumpAndSettle();
      expect(nativeModes, [true]);
      bridge.failUpdates = true;
      await tester.pumpWidget(
        _host(
          selectedIndex: 1,
          onSelected: selections.add,
          onNativeModeChanged: nativeModes.add,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(UiKitView), findsNothing);
      expect(nativeModes, [true, false]);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      expect(await bridge.send('select', 'profile'), isNull);
      await tester.tap(find.text('Profile'));
      expect(selections, [2]);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.iOS),
  );

  testWidgets(
    'extended body draws behind the dock but scrolls its last item above it',
    (tester) async {
      final controller = ScrollController();
      addTearDown(controller.dispose);
      const viewportKey = Key('home-viewport');
      const lastItemKey = Key('last-home-item');
      double? contentInset;
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(800, 600),
              padding: EdgeInsets.only(top: 24, bottom: 34),
              viewPadding: EdgeInsets.only(top: 24, bottom: 34),
            ),
            child: Scaffold(
              extendBody: true,
              bottomNavigationBar: const SizedBox(height: 122),
              body: HomeDockBody(
                extended: true,
                child: Builder(
                  builder: (context) {
                    contentInset = HomeDockInsets.bottomOf(context);
                    return ListView(
                      key: viewportKey,
                      controller: controller,
                      padding: EdgeInsets.only(bottom: contentInset!),
                      children: [
                        for (var index = 0; index < 20; index++)
                          SizedBox(
                            key: index == 19 ? lastItemKey : null,
                            height: 48,
                            child: Text('Item $index'),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      );

      expect(contentInset, 122);
      final viewport = tester.getRect(find.byKey(viewportKey));
      expect(viewport.top, 24);
      expect(viewport.bottom, 600);
      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pump();
      expect(tester.getRect(find.byKey(lastItemKey)).bottom, 478);
    },
  );

  testWidgets('legacy body keeps its safe area without a floating dock inset', (
    tester,
  ) async {
    const contentKey = Key('legacy-content');
    double? contentInset;
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(800, 600),
            padding: EdgeInsets.fromLTRB(12, 24, 12, 34),
            viewPadding: EdgeInsets.fromLTRB(12, 24, 12, 34),
          ),
          child: HomeDockBody(
            extended: false,
            child: Builder(
              builder: (context) {
                contentInset = HomeDockInsets.bottomOf(context);
                return const SizedBox.expand(key: contentKey);
              },
            ),
          ),
        ),
      ),
    );

    expect(contentInset, 0);
    expect(
      tester.getRect(find.byKey(contentKey)),
      const Rect.fromLTRB(12, 24, 788, 566),
    );
  });
}
