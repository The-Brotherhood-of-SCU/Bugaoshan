import 'package:bugaoshan/widgets/common/swipe_page_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('横向拖动翻页并同步 TabController', (tester) async {
    await _pumpHost(tester);

    expect(_hostState(tester).tabController.index, 0);

    // 向左拖过半屏，应翻到第 2 页
    await _swipe(tester, const Offset(-400, 0));

    expect(_hostState(tester).tabController.index, 1);
    expect(find.text('page 1'), findsOneWidget);
  });

  testWidgets('纵向拖动只滚动页内列表，不翻页', (tester) async {
    await _pumpHost(tester);

    await _swipe(tester, const Offset(0, -300));

    expect(_hostState(tester).tabController.index, 0);
    // 页内 ListView 已滚动
    final scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).last,
    );
    expect(scrollable.position.pixels, greaterThan(0));
  });

  testWidgets('点击 Tab 翻页', (tester) async {
    final pages = <int>[];
    await _pumpHost(tester, onPageChanged: pages.add);

    await tester.tap(find.text('Tab 2'));
    await tester.pumpAndSettle();

    expect(_hostState(tester).tabController.index, 2);
    expect(find.text('page 2'), findsOneWidget);
    expect(pages.last, 2);
  });

  testWidgets('keepPagesAlive 翻页后保留页面状态', (tester) async {
    await _pumpHost(tester, keepAlive: true);

    await tester.tap(find.text('page 0'));
    await tester.pumpAndSettle();
    expect(find.text('count 1'), findsOneWidget);

    // 翻到第 2 页再回来，计数不丢
    await _swipe(tester, const Offset(-400, 0));
    await _swipe(tester, const Offset(400, 0));

    expect(find.text('count 1'), findsOneWidget);
    expect(_hostState(tester).tabController.index, 0);
  });
}

/// 模拟真实设备的逐帧拖动：每步位移之间隔一帧。
///
/// `tester.drag` 会把整段位移拆成两笔同帧事件一次性送达，拖动判定
/// （onPanUpdate）拿不到逐帧增量，与真机行为不符；这里手动分步并逐帧
/// pump，保证拖动过程中 onPanUpdate 正常触发。
Future<void> _swipe(WidgetTester tester, Offset delta) async {
  final gesture = await tester.startGesture(
    tester.getCenter(find.byType(SwipePageView)),
  );
  const steps = 4;
  final step = delta / steps.toDouble();
  for (var i = 0; i < steps; i++) {
    await gesture.moveBy(step);
    await tester.pump();
  }
  await gesture.up();
  await tester.pumpAndSettle();
}

Future<void> _pumpHost(
  WidgetTester tester, {
  bool keepAlive = false,
  void Function(int index)? onPageChanged,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: _TestHost(keepAlive: keepAlive, onPageChanged: onPageChanged),
    ),
  );
}

_TestHostState _hostState(WidgetTester tester) =>
    tester.state<_TestHostState>(find.byType(_TestHost));

class _TestHost extends StatefulWidget {
  const _TestHost({this.keepAlive = false, this.onPageChanged});

  final bool keepAlive;
  final void Function(int index)? onPageChanged;

  @override
  State<_TestHost> createState() => _TestHostState();
}

class _TestHostState extends State<_TestHost>
    with SingleTickerProviderStateMixin {
  late final TabController tabController;

  @override
  void initState() {
    super.initState();
    tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        bottom: TabBar(
          controller: tabController,
          tabs: const [
            Tab(text: 'Tab 0'),
            Tab(text: 'Tab 1'),
            Tab(text: 'Tab 2'),
          ],
        ),
      ),
      body: SwipePageView(
        tabController: tabController,
        keepPagesAlive: widget.keepAlive,
        onPageChanged: widget.onPageChanged,
        children: const [_CounterPage(0), _CounterPage(1), _CounterPage(2)],
      ),
    );
  }
}

/// 带本地状态 + 纵向可滚动内容的测试页。
class _CounterPage extends StatefulWidget {
  const _CounterPage(this.index);

  final int index;

  @override
  State<_CounterPage> createState() => _CounterPageState();
}

class _CounterPageState extends State<_CounterPage> {
  int _count = 0;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        TextButton(
          onPressed: () => setState(() => _count++),
          child: Text('page ${widget.index}'),
        ),
        Text('count $_count'),
        const SizedBox(height: 1200),
        Text('page ${widget.index} bottom'),
      ],
    );
  }
}
