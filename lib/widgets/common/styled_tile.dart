import 'package:flutter/material.dart';
import 'package:bugaoshan/utils/app_shapes.dart';

/// Base tile with padding and optional InkWell tap.
class BaseTile extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;

  const BaseTile({super.key, required this.child, this.onTap});

  @override
  Widget build(BuildContext context) {
    final tile = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: child,
    );
    if (onTap != null) {
      return InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppShapes.largeIncreased),
        child: tile,
      );
    }
    return tile;
  }
}

/// Icon container (36x36, rounded, primary tint).
class TileIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;

  const TileIcon({super.key, required this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final primaryColor = color ?? Theme.of(context).colorScheme.primary;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppShapes.medium),
      ),
      child: Icon(icon, color: primaryColor, size: 20),
    );
  }
}

/// Common tile: icon + label + optional value + optional trailing.
class IconTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final String? value;
  final Widget? trailing;
  final Color? iconColor;
  final Color? labelColor;

  /// When true, suppress the auto-chevron even if [onTap] is provided.
  /// Used by subclasses ([BadgedTile], [LinkTile]) that manage their own trailing.
  final bool _suppressChevron;

  const IconTile({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.value,
    this.trailing,
    this.iconColor,
    this.labelColor,
  }) : _suppressChevron = false;

  const IconTile._internal({
    required this.icon,
    required this.label,
    this.onTap,
    this.value,
    this.trailing,
    this.iconColor,
  }) : _suppressChevron = true,
       labelColor = null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BaseTile(
      onTap: onTap,
      child: Row(
        children: [
          TileIcon(icon: icon, color: iconColor),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyLarge?.copyWith(color: labelColor),
            ),
          ),
          if (value != null)
            Text(
              value!,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          if (trailing != null) ...[
            if (value != null) const SizedBox(width: 8),
            trailing!,
          ],
          if (onTap != null && !_suppressChevron) ...[
            const SizedBox(width: 8),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              size: 20,
            ),
          ],
        ],
      ),
    );
  }
}

/// [IconTile] with a red dot badge next to the label.
class BadgedTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? iconColor;
  final bool showBadge;
  final Widget? trailing;

  const BadgedTile({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.iconColor,
    this.showBadge = true,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    if (!showBadge && trailing == null) {
      return IconTile(
        icon: icon,
        label: label,
        onTap: onTap,
        iconColor: iconColor,
      );
    }
    return IconTile._internal(
      icon: icon,
      label: label,
      onTap: onTap,
      iconColor: iconColor,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showBadge) ...[
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 8),
          ],
          if (trailing != null)
            trailing!
          else ...[
            Icon(
              Icons.chevron_right_rounded,
              color: Theme.of(
                context,
              ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
              size: 20,
            ),
          ],
        ],
      ),
    );
  }
}

/// [IconTile] with an external link icon (open_in_new).
class LinkTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? iconColor;
  final String? value;

  const LinkTile({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.iconColor,
    this.value,
  });

  @override
  Widget build(BuildContext context) {
    return IconTile._internal(
      icon: icon,
      label: label,
      onTap: onTap,
      iconColor: iconColor,
      value: value,
      trailing: Icon(
        Icons.open_in_new,
        color: Theme.of(
          context,
        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.4),
        size: 18,
      ),
    );
  }
}

/// [IconTile] with a loading indicator as trailing.
class LoadingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? iconColor;

  const LoadingTile({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return IconTile._internal(
      icon: icon,
      label: label,
      onTap: onTap,
      iconColor: iconColor,
      trailing: const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
