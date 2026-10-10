import 'package:flutter/material.dart';

import 'package:bugaoshan/utils/app_logger.dart';

/// 顶部筛选条：level 多选 chip + tag 下拉。
class LogFilterBar extends StatelessWidget {
  /// 各 tag 的当前条数，已按条数降序（见 [AppLogger.tagCounts]）。
  final List<MapEntry<String, int>> tagCounts;
  // null = 无筛选（全部 level 启用）；非空 = 仅显示这些 level。
  final Set<LogLevel>? levels;
  final String? tag;
  final void Function(LogLevel level, bool selected) onLevelToggled;
  final ValueChanged<String?> onTagChanged;

  const LogFilterBar({
    super.key,
    required this.tagCounts,
    required this.levels,
    required this.tag,
    required this.onLevelToggled,
    required this.onTagChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selectedLevels = levels; // null = 全部
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final l in LogLevel.values)
                    LogLevelChip(
                      label: l.name.toUpperCase(),
                      // null = 全部启用 ⇒ 全部勾上
                      selected: selectedLevels == null
                          ? true
                          : selectedLevels.contains(l),
                      onSelected: (sel) => onLevelToggled(l, sel),
                      level: l,
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          // 按条数降序而非字母序：排查时第一眼就能看出哪个模块在刷屏，
          // 而不必在字母序列表里逐个辨认。
          DropdownButton<String?>(
            value: tag,
            focusColor: Colors.transparent,
            hint: const Text('All tags'),
            onChanged: onTagChanged,
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All tags'),
              ),
              for (final e in tagCounts)
                DropdownMenuItem<String?>(
                  value: e.key,
                  child: Text('${e.key}  ${e.value}'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 单个 level 筛选 chip（复选语义，带 ✓ 标记）。
class LogLevelChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final LogLevel level;

  const LogLevelChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onSelected,
    required this.level,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Color bg = switch (level) {
      LogLevel.debug => scheme.surfaceContainerHighest,
      LogLevel.info => scheme.primaryContainer,
      LogLevel.warn => scheme.tertiaryContainer,
      LogLevel.error => scheme.errorContainer,
    };
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: FilterChip(
        label: Text(label),
        selected: selected,
        onSelected: onSelected,
        showCheckmark: true,
        backgroundColor: bg,
      ),
    );
  }
}
