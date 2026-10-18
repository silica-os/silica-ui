// The value types of the Amalfi design tokens. The values themselves are generated into
// `tokens.g.dart` from `tool/amalfi/tokens.json` and `tool/amalfi/motion.md`.

import 'package:flutter/widgets.dart';

/// The palette of one app (`App/<App>/<Token>` in `tokens.json`), in one appearance.
///
/// Each app with a palette has a generated subclass with a typed field per token (for
/// example `AmalfiTerminalColors.selection`), reached from [AmalfiColors] by a field named
/// after the app (`AmalfiColors.light.terminal`) or by name
/// (`AmalfiColors.light.app('Terminal', 'Selection')`).
///
/// An app with a single appearance (for example a dark-only one) has the same palette in
/// both [AmalfiColors.light] and [AmalfiColors.dark]: [brightness] says which one it is and
/// [appearances] lists those the app defines. Such an app should also force its appearance
/// (`SilicaAppearance.dark` on its `SilicaApp` or window).
abstract class AmalfiAppColors {
  const AmalfiAppColors();

  /// The app's name as in the token names (`Terminal`, `Mission Control`).
  String get app;

  /// The appearance this palette belongs to.
  Brightness get brightness;

  /// The appearances the app defines a palette for.
  Set<Brightness> get appearances;

  /// The token names, without the `App/<App>/` prefix, in the order of `tokens.json`.
  List<String> get tokenNames;

  /// The colour of [token] (without the `App/<App>/` prefix); null when the app has no
  /// such token.
  Color? operator [](String token);
}

/// A text style token: family, size, line height and weight from `tokens.json`.
@immutable
final class AmalfiTextToken {
  const AmalfiTextToken({
    required this.name,
    required this.family,
    required this.size,
    required this.lineHeight,
    required this.weight,
    this.tracking = 0,
    this.features = const [],
    required this.colorTokens,
  });

  /// The style's name in `tokens.json` (`Title 1`).
  final String name;

  /// The font family, served by this package (`Inter`, `JetBrains Mono`).
  final String family;

  /// Font size in points.
  final double size;

  /// Line height in points; null for the font's natural line height.
  final double? lineHeight;

  /// Font weight.
  final FontWeight weight;

  /// Tracking in points (the kit's character spacing), added after every character; 0: the
  /// font's own spacing.
  final double tracking;

  /// OpenType features by tag (`tnum`: tabular figures).
  final List<String> features;

  /// The colour tokens the kit pairs with this style (`Text/Primary`, `Accent/Amalfi`, …),
  /// to be resolved with `AmalfiColors.byName`. `On Photo` is not a token: white ink straight
  /// on the wallpaper (the lock screen).
  final List<String> colorTokens;

  /// The style as a [TextStyle], in [color] (none: inherited). The extra line height is split
  /// evenly above and below the glyphs, as in the kit. Without [tracking] the font's own
  /// spacing applies.
  TextStyle style({Color? color}) => TextStyle(
    fontFamily: family,
    package: 'silica_ui',
    fontSize: size,
    height: lineHeight == null ? null : lineHeight! / size,
    leadingDistribution: TextLeadingDistribution.even,
    fontWeight: weight,
    letterSpacing: tracking == 0 ? null : tracking,
    fontFeatures: features.isEmpty
        ? null
        : [for (final f in features) FontFeature(f)],
    color: color,
  );
}

/// The colours of one window control disc (close, minimise, zoom), at rest in an active
/// light window.
@immutable
final class AmalfiWindowControl {
  const AmalfiWindowControl({
    required this.top,
    required this.bottom,
    required this.rim,
    required this.rimWidth,
  });

  /// The colour at the top of the vertical gradient.
  final Color top;

  /// The colour at the bottom of the vertical gradient.
  final Color bottom;

  /// The colour of the rim.
  final Color rim;

  /// The width of the rim in points (the number after the colour in `tokens.json`, read as a
  /// stroke width).
  final double rimWidth;
}

/// The refraction of a glass material: a lens (`Glass/Clear`, which also magnifies) or the edge
/// refraction of `Glass/Regular` and `Glass/Thick` (magnification 1).
@immutable
final class AmalfiRefraction {
  const AmalfiRefraction({
    required this.distortion,
    required this.depth,
    required this.chromaticAberration,
    required this.magnification,
  });

  /// How much the edge bends what is under it (0–1).
  final double distortion;

  /// The apparent depth of the lens (0–1).
  final double depth;

  /// How far the colour channels split at the edge (0–1).
  final double chromaticAberration;

  /// The scale of what is under the lens (1 = none).
  final double magnification;
}

