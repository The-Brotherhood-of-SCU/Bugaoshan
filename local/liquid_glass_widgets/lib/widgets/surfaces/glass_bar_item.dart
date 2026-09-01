import 'package:flutter/widgets.dart';

import '../overlays/glass_menu.dart';

/// How an item's glass background is drawn.
///
/// Mirrors the two booleans iOS 26 added to `UIBarButtonItem`:
/// `sharesBackground` (default `YES`) and `hidesSharedBackground` (default
/// `NO`). Their four combinations describe three distinct results, which are
/// the three values here.
///
/// Both are documented as being ignored for an item inside an explicit group
/// of more than one; the equivalent here is that [GlassBarItemBackground.shared]
/// is the only value that lets an item join its neighbours.
enum GlassBarItemBackground {
  /// The item joins one glass capsule with its neighbours.
  ///
  /// `sharesBackground = YES` — the default, and the only value that groups.
  shared,

  /// The item gets a glass capsule of its own, sharing with nothing.
  ///
  /// `sharesBackground = NO`. A lone icon in its own capsule is the circular
  /// button iOS 26 draws for a single bar item.
  separate,

  /// No glass is drawn behind the item at all.
  ///
  /// `hidesSharedBackground = YES`. For content that carries its own shape —
  /// a profile photo, a coloured badge — where a capsule behind it would read
  /// as a second, competing surface.
  none,
}

/// A single item in a pinned navigation-bar cluster.
///
/// Mirrors UIKit's `UIBarButtonItem`: items are declared as **data**, and the
/// system owns their placement. There is deliberately no way to offset or
/// reposition a cluster — iOS 26 provides no such API either, and the only
/// lever it does provide (splitting the shared background) is modelled by
/// [GlassBarItem.spacer].
///
/// That constraint is what makes custom content simple: a custom widget is an
/// *item*, so the cluster measures and lays itself out around it. A screen
/// never has to tell the bar to make room.
///
/// ```dart
/// GlassAppBar.pinned(
///   title: const Text('Repository'),
///   actions: [
///     GlassBarItem.icon(icon: const Icon(CupertinoIcons.add), id: 'add', onTap: _add),
///     GlassBarItem.custom(child: UnreadPill(count: 3), onTap: _openInbox),
///   ],
/// )
/// ```
sealed class GlassBarItem {
  /// Const base constructor for the sealed hierarchy.
  const GlassBarItem();

  /// An icon button inside the pinned cluster.
  ///
  /// [id] mirrors `UIBarButtonItem.identifier`: items that share an [id]
  /// across two routes are treated as the *same* item during a navigation
  /// transition, so the item stays put while everything around it morphs.
  /// When [id] is null, items are matched positionally from the trailing
  /// edge — the same heuristic UIKit documents as its default.
  const factory GlassBarItem.icon({
    required Widget icon,
    required VoidCallback onTap,
    Object? id,
    String? label,
    bool enabled,
    GlassBarItemBackground background,
  }) = GlassBarIconItem;

  /// An arbitrary widget inside the pinned cluster.
  ///
  /// Equivalent to `UIBarButtonItem(customView:)`. The widget is measured at
  /// its intrinsic width during layout and the capsule sizes itself around it,
  /// so it participates in the pinned morph exactly like an icon does — it
  /// stays put while the page slides, and animates between routes.
  ///
  /// Constrained to the cluster's height; give the child its own padding if it
  /// needs breathing room. Supply [id] to keep it matched across routes.
  ///
  /// [onTap] is optional here, unlike on [GlassBarItem.icon]: a custom view is
  /// as often a status readout as it is a button, and one that handles its own
  /// gestures wants the cluster to stay out of the way.
  const factory GlassBarItem.custom({
    required Widget child,
    VoidCallback onTap,
    Object? id,
    String? label,
    bool enabled,
    GlassBarItemBackground background,
  }) = GlassBarCustomItem;

  /// An icon that opens a [GlassMenu] pull-down, mirroring
  /// `UIBarButtonItem.menu` — the standard iOS 26 overflow button.
  ///
  /// The whole capsule morphs into the menu rather than just the icon's slot,
  /// matching iOS 26's `GlassEffectContainer` behaviour and
  /// [GlassButtonGroupItem.menu]. Only the first menu item in a cluster opens
  /// a menu; a second is treated as a plain icon.
  ///
  /// [menuItems] takes [GlassMenuItem] and [GlassMenuDivider] widgets — the
  /// same contract as [GlassMenu.items]. An open menu is dismissed if
  /// navigation starts underneath it.
  const factory GlassBarItem.menu({
    required Widget icon,
    required List<Widget> menuItems,
    GlassMenuAlignment? menuAlignment,
    double menuWidth,
    Object? id,
    String? label,
    GlassBarItemBackground background,
  }) = GlassBarMenuItem;

