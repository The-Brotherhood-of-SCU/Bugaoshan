import 'package:bugaoshan/app.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// 全局开启鼠标拖拽（AppScrollBehavior）后，与文本选择 / 输入框手势的
/// 仲裁回归：在文本上按住鼠标拖动应产生选区且父列表不滚动；在列表空白区
/// 拖动应滚动列表。三种承载分别对应环境信息页（ListView + SelectableText）、
/// 登录页（ListView + TextField）与崩溃页（SingleChildScrollView +
/// SelectableText）。
void main() {
  Future<void> mouseDrag(
    WidgetTester tester,
    Offset start,
    Offset delta,
  ) async {
    final gesture =
        await tester.startGesture(start, kind: PointerDeviceKind.mouse);
    await tester.pump();
    await gesture.moveBy(delta);
    await tester.pump();
    await gesture.moveBy(delta);
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
  }

  RenderEditable findRenderEditable(WidgetTester tester) {
    final root = tester.renderObject(find.byType(EditableText));
    RenderEditable? found;
    void visit(RenderObject node) {
      if (node is RenderEditable) {
        found = node;
        return;
      }
      node.visitChildren(visit);
    }

    visit(root);
    return found!;
  }

  testWidgets('ListView + SelectableText：拖文本产生选区，列表不动；空白区拖动滚动',
      (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(MaterialApp(
      scrollBehavior: const AppScrollBehavior(),
      home: Scaffold(
        body: ListView(
          controller: controller,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: SelectableText(
                'hello selectable world this is a long line of text',
                style: TextStyle(fontSize: 18),
              ),
            ),
            Container(height: 600, color: Colors.blue),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(controller.offset, 0);

    final textTopLeft = tester.getTopLeft(find.byType(SelectableText));
    await mouseDrag(
        tester, textTopLeft + const Offset(30, 8), const Offset(60, 12));

    expect(
      findRenderEditable(tester).selection?.isCollapsed,
      isFalse,
      reason: 'mouse drag on SelectableText should create a selection',
    );
    expect(controller.offset, 0,
        reason: 'dragging on SelectableText must not scroll the list');

    final blueCenter = tester.getCenter(find.byType(Container).last);
    await mouseDrag(tester, blueCenter, const Offset(0, -120));
    expect(controller.offset, greaterThan(0),
        reason: 'dragging on empty list area must scroll the list');
  });

  testWidgets('ListView + TextField：框内拖动聚焦且列表不动；空白区拖动滚动',
      (tester) async {
    final controller = ScrollController();
    final fieldFocus = FocusNode();
    await tester.pumpWidget(MaterialApp(
      scrollBehavior: const AppScrollBehavior(),
      home: Scaffold(
        body: ListView(
          controller: controller,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                focusNode: fieldFocus,
                controller: TextEditingController(text: 'username here'),
              ),
            ),
            Container(height: 600, color: Colors.blue),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(controller.offset, 0);

    final fieldTopLeft = tester.getTopLeft(find.byType(TextField));
    await mouseDrag(
        tester, fieldTopLeft + const Offset(40, 20), const Offset(50, 4));
    expect(fieldFocus.hasFocus, isTrue);
    expect(controller.offset, 0,
        reason: 'dragging inside a TextField must not scroll the list');

    final blueCenter = tester.getCenter(find.byType(Container).last);
    await mouseDrag(tester, blueCenter, const Offset(0, -120));
    expect(controller.offset, greaterThan(0),
        reason: 'dragging on empty list area must scroll the list');
  });

  testWidgets('SingleChildScrollView + SelectableText（崩溃页同构）：选择与滚动互不干扰',
      (tester) async {
    final controller = ScrollController();
    await tester.pumpWidget(MaterialApp(
      scrollBehavior: const AppScrollBehavior(),
      home: Scaffold(
        body: SingleChildScrollView(
          controller: controller,
          child: Column(
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: SelectableText(
                  'stack trace line one\nstack trace line two\nline three',
                ),
              ),
              Container(height: 600, color: Colors.blue),
            ],
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(controller.offset, 0);

    final textTopLeft = tester.getTopLeft(find.byType(SelectableText));
    await mouseDrag(
        tester, textTopLeft + const Offset(30, 8), const Offset(60, 12));

    expect(
      findRenderEditable(tester).selection?.isCollapsed,
      isFalse,
      reason: 'mouse drag on SelectableText should create a selection',
    );
    expect(controller.offset, 0,
        reason: 'dragging on SelectableText must not scroll the view');

    final blueCenter = tester.getCenter(find.byType(Container).last);
    await mouseDrag(tester, blueCenter, const Offset(0, -120));
    expect(controller.offset, greaterThan(0),
        reason: 'dragging on empty area must scroll the view');
  });
}
