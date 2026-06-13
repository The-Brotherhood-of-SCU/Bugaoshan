import 'package:flutter/material.dart';

import 'package:bugaoshan/utils/auth_logger.dart';

/// 顶部筛选条：level 多选 chip + tag 下拉。
class AuthLogFilterBar extends StatelessWidget {
  final List<AuthLogEntry> entries;
  // null = 无筛选（全部 level 启用）；非空 = 仅显示这些 level。
  final Set<AuthLogLevel>? levels;
  final String? tag;
  final void Function(AuthLogLevel level, bool selected) onLevelToggled;
  final ValueChanged<String?> onTagChanged;

  const AuthLogFilterBar({
    super.key,
    required this.entries,
    required this.levels,
    required this.tag,
    required this.onLevelToggled,
    required this.onTagChanged,
  });

  @override
  Widget build(BuildContext context) {
    final tags = <String>{for (final e in entries) e.tag}.toList()..sort();
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
                  for (final l in AuthLogLevel.values)
                    AuthLogLevelChip(
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
          DropdownButton<String?>(
            value: tag,
            hint: const Text('All tags'),
            onChanged: onTagChanged,
            items: <DropdownMenuItem<String?>>[
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('All tags'),
              ),
              for (final t in tags)
                DropdownMenuItem<String?>(value: t, child: Text(t)),
            ],
          ),
        ],
      ),
    );
  }
}

/// 单个 level 筛选 chip（复选语义，带 ✓ 标记）。
class AuthLogLevelChip extends StatelessWidget {
  final String label;
  final bool selected;
  final ValueChanged<bool> onSelected;
  final AuthLogLevel level;

  const AuthLogLevelChip({
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
      AuthLogLevel.debug => scheme.surfaceContainerHighest,
      AuthLogLevel.info => scheme.primaryContainer,
      AuthLogLevel.warn => scheme.tertiaryContainer,
      AuthLogLevel.error => scheme.errorContainer,
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
