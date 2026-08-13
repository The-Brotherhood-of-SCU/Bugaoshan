import 'package:bugaoshan/widgets/common/auth_scoped_indexed_stack.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('认证边界变化会销毁并重建缓存页面状态', (tester) async {
    final authenticated = ValueNotifier<bool>(true);
    var created = 0;
    var disposed = 0;

    Widget buildStack() {
      return MaterialApp(
        home: AuthScopedIndexedStack(
          authListenable: authenticated,
          isAuthenticated: () => authenticated.value,
          visibleIds: const ['private-page'],
          selectedIndex: 0,
          pageBuilder: (_) =>
              _LifecycleProbe(serial: ++created, onDispose: () => disposed++),
        ),
      );
    }

    await tester.pumpWidget(buildStack());
    expect(find.text('probe-1'), findsOneWidget);

    authenticated.value = false;
    await tester.pump();
    expect(disposed, 1);
    expect(find.text('probe-2'), findsOneWidget);

    authenticated.value = true;
    await tester.pump();
    expect(disposed, 2);
    expect(find.text('probe-3'), findsOneWidget);
  });

  testWidgets('切换 selectedIndex 时能正常播放左右滑动切页动画并保持页面状态', (tester) async {
    final authenticated = ValueNotifier<bool>(true);
    final selectedIndex = ValueNotifier<int>(0);

    Widget buildStack() {
      return MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: selectedIndex,
          builder: (context, index, _) {
            return AuthScopedIndexedStack(
              authListenable: authenticated,
              isAuthenticated: () => true,
              visibleIds: const ['page-1', 'page-2'],
              selectedIndex: index,
              duration: const Duration(milliseconds: 300),
              pageBuilder: (id) => Text('content-$id'),
            );
          },
        ),
      );
    }

    await tester.pumpWidget(buildStack());
    expect(find.text('content-page-1'), findsOneWidget);

    selectedIndex.value = 1;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    expect(find.text('content-page-2'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('content-page-2'), findsOneWidget);

    selectedIndex.value = 0;
    await tester.pump();
    await tester.pumpAndSettle();
    expect(find.text('content-page-1'), findsOneWidget);
  });
}

class _LifecycleProbe extends StatefulWidget {
  const _LifecycleProbe({required this.serial, required this.onDispose});

  final int serial;
  final VoidCallback onDispose;

  @override
  State<_LifecycleProbe> createState() => _LifecycleProbeState();
}

class _LifecycleProbeState extends State<_LifecycleProbe> {
  @override
  void dispose() {
    widget.onDispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Text('probe-${widget.serial}');
}