  /// Splits the shared glass background, mirroring SwiftUI's
  /// `ToolbarSpacer(.fixed)` and UIKit's `UIBarButtonItem.fixedSpace`.
  ///
  /// Items on either side of a spacer render in separate glass capsules.
  ///
  /// Currently parsed and validated but not yet rendered — a cluster
  /// containing a spacer asserts in debug mode. Multi-capsule grouping is a
  /// follow-up.
  const factory GlassBarItem.spacer() = GlassBarSpacer;
}

/// An item that renders content and can be tapped.
///
/// The shared supertype of [GlassBarIconItem] and [GlassBarCustomItem], so the
/// cluster can match, measure and lay out both kinds uniformly.
sealed class GlassBarActionItem extends GlassBarItem {
  /// Const base constructor.
  const GlassBarActionItem({
    required this.onTap,
    this.id,
    this.label,
    this.enabled = true,
    this.background = GlassBarItemBackground.shared,
  });

  /// The tap handler for items that do not want one, mirroring
  /// `GlassButtonGroupItem.menu`.
  static void _noOp() {}

  /// Called when the item is tapped.
  ///
  /// Never null: an icon in a navigation bar that does nothing is a bug, so
  /// [GlassBarItem.icon] requires one. Passive [GlassBarItem.custom] content
  /// gets an internal no-op instead, keeping every reader of it callable.
  /// [GlassBarItem.menu] does the same — its tap opens the menu, which the
  /// cluster drives directly.
  final VoidCallback onTap;

  /// Identity used to match this item against items on other routes.
  ///
  /// See [GlassBarItem.icon] for the matching rules.
  final Object? id;

  /// Optional semantic label.
  final String? label;

  /// Whether the item responds to taps. Disabled items render dimmed.
  final bool enabled;

  /// How this item's glass background is drawn.
  ///
  /// Defaults to [GlassBarItemBackground.shared], so items form one capsule.
  final GlassBarItemBackground background;

  /// The widget rendered inside the cluster.
  Widget get content;
}

/// An icon item in a pinned navigation-bar cluster.
///
/// Created via [GlassBarItem.icon].
final class GlassBarIconItem extends GlassBarActionItem {
  /// Creates an icon item. Prefer [GlassBarItem.icon].
  const GlassBarIconItem({
    required this.icon,
    required super.onTap,
    super.id,
    super.label,
    super.enabled,
    super.background,
  });

  /// The icon widget, typically an [Icon].
  ///
  /// Size and colour are applied by the enclosing cluster.
  final Widget icon;

  @override
  Widget get content => icon;
}

/// A custom-content item in a pinned navigation-bar cluster.
///
/// Created via [GlassBarItem.custom].
final class GlassBarCustomItem extends GlassBarActionItem {
  /// Creates a custom item. Prefer [GlassBarItem.custom].
  const GlassBarCustomItem({
    required this.child,
    super.onTap = GlassBarActionItem._noOp,
    super.id,
    super.label,
    super.enabled,
    super.background,
  });

  /// The widget rendered inside the cluster, measured at its intrinsic width.
  final Widget child;

  @override
  Widget get content => child;
}

/// A pull-down menu item in a pinned navigation-bar cluster.
///
/// Created via [GlassBarItem.menu].
final class GlassBarMenuItem extends GlassBarActionItem {
  /// Creates a menu item. Prefer [GlassBarItem.menu].
  const GlassBarMenuItem({
    required this.icon,
    required this.menuItems,
    this.menuAlignment,
    this.menuWidth = 200,
    super.id,
    super.label,
    super.background,
  }) : super(onTap: GlassBarActionItem._noOp);

  /// The icon widget, typically an [Icon]. Conventionally an ellipsis.
  ///
  /// Size and colour are applied by the enclosing cluster.
  final Widget icon;

  /// The menu's contents: [GlassMenuItem] and [GlassMenuDivider] widgets.
  final List<Widget> menuItems;

  /// Where the menu expands relative to the capsule.
  ///
  /// Defaults to auto-detection from the capsule's screen position.
  final GlassMenuAlignment? menuAlignment;

  /// Width of the expanded menu panel, in logical pixels.
  final double menuWidth;

  @override
  Widget get content => icon;
}

/// A glass-background break in a pinned cluster.
///
/// Created via [GlassBarItem.spacer].
final class GlassBarSpacer extends GlassBarItem {
  /// Creates a spacer. Prefer [GlassBarItem.spacer].
  const GlassBarSpacer();
}
