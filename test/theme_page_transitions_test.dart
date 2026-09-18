import 'package:bugaoshan/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // 页面转场时长跟随「设置 → 动画时长」（进页与退出同值）。Flutter 3.44 起
  // MaterialPageRoute 的时长由 PageTransitionsBuilder 决定且退出默认等于进页
  // 时长（450-500ms），返回期间下层页面要等退出动画结束才能跟手滚动；这里
  // 锁住主题层的取值契约。注意：「动画时长」页里的「Dock栏页面切换动画」
  // 开关只控制 Dock 栏切换（AuthScopedIndexedStack），不影响全局转场。
  test('默认主题各平台进页/退出转场时长均为 300ms', () {
    final theme = buildTheme(
      brightness: Brightness.light,
      seedColor: Colors.blue,
    );
    final builders = theme.pageTransitionsTheme.builders;

    expect(builders.keys.toSet(), <TargetPlatform>{
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
      TargetPlatform.macOS,
    });

    for (final entry in builders.entries) {
      expect(
        entry.value.transitionDuration,
        const Duration(milliseconds: 300),
        reason: '${entry.key} 的 transitionDuration 应为 300ms',
      );
      expect(
        entry.value.reverseTransitionDuration,
        const Duration(milliseconds: 300),
        reason: '${entry.key} 的 reverseTransitionDuration 应为 300ms',
      );
    }
  });

  test('转场时长跟随自定义参数', () {
    final theme = buildTheme(
      brightness: Brightness.light,
      seedColor: Colors.blue,
      pageTransitionDuration: const Duration(milliseconds: 123),
    );
    for (final entry in theme.pageTransitionsTheme.builders.entries) {
      expect(
        entry.value.transitionDuration,
        const Duration(milliseconds: 123),
        reason: '${entry.key} 的 transitionDuration 应跟随设置值',
      );
      expect(
        entry.value.reverseTransitionDuration,
        const Duration(milliseconds: 123),
        reason: '${entry.key} 的 reverseTransitionDuration 应跟随设置值',
      );
    }
  });

  testWidgets('MaterialPageRoute 运行时从主题读取转场时长', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(
          brightness: Brightness.light,
          seedColor: Colors.blue,
          pageTransitionDuration: const Duration(milliseconds: 123),
        ),
        home: const Scaffold(body: SizedBox()),
      ),
    );

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    final route = MaterialPageRoute<void>(
      builder: (_) => const Scaffold(body: SizedBox()),
    );
    final pushed = navigator.push<void>(route);
    await tester.pumpAndSettle();

    expect(
      route.transitionDuration,
      const Duration(milliseconds: 123),
      reason: '进页时长应取自主题的 PageTransitionsBuilder',
    );
    expect(
      route.reverseTransitionDuration,
      const Duration(milliseconds: 123),
      reason: '退出时长应取自主题的 PageTransitionsBuilder',
    );

    navigator.pop();
    await tester.pumpAndSettle();
    await pushed;
  });
}
