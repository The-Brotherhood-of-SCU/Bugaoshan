import 'package:flutter/material.dart';
import 'package:bugaoshan/theme_shape.dart';

/// 活动等级（院/校级）标签。
///
/// 与状态标签并存展示，故统一用中性配色，避免与状态标签的语义色冲突。
class CcylLevelChip extends StatelessWidget {
  final String label;

  const CcylLevelChip({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppShapes.xs),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
      ),
    );
  }
}
