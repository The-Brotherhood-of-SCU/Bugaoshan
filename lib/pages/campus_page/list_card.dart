import 'package:bugaoshan/widgets/common/styled_card.dart';
import 'package:flutter/material.dart';
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
  });

  final IconData icon;
  final String title;
  final String? desc;
  final Widget? trailing;
  final Color? iconContainerColor;
  final Color? iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return StyledCard(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color:
                    iconContainerColor ??
                    Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppShapes.medium),
              ),
              child: Icon(
                icon,
                color:
                    iconColor ??
                    Theme.of(context).colorScheme.onPrimaryContainer,
                size: 28,
              ),
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
