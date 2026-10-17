// The icon of an app or a place as the shell draws it. The layered icons of silica-icons
// take shape, edge and shadow from here (icon-format.md: the layers do not contain them);
// already composed freedesktop icons are reduced to the keyline on a neutral background;
// without an icon, the tile with the initial.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter, TileMode;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../silica_ui.dart' show uiFontFamily, uiText;
import 'file_icons.dart';
import '../thumbnails.dart';
import 'silica_icons.dart';

/// Icon canvas: 1024, body 824 at 100 from the edge, square keyline 600.
const double canvasSide = 1024;
const double bodyInset = 100;
const double bodySide = 824;
const double keylineSide = 600;

/// Body mask: a superellipse per corner with n ≈ 2.6 and radius ≈ 0.32 × side
/// (plan/reference/icons.md, measured on the app switcher).
const double maskExponent = 2.6;
const double maskRadiusRatio = 0.32;

/// Shadow of the icon on the background: ~3 % of the side below, blurred as much (dock.md).
const double dropOffsetRatio = 0.03;
const Color dropColor = Color(0x55000000);

/// Shadow of the foreground on the background (`"shadow": "neutral"`).
const double layerShadowRatio = 0.012;
const Color layerShadowColor = Color(0x38000000);

/// The ground shadow of an icon (plan/reference/icons.md, IC-01: a fitted black Gaussian
/// shadow, the same in every theme). Measurements per canvas side: 32 → opacity 0.35, σ 1.2,
/// down 0.55; 64 → 0.20, 1.45, 0.8; 128 → 0.28, 2.7, 1.2; 512 → 0.25, 7.5, 3.1 (pt).
/// Between the measurements σ and offset follow the side in proportion, the opacity is interpolated;
/// at 128 the shadow spills ~5 pt per side, as silica-icons says.
@immutable
class IconShadow {
  const IconShadow(this.opacity, this.sigma, this.offset);

  final double opacity;
  final double sigma;
  final double offset;

  static const List<(double, double, double, double)> _measured = [
    (32, 0.35, 1.2, 0.55),
    (64, 0.20, 1.45, 0.8),
    (128, 0.28, 2.7, 1.2),
    (512, 0.25, 7.5, 3.1),
  ];

  static IconShadow forSide(double side) {
    final first = _measured.first, last = _measured.last;
    if (side <= first.$1) {
      final k = side / first.$1;
      return IconShadow(first.$2, first.$3 * k, first.$4 * k);
    }
    if (side >= last.$1) {
      final k = side / last.$1;
      return IconShadow(last.$2, last.$3 * k, last.$4 * k);
    }
    for (var i = 1; i < _measured.length; i++) {
      final (s0, a0, g0, d0) = _measured[i - 1];
      final (s1, a1, g1, d1) = _measured[i];
      if (side > s1) continue;
      // On the logarithmic scale of the side, like the measured ratios.
      final t = (math.log(side) - math.log(s0)) / (math.log(s1) - math.log(s0));
      double lerp(double a, double b) => a + (b - a) * t;
      return IconShadow(
        lerp(a0, a1),
        side * lerp(g0 / s0, g1 / s1),
        side * lerp(d0 / s0, d1 / s1),
      );
    }
    return IconShadow(last.$2, last.$3, last.$4);
  }
}

/// Neutral background of icons without layers.
const List<Color> neutralLight = [Color(0xFFFFFFFF), Color(0xFFEDEDF0)];
const List<Color> neutralDark = [Color(0xFF3A3A3C), Color(0xFF161618)];

/// Blur of the backdrop behind the translucent body of the Clear styles, per side of the body.
const double clearBlurRatio = 0.08;

/// The background the shell generates for an app in Clear and Tinted (icon-format.md, "Themes"),
/// top to bottom: light glass white 50 % → 25 %, dark glass graphite 50 % → black 55 %; the tint
/// lightened towards white by 90 % → 76 %, or darkened by 62 % → 84 %. Default and Dark have
/// their own background layer; for them the neutral one is returned.
List<Color> themeBackground(IconAppearance look, Color tint) {
  Color mix(Color a, Color b, double t) => Color.lerp(a, b, t)!;
  Color darken(double by) => Color.from(
    alpha: 1,
    red: tint.r * (1 - by),
    green: tint.g * (1 - by),
    blue: tint.b * (1 - by),
  );
  const white = Color(0xFFFFFFFF);
  return switch (look) {
    IconAppearance.clear => const [Color(0x80FFFFFF), Color(0x40FFFFFF)],
    IconAppearance.clearDark => const [Color(0x803A3A3C), Color(0x8C000000)],
    IconAppearance.tinted => [mix(tint, white, 0.90), mix(tint, white, 0.76)],
    IconAppearance.tintedDark => [darken(0.62), darken(0.84)],
    IconAppearance.light => neutralLight,
    IconAppearance.dark => neutralDark,
  };
}

