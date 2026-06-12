import 'package:flutter/material.dart';
import 'package:bugaoshan/utils/app_shapes.dart';

/// A card container that groups child widgets with dividers between them.
///
/// Matches the "about page" visual style: surface background, 16px radius,
/// thin border (alpha 0.08).
class InfoCard extends StatelessWidget {
  final List<Widget> children;

  const InfoCard({super.key, required this.children});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppShapes.largeIncreased),
        border: Border.all(color: theme.dividerColor.withValues(alpha: 0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(AppShapes.largeIncreased),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: _intersperse(children, divider(theme)),
        ),
      ),
    );
  }

  /// Standard divider between tiles (indent: 56 to align after icon).
  static Widget divider(ThemeData theme) {
    return Divider(
      height: 1,
      indent: 56,
      color: theme.dividerColor.withValues(alpha: 0.08),
    );
  }

  static List<Widget> _intersperse(List<Widget> widgets, Widget separator) {
    if (widgets.length <= 1) return widgets;
    final result = <Widget>[];
    for (var i = 0; i < widgets.length; i++) {
      if (i > 0) result.add(separator);
      result.add(widgets[i]);
    }
    return result;
  }
}
