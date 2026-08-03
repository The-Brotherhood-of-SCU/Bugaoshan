import 'package:flutter/material.dart';
import 'package:bugaoshan/theme_shape.dart';

/// 统一卡片样式外壳。
///
/// 只负责"卡片样式"这一件事：背景、圆角、描边、裁剪、可选的整体点击
/// 水波纹。不负责内容组织（分组、分隔线等），那是上层组件（如 InfoCard）
/// 的职责——上层组件把拼好的内容作为 [child] 传进来即可。
///
/// 视觉规范对齐 InfoCard（"about page" 风格）：
/// - 背景 `colorScheme.surface`
/// - 圆角 [AppShapes.largeIncreased]
/// - 描边 `dividerColor.withValues(alpha: 0.08)`，宽度 1
/// - `Container` 提供描边与圆角裁剪，`Material` 提供不透明背景以承载
///   `InkWell` 水波纹
/// - 无 elevation
///
/// [padding] / [margin] 默认为 null，由调用方显式控制，避免和子内容
/// （如分组 tile）自带的 padding 冲突。
class StyledCard extends StatelessWidget {
  /// 卡片内容。
  final Widget child;

  /// 内边距。默认不施加，由调用方控制。
  final EdgeInsetsGeometry? padding;

  /// 外边距。默认不施加。
  final EdgeInsetsGeometry? margin;

  /// 点击回调。非 null 时整体包裹 `InkWell`。
  final VoidCallback? onTap;

  /// 圆角半径，默认 [AppShapes.largeIncreased]。
  final double? borderRadius;

  final Color? backgroundColor;

  final Color? borderColor;

  const StyledCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.borderRadius,
    this.backgroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius = borderRadius ?? AppShapes.largeIncreased;
    final color = backgroundColor ?? theme.colorScheme.surfaceContainerLow;
    final border = borderColor ?? theme.dividerColor.withValues(alpha: 0.15);

    Widget body = child;
    if (padding != null) {
      body = Padding(padding: padding!, child: body);
    }

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: border),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        clipBehavior: Clip.antiAlias,
        child: onTap == null
            ? body
            : InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(radius),
                child: body,
              ),
      ),
    );
  }
}

Widget titleText(String text) {
  return Padding(
    padding: const EdgeInsets.fromLTRB(0, 0, 0, 10),
    child: Text(
      text,
      textScaler: const TextScaler.linear(1.3),
      style: const TextStyle(fontWeight: FontWeight.w800),
    ),
  );
}

class CardWithTitle extends StatelessWidget {
  final String title;
  final Widget? icon;
  final Widget? child;
  final void Function()? onTap;
  const CardWithTitle({
    super.key,
    required this.title,
    this.icon,
    this.child,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return StyledCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [titleText(title), icon ?? Container()],
            ),
            child ?? Container(),
          ],
        ),
      ),
    );
  }
}
