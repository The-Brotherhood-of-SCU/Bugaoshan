import 'package:flutter/material.dart';

import 'package:bugaoshan/utils/auth_logger.dart';

/// 单条日志的行视图：时间 · level · tag · message，按 level 着色。
/// 用于 [AuthLogViewerPage] 内的列表渲染。
class AuthLogEntryTile extends StatelessWidget {
  final AuthLogEntry entry;
  const AuthLogEntryTile({super.key, required this.entry});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (Color bg, Color fg) = switch (entry.level) {
      AuthLogLevel.debug => (
        scheme.surfaceContainerLow,
        scheme.onSurfaceVariant,
      ),
      AuthLogLevel.info => (scheme.primaryContainer, scheme.onPrimaryContainer),
      AuthLogLevel.warn => (
        scheme.tertiaryContainer,
        scheme.onTertiaryContainer,
      ),
      AuthLogLevel.error => (scheme.errorContainer, scheme.onErrorContainer),
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
                SelectableText(
                  entry.message,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: fg),
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
