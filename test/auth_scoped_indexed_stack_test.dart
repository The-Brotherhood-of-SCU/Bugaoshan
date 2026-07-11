import 'package:bugaoshan/widgets/common/auth_scoped_indexed_stack.dart';
import 'package:flutter/material.dart';
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
