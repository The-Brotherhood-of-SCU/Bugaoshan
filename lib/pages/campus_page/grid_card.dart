import 'package:flutter/material.dart';
import 'package:bugaoshan/utils/app_shapes.dart';

/// Shared grid-style card: icon container + title (vertical layout).
class CampusGridCard extends StatelessWidget {
  const CampusGridCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.iconContainerColor,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final Color? iconContainerColor;
  final Color? iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppShapes.large),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            vertical: AppShapes.large,
            horizontal: AppShapes.medium,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(AppShapes.medium),
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
              const SizedBox(height: 10),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
