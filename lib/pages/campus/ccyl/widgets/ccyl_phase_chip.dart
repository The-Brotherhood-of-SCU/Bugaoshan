import 'package:flutter/material.dart';
import 'package:bugaoshan/l10n/app_localizations.dart';
import 'package:bugaoshan/pages/campus/ccyl/ccyl_activity_phase.dart';
import 'package:bugaoshan/theme_shape.dart';

/// 状态标签文案（列表卡片与筛选面板共用）。
String ccylPhaseLabel(AppLocalizations l10n, CcylActivityPhase phase) {
  return switch (phase) {
    CcylActivityPhase.subscribed => l10n.ccylSubscribed,
    CcylActivityPhase.available => l10n.ccylAvailable,
    CcylActivityPhase.enrolling => l10n.ccylStatusEnrolling,
    CcylActivityPhase.ongoing => l10n.ccylInProgress,
    CcylActivityPhase.notStarted => l10n.ccylStatusNotStarted,
    CcylActivityPhase.ended => l10n.ccylCompleted,
  };
}

/// 状态标签视觉规格：每种标签一个独立底色，便于一眼区分。
///
/// 全部取自 [ColorScheme]，明暗主题均成立：
/// 已预约 = 主色 / 报名中 = 次色 / 进行中 = 第三色 / 可预约 = 中性填充 /
/// 未开始 = 描边 / 已结束 = 反色，避免引入主题外语义色。
({Color? background, Color foreground, bool outlined}) ccylPhaseStyle(
  ColorScheme scheme,
  CcylActivityPhase phase,
) {
  return switch (phase) {
    CcylActivityPhase.subscribed => (
      background: scheme.primaryContainer,
      foreground: scheme.onPrimaryContainer,
      outlined: false,
    ),
    CcylActivityPhase.enrolling => (
      background: scheme.secondaryContainer,
      foreground: scheme.onSecondaryContainer,
      outlined: false,
    ),
    CcylActivityPhase.ongoing => (
      background: scheme.tertiaryContainer,
      foreground: scheme.onTertiaryContainer,
      outlined: false,
    ),
    CcylActivityPhase.available => (
      background: scheme.surfaceContainerHighest,
      foreground: scheme.onSurfaceVariant,
      outlined: false,
    ),
    CcylActivityPhase.notStarted => (
      background: null,
      foreground: scheme.onSurfaceVariant,
      outlined: true,
    ),
    CcylActivityPhase.ended => (
      background: scheme.inverseSurface,
      foreground: scheme.onInverseSurface,
      outlined: false,
    ),
  };
}

/// 单个活动状态标签。
class CcylPhaseChip extends StatelessWidget {
  final CcylActivityPhase phase;

  const CcylPhaseChip({super.key, required this.phase});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final style = ccylPhaseStyle(scheme, phase);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: style.background,
        borderRadius: BorderRadius.circular(AppShapes.xs),
        border: style.outlined ? Border.all(color: scheme.outline) : null,
      ),
      child: Text(
        ccylPhaseLabel(AppLocalizations.of(context)!, phase),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: style.foreground),
      ),
    );
  }
}

/// 状态标签组：报名中与进行中可同时展示，其余状态单标签。
class CcylPhaseChips extends StatelessWidget {
  final List<CcylActivityPhase> phases;

  const CcylPhaseChips({super.key, required this.phases});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < phases.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          CcylPhaseChip(phase: phases[i]),
        ],
      ],
    );
  }
}
