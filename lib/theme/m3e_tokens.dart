import 'package:flutter/material.dart';

/// Material 3 Expressive shape corner-radius tokens.
///
/// Mapped to the 7-step corner-radius ladder introduced by M3 Expressive.
/// Use [AppRadius] in place of `BorderRadius.circular(N)` literals so that
/// the visual rhythm stays consistent across the app.
enum AppRadius {
  xs(4, BorderRadius.all(Radius.circular(4))),
  sm(8, BorderRadius.all(Radius.circular(8))),
  md(12, BorderRadius.all(Radius.circular(12))),
  lg(16, BorderRadius.all(Radius.circular(16))),
  xl(20, BorderRadius.all(Radius.circular(20))),
  xxl(28, BorderRadius.all(Radius.circular(28))),
  full(999, BorderRadius.all(Radius.circular(999)));

  const AppRadius(this.value, this.borderRadius);

  final double value;

  /// Pre-built [BorderRadius] using this token. Const-friendly.
  final BorderRadius borderRadius;

  /// Corner radius as a [Radius], useful for `BorderRadius.vertical(...)` etc.
  Radius get asRadius => Radius.circular(value);
}

/// Common [ShapeBorder] constants built from [AppRadius].
///
/// These match the standard MD3E corner-radius ladder and are intended
/// for use in `Card`/`Button`/`Sheet` shape customization.
class AppShapes {
  const AppShapes._();

  static const RoundedRectangleBorder roundedXs = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(4)),
  );
  static const RoundedRectangleBorder roundedSm = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
  );
  static const RoundedRectangleBorder roundedMd = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(12)),
  );
  static const RoundedRectangleBorder roundedLg = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(16)),
  );
  static const RoundedRectangleBorder roundedXl = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(20)),
  );
  static const RoundedRectangleBorder roundedXxl = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(28)),
  );

  /// Pill shape (fully rounded). Used by Filled buttons and badges.
  static const ShapeBorder pill = StadiumBorder();

  /// Build a card-like [RoundedRectangleBorder] with a 1-px outline side.
  ///
  /// [outlineColor] defaults to a transparent stroke; supply a theme color
  /// (typically `colorScheme.outline.withValues(alpha: 0.2)`) for the
  /// outlined-card look used by the app.
  static RoundedRectangleBorder outlined({
    AppRadius radius = AppRadius.lg,
    Color outlineColor = Colors.transparent,
  }) {
    return RoundedRectangleBorder(
      borderRadius: radius.borderRadius,
      side: BorderSide(color: outlineColor, width: 1),
    );
  }

  /// Top-rounded card shape, used for `showModalBottomSheet` containers.
  static const BorderRadius sheetTopRadius = BorderRadius.vertical(
    top: Radius.circular(20),
  );
}

/// Material 3 Expressive motion curves.
///
/// Flutter's built-in curves are used as approximate stand-ins for the
/// "emphasized" easing family introduced by M3E (no external package).
class AppMotion {
  const AppMotion._();

  /// Emphasized decelerate — elements entering the screen.
  static const Curve emphasizedDecelerate = Curves.easeOutCubic;

  /// Emphasized accelerate — elements leaving the screen.
  static const Curve emphasizedAccelerate = Curves.easeInCubic;

  /// Emphasized standard — elements moving on screen.
  static const Cubic emphasizedStandard = Cubic(0.2, 0.0, 0.0, 1.0);
}
