import 'package:bugaoshan/utils/system_insets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 三键导航条 / 手势条的高度（dp）。Android 15+ 强制 edge-to-edge 后，
/// 系统栏会直接压在这块区域上（#379）。
const double _systemBar = 48;

Widget _page({required bool useInset}) {
  final padding = const EdgeInsets.all(24);
  return MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('t')),
      body: Builder(
        builder: (context) => ListView(
          padding: useInset ? withSystemBottomInset(context, padding) : padding,
          children: [
            for (var i = 0; i < 40; i++)
              SizedBox(height: 60, child: Text('item$i')),
          ],
        ),
      ),
    ),
  );
}

Future<double> _lastItemBottom(
  WidgetTester tester, {
  required bool useInset,
}) async {
  await tester.pumpWidget(_page(useInset: useInset));
  final position = tester
      .state<ScrollableState>(find.byType(Scrollable))
      .position;
  position.jumpTo(position.maxScrollExtent);
  await tester.pumpAndSettle();
  return tester.getRect(find.text('item39')).bottom;
}

void main() {
  group('withSystemBottomInset', () {
    testWidgets('系统 inset 为 0 时原样返回', (tester) async {
      late EdgeInsets resolved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              resolved = withSystemBottomInset(
                context,
                const EdgeInsets.all(16),
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(resolved, const EdgeInsets.all(16));
    });

    testWidgets('底边取系统 inset 与实际 padding 的较大者', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(bottom: _systemBar * 3);
      tester.view.viewPadding = const FakeViewPadding(bottom: _systemBar * 3);
      addTearDown(tester.view.reset);

      late EdgeInsets resolved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              resolved = withSystemBottomInset(
                context,
                const EdgeInsets.fromLTRB(1, 2, 3, 4),
              );
              return const SizedBox();
            },
          ),
        ),
      );
      // 原底边 4 小于系统栏高度，取系统栏高度（max 语义，非相加）。
      expect(resolved, const EdgeInsets.fromLTRB(1, 2, 3, _systemBar));
    });

    testWidgets('原有底边 padding 更大时保留原值', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 3.0;
      tester.view.padding = const FakeViewPadding(bottom: _systemBar * 3);
      tester.view.viewPadding = const FakeViewPadding(bottom: _systemBar * 3);
      addTearDown(tester.view.reset);

      const generous = _systemBar * 2;
      late EdgeInsets resolved;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              resolved = withSystemBottomInset(
                context,
                const EdgeInsets.fromLTRB(1, 2, 3, generous),
              );
              return const SizedBox();
            },
          ),
        ),
      );
      expect(resolved, const EdgeInsets.fromLTRB(1, 2, 3, generous));
    });
  });

  testWidgets('列表滚到底时最后一项不会被系统栏压住（#379）', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 3.0;
    tester.view.padding = const FakeViewPadding(bottom: _systemBar * 3);
    tester.view.viewPadding = const FakeViewPadding(bottom: _systemBar * 3);
    addTearDown(tester.view.reset);

    final screenBottom =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final barTop = screenBottom - _systemBar;

    // 写死 padding 时，滚动组件不再消费环境 padding，末项落在系统栏下方。
    expect(await _lastItemBottom(tester, useInset: false), greaterThan(barTop));

    // 补上 inset 后，末项整块停在系统栏上方。
    expect(
      await _lastItemBottom(tester, useInset: true),
      lessThanOrEqualTo(barTop),
    );
  });
}
