import 'package:flutter/material.dart';

class StyledCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final VoidCallback? onTap;
  final double? borderRadius;
  final Color? backgroundColor;
  final BorderSide? borderSide;
  final double? elevation;

  const StyledCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.borderRadius,
    this.backgroundColor,
    this.borderSide,
    this.elevation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: margin ?? const EdgeInsets.only(bottom: 16),
      elevation: elevation ?? 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius ?? 16),
        side:
            borderSide ??
            BorderSide(
              color: colorScheme.outline.withValues(alpha: 0.2),
              width: 1,
            ),
      ),
      color: backgroundColor ?? colorScheme.surface,
      child: InkWell(
        borderRadius: BorderRadius.circular(borderRadius ?? 16),
        onTap: onTap,
        child: Padding(
          padding: padding ?? const EdgeInsets.all(16),
          child: child,
        ),
      ),
    );
  }
}