/// A blur strip (`Blur/*` in tokens.json): the background blurred and saturated under a tint,
/// with no refraction, rim, shadow or specular: the title bar section over a sidebar.
@immutable
final class AmalfiBlurStrip {
  const AmalfiBlurStrip({
    required this.name,
    required this.backgroundBlur,
    required this.saturation,
    required this.tintLight,
    required this.tintDark,
  });

  final String name;

  /// The blur sigma, in points.
  final double backgroundBlur;
  final double saturation;
  final Color tintLight;
  final Color tintDark;

  /// The tint in [brightness].
  Color tint(Brightness brightness) =>
      brightness == Brightness.dark ? tintDark : tintLight;
}

/// The parameters of a glass material (`Glass/Regular`, `Glass/Thick`, `Glass/Clear`), as
/// plain data. How to render them: `docs/design/amalfi/materials.md` in silica-desktop.
@immutable
final class AmalfiGlassMaterial {
  const AmalfiGlassMaterial({
    required this.name,
    required this.backgroundBlur,
    required this.saturation,
    required this.tintLight,
    required this.tintDark,
    required this.rimInsideWidth,
    required this.rimInsideLight,
    required this.rimInsideDark,
    required this.rimLightOffset,
    required this.rimLightBlur,
    required this.rimLightLight,
    required this.rimLightDark,
    required this.shadowLevel,
    required this.lens,
    required this.refraction,
    required this.specularHighlights,
    required this.brightnessLight,
    required this.brightnessDark,
    this.increaseContrastLight,
    this.increaseContrastDark,
    this.reduceTransparencyLight,
    this.reduceTransparencyDark,
  });

  /// The material's name in `tokens.json` (`Glass/Regular`).
  final String name;

  /// The Gaussian blur radius of the backdrop, in points.
  final double backgroundBlur;

  /// The saturation factor applied to the blurred backdrop (1 = unchanged).
  final double saturation;

  /// The tint over the backdrop in the light appearance; null: no tint.
  final Color? tintLight;

  /// The tint over the backdrop in the dark appearance; null: no tint.
  final Color? tintDark;

  /// The width of the rim drawn inside the shape, in points.
  final double rimInsideWidth;

  /// The inside rim's colour, light appearance.
  final Color rimInsideLight;

  /// The inside rim's colour, dark appearance.
  final Color rimInsideDark;

  /// The offset of the rim light (an inner shadow along the top edge).
  final Offset rimLightOffset;

  /// The blur of the rim light, in points.
  final double rimLightBlur;

  /// The rim light's colour, light appearance.
  final Color rimLightLight;

  /// The rim light's colour, dark appearance.
  final Color rimLightDark;

  /// The level of `AmalfiShadows` dropped outside the shape (1–3); null: no shadow.
  final int? shadowLevel;

  /// Whether the material is a lens (it refracts and magnifies what is under it).
  final bool lens;

  /// The refraction; null for a material that does not refract.
  final AmalfiRefraction? refraction;

  /// Whether the material draws specular highlights along its rim.
  final bool specularHighlights;

  /// The brightness factor of what is under the material, light appearance (1 = unchanged).
  final double brightnessLight;

  /// The brightness factor of what is under the material, dark appearance (1 = unchanged).
  final double brightnessDark;

  /// The tint in [brightness]; null: no tint.
  Color? tint(Brightness brightness) =>
      brightness == Brightness.dark ? tintDark : tintLight;

  /// The inside rim's colour in [brightness].
  Color rimInside(Brightness brightness) =>
      brightness == Brightness.dark ? rimInsideDark : rimInsideLight;

  /// The rim light's colour in [brightness].
  Color rimLight(Brightness brightness) =>
      brightness == Brightness.dark ? rimLightDark : rimLightLight;

  /// The material's own Increase Contrast treatment, light appearance; null: none.
  final AmalfiGlassVariant? increaseContrastLight;

  /// The material's own Increase Contrast treatment, dark appearance; null: none.
  final AmalfiGlassVariant? increaseContrastDark;

  /// The material's own Reduce Transparency treatment, light appearance; null: none.
  final AmalfiGlassVariant? reduceTransparencyLight;

  /// The material's own Reduce Transparency treatment, dark appearance; null: none.
  final AmalfiGlassVariant? reduceTransparencyDark;

  /// The Increase Contrast treatment in [brightness]; null: the material has none.
  AmalfiGlassVariant? increaseContrast(Brightness brightness) =>
      brightness == Brightness.dark
      ? increaseContrastDark
      : increaseContrastLight;

  /// The Reduce Transparency treatment in [brightness]; null: the material has none.
  AmalfiGlassVariant? reduceTransparency(Brightness brightness) =>
      brightness == Brightness.dark
      ? reduceTransparencyDark
      : reduceTransparencyLight;
}

