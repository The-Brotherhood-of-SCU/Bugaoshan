import 'dart:ui';

import 'package:flutter/material.dart';

/// 沉浸光感风格的悬浮底部导航栏。
///
/// 视觉对齐 HarmonyOS 6「沉浸光感」材质：毛玻璃通透（BackdropFilter 高斯模糊）
/// + 表面渐变通光 + 顶部高光描边 + 悬浮投影。暗色/亮色主题自动适配。
///
/// 用法：作为 [Scaffold.bottomNavigationBar] 传入，并配合 `extendBody: true`
/// 让页面内容延伸到底栏下方，滚动时透出模糊光影。
class ImmersiveDockBar extends StatelessWidget {
  const ImmersiveDockBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    // 光感参数：暗色更通透，亮色更凝实
    final double topAlpha = isDark ? 0.42 : 0.68;
    final double bottomAlpha = isDark ? 0.30 : 0.55;
    final double borderAlpha = isDark ? 0.10 : 0.45;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 14),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(32),
            boxShadow: [
              // 主投影：托起悬浮感
              BoxShadow(
                color: scheme.shadow.withValues(alpha: isDark ? 0.45 : 0.18),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              // 环境柔光
              BoxShadow(
                color: scheme.primary.withValues(alpha: isDark ? 0.10 : 0.06),
                blurRadius: 40,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(32),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 32, sigmaY: 32),
              child: Container(
                decoration: BoxDecoration(
                  // 自上而下的通光渐变，模拟光照在玻璃上的衰减
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      scheme.surfaceContainerHighest.withValues(alpha: topAlpha),
                      scheme.surface.withValues(alpha: bottomAlpha),
                    ],
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: borderAlpha),
                    width: 0.8,
                  ),
                  borderRadius: BorderRadius.circular(32),
                ),
                child: NavigationBar(
                  height: 64,
                  backgroundColor: Colors.transparent,
                  surfaceTintColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  selectedIndex: selectedIndex,
                  onDestinationSelected: onDestinationSelected,
                  destinations: destinations,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