/// How the foreground (and the dynamic content) is recoloured in Clear and Tinted: the luminance
/// mapped to grey 105–255 (Clear Light) or 150–255 (Clear Dark), or from the dark tint to white
/// (Tinted Light) or to the light tint (Tinted Dark). Null for Default and Dark.
ColorFilter? foregroundFilter(IconAppearance look, Color tint) {
  const white = Color(0xFFFFFFFF);
  final deep = Color.from(
    alpha: 1,
    red: tint.r * 0.3,
    green: tint.g * 0.3,
    blue: tint.b * 0.3,
  );
  final (Color, Color)? ramp = switch (look) {
    IconAppearance.clear => (const Color(0xFF696969), white),
    IconAppearance.clearDark => (const Color(0xFF969696), white),
    IconAppearance.tinted => (deep, white),
    IconAppearance.tintedDark => (deep, Color.lerp(tint, white, 0.8)!),
    IconAppearance.light || IconAppearance.dark => null,
  };
  if (ramp == null) return null;
  final (from, to) = ramp;
  const lum = [0.2126, 0.7152, 0.0722];
  final rows = <double>[];
  for (final (lo, hi) in [(from.r, to.r), (from.g, to.g), (from.b, to.b)]) {
    final k = hi - lo;
    rows.addAll([k * lum[0], k * lum[1], k * lum[2], 0, lo * 255]);
  }
  return ColorFilter.matrix([...rows, 0, 0, 0, 1, 0]);
}

/// A `rendered` PNG of an app icon on the 1024 canvas drawn at [canvas] pt. It is decoded at
/// [decodeSide] pixels, not always at 1024, and drawn with mipmapped filtering.
class RenderedIconImage extends StatelessWidget {
  const RenderedIconImage({
    super.key,
    required this.path,
    required this.canvas,
    this.fallback,
  });

  final String path;
  final double canvas;

  /// Shown if the PNG cannot be decoded (the composed layers).
  final Widget? fallback;

  /// The decoded side for [pixels] device pixels: the smallest power of two from 64 that covers
  /// them, at most 1024 (the PNG). Dock magnification re-decodes only at these steps.
  static int decodeSide(double pixels) {
    var side = 64;
    while (side < pixels && side < 1024) {
      side *= 2;
    }
    return side;
  }

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    final decoded = decodeSide(canvas * ratio);
    final ImageProvider file = FileImage(File(path));
    return Image(
      image: decoded < 1024
          ? ResizeImage(file, width: decoded, height: decoded)
          : file,
      width: canvas,
      height: canvas,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      excludeFromSemantics: true,
      errorBuilder: (_, _, _) => fallback ?? SizedBox.square(dimension: canvas),
    );
  }
}

/// Months for the calendar icon, by language: English is the source, Italian the first
/// translation; other languages fall back to English.
const Map<String, List<String>> monthNamesByLanguage = {
  'en': [
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ],
  'it': [
    'gennaio',
    'febbraio',
    'marzo',
    'aprile',
    'maggio',
    'giugno',
    'luglio',
    'agosto',
    'settembre',
    'ottobre',
    'novembre',
    'dicembre',
  ],
};

/// The name of `month` (1–12) in `language` (`it`, `en`…), English if not translated.
String monthName(int month, String? language) {
  final names = monthNamesByLanguage[language] ?? monthNamesByLanguage['en']!;
  return names[(month - 1).clamp(0, 11)];
}

