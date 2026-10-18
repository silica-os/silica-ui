// The Amalfi glass surface: Glass/Regular, Glass/Thick and the static look of Glass/Clear,
// drawn in the order of `materials.md`: backdrop → blur → saturation → tint → inside rim →
// rim light → content, with the drop shadow outside the shape only.
//
// The kit's (CSS) blur semantics are kept: a background blur of radius r is a Gaussian of
// σ = r; a drop or inner shadow of blur b is a Gaussian of σ = b / 2.

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import '../glass.dart' as compositor;
import 'components/popovers/popover_surface.dart';
import 'foundation/shadow.dart';
import 'glass_refraction.dart';
import 'smooth_border.dart';
import '../system_look.dart';
import 'theme.dart';
import 'token_types.dart';
import 'tokens.g.dart';

/// Who draws the glass of the Amalfi widgets.
enum AmalfiGlassBackend {
  /// Flutter draws everything: a backdrop blur and saturation, the tint, the rims and the
  /// shadow (the default; tests and the gallery). Needs something behind the glass in the
  /// same layer.
  flutter,

  /// The compositor (Ossido) draws the glass: the widget declares a region (`Glass`, with the
  /// [AmalfiGlassKind] as profile and the profile's shadow) and paints only its content: no
  /// backdrop, tint, rims or shadow. Use it in shell surfaces, which are layers of their own.
  compositor,
}

/// The kind of surface a glass belongs to; it is the `profile` of the compositor region
/// (`silica-glass-v1` version 7), so Ossido picks blur, tint, rims and shadow of that kind.
/// The Flutter backend ignores it (the material decides).
enum AmalfiGlassKind {
  menu(compositor.GlassProfile.menu),
  popover(compositor.GlassProfile.popover),
  panel(compositor.GlassProfile.panel),
  module(compositor.GlassProfile.module),
  control(compositor.GlassProfile.control),
  dock(compositor.GlassProfile.dock),
  tooltip(compositor.GlassProfile.tooltip),
  sheet(compositor.GlassProfile.sheet),
  banner(compositor.GlassProfile.banner);

  const AmalfiGlassKind(this.profile);

  /// The profile of the compositor region.
  final compositor.GlassProfile profile;
}

/// Sets the [AmalfiGlassBackend] of the [AmalfiGlass] widgets below it.
class AmalfiGlassBackendScope extends InheritedWidget {
  const AmalfiGlassBackendScope({
    super.key,
    required this.backend,
    required super.child,
  });

  final AmalfiGlassBackend backend;

  /// The backend in effect under [context]; [AmalfiGlassBackend.flutter] without a scope.
  static AmalfiGlassBackend of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<AmalfiGlassBackendScope>()
          ?.backend ??
      AmalfiGlassBackend.flutter;

  @override
  bool updateShouldNotify(AmalfiGlassBackendScope old) =>
      old.backend != backend;
}

/// A surface of an Amalfi glass [material] with smooth corners of [radius] (or in the outline
/// of any [shape]: a popover with its arrow), holding [child] (which is not clipped: keep it
/// inside the shape).
///
/// The appearance comes from [AmalfiTheme.of]. With [opaque] (no blur available, or reduced
/// transparency) the backdrop is replaced by `Surface/Window` under the tint, as
/// `materials.md` asks; rims and shadow stay. Regular and Thick are real glass: where
/// the engine runs shader image filters (Impeller) the blurred backdrop is bent at the rim over
/// a band of `depth` x half the shorter side, with a small chromatic split and a specular
/// highlight (`shaders/glass_edge.frag`); elsewhere only blur, saturation and brightness. A lens
/// material ([AmalfiMaterials.clear]) is drawn without its refraction: the lens itself is a
/// separate, animated effect.
///
/// The [AmalfiGlassBackend] in effect ([AmalfiGlassBackendScope]) decides who draws it. With
/// [AmalfiGlassBackend.compositor] the widget declares a compositor region of [kind] (default
/// from the material: thick menu, regular control, clear control) with the [outline]'s radius
/// (a popover's arrow becomes the region's tip) and paints only [child]; [opaque] is ignored.
class AmalfiGlass extends StatefulWidget {
  const AmalfiGlass({
    super.key,
    this.material = AmalfiMaterials.thick,
    this.radius = 0,
    this.shape,
    this.opaque = false,
    this.kind,
    this.group = 0,
    this.child,
  });

  /// The compositor group: a glass merges only with glass of its own group, and a higher
  /// group sits on top (a submenu on its menu). Ignored by the Flutter backend.
  final int group;

  /// The kind of surface, for the compositor backend; null: from [material].
  final AmalfiGlassKind? kind;

  /// The kind in effect: [kind], or the default of [material].
  AmalfiGlassKind get effectiveKind =>
      kind ??
      (material == AmalfiMaterials.thick
          ? AmalfiGlassKind.menu
          : AmalfiGlassKind.control);

