import 'package:flutter/material.dart';
import 'package:bugaoshan/theme_shape.dart';
import 'package:bugaoshan/widgets/common/liquid_glass.dart';

/// 液态玻璃风格的导航条，横向用于手机底部 Dock，纵向用于宽屏侧边 Dock。
///
/// 之所以不用 `NavigationBar` / `NavigationRail`，是因为这两者都带有 Material
/// 3 的实心 `indicator` 与不透明背景，无法叠加 `BackdropFilter` 做玻璃折射。
/// 这里手写导航条以获得完整的视觉控制权，同时保留原有两个组件的关键行为：
///
/// - **选中态**：图标在 `icon` / `selectedIcon` 之间切换，并带一个玻璃药丸指示器；
/// - **无障碍**：`Semantics` 的 `selected` / `button` 语义，与原组件一致；
/// - **触控热区**：每个 item 最小 48dp 高，遵循 Material 触控尺寸规范；
/// - **文字缩放**：标签使用 `labelSmall` + `FittedBox`，长文案（如"第二课堂"）
///   在窄屏下缩放而非溢出。
///
/// 动效时长由调用方从 `AppConfigProvider.cardSizeAnimationDuration` 传入，
/// 让全局动效偏好仍然生效。
class LiquidGlassDock extends StatelessWidget {
  /// 导航项。顺序即显示顺序。
  final List<LiquidGlassDockItem> items;

  /// 当前选中索引。
  final int selectedIndex;

  /// 选中变化回调。
  final ValueChanged<int> onSelected;

  /// 排列方向。[Axis.horizontal] 为底部 Dock，[Axis.vertical] 为侧边 Dock。
  final Axis axis;

  /// 单个 item 的期望高度（横向）或宽度（纵向）。
  final double itemExtent;

  /// 标签最大宽度（横向）/ 高度（纵向），用于 `FittedBox` 防溢出。
  final double labelExtent;

  /// 动画时长。
  final Duration duration;

  const LiquidGlassDock({
    super.key,
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    this.axis = Axis.horizontal,
    this.itemExtent = 64,
    this.labelExtent = 64,
    this.duration = const Duration(milliseconds: 200),
  });

  @override
  Widget build(BuildContext context) {
    final isHorizontal = axis == Axis.horizontal;

    return SafeArea(
      top: !isHorizontal,
      bottom: isHorizontal,
      left: false,
      right: false,
      child: Padding(
        // 悬浮感的关键：玻璃不贴边，四周留出间距让背景透出来。
        padding: isHorizontal
            ? const EdgeInsets.fromLTRB(12, 6, 12, 10)
            : const EdgeInsets.fromLTRB(10, 12, 10, 12),
        child: SizedBox(
          height: isHorizontal ? itemExtent : null,
          width: isHorizontal ? null : itemExtent,
          child: LiquidGlass(
            // 纵向 Dock 在屏幕上很高，减小圆角以免视觉上过于"胶囊"。
            borderRadius: isHorizontal ? AppShapes.extraLarge : AppShapes.large,
            child: isHorizontal
                ? _buildHorizontal(context)
                : _buildVertical(context),
          ),
        ),
      ),
    );
  }

  Widget _buildHorizontal(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < items.length; i++)
          Expanded(
            child: _DockItemView(
              item: items[i],
              isSelected: i == selectedIndex,
              axis: Axis.horizontal,
              labelExtent: labelExtent,
              duration: duration,
              onTap: () => onSelected(i),
            ),
          ),
      ],
    );
  }

  Widget _buildVertical(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: _DockItemView(
                item: items[i],
                isSelected: i == selectedIndex,
                axis: Axis.vertical,
                labelExtent: itemExtent,
                duration: duration,
                onTap: () => onSelected(i),
              ),
            ),
        ],
      ),
    );
  }
}

/// 单个 Dock 导航项。
class LiquidGlassDockItem {
  /// 未选中时图标。
  final Widget icon;

  /// 选中时图标。
  final Widget selectedIcon;

  /// 标签文案。
  final String label;

  /// 无障碍语义标签。为 null 时回退到 [label]。
  final String? semanticLabel;

  const LiquidGlassDockItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.semanticLabel,
  });
}

class _DockItemView extends StatelessWidget {
  final LiquidGlassDockItem item;
  final bool isSelected;
  final Axis axis;
  final double labelExtent;
  final Duration duration;
  final VoidCallback onTap;

  const _DockItemView({
    required this.item,
    required this.isSelected,
    required this.axis,
    required this.labelExtent,
    required this.duration,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isHorizontal = axis == Axis.horizontal;

    // 选中态用主题主色，未选中用 onSurfaceVariant，保证在玻璃上仍有足够对比度。
    final effectiveColor = isSelected
        ? theme.colorScheme.primary
        : theme.colorScheme.onSurfaceVariant;

    final icon = AnimatedSwitcher(
      duration: duration,
      child: IconTheme.merge(
        data: IconThemeData(
          color: effectiveColor,
          size: isHorizontal ? 24 : 26,
        ),
        child: isSelected
            ? KeyedSubtree(
                key: const ValueKey('selected'),
                child: item.selectedIcon,
              )
            : KeyedSubtree(key: const ValueKey('unselected'), child: item.icon),
      ),
    );

    final label = SizedBox(
      width: isHorizontal ? labelExtent : double.infinity,
      height: isHorizontal ? null : 14,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          item.label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelSmall?.copyWith(
            color: effectiveColor,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );

    return Semantics(
      selected: isSelected,
      button: true,
      label: item.semanticLabel ?? item.label,
      child: ExcludeSemantics(
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppShapes.large),
          // 水波纹不裁到玻璃外：由外层 ClipRRect 统一裁剪。
          splashColor: theme.colorScheme.primary.withValues(alpha: 0.12),
          highlightColor: Colors.transparent,
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isHorizontal ? 2 : 8,
              vertical: isHorizontal ? 6 : 8,
            ),
            child: AnimatedContainer(
              duration: duration,
              curve: Curves.easeOutQuart,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppShapes.large),
                color: isSelected
                    ? theme.colorScheme.primary.withValues(alpha: 0.16)
                    : Colors.transparent,
              ),
              child: isHorizontal
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        icon,
                        const SizedBox(height: 3),
                        label,
                      ],
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        icon,
                        const SizedBox(height: 4),
                        label,
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