/// An accessibility treatment of a glass material (`Glass/Lock Increase Contrast`, `Glass/Lock
/// Reduce Transparency`): an opaque fill with its rims, in one appearance.
@immutable
final class AmalfiGlassVariant {
  const AmalfiGlassVariant({
    required this.fill,
    required this.rimInside,
    required this.rimLight,
    required this.backgroundBlur,
    required this.saturation,
  });

  /// The fill (opaque or nearly).
  final Color fill;

  /// The 1 pt rim inside the shape.
  final Color rimInside;

  /// The rim light along the top edge; null: none.
  final Color? rimLight;

  /// The background blur that shows only at the antialiased edge; 0: none.
  final double backgroundBlur;

  /// The saturation of that blur (1 = unchanged).
  final double saturation;
}

/// A glass clipped to glyphs (`Glass/Clock`, the lock screen's digits): the backdrop blurred,
/// saturated and brightened through the glyphs, a fill, a line inside and a rim outside.
@immutable
final class AmalfiGlyphGlass {
  const AmalfiGlyphGlass({
    required this.name,
    required this.backgroundBlur,
    required this.saturation,
    required this.brightness,
    required this.refraction,
    required this.specularHighlights,
    required this.fill,
    required this.lineInsideWidth,
    required this.lineInside,
    required this.rimOutsideWidth,
    required this.rimOutsideLight,
    required this.rimOutsideDark,
    required this.reduceTransparencyFill,
    required this.increaseContrastFill,
    required this.increaseContrastRimWidth,
    required this.increaseContrastRim,
  });

  /// The material's name in `tokens.json` (`Glass/Clock`).
  final String name;

  /// The blur of the backdrop seen through the glyphs, in points.
  final double backgroundBlur;

  /// The saturation factor of that backdrop.
  final double saturation;

  /// The brightness factor of that backdrop.
  final double brightness;

  /// The edge refraction.
  final AmalfiRefraction refraction;

  /// Whether the glyphs' edges draw specular highlights.
  final bool specularHighlights;

  /// The fill over the backdrop.
  final Color fill;

  /// The width of the bright line just inside the outline.
  final double lineInsideWidth;

  /// The bright line's colour.
  final Color lineInside;

  /// The width of the dark rim just outside the outline.
  final double rimOutsideWidth;

  /// The dark rim's colour, light appearance.
  final Color rimOutsideLight;

  /// The dark rim's colour, dark appearance.
  final Color rimOutsideDark;

  /// Reduce Transparency: the fill, no glass and no line inside; the rim stays.
  final Color reduceTransparencyFill;

  /// Increase Contrast: the solid fill, no glass and no line inside.
  final Color increaseContrastFill;

  /// Increase Contrast: the width of the rim outside.
  final double increaseContrastRimWidth;

  /// Increase Contrast: the rim's colour.
  final Color increaseContrastRim;

  /// The rim outside in [brightness].
  Color rimOutside(Brightness brightness) =>
      brightness == Brightness.dark ? rimOutsideDark : rimOutsideLight;
}

/// A scrim: a vertical gradient over a picture, under everything else (`Scrim/Lock Light`).
@immutable
final class AmalfiScrim {
  const AmalfiScrim({
    required this.name,
    required this.stops,
    required this.colors,
  });

  /// The scrim's name in `tokens.json`.
  final String name;

  /// The stop positions, 0 (top) to 1 (bottom).
  final List<double> stops;

  /// The colour at each stop.
  final List<Color> colors;

  /// The gradient, top to bottom.
  LinearGradient get gradient => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: colors,
    stops: stops,
  );
}

/// A spring motion token: a [SpringDescription] (mass 1) with the response and damping ratio
/// it was derived from (stiffness k = (2π / response)², damping c = 2 ζ √k).
final class AmalfiSpring extends SpringDescription {
  const AmalfiSpring({
    required this.name,
    required this.response,
    required this.dampingRatio,
    required super.stiffness,
    required super.damping,
  }) : super(mass: 1);

  /// The token's name in `motion.md` (`spring.snappy`).
  final String name;

  /// The response (period of the undamped spring), in seconds.
  final double response;

  /// The damping ratio ζ (1 = critically damped).
  final double dampingRatio;
}

/// A fade motion token: a duration and a curve.
@immutable
final class AmalfiFade {
  const AmalfiFade({
    required this.name,
    required this.duration,
    required this.curve,
  });

  /// The token's name in `motion.md` (`fade.quick`).
  final String name;

  /// How long the fade lasts.
  final Duration duration;

  /// The easing curve.
  final Curve curve;
}
