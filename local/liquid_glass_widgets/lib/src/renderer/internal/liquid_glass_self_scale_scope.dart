import 'package:flutter/widgets.dart';

/// Marks a subtree whose ancestor scale is applied to the glass alone, and not
/// to the backdrop that glass samples.
///
/// [RenderLiquidGlassLayer] freezes its shader UV coordinates when it sees a
/// uniform scale-down above it, because the case that motivated it — the
/// CupertinoSheet push-back (#192) — scales the glass *and* the page it samples
/// together, leaving the sampled texture in unscaled coordinates.
///
/// A surface that scales itself is the opposite arrangement: the backdrop
/// behind it holds still, so the live transform is the correct one and freezing
/// strands the shader's shape at the size and position the surface had when the
/// scale began. The two are indistinguishable from the matrix, so the widget
/// applying the scale says which it is.
class LiquidGlassSelfScaleScope extends InheritedWidget {
  /// Declares that an ancestor scale over [child] does not move its backdrop.
  const LiquidGlassSelfScaleScope({
    required this.selfScaled,
    required super.child,
    super.key,
  });

  /// Whether such a scale is currently in effect.
  ///
  /// Held false while the surface sits at its natural size, so an ordinary
  /// push-back over a resting surface still freezes as it should.
  final bool selfScaled;

  /// The scale below which [RenderLiquidGlassLayer] freezes, so a caller can
  /// declare itself on exactly the same boundary rather than an invented one.
  static const double freezeScaleThreshold = 0.9999;

  /// Whether [context] sits under a scope that is currently self-scaling.
  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<LiquidGlassSelfScaleScope>()
          ?.selfScaled ??
      false;

  @override
  bool updateShouldNotify(LiquidGlassSelfScaleScope oldWidget) =>
      selfScaled != oldWidget.selfScaled;
}