  static compositor.GlassMaterial _compositorMaterial(
    AmalfiGlassMaterial material,
  ) => material == AmalfiMaterials.thick
      ? compositor.GlassMaterial.thick
      : material == AmalfiMaterials.regular
      ? compositor.GlassMaterial.regular
      : compositor.GlassMaterial.clear;

  Widget _buildCompositor() {
    final shape = this.shape;
    final glassMaterial = _compositorMaterial(material);
    final profile = effectiveKind.profile;
    if (shape is AmalfiPopoverBorder) {
      final popover = shape.shape;
      final side = popover.side;
      if (side == null) {
        return compositor.Glass(
          radius: AmalfiPopoverMetrics.radius,
          material: glassMaterial,
          profile: profile,
          group: group,
          profileShadow: true,
          child: child,
        );
      }
      return LayoutBuilder(
        builder: (context, constraints) {
          // The tip's position along the body's edge, from the body's own origin.
          final size = constraints.biggest;
          final rect = Offset.zero & (size.isFinite ? size : Size.zero);
          final body = popover.body(rect);
          final tip = popover.tip(rect);
          final horizontal =
              side == AxisDirection.up || side == AxisDirection.down;
          final x = tip == null
              ? 0.0
              : horizontal
              ? tip.dx - body.left
              : tip.dy - body.top;
          return Padding(
            padding: popover.arrowInsets,
            child: compositor.Glass(
              radius: AmalfiPopoverMetrics.radius,
              material: glassMaterial,
              profile: profile,
              group: group,
              profileShadow: true,
              tip: compositor.GlassTip(
                x: x,
                width: AmalfiPopoverMetrics.arrowHalfBase * 2,
                height: AmalfiPopoverMetrics.arrowDepth,
                edge: switch (side) {
                  AxisDirection.up => compositor.TipEdge.top,
                  AxisDirection.down => compositor.TipEdge.bottom,
                  AxisDirection.left => compositor.TipEdge.left,
                  AxisDirection.right => compositor.TipEdge.right,
                },
              ),
              child: child,
            ),
          );
        },
      );
    }
    return compositor.Glass(
      radius: shape is AmalfiSmoothBorder ? shape.radius : radius,
      material: glassMaterial,
      profile: profile,
      group: group,
      profileShadow: true,
      child: child,
    );
  }

  /// The material (`AmalfiMaterials.regular`, `.thick`, `.clear`).
  final AmalfiGlassMaterial material;

  /// The corner radius in points (smoothing [AmalfiRadii.smoothing]); a radius of at least
  /// half the shorter side gives a capsule.
  final double radius;

  /// The outline; null: an [AmalfiSmoothBorder] of [radius]. Its side is not painted (the
  /// rim is the material's).
  final ShapeBorder? shape;

  /// The outline drawn: [shape], or smooth corners of [radius].
  ShapeBorder get outline => shape ?? AmalfiSmoothBorder(radius: radius);

  /// Whether to draw an opaque fallback instead of blurring the backdrop.
  final bool opaque;

  final Widget? child;

  /// The drop shadows of [material] in [brightness]; empty when it has none.
  static List<BoxShadow> shadowsOf(
    AmalfiGlassMaterial material,
    Brightness brightness,
  ) {
    final level = material.shadowLevel;
    if (level == null) return const [];
    return AmalfiShadows.of(brightness).level(level) ?? const [];
  }

  /// Whether [material] refracts at its edge (Regular and Thick; a lens is a separate effect).
  bool get refracts => !material.lens && material.refraction != null;

  @override
  State<AmalfiGlass> createState() => _AmalfiGlassState();
}