/// The outline of the body in the rectangle `r`.
Path iconBodyPath(Rect r) {
  final radius = math.min(r.width, r.height) * maskRadiusRatio;
  const steps = 16;
  final path = Path();
  // A corner: center (cx, cy), directions (sx, sy) outwards; from side to side.
  void corner(double cx, double cy, double sx, double sy, bool first) {
    for (var i = 0; i <= steps; i++) {
      final t = (sx * sy > 0 ? i : steps - i) / steps * math.pi / 2;
      final x = cx + sx * radius * math.pow(math.cos(t), 2 / maskExponent);
      final y = cy + sy * radius * math.pow(math.sin(t), 2 / maskExponent);
      if (first && i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
  }

  corner(r.right - radius, r.bottom - radius, 1, 1, true);
  corner(r.left + radius, r.bottom - radius, -1, 1, false);
  corner(r.left + radius, r.top + radius, -1, -1, false);
  corner(r.right - radius, r.top + radius, 1, -1, false);
  return path..close();
}

/// Where the icon comes from.
sealed class IconSource {
  const IconSource();
}

class LayeredSource extends IconSource {
  const LayeredSource(this.icon);
  final LayeredIcon icon;
}

/// A file or folder drawn by the system (`Thumbnails1.Icon`): the daemon composes kind, handling
/// app, folder colour and symbol at the exact pixel size; until it answers the plain generic
/// layers show. silica_ui composes nothing itself.
class ServiceSource extends IconSource {
  const ServiceSource(
    this.file, {
    this.isFolder = false,
    this.preview = false,
    this.revision,
  });

  /// The file or folder, as a `file://` URI.
  final Uri file;
  final bool isFolder;

  /// Allow the preview of the content (images, PDF) instead of the composed icon.
  final bool preview;

  /// Changes when the icon may have changed in place (see `SilicaFileIcon.revision`).
  final Object? revision;
}

/// An already composed SVG or PNG file (freedesktop theme).
class FlatSource extends IconSource {
  const FlatSource(this.path);
  final String path;
}

/// The icon of `side` × `side`. For an app `side` is the body and the canvas spills
/// `side × 100 / 824` per side, as in the drawing; for files, folders, volumes and Trash `side`
/// is the whole canvas (silica-icons 0.2: icon-format.md, "Principle"), unless [besideApps].
class SilicaIcon extends StatelessWidget {
  const SilicaIcon(
    this.source, {
    super.key,
    required this.side,
    this.dark,
    this.appearance,
    this.tint,
    this.badges = const {},
    this.env,
    this.besideApps = false,
  });

  /// A place (folder, Trash) next to the apps, as in the Dock: it too has `side` as its
  /// body and the app canvas around it.
  final bool besideApps;

  /// The icon canvas coincides with `side` (files, folders, volumes outside the Dock).
  bool get fullCanvas =>
      !besideApps &&
      switch (source) {
        LayeredSource(:final icon) => icon.kind != IconKind.app,
        ServiceSource() => true,
        FlatSource() => false,
      };

  /// The side of the 1024 canvas, in pt: the `min_size` bands are compared with it.
  double get canvasExtent => fullCanvas ? side : side * canvasSide / bodySide;

  /// The badges to overlay (alias, unreadable, locked, cloud): how many and where depends on the
  /// side (icon-format.md, "Badges").
  final Set<IconBadge> badges;

  /// The environment for finding the badges (tests).
  final Map<String, String>? env;

  final IconSource source;
  final double side;

  /// The dark variant. It is the icon style (icons.md IC-01: Settings › Appearance ›
  /// Icon style, "Dark"), not the system appearance: in dark appearance with the normal style
  /// the icons stay the same (appswitcher.md; silica-reference MU-20). Null: light.
  /// [appearance], when given, wins.
  final bool? dark;

  /// The icon style (icon-format.md, "Themes"): Default, Dark, Clear or Tinted, light or dark.
  /// Null: from [dark]. App icons with `rendered` PNGs draw them; the others compose the layers.
  final IconAppearance? appearance;

  /// The tint of the Tinted styles; null is [defaultIconTint]. With another tint the app icon is
  /// composed from its layers (the Tinted PNGs carry the default tint).
  final Color? tint;

  /// The style actually drawn.
  IconAppearance get resolvedAppearance =>
      appearance ?? (dark == true ? IconAppearance.dark : IconAppearance.light);

  @override
  Widget build(BuildContext context) {
    final look = resolvedAppearance;
    final isDark = look.isDark;
    final canvas = canvasExtent;
    final inset = (canvas - side) / 2;
    final body = Rect.fromLTWH(inset, inset, side, side);
    final Widget content = switch (source) {
      LayeredSource(:final icon) when icon.kind == IconKind.app => _layeredApp(
        context,
        icon,
        canvas,
        body,
        look,
      ),
      LayeredSource(:final icon) => Stack(
        children: [
          // The conditional layers (the sheet of a folder with items) belong to the composed
          // icon of the daemon, not to this plain one.
          for (final layer in icon.layers)
            if (layer.when == null) _svg(layer.pathFor(dark: isDark), canvas),
        ],
      ),
      ServiceSource(
        :final file,
        :final isFolder,
        :final preview,
        :final revision,
      ) =>
        SilicaFileIcon(
          file: file,
          size: canvas,
          isFolder: isFolder,
          preview: preview,
          revision: revision,
          env: env,
        ),
      FlatSource(:final path) => _flat(path, canvas, body, isDark),
    };
    // Files, folders, volumes and Trash are flat: the context shadow is added by whoever
    // draws them (icon-format.md › "What does NOT go in the layers"), under the shape of the drawing.
    final grounded = switch (source) {
      LayeredSource(:final icon) => icon.kind != IconKind.app,
      ServiceSource() => true,
      FlatSource() => false,
    };
    final shown = badges.isEmpty
        ? const <IconBadge>[]
        : visibleBadges(
            badges,
            canvas,
            order: findBadgeRules(env: env)?.order ?? IconBadge.values,
          );
    return SizedBox(
      width: side,
      height: side,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: -inset,
            top: -inset,
            width: canvas,
            height: canvas,
            child: IgnorePointer(
              child: grounded ? _grounded(content, canvas) : content,
            ),
          ),
          for (final badge in shown) _badge(badge, canvas, inset, isDark),
        ],
      ),
    );
  }

  /// The icon with its ground shadow: the same shape, black, blurred and shifted down.
  Widget _grounded(Widget content, double canvas) =>
      _GroundShadow(shadow: IconShadow.forSide(canvas), child: content);

  /// A badge over the composed icon, without shadow: side 315/1024 of the canvas from 32 pt, 509 if it is
  /// the only one (16–31 pt); resting on the bottom corner of the app body (100…924 on the
  /// canvas), not on the drawing.
  Widget _badge(IconBadge badge, double canvas, double inset, bool isDark) {
    final path = findBadgeRules(env: env)?.pathFor(badge, dark: isDark);
    if (path == null) return const SizedBox.shrink();
    final scale = canvas / canvasSide;
    final edge = (canvas >= 32 ? 315.0 : 509.0) * scale;
    final near = bodyInset * scale - inset;
    final far = (bodyInset + bodySide) * scale - inset;
    // alias at the bottom left, the others at the bottom right.
    final left = badge == IconBadge.alias ? near : far - edge;
    // The 1024 canvas of the badge, scaled by edge/824, with its body on the box.
    final k = edge / bodySide;
    return Positioned(
      left: left - bodyInset * k,
      top: far - edge - bodyInset * k,
      width: canvasSide * k,
      height: canvasSide * k,
      child: IgnorePointer(child: _svg(path, canvasSide * k)),
    );
  }

  /// An app icon. Default and Dark (and Clear and Tinted with the default tint) draw the
  /// `rendered` PNG of the style when the pack has one; otherwise the SVG layers are composed,
  /// with the glass background or the tint of the style. The body mask, the rim and the drop
  /// shadow are the shell's in both cases; dynamic content (clock hands, calendar text) goes on
  /// top, recoloured like the foreground in Clear and Tinted.
  Widget _layeredApp(
    BuildContext context,
    LayeredIcon icon,
    double canvas,
    Rect body,
    IconAppearance look,
  ) {
    final isDark = look.isDark;
    if (icon.format == 2 && icon.dir != null) {
      return _ServiceApp(
        icon: icon,
        canvas: canvas,
        body: body,
        side: side,
        look: look,
        tint: tint,
      );
    }
    final tintColor = tint ?? defaultIconTint;
    final customTint =
        look.isTinted && tintColor.toARGB32() != defaultIconTint.toARGB32();
    final rendered = customTint ? null : icon.renderedFor(look);
    final filter = foregroundFilter(look, tintColor);

    Widget recolored(Widget child) => filter == null
        ? child
        : ColorFiltered(colorFilter: filter, child: child);

    final layers = _appLayers(icon, canvas, look, tintColor, filter);
    final Widget dynamicContent = switch (icon.dynamic) {
      ClockHands hands => recolored(
        _Clock(hands: hands, canvas: canvas, dark: isDark, seconds: side >= 64),
      ),
      CalendarText text => recolored(
        _Calendar(text: text, canvas: canvas, dark: isDark),
      ),
      null => const SizedBox.shrink(),
    };
    return Stack(
      children: [
        CustomPaint(
          size: Size.square(canvas),
          painter: _DropPainter(body, side),
        ),
        ClipPath(
          clipper: _BodyClipper(body),
          child: Stack(
            children: [
              // Clear: the glass blurs what is behind the translucent body.
              if (look.isClear)
                BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: side * clearBlurRatio,
                    sigmaY: side * clearBlurRatio,
                  ),
                  child: SizedBox.square(dimension: canvas),
                ),
              if (rendered != null)
                RenderedIconImage(
                  path: rendered,
                  canvas: canvas,
                  // An unreadable PNG falls back to the layers.
                  fallback: layers,
                )
              else
                layers,
              dynamicContent,
            ],
          ),
        ),
        CustomPaint(
          size: Size.square(canvas),
          painter: _RimPainter(body, side, isDark),
        ),
      ],
    );
  }

  /// The SVG layers of an app in the style [look]: Default and Dark as drawn (the `-dark`
  /// layers for Dark), Clear and Tinted with the generated background (icon-format.md, "Themes")
  /// and the foregrounds through [filter].
  Widget _appLayers(
    LayeredIcon icon,
    double canvas,
    IconAppearance look,
    Color tintColor,
    ColorFilter? filter,
  ) {
    final isDark = look.isDark;
    final shadow = side * layerShadowRatio;
    final generated = look.isClear || look.isTinted;
    final children = <Widget>[];
    for (final (index, layer) in icon.layers.indexed) {
      final path = layer.pathFor(dark: isDark);
      if (index == 0 && generated) {
        // The background is the style's: glass or tint, top to bottom.
        children.add(
          SizedBox.square(
            dimension: canvas,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: themeBackground(look, tintColor),
                ),
              ),
            ),
          ),
        );
        continue;
      }
      if (layer.shadow) {
        children.add(
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: shadow, sigmaY: shadow),
            child: Transform.translate(
              offset: Offset(0, shadow),
              child: ColorFiltered(
                colorFilter: const ColorFilter.mode(
                  layerShadowColor,
                  BlendMode.srcIn,
                ),
                child: _svg(path, canvas),
              ),
            ),
          ),
        );
      }
      final art = _svg(path, canvas);
      children.add(
        index > 0 && filter != null
            ? ColorFiltered(colorFilter: filter, child: art)
            : art,
      );
    }
    return SizedBox.square(
      dimension: canvas,
      child: Stack(children: children),
    );
  }

  Widget _flat(String path, double canvas, Rect body, bool isDark) {
    final glyph = side * keylineSide / bodySide;
    final file = File(path);
    return Stack(
      children: [
        CustomPaint(
          size: Size.square(canvas),
          painter: _DropPainter(body, side),
        ),
        ClipPath(
          clipper: _BodyClipper(body),
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: isDark ? neutralDark : neutralLight,
              ),
            ),
            child: Center(
              child: path.endsWith('.svg')
                  ? SvgPicture.string(
                      svgText(path),
                      width: glyph,
                      height: glyph,
                    )
                  : Image.file(
                      file,
                      width: glyph,
                      height: glyph,
                      filterQuality: FilterQuality.medium,
                    ),
            ),
          ),
        ),
        CustomPaint(
          size: Size.square(canvas),
          painter: _RimPainter(body, side, isDark),
        ),
      ],
    );
  }
}

