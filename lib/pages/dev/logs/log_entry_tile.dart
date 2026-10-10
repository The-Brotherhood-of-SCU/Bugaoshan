import 'package:flutter/material.dart';

import 'package:bugaoshan/utils/app_logger.dart';

/// 单条日志的行视图：时间 · level · tag · message，按 level 着色。
/// 用于 [LogViewerPage] 内的列表渲染。
class LogEntryTile extends StatelessWidget {
  final LogEntry entry;
  const LogEntryTile({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color bg, Color fg) = switch (entry.level) {
      LogLevel.debug => (scheme.surfaceContainerLow, scheme.onSurfaceVariant),
      LogLevel.info => (scheme.primaryContainer, scheme.onPrimaryContainer),
      LogLevel.warn => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      LogLevel.error => (scheme.errorContainer, scheme.onErrorContainer),
    };
    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 86,
            child: Text(
              _formatTime(entry.timestamp),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                color: fg,
              ),
            ),
          ),
          SizedBox(
            width: 44,
            child: Text(
              entry.level.name.toUpperCase(),
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: fg, letterSpacing: 0.6),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.tag,
                  style: Theme.of(
                    context,
                  ).textTheme.labelSmall?.copyWith(color: fg),
                ),
                const SizedBox(height: 2),
                // 用 Text 而非 SelectableText：后者要装配可编辑区域，布局开销
                // 明显更高，而本页列表会随每条日志重建。页面 AppBar 已提供
                // 「复制全部」，单条复制可走系统长按菜单。
                Text(
                  entry.message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: fg),
                ),
                // error 与堆栈作为独立字段渲染（移植自 PR #369，
                // moranfanhua）：此前它们被拼进 message 字符串，UI 无法
                // 分别处理。错误单独一行、堆栈默认折叠——堆栈往往十几行，
                // 全部展开会把几十条日志挤出可视区。
                if (entry.error != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    entry.error!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: fg),
                  ),
                ],
                if (entry.stackTrace != null)
                  // 必须自带 Material：外层行是 ColoredBox，而 ExpansionTile
                  // 继承 ListTile，其背景与墨迹绘制在最近的 Material 祖先上——
                  // 没有这层 Material 会导致展开动画不可见并触发框架断言。
                  Material(
                    color: bg,
                    child: Theme(
                      data: Theme.of(
                        context,
                      ).copyWith(dividerColor: Colors.transparent),
                      child: ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        childrenPadding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        title: Text(
                          '错误堆栈',
                          style: Theme.of(
                            context,
                          ).textTheme.labelSmall?.copyWith(color: fg),
                        ),
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              entry.stackTrace!,
                              style: Theme.of(
                                context,
                              ).textTheme.bodySmall?.copyWith(color: fg),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _two(int n) => n.toString().padLeft(2, '0');
  static String _three(int n) => n.toString().padLeft(3, '0');
  static String _formatTime(DateTime t) {
    return '${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}.${_three(t.millisecond)}';
  }
}
