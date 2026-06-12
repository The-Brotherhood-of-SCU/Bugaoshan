import 'package:flutter/material.dart';
import 'package:bugaoshan/utils/app_shapes.dart';

class WidgetSizeCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String sizeLabel;
  final VoidCallback onPressed;
  final String pinLabel;

  const WidgetSizeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.sizeLabel,
    required this.onPressed,
    required this.pinLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(AppShapes.medium),
              ),
              child: Icon(
                icon,
                size: 28,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonal(onPressed: onPressed, child: Text(pinLabel)),
          ],
        ),
      ),
    );
  }
}