Widget _svg(String path, double canvas) =>
    SvgPicture.string(svgText(path), width: canvas, height: canvas);

/// SVGs exported from Sketch use filters, which flutter_svg does not apply:
/// - the shadow passes (a copy of the path with a `filter`, black by default) are
///   removed, otherwise they would be drawn solid black;
/// - blurred ellipses and circles (ground shadows, glows) become a radial gradient
///   fading over ~2σ beyond the edge (their `mask`, `clip-path` and `transform`
///   are kept on a wrapping group; the referenced defs are left untouched);
/// - any other `filter` attribute is ignored;
/// - text in Inter uses the Inter of the silica_ui package (Sketch writes
///   `font-family="Inter-Regular_Medium, Inter"`).
final RegExp _filteredUse = RegExp(
  r'<use\b[^>]*\bfilter="[^"]*"[^>]*?(/>|>\s*</use>)',
);
final RegExp _blurredShape = RegExp(
  r'<(ellipse|circle)\b([^>]*?)\sfilter="url\(#([^)"]+)\)"([^>]*?)(/>|>\s*</\1>)',
);
final RegExp _filterAttribute = RegExp(r'\sfilter="[^"]*"');
final RegExp _interFamily = RegExp(r'font-family="[^"]*\bInter\b[^"]*"');

