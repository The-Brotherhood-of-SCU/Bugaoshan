import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bugaoshan/pages/dev/logs/log_entry_tile.dart';
import 'package:bugaoshan/utils/app_logger.dart';

/// 日志条目渲染的组件测试。
///
/// 关注点是 [LogEntry.error] / [LogEntry.stackTrace] 这两个独立字段的呈现：
/// 错误应单独成行、堆栈应默认折叠——堆栈常有十几行，全部展开会把几十条
/// 日志挤出可视区，查看器本就靠纵向空间排障。
void main() {
  Widget wrap(LogEntry entry) => MaterialApp(
    home: Scaffold(body: LogEntryTile(entry: entry)),
  );

  final base = DateTime(2026, 10, 10, 12, 30, 45);

  testWidgets('有堆栈时默认折叠，不直接展开全文', (tester) async {
    final entry = LogEntry(
      timestamp: base,
      level: LogLevel.error,
      tag: 'ScuAuth',
      message: '登录失败',
      stackTrace: '#0 a (a.dart:1)\n#1 b (b.dart:2)',
    );

    await tester.pumpWidget(wrap(entry));
    await tester.pumpAndSettle();

    // 折叠标题可见，但帧内容未渲染。
    expect(find.text('错误堆栈'), findsOneWidget);
    expect(find.textContaining('#0 a (a.dart:1)'), findsNothing);

    // 展开后堆栈可见。
    await tester.tap(find.text('错误堆栈'));
    await tester.pumpAndSettle();
    expect(find.textContaining('#0 a (a.dart:1)'), findsOneWidget);
  });

  testWidgets('无堆栈时不显示折叠标题', (tester) async {
    await tester.pumpWidget(
      wrap(
        LogEntry(
          timestamp: base,
          level: LogLevel.warn,
          tag: 'T',
          message: '仅消息',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('错误堆栈'), findsNothing);
    expect(find.text('仅消息'), findsOneWidget);
  });

  testWidgets('error 单独成行渲染，不混入 message', (tester) async {
    await tester.pumpWidget(
      wrap(
        LogEntry(
          timestamp: base,
          level: LogLevel.error,
          tag: 'T',
          message: '缓存解析失败',
          error: 'FormatException: Unexpected character',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('缓存解析失败'), findsOneWidget);
    expect(find.text('FormatException: Unexpected character'), findsOneWidget);
    // 两处信息各自独立成文：message 只说结论，异常细节单独一行。
    // 若实现退回到「把error 拼进 message」，下面的断言就会失败。
    expect(find.textContaining('FormatException'), findsOneWidget);
  });
}
