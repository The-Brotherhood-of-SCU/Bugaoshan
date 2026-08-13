import 'package:bugaoshan/widgets/common/styled_card.dart';
import 'package:material_ui/material_ui.dart';
import 'package:bugaoshan/theme_shape.dart';

/// Shared list-style card: icon container + title + desc + trailing widget.
class CampusListCard extends StatelessWidget {
  const CampusListCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.desc,
    this.trailing,
    this.iconContainerColor,
    this.iconColor,
    this.accentColor,
  });

  final IconData icon;
  final String title;
  final String? desc;
  final Widget? trailing;
  final Color? iconContainerColor;
  final Color? iconColor;

  /// 强调色。传入后自动派生柔和的图标容器底色与图标色；
  /// 优先级低于显式指定的 [iconContainerColor] / [iconColor]。
  final Color? accentColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = accentColor;
    final containerColor =
        iconContainerColor ??
        (accent != null
            ? accent.withValues(
                alpha: colorScheme.brightness == Brightness.dark ? 0.24 : 0.14,
              )
            : colorScheme.primaryContainer);
    final foregroundColor =
        iconColor ?? accent ?? colorScheme.onPrimaryContainer;

    return StyledCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: containerColor,
                borderRadius: BorderRadius.circular(AppShapes.large),
              ),
              child: Icon(icon, color: foregroundColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (desc != null && desc!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      desc!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ?trailing,
          ],
        ),
      ),
    );
  }
}