String withoutFilters(String svg) {
  var soft = 0;
  final shapes = svg.replaceAllMapped(_blurredShape, (m) {
    final attributes = '${m[2]}${m[4]}';
    String? attr(String name) =>
        RegExp('\\s$name="([^"]*)"').firstMatch(attributes)?.group(1);
    double number(String name, double fallback) =>
        double.tryParse(attr(name) ?? '') ?? fallback;
    final sigma =
        double.tryParse(
          RegExp(
                '<filter[^>]*id="${RegExp.escape(m[3]!)}"[^>]*>\\s*'
                '<feGaussianBlur[^>]*stdDeviation="([0-9.]+)"',
              ).firstMatch(svg)?.group(1) ??
              '',
        ) ??
        0;
    final cx = number('cx', 0);
    final cy = number('cy', 0);
    final rx = m[1] == 'circle' ? number('r', 0) : number('rx', 0);
    final ry = m[1] == 'circle' ? number('r', 0) : number('ry', 0);
    final fill = attr('fill') ?? '#000000';
    final alpha = number('fill-opacity', 1) * number('opacity', 1);
    if (rx <= 0 || ry <= 0 || !fill.startsWith('#')) return '';
    final grow = 2 * sigma;
    final inner =
        (math.min(rx, ry) - sigma).clamp(0, double.infinity) /
        (math.min(rx, ry) + grow);
    final id = 'silica-soft-${soft++}';
    // Keep the element's mask, clip-path and transform by wrapping the
    // rewritten ellipse in a group (opacity is already baked into the stops).
    final wrap = [
      for (final name in const ['mask', 'clip-path', 'transform'])
        if (attr(name) != null) '$name="${attr(name)}"',
    ].join(' ');
    final open = wrap.isEmpty ? '' : '<g $wrap>';
    final close = wrap.isEmpty ? '' : '</g>';
    return '$open<defs><radialGradient id="$id">'
        '<stop offset="0" stop-color="$fill" stop-opacity="$alpha"/>'
        '<stop offset="$inner" stop-color="$fill" stop-opacity="$alpha"/>'
        '<stop offset="1" stop-color="$fill" stop-opacity="0"/>'
        '</radialGradient></defs>'
        '<ellipse cx="$cx" cy="$cy" rx="${rx + grow}" ry="${ry + grow}" '
        'fill="url(#$id)"/>$close';
  });
  return shapes
      .replaceAll(_filteredUse, '')
      .replaceAll(_filterAttribute, '')
      .replaceAll(
        _interFamily,
        'font-family="packages/silica_ui/$uiFontFamily"',
      );
}