class _AmalfiGlassState extends State<AmalfiGlass>
    with AmalfiGlassShaderState<AmalfiGlass> {
  @override
  void initState() {
    super.initState();
    if (widget.refracts) loadGlassShader();
  }

  @override
  void didUpdateWidget(AmalfiGlass old) {
    super.didUpdateWidget(old);
    if (widget.refracts) loadGlassShader();
  }

  @override
  Widget build(BuildContext context) {
    if (AmalfiGlassBackendScope.of(context) == AmalfiGlassBackend.compositor) {
      return widget._buildCompositor();
    }
    final material = widget.material;
    // Reduce Transparency (Settings › Accessibility › Display) draws every glass opaque.
    final opaque =
        widget.opaque || SystemLookScope.of(context).reduceTransparency;
    final theme = AmalfiTheme.of(context);
    final brightness = theme.brightness;
    final shape = widget.outline;
    final face = CustomPaint(
      painter: _GlassFacePainter(
        shape: shape,
        under: opaque ? theme.colors.surfaceWindow : null,
        tint: material.tint(brightness),
        rim: material.rimInside(brightness),
        rimWidth: material.rimInsideWidth,
        rimLight: material.rimLight(brightness),
        rimLightOffset: material.rimLightOffset,
        rimLightBlur: material.rimLightBlur,
      ),
      child: widget.child,
    );
    final gain = brightness == Brightness.dark
        ? material.brightnessDark
        : material.brightnessLight;
    // With the edge-refraction shader (Impeller) the backdrop is blurred first, then the shader
    // bends it at the rim and applies saturation and brightness; without it, the blur and the
    // colour matrix alone.
    final shader = glassShader;
    final refract =
        widget.refracts &&
        shader != null &&
        AmalfiGlassRefraction.supported &&
        AmalfiGlassRefraction.geometry(shape, const Size(1, 1)) != null;
    final blur = ui.ImageFilter.blur(
      sigmaX: material.backgroundBlur,
      sigmaY: material.backgroundBlur,
      tileMode: TileMode.clamp,
    );
    // The backdrop blur is clipped to the shape; the face is drawn unclipped with its own
    // antialiased outline, so that the edge pixels are not antialiased twice.
    return CustomPaint(
      painter: _OutsideShadowPainter(
        shape: shape,
        shadows: AmalfiGlass.shadowsOf(material, brightness),
      ),
      child: Stack(
        children: [
          if (!opaque)
            Positioned.fill(
              child: ClipPath(
                clipper: ShapeBorderClipper(shape: shape),
                child: BackdropFilter(
                  filter: refract
                      ? blur
                      : ui.ImageFilter.compose(
                          outer: ColorFilter.matrix(
                            _toneMatrix(material.saturation, gain),
                          ),
                          inner: blur,
                        ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          if (!opaque && refract)
            Positioned.fill(
              child: AmalfiGlassRefractionLayer(
                key: const ValueKey('amalfi glass refraction'),
                shader: shader,
                shape: shape,
                material: material,
                brightness: brightness,
              ),
            ),
          face,
        ],
      ),
    );
  }
}

/// The colour matrix that multiplies the saturation by [s] (Rec. 709 luma weights) and then
/// the brightness by [gain].
List<double> _toneMatrix(double s, double gain) {
  const r = 0.2126, g = 0.7152, b = 0.0722;
  final t = 1 - s;
  return [
    (r * t + s) * gain, g * t * gain, b * t * gain, 0, 0, //
    r * t * gain, (g * t + s) * gain, b * t * gain, 0, 0, //
    r * t * gain, g * t * gain, (b * t + s) * gain, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

/// Paints [shadows] of [shape] outside the shape only, as the kit draws them under glass.
class _OutsideShadowPainter extends CustomPainter {
  const _OutsideShadowPainter({required this.shape, required this.shadows});

  final ShapeBorder shape;
  final List<BoxShadow> shadows;

  @override
  void paint(Canvas canvas, Size size) =>
      paintAmalfiShadows(canvas, Offset.zero & size, shadows, shape: shape);

  @override
  bool shouldRepaint(_OutsideShadowPainter old) =>
      old.shape != shape || old.shadows != shadows;
}

/// Paints the face of the glass: optional opaque base, tint, inside rim, rim light.
class _GlassFacePainter extends CustomPainter {
  const _GlassFacePainter({
    required this.shape,
    required this.under,
    required this.tint,
    required this.rim,
    required this.rimWidth,
    required this.rimLight,
    required this.rimLightOffset,
    required this.rimLightBlur,
  });

  final ShapeBorder shape;
  final Color? under;
  final Color? tint;
  final Color rim;
  final double rimWidth;
  final Color rimLight;
  final Offset rimLightOffset;
  final double rimLightBlur;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final outline = shape.getOuterPath(rect);
    if (under case final color?) {
      canvas.drawPath(outline, Paint()..color = color);
    }
    if (tint case final color?) {
      canvas.drawPath(outline, Paint()..color = color);
    }
    // An inside stroke of the outline itself (as the kit strokes it).
    paintAmalfiInsideBorder(
      canvas,
      rect,
      shape,
      BorderSide(color: rim, width: rimWidth),
    );
    // The rim light: an inner shadow, the light falling inside the edge from [rimLightOffset].
    final reach = rimLightBlur * 2 + rimLightOffset.distance + 1;
    canvas
      ..save()
      ..clipPath(outline)
      ..drawPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(rect.inflate(reach)),
          outline.shift(rimLightOffset),
        ),
        Paint()
          ..color = rimLight
          ..maskFilter = rimLightBlur > 0
              ? MaskFilter.blur(
                  BlurStyle.normal,
                  amalfiShadowSigma(rimLightBlur),
                )
              : null,
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_GlassFacePainter old) =>
      old.shape != shape ||
      old.under != under ||
      old.tint != tint ||
      old.rim != rim ||
      old.rimWidth != rimWidth ||
      old.rimLight != rimLight ||
      old.rimLightOffset != rimLightOffset ||
      old.rimLightBlur != rimLightBlur;
}
