import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:bugaoshan/theme_shape.dart';

/// 液态玻璃（Liquid Glass）表面。
///
/// 视觉思路参考 [iOS 26 Liquid Glass] 与开源实现 `dhbxs/liquid-glass-dock`，
/// 在 Flutter 侧用四层叠加还原「折射 + 模糊 + 镜面高光 + 内侧描边」的观感：
///
/// 1. **refract（折射层）**：`BackdropFilter` 上的高斯模糊，模拟玻璃把
///    背后内容揉开的效果；
/// 2. **tint（色调层）**：一层极低透明度的中性色，亮色偏白、暗色偏黑，
///    保证前景文字对比度；
/// 3. **highlight（高光层）**：顶部偏上的白色斜向渐变，模拟光源在玻璃上沿
///    的镜面反射；
/// 4. **rim（边缘层）**：`inset` 双向阴影 + 1px 半透明白描边，还原 iOS 上那种
///    "玻璃边缘被光勾出一圈亮线" 的观感，这是液态玻璃最关键的一层。
///
/// 之所以拆成独立组件而不是把样式写进 Dock，是为了让底部 Dock、宽屏侧边
/// Dock、设置页预览三处共用同一套参数，保证视觉完全一致。
///
/// 性能注意：`BackdropFilter` 会对**裁剪区域内**的内容做逐帧模糊，属于重开销。
/// 本组件已把模糊限制在自身尺寸内（[ClipRRect] 与 [BackdropFilter] 同层），
/// 请勿在 [LiquidGlass] 内部再放会重绘的动画；如需动画请放在玻璃层**之外**。
///
/// [iOS 26 Liquid Glass]: https://developer.apple.com/design/human-interface-guidelines/materials
class LiquidGlass extends StatelessWidget {
  /// 玻璃内部内容。
  final Widget child;

  /// 圆角半径，默认 [AppShapes.extraLarge]（28dp），贴近 iOS Dock 观感。
  final double borderRadius;

  /// 模糊强度（`sigma`）。默认 18，接近 iOS 的强揉化效果。
  final double blurSigma;

  /// 色调层不透明度。亮色主题下表现为一层白纱，暗色主题下表现为黑纱。
  /// 默认 0.12。
  final double tintOpacity;

  /// 高光层强度。默认 0.35。
  final double highlightOpacity;

  /// 玻璃上方投射到内容上的阴影强度。默认 0.12。
  final double shadowOpacity;

  /// 是否绘制镜面高光层。默认 true。
  ///
  /// 极窄空间（可用宽度 < 200dp）下可关掉以省一次绘制，但通常无需调整。
  final bool showHighlight;

  const LiquidGlass({
    super.key,
    required this.child,
    this.borderRadius = AppShapes.extraLarge,
    this.blurSigma = 18,
    this.tintOpacity = 0.12,
    this.highlightOpacity = 0.35,
    this.shadowOpacity = 0.12,
    this.showHighlight = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // 亮色主题：白纱压背景 + 暗色主题：黑纱压背景。
    // 前景文字对比度由 AppBar / NavigationBar 的 onSurface 体系保证。
    final tintColor = isDark ? Colors.black : Colors.white;

    final radius = BorderRadius.circular(borderRadius);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        // 玻璃悬浮在内容之上，用较柔和的外阴影把它"托"起来。
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: shadowOpacity),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: CustomPaint(
            // 复合背景：色调层 + 高光层，两者在一次绘制里完成。
            painter: _LiquidGlassPainter(
              tintColor: tintColor,
              tintOpacity: tintOpacity,
              highlightOpacity: showHighlight ? highlightOpacity : 0,
              isDark: isDark,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                // 边缘亮线：内阴影模拟"光从边缘渗入"，外描边补齐 1px 亮线。
                border: Border.all(
                  color: Colors.white.withValues(
                    alpha: isDark ? 0.16 : 0.5,
                  ),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(
                      alpha: isDark ? 0.10 : 0.55,
                    ),
                    blurRadius: 0,
                    spreadRadius: -0.5,
                  ),
                ],
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

/// 液态玻璃的色调 + 高光复合背景。
///
/// 拆成 [Paint] 而非嵌套多个 [Container]，是因为两层都是纯装饰性的全屏渐变，
/// 合成一次绘制比两个 widget 少一次 layer。
///
/// 高光层的渐变刻意做成 "上沿亮、中心过渡、下沿回到透明" 的三段式，
/// 对应 iOS 玻璃在顶部光源下的真实衰减。
class _LiquidGlassPainter extends CustomPainter {
  final Color tintColor;
  final double tintOpacity;
  final double highlightOpacity;

  /// 暗色主题下高光更弱，因为深色背景上再加高光容易显脏。
  final bool isDark;

  const _LiquidGlassPainter({
    required this.tintColor,
    required this.tintOpacity,
    required this.highlightOpacity,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. 色调层：均匀铺一层中性色，保证前景文字可读。
    if (tintOpacity > 0) {
      canvas.drawRect(
        rect,
        Paint()..color = tintColor.withValues(alpha: tintOpacity),
      );
    }

    // 2. 高光层：顶部最亮，约 45% 处衰减为 0。
    if (highlightOpacity > 0) {
      final topStrength = isDark ? highlightOpacity * 0.5 : highlightOpacity;
      canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.white.withValues(alpha: topStrength),
              Colors.white.withValues(alpha: topStrength * 0.25),
              Colors.white.withValues(alpha: 0),
            ],
            stops: const [0, 0.55, 1],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_LiquidGlassPainter oldDelegate) {
    return oldDelegate.tintColor != tintColor ||
        oldDelegate.tintOpacity != tintOpacity ||
        oldDelegate.highlightOpacity != highlightOpacity ||
        oldDelegate.isDark != isDark;
  }
}