const String _emptySvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024"/>';
final Map<String, String> _svgCache = {};

/// The SVG text ready for flutter_svg; empty if the file cannot be read.
String svgText(String path) => _svgCache.putIfAbsent(path, () {
  try {
    return withoutFilters(File(path).readAsStringSync());
  } on FileSystemException {
    return _emptySvg;
  }
});

class _BodyClipper extends CustomClipper<Path> {
  const _BodyClipper(this.body);
  final Rect body;

  @override
  Path getClip(Size size) => iconBodyPath(body);

  @override
  bool shouldReclip(_BodyClipper old) => old.body != body;
}

class _DropPainter extends CustomPainter {
  const _DropPainter(this.body, this.side);
  final Rect body;
  final double side;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      iconBodyPath(body.shift(Offset(0, side * dropOffsetRatio))),
      Paint()
        ..color = dropColor
        ..maskFilter = MaskFilter.blur(
          BlurStyle.normal,
          side * dropOffsetRatio,
        ),
    );
  }

  @override
  bool shouldRepaint(_DropPainter old) => old.body != body;
}

/// The bright edge of the body: lighter at the top, fading at the bottom. Its alpha is half of
/// the first version's (light 0x80 -> 0x1A became 0x40 -> 0x0D, dark 0x40 -> 0x0F became
/// 0x20 -> 0x08), the width unchanged (silica-desktop#213).
class _RimPainter extends CustomPainter {
  const _RimPainter(this.body, this.side, this.dark);
  final Rect body;
  final double side;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final width = math.max(1.0, side / 64);
    canvas.drawPath(
      iconBodyPath(body.deflate(width / 2)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = width
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? const [Color(0x20FFFFFF), Color(0x08FFFFFF)]
              : const [Color(0x40FFFFFF), Color(0x0DFFFFFF)],
        ).createShader(body),
    );
  }

  @override
  bool shouldRepaint(_RimPainter old) => old.body != body || old.dark != dark;
}

/// A format 2 app icon: the PNG the thumbnail service composes for the look, the tint and the
/// exact pixel size (`Thumbnails1.AppIcon`), with the body mask, rim and drop shadow of the
/// host and the dynamic layers (Clock hands) drawn live on top. Until the service answers, and
/// for good without it (or without a compiled `icon.assets`), the bundled flat `icon.png` /
/// `icon-dark.png` shows alone: it already has the hands baked in, so none are drawn over it.
class _ServiceApp extends StatefulWidget {
  const _ServiceApp({
    required this.icon,
    required this.canvas,
    required this.body,
    required this.side,
    required this.look,
    required this.tint,
  });

  final LayeredIcon icon;
  final double canvas;
  final Rect body;
  final double side;
  final IconAppearance look;
  final Color? tint;

  @override
  State<_ServiceApp> createState() => _ServiceAppState();
}

class _ServiceAppState extends State<_ServiceApp> {
  String? _path;
  Object? _key;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(_ServiceApp old) {
    super.didUpdateWidget(old);
    _load();
  }

  void _load() {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final px = (widget.canvas * dpr).round();
    final dir = widget.icon.dir;
    if (dir == null || px <= 0 || !widget.canvas.isFinite) return;
    final tint = widget.look.isTinted ? widget.tint : null;
    final key = (dir, px, dpr, widget.look, tint?.toARGB32());
    if (key == _key) return;
    _key = key;
    final generation = ++_generation;
    SilicaThumbnails.appIcon(
      dir,
      px,
      scale: dpr,
      look: widget.look,
      accent: tint,
    ).then((path) {
      if (!mounted || generation != _generation) return;
      // A look that changed keeps the last image until the new one is there.
      if (path != null) setState(() => _path = path);
    });
  }

