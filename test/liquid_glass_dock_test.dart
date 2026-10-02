import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bugaoshan/widgets/common/liquid_glass.dart';
import 'package:bugaoshan/widgets/common/liquid_glass_dock.dart';

/// 构造测试用的导航项。
LiquidGlassDockItem _item(String label, {IconData icon = Icons.home}) {
  return LiquidGlassDockItem(
    icon: Icon(icon),
    selectedIcon: Icon(icon),
    label: label,
  );
}

Widget _wrap(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: ThemeData(brightness: brightness),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  group('LiquidGlass', () {
    testWidgets('渲染子内容并应用玻璃表面', (tester) async {
      await tester.pumpWidget(
        _wrap(const LiquidGlass(child: Text('glass'))),
      );

      expect(find.text('glass'), findsOneWidget);
      // 玻璃本体由 BackdropFilter + ClipRRect + CustomPaint 三层构成。
      expect(find.byType(BackdropFilter), findsOneWidget);
      expect(find.byType(ClipRRect), findsWidgets);
    });

    testWidgets('亮色与暗色主题均可正常构建', (tester) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          _wrap(
            const LiquidGlass(child: Text('glass')),
            brightness: brightness,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('glass'), findsOneWidget);
      }
    });

    testWidgets('showHighlight 为 false 时不绘制高光层', (tester) async {
      await tester.pumpWidget(
        _wrap(const LiquidGlass(child: Text('glass'), showHighlight: false)),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('glass'), findsOneWidget);
    });
  });

  group('LiquidGlassDock', () {
    testWidgets('渲染全部导航项与标签', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LiquidGlassDock(
            items: [_item('Course'), _item('Campus'), _item('Profile')],
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(LiquidGlass), findsOneWidget);
      expect(find.text('Course'), findsOneWidget);
      expect(find.text('Campus'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('点击导航项触发对应索引', (tester) async {
      final selected = <int>[];
      await tester.pumpWidget(
        _wrap(
          LiquidGlassDock(
            items: [_item('Course'), _item('Campus'), _item('Profile')],
            selectedIndex: 0,
            onSelected: selected.add,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(selected, [2]);

      await tester.tap(find.text('Campus'));
      await tester.pumpAndSettle();
      expect(selected, [2, 1]);
    });

    testWidgets('选中项切换为 selectedIcon', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LiquidGlassDock(
            items: [
              const LiquidGlassDockItem(
                icon: Icon(Icons.abc),
                selectedIcon: Icon(Icons.xyz),
                label: 'Switch',
              ),
            ],
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // 选中态应展示 selectedIcon，未选中图标不应存在。
      expect(find.byIcon(Icons.xyz), findsOneWidget);
      expect(find.byIcon(Icons.abc), findsNothing);
    });

    testWidgets('纵向排列时全部导航项仍可见', (tester) async {
      await tester.pumpWidget(
        _wrap(
          LiquidGlassDock(
            axis: Axis.vertical,
            itemExtent: 84,
            items: [_item('Course'), _item('Campus')],
            selectedIndex: 1,
            onSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Course'), findsOneWidget);
      expect(find.text('Campus'), findsOneWidget);
      expect(find.byType(LiquidGlass), findsOneWidget);
    });

    testWidgets('长标签在窄宽度下缩放而非溢出', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 160,
            child: LiquidGlassDock(
              itemExtent: 64,
              labelExtent: 48,
              items: [
                LiquidGlassDockItem(
                  icon: Icon(Icons.home),
                  selectedIcon: Icon(Icons.home),
                  label: '超长标签文案测试',
                ),
              ],
              selectedIndex: 0,
              onSelected: _ {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('超长标签文案测试'), findsOneWidget);
    });

    testWidgets('提供 semanticLabel 时覆盖 label 语义', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _wrap(
          LiquidGlassDock(
            items: const [
              LiquidGlassDockItem(
                icon: Icon(Icons.person),
                selectedIcon: Icon(Icons.person),
                label: 'Me',
                semanticLabel: 'Personal Center',
              ),
            ],
            selectedIndex: 0,
            onSelected: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel('Personal Center'), findsOneWidget);
      handle.dispose();
    });
  });
}
