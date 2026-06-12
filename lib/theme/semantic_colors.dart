import 'package:flutter/material.dart';

/// Domain-specific semantic colors exposed via [ThemeExtension].
///
/// These mirror the legacy hardcoded `Colors.*` calls used by holiday markers,
/// status badges, and the course detail sheet. The cluster is split out into
/// a [ThemeExtension] so that light/dark switching can adjust them without
/// reaching into [Colors] directly.
@immutable
class SemanticColors extends ThemeExtension<SemanticColors> {
  const SemanticColors({
    required this.holiday,
    required this.festival,
    required this.solarTerm,
    required this.statusBadge,
    required this.infoTeal,
    required this.warnOrange,
    required this.linkBlue,
    required this.errorAccent,
  });

  /// Public-holiday label color (e.g. 国庆).
  final Color holiday;

  /// Festival label color (e.g. 春节).
  final Color festival;

  /// Solar-term label color (e.g. 冬至).
  final Color solarTerm;

  /// Tiny status dot used by [BadgedTile] and similar.
  final Color statusBadge;

  /// Info / teacher icon tint used in the course detail sheet.
  final Color infoTeal;

  /// Warning / location icon tint used in the course detail sheet.
  final Color warnOrange;

  /// External link / school icon tint used in the course detail sheet.
  final Color linkBlue;

  /// Destructive / delete icon tint used in the course detail sheet.
  final Color errorAccent;

  /// Light theme defaults — match the previous hardcoded `Colors.*` values.
  static const light = SemanticColors(
    holiday: Color(0xFFD32F2F),
    festival: Color(0xFFE65100),
    solarTerm: Color(0xFF2E7D32),
    statusBadge: Color(0xFFD32F2F),
    infoTeal: Color(0xFF00897B),
    warnOrange: Color(0xFFE65100),
    linkBlue: Color(0xFF1976D2),
    errorAccent: Color(0xFFD32F2F),
  );

  /// Dark theme defaults — soft counterparts of the light values.
  static const dark = SemanticColors(
    holiday: Color(0xFFEF9A9A),
    festival: Color(0xFFFFB74D),
    solarTerm: Color(0xFF81C784),
    statusBadge: Color(0xFFEF9A9A),
    infoTeal: Color(0xFF4DB6AC),
    warnOrange: Color(0xFFFFB74D),
    linkBlue: Color(0xFF64B5F6),
    errorAccent: Color(0xFFEF9A9A),
  );

  /// Convenience accessor for [BuildContext].
  static SemanticColors of(BuildContext context) {
    final extension = Theme.of(context).extension<SemanticColors>();
    assert(
      extension != null,
      'SemanticColors is missing. Did you register it in ThemeData.extensions?',
    );
    return extension ?? light;
  }

  @override
  SemanticColors copyWith({
    Color? holiday,
    Color? festival,
    Color? solarTerm,
    Color? statusBadge,
    Color? infoTeal,
    Color? warnOrange,
    Color? linkBlue,
    Color? errorAccent,
  }) {
    return SemanticColors(
      holiday: holiday ?? this.holiday,
      festival: festival ?? this.festival,
      solarTerm: solarTerm ?? this.solarTerm,
      statusBadge: statusBadge ?? this.statusBadge,
      infoTeal: infoTeal ?? this.infoTeal,
      warnOrange: warnOrange ?? this.warnOrange,
      linkBlue: linkBlue ?? this.linkBlue,
      errorAccent: errorAccent ?? this.errorAccent,
    );
  }

  @override
  SemanticColors lerp(ThemeExtension<SemanticColors>? other, double t) {
    if (other is! SemanticColors) return this;
    return SemanticColors(
      holiday: Color.lerp(holiday, other.holiday, t) ?? holiday,
      festival: Color.lerp(festival, other.festival, t) ?? festival,
      solarTerm: Color.lerp(solarTerm, other.solarTerm, t) ?? solarTerm,
      statusBadge: Color.lerp(statusBadge, other.statusBadge, t) ?? statusBadge,
      infoTeal: Color.lerp(infoTeal, other.infoTeal, t) ?? infoTeal,
      warnOrange: Color.lerp(warnOrange, other.warnOrange, t) ?? warnOrange,
      linkBlue: Color.lerp(linkBlue, other.linkBlue, t) ?? linkBlue,
      errorAccent: Color.lerp(errorAccent, other.errorAccent, t) ?? errorAccent,
    );
  }
}