  @override
  Widget build(BuildContext context) {
    final look = widget.look;
    final canvas = widget.canvas;
    final path = _path;
    final flat = widget.icon.renderedFor(
      look.isDark ? IconAppearance.dark : IconAppearance.light,
    );
    return Stack(
      children: [
        CustomPaint(
          size: Size.square(canvas),
          painter: _DropPainter(widget.body, widget.side),
        ),
        ClipPath(
          clipper: _BodyClipper(widget.body),
          child: Stack(
            children: [
              if (path == null)
                if (flat != null)
                  RenderedIconImage(
                    path: flat,
                    canvas: canvas,
                    fallback: SizedBox.square(dimension: canvas),
                  )
                else
                  SizedBox.square(dimension: canvas)
              else ...[
                // Clear: the glass blurs what is behind the translucent body.
                if (look.isClear)
                  BackdropFilter(
                    filter: ImageFilter.blur(
                      sigmaX: widget.side * clearBlurRatio,
                      sigmaY: widget.side * clearBlurRatio,
                    ),
                    child: SizedBox.square(dimension: canvas),
                  ),
                RenderedIconImage(
                  path: path,
                  canvas: canvas,
                  fallback: SizedBox.square(dimension: canvas),
                ),
                if (widget.icon.dynamicLayers.isNotEmpty)
                  _LiveLayers(
                    layers: widget.icon.dynamicLayers,
                    canvas: canvas,
                    look: look,
                    tint: widget.tint ?? defaultIconTint,
                  ),
              ],
            ],
          ),
        ),
        CustomPaint(
          size: Size.square(canvas),
          painter: _RimPainter(widget.body, widget.side, look.isDark),
        ),
      ],
    );
  }
}

/// The dynamic layers of a format 2 icon at the current time, bottom to top as listed: a clock
/// hand turns around its pivot (hours (h mod 12 + m/60 + s/3600) × 30°, minutes (m + s/60) × 6°,
/// seconds s × 6°), the cap stays. Layers whose `min_size` is above [canvas], or whose mode is
/// `hide` in the look, are left out; the others are recoloured like the foreground (Clear and
/// Tinted). Calendar text layers are not drawn yet.
class _LiveLayers extends StatefulWidget {
  const _LiveLayers({
    required this.layers,
    required this.canvas,
    required this.look,
    required this.tint,
  });

  final List<DynamicLayer> layers;
  final double canvas;
  final IconAppearance look;
  final Color tint;

  @override
  State<_LiveLayers> createState() => _LiveLayersState();
}

