// The high-contrast variant of the Amalfi palette (Settings › Accessibility › Display ›
// Increase Contrast): secondary text and lines are stronger, the accent is deeper (light) or
// brighter (dark) and the hover and press washes are firmer. Derived from the tokens, so it
// follows them; it changes only the system colours, never an app's palette.

import 'package:flutter/widgets.dart';

import 'tokens.g.dart';

/// [colors] with more contrast between content and background.
AmalfiColors increaseContrastOf(AmalfiColors colors) {
  final dark = colors.brightness == Brightness.dark;
  final ink = dark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);

  /// [c] moved [t] of the way to the ink, and at least [alpha] opaque.
  Color stronger(Color c, double t, double alpha) {
    final moved = Color.lerp(c.withAlpha(0xFF), ink, t) ?? c;
    final a = (c.a > alpha ? c.a : alpha).clamp(0.0, 1.0);
    return moved.withValues(alpha: a);
  }

  Color withAlphaScaled(Color c, double factor) =>
      c.withValues(alpha: (c.a * factor).clamp(0.0, 1.0));

  return colors.mapSystem((field, c) {
    switch (field) {
      case 'textSecondary':
        return stronger(c, 0.55, 0.9);
      case 'textTertiary':
        return stronger(c, 0.5, 0.78);
      case 'lineSeparator':
        return ink.withValues(alpha: dark ? 0.42 : 0.36);
      case 'lineBorder':
        return ink.withValues(alpha: dark ? 0.6 : 0.55);
      case 'accentAmalfi':
        return Color.lerp(c, ink, dark ? 0.16 : 0.2) ?? c;
      case 'accentAmalfiPressed':
        return Color.lerp(c, ink, dark ? 0.04 : 0.3) ?? c;
      case 'accentAmalfiSoft':
      case 'stateHoverOverlay':
      case 'statePressOverlay':
        return withAlphaScaled(c, 1.6);
      default:
        return c;
    }
  });
}
