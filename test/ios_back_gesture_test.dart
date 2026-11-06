import 'package:bugaoshan/widgets/common/swipe_page_view.dart';
import 'package:bugaoshan/widgets/route/ios_back_gesture.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const Duration _transitionDuration = Duration(milliseconds: 300);

/// 只给 iOS 配上自研转场，其余平台行为保持不变。
ThemeData _iosTheme() => ThemeData(
  platform: TargetPlatform.iOS,
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.iOS: AppCupertinoPageTransitionsBuilder(
        duration: _transitionDuration,
      ),
    },
  ),
);

/// 搭一个「首页 → 详情页」的最小导航场景，并把详情页推入栈中。
Future<void> _pumpPushedPage(
  WidgetTester tester, {
  ThemeData? theme,
  Widget? secondPage,
  bool fullscreenDialog = false,
  bool rtl = false,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? _iosTheme(),
      builder: rtl
          ? (BuildContext context, Widget? child) =>
                Directionality(textDirection: TextDirection.rtl, child: child!)
          : null,
      home: Scaffold(
        body: Center(
          child: Builder(
            builder: (BuildContext context) => TextButton(
              onPressed: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute<void>(
                    fullscreenDialog: fullscreenDialog,
                    builder: (BuildContext context) =>
                        secondPage ?? const _SecondPage(),
                  ),
                );
              },
              child: const Text('push'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('push'));
  if (settle) {
    await tester.pumpAndSettle();
  } else {
    // 让进页转场只走一部分，页面已可命中但动画尚未结束。
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  }
}

/// 慢速拖动：每步都推进时间，让速度远低于「甩出」阈值，
/// 从而稳定地按拖动距离判定（高速 drag 会被当成 fling）。
Future<void> _slowDrag(
  WidgetTester tester,
  Offset start,
  Offset total, {
  int steps = 12,
}) async {
  final TestGesture gesture = await tester.startGesture(start);
  final Offset step = total / steps.toDouble();
  for (int i = 0; i < steps; i++) {
    await gesture.moveBy(step);
    await tester.pump(const Duration(milliseconds: 120));
  }
  await gesture.up();
  await tester.pumpAndSettle();
  _expectNoUserGesture(tester);
}

/// 手势生命周期唯一的黑盒观测量：结束后 Navigator 必须退出 userGesture 状态，
/// 否则会卡住任何依赖它的返回/转场逻辑。
void _expectNoUserGesture(WidgetTester tester) {
  final NavigatorState navigator = tester.state<NavigatorState>(
    find.byType(Navigator).first,
  );
  expect(navigator.userGestureInProgress, isFalse);
}

Future<void> _dragPushedPage(
  WidgetTester tester,
  Offset total, {
  Finder? from,
  int steps = 12,
}) {
  final Finder start = from ?? find.text(_SecondPage.marker);
  return _slowDrag(tester, tester.getCenter(start), total, steps: steps);
}

class _SecondPage extends StatelessWidget {
  const _SecondPage({this.child = const Text(marker)});

  static const String marker = 'second page';

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: child));
  }
}