class _LiveLayersState extends State<_LiveLayers> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  bool _drawn(DynamicLayer l) {
    if (l.minSize > widget.canvas) return false;
    final mode = widget.look.isClear
        ? l.clearMode
        : widget.look.isTinted
        ? l.tintedMode
        : 'keep';
    return mode != 'hide';
  }

  bool get _seconds =>
      widget.layers.any((l) => l.unit == ClockUnit.second && _drawn(l));

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(_LiveLayers old) {
    super.didUpdateWidget(old);
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer.periodic(
      _seconds ? const Duration(seconds: 1) : const Duration(seconds: 20),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  double _degrees(ClockUnit unit) {
    final s = _now.second.toDouble();
    final m = _now.minute + s / 60;
    return switch (unit) {
      ClockUnit.hour => (_now.hour % 12 + m / 60) * 30,
      ClockUnit.minute => m * 6,
      ClockUnit.second => s * 6,
    };
  }

  @override
  Widget build(BuildContext context) {
    final look = widget.look;
    final k = widget.canvas / canvasSide;
    final filter = foregroundFilter(look, widget.tint);
    final children = <Widget>[];
    for (final l in widget.layers) {
      if (!_drawn(l)) continue;
      Widget art = _svg(l.layer.pathFor(dark: look.isDark), widget.canvas);
      switch (l.kind) {
        case DynamicKind.clockHand:
          final unit = l.unit;
          if (unit == null) continue;
          art = Transform.rotate(
            angle: _degrees(unit) * math.pi / 180,
            origin: Offset(l.pivot.dx * k, l.pivot.dy * k),
            alignment: Alignment.topLeft,
            child: art,
          );
        case DynamicKind.clockCap:
          break;
        case DynamicKind.calendarMonth || DynamicKind.calendarDay:
          continue;
      }
      final keep = look.isClear
          ? l.clearMode == 'keep'
          : look.isTinted && l.tintedMode == 'keep';
      children.add(
        filter == null || keep
            ? art
            : ColorFiltered(colorFilter: filter, child: art),
      );
    }
    return SizedBox.square(
      dimension: widget.canvas,
      child: Stack(children: children),
    );
  }
}

/// The hands at the current time: hours (h mod 12 + m/60 + s/3600) × 30°, minutes
/// (m + s/60) × 6°, seconds s × 6°; the cap on top. Seconds only from 64 pt.
class _Clock extends StatefulWidget {
  const _Clock({
    required this.hands,
    required this.canvas,
    required this.dark,
    required this.seconds,
  });

  final ClockHands hands;
  final double canvas;
  final bool dark;
  final bool seconds;

  @override
  State<_Clock> createState() => _ClockState();
}

class _ClockState extends State<_Clock> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(_Clock old) {
    super.didUpdateWidget(old);
    if (old.seconds != widget.seconds) _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    _timer = Timer.periodic(
      widget.seconds ? const Duration(seconds: 1) : const Duration(seconds: 20),
      (_) => setState(() => _now = DateTime.now()),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = _now.second.toDouble();
    final m = _now.minute + s / 60;
    final h = _now.hour % 12 + m / 60;
    Widget hand(IconLayer layer, double degrees) => Transform.rotate(
      angle: degrees * math.pi / 180,
      child: _svg(layer.pathFor(dark: widget.dark), widget.canvas),
    );
    return Stack(
      children: [
        hand(widget.hands.hour, h * 30),
        hand(widget.hands.minute, m * 6),
        if (widget.seconds)
          if (widget.hands.second case final second?) hand(second, s * 6),
        _svg(widget.hands.cap.pathFor(dark: widget.dark), widget.canvas),
      ],
    );
  }
}

/// Today's month and day, updated at midnight.
class _Calendar extends StatefulWidget {
  const _Calendar({
    required this.text,
    required this.canvas,
    required this.dark,
  });

  final CalendarText text;
  final double canvas;
  final bool dark;

  @override
  State<_Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<_Calendar> {
  Timer? _timer;
  DateTime _today = DateTime.now();

  @override
  void initState() {
    super.initState();
    _schedule();
  }

  void _schedule() {
    final now = DateTime.now();
    final midnight = DateTime(now.year, now.month, now.day + 1);
    _timer = Timer(midnight.difference(now) + const Duration(seconds: 1), () {
      setState(() => _today = DateTime.now());
      _schedule();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = widget.canvas / canvasSide;
    Widget line(IconText t, String value) {
      final style =
          uiText(
            size: t.size * k,
            color: widget.dark ? t.darkColor : t.color,
          ).copyWith(
            fontWeight: FontWeight.values[(t.weight ~/ 100 - 1).clamp(0, 8)],
            letterSpacing: t.tracking * k,
            height: 1,
          );
      final width = (t.maxWidth ?? t.box.width) * k;
      return Positioned(
        left: t.box.left * k,
        top: t.box.top * k,
        width: t.box.width * k,
        height: t.box.height * k,
        child: Center(
          child: SizedBox(
            width: width,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                t.upper ? value.toUpperCase() : value,
                style: style,
                maxLines: 1,
              ),
            ),
          ),
        ),
      );
    }

    return Stack(
      children: [
        line(
          widget.text.month,
          monthName(
            _today.month,
            (Localizations.maybeLocaleOf(context) ??
                    WidgetsBinding.instance.platformDispatcher.locale)
                .languageCode,
          ),
        ),
        line(widget.text.day, '${_today.day}'),
      ],
    );
  }
}

/// Paints the child twice: first black, blurred and shifted (the shadow), then as it is. A single
/// child in the tree (no duplicate texts for whoever searches the widgets).
class _GroundShadow extends SingleChildRenderObjectWidget {
  const _GroundShadow({required this.shadow, super.child});
  final IconShadow shadow;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderGroundShadow(shadow);

  @override
  void updateRenderObject(BuildContext context, _RenderGroundShadow render) =>
      render.shadow = shadow;
}

class _RenderGroundShadow extends RenderProxyBox {
  _RenderGroundShadow(this._shadow);

  IconShadow _shadow;
  set shadow(IconShadow value) {
    if (value.opacity == _shadow.opacity &&
        value.sigma == _shadow.sigma &&
        value.offset == _shadow.offset) {
      return;
    }
    _shadow = value;
    markNeedsPaint();
  }

  final LayerHandle<ImageFilterLayer> _layer = LayerHandle<ImageFilterLayer>();

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final filter = ImageFilter.compose(
      outer: ImageFilter.blur(
        sigmaX: _shadow.sigma,
        sigmaY: _shadow.sigma,
        tileMode: TileMode.decal,
      ),
      inner: ColorFilter.mode(
        Color.fromRGBO(0, 0, 0, _shadow.opacity),
        BlendMode.srcIn,
      ),
    );
    final layer = (_layer.layer ??= ImageFilterLayer())..imageFilter = filter;
    context.pushLayer(
      layer,
      (context, offset) => context.paintChild(child, offset),
      offset + Offset(0, _shadow.offset),
    );
    context.paintChild(child, offset);
  }

  @override
  void dispose() {
    _layer.layer = null;
    super.dispose();
  }
}