void main() {
  testWidgets('从内容区中央向右拖过半屏即返回上一页', (tester) async {
    await _pumpPushedPage(tester);
    expect(find.text(_SecondPage.marker), findsOneWidget);

    await _dragPushedPage(tester, const Offset(500, 0));

    expect(find.text(_SecondPage.marker), findsNothing);
    expect(find.text('push'), findsOneWidget);
  });

  testWidgets('未过半屏松手回弹，不返回', (tester) async {
    await _pumpPushedPage(tester);

    await _dragPushedPage(tester, const Offset(120, 0));

    expect(find.text(_SecondPage.marker), findsOneWidget);
  });

  testWidgets('向左拖动不触发返回', (tester) async {
    await _pumpPushedPage(tester);

    await _dragPushedPage(tester, const Offset(-500, 0));

    expect(find.text(_SecondPage.marker), findsOneWidget);
  });

  testWidgets('纵向拖动交给页内列表，不触发返回', (tester) async {
    await _pumpPushedPage(
      tester,
      secondPage: _SecondPage(
        child: ListView(
          children: <Widget>[
            for (int i = 0; i < 40; i++)
              SizedBox(height: 80, child: Text('row $i')),
          ],
        ),
      ),
    );

    await _dragPushedPage(
      tester,
      const Offset(0, -300),
      from: find.text('row 0'),
    );

    expect(find.byType(ListView), findsOneWidget);
    final ScrollableState scrollable = tester.state<ScrollableState>(
      find.byType(Scrollable).last,
    );
    expect(scrollable.position.pixels, greaterThan(0));
  });

  testWidgets('RTL 下向左拖动即返回（从前往后）', (tester) async {
    await _pumpPushedPage(tester, rtl: true);

    await _dragPushedPage(tester, const Offset(-500, 0));

    expect(find.text(_SecondPage.marker), findsNothing);
  });

  testWidgets('RTL 下向右拖动不返回', (tester) async {
    await _pumpPushedPage(tester, rtl: true);

    await _dragPushedPage(tester, const Offset(500, 0));

    expect(find.text(_SecondPage.marker), findsOneWidget);
  });

  testWidgets('内层横向滚动内容优先消费手势', (tester) async {
    await _pumpPushedPage(
      tester,
      secondPage: _SecondPage(
        child: SizedBox(
          height: 120,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: const <Widget>[
              SizedBox(width: 200, child: Text(_SecondPage.marker)),
              SizedBox(width: 200, child: Text('item 1')),
              SizedBox(width: 200, child: Text('item 2')),
              SizedBox(width: 200, child: Text('item 3')),
              SizedBox(width: 200, child: Text('item 4')),
              SizedBox(width: 200, child: Text('item 5')),
              SizedBox(width: 200, child: Text('item 6')),
              SizedBox(width: 200, child: Text('item 7')),
            ],
          ),
        ),
      ),
    );

    // 右拖：横滑列表在更深的命中路径上先赢得手势竞技场，返回手势不应介入。
    await _dragPushedPage(tester, const Offset(500, 0));

    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('内层横向翻页容器优先消费手势', (tester) async {
    await _pumpPushedPage(
      tester,
      secondPage: _SecondPage(
        child: SwipePageView(
          children: const <Widget>[Text('tab 0'), Text('tab 1')],
        ),
      ),
    );

    // SwipePageView 自带横向拖动识别器，位于更深的命中路径上。
    await _dragPushedPage(
      tester,
      const Offset(500, 0),
      from: find.text('tab 0'),
    );

    expect(find.byType(SwipePageView), findsOneWidget);
  });

  testWidgets('转场尚未结束时按下不起手', (tester) async {
    await _pumpPushedPage(
      tester,
      secondPage: const _SecondPage(),
      settle: false,
    );

    // 进页动画进行中：popGestureEnabled 为 false，手势不应介入。
    await _dragPushedPage(tester, const Offset(500, 0));

    expect(find.text(_SecondPage.marker), findsOneWidget);
  });

  testWidgets('PopScope(canPop: false) 的页面不响应全局返回手势', (tester) async {
    await _pumpPushedPage(
      tester,
      secondPage: PopScope(canPop: false, child: const _SecondPage()),
    );

    await _dragPushedPage(tester, const Offset(500, 0));

    expect(find.text(_SecondPage.marker), findsOneWidget);
  });

  testWidgets('fullscreenDialog 路由不安装全局返回手势', (tester) async {
    await _pumpPushedPage(tester, fullscreenDialog: true);

    await _dragPushedPage(tester, const Offset(500, 0));

    expect(find.text(_SecondPage.marker), findsOneWidget);
  });

  testWidgets('栈底页面拖动无副作用', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: _iosTheme(),
        home: const Scaffold(body: Center(child: Text('home'))),
      ),
    );

    await _slowDrag(
      tester,
      tester.getCenter(find.text('home')),
      const Offset(500, 0),
    );

    expect(find.text('home'), findsOneWidget);
  });

  testWidgets('Android 平台不安装全局返回手势', (tester) async {
    await _pumpPushedPage(
      tester,
      theme: ThemeData(platform: TargetPlatform.android),
    );

    await _dragPushedPage(tester, const Offset(500, 0));

    expect(find.text(_SecondPage.marker), findsOneWidget);
  });

  testWidgets('拖动中被程序化 pop 不会卡住手势状态', (tester) async {
    await _pumpPushedPage(tester);
    final NavigatorState navigator = tester.state<NavigatorState>(
      find.byType(Navigator).first,
    );

    final TestGesture gesture = await tester.startGesture(
      tester.getCenter(find.text(_SecondPage.marker)),
    );
    for (int i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 120));
    }
    // 拖动进行中由业务代码发起真正的返回。
    navigator.pop();
    await tester.pump();
    for (int i = 0; i < 4; i++) {
      await gesture.moveBy(const Offset(20, 0));
      await tester.pump(const Duration(milliseconds: 120));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(find.text(_SecondPage.marker), findsNothing);
    _expectNoUserGesture(tester);
  });

  testWidgets('连续两次全局返回可逐页退出', (tester) async {
    await _pumpPushedPage(tester);
    await _dragPushedPage(tester, const Offset(500, 0));
    expect(find.text(_SecondPage.marker), findsNothing);

    // 重新推入第二页，再次返回，确认手势在多次进出后仍然可用。
    await tester.tap(find.text('push'));
    await tester.pumpAndSettle();
    await _dragPushedPage(tester, const Offset(500, 0));

    expect(find.text(_SecondPage.marker), findsNothing);
    expect(find.text('push'), findsOneWidget);
  });
}
