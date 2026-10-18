// The small glyphs the Amalfi controls draw themselves (checkmarks, chevrons, plus, minus,
// xmark, the field and chrome symbols), painted synchronously from their path data.
//
// The glyphs are Icon Kit symbols: the Regular 24 pt `symbols/regular/<name>.svg` of
// silica-icons (CC BY-SA 4.0, the Silica project), transcribed into [AmalfiGlyphs] at
// silica-icons 402191a. A glyph drawn at another size is the plain vector scaling of the
// 24 pt drawing, stroke included (`docs/design/amalfi/README.md`: Regular 24 → 1.5,
// 16 → 1.0, 12 → 0.75, 8 → 0.5). Symbols an app chooses at runtime come from the installed
// silica-icons instead: see `AmalfiSymbol` (symbol.dart).

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme.dart';
import 'symbol.dart';

/// One path of a glyph: SVG path data on the 24 × 24 canvas, stroked with the glyph's stroke
/// and, with [fill], filled too (as an SVG `<path fill="currentColor">` in a stroked group).
@immutable
class AmalfiGlyphPath {
  const AmalfiGlyphPath(
    this.data, {
    this.fill = false,
    this.stroke = true,
    this.opacity = 1,
  });

  /// SVG path data (`M L H V C Q A Z`, absolute or relative).
  final String data;

  /// Whether the path is filled.
  final bool fill;

  /// Whether the path is stroked (`stroke="none"` turns it off).
  final bool stroke;

  /// The path's opacity (0–1).
  final double opacity;

  @override
  bool operator ==(Object other) =>
      other is AmalfiGlyphPath &&
      other.data == data &&
      other.fill == fill &&
      other.stroke == stroke &&
      other.opacity == opacity;

  @override
  int get hashCode => Object.hash(data, fill, stroke, opacity);
}

/// An Icon Kit glyph: its [name] in silica-icons, its [paths] on the 24 pt canvas and the
/// [strokeWidth] of its weight on that canvas (Regular 1.5).
@immutable
class AmalfiGlyphData {
  const AmalfiGlyphData(this.name, this.paths, {this.strokeWidth = 1.5});

  /// The Icon Kit canvas side, in points.
  static const double canvas = 24;

  /// The Regular stroke on the 24 pt canvas.
  static const double regularStroke = 1.5;

  /// The glyph name (`xmark`, `chevron-down`).
  final String name;

  /// The paths, on the 24 × 24 canvas.
  final List<AmalfiGlyphPath> paths;

  /// The stroke width on the 24 pt canvas.
  final double strokeWidth;

  /// The Regular stroke width of a glyph [size] points square: 1.5 at 24, scaled linearly
  /// (12 → 0.75).
  static double regularStrokeAt(double size) => regularStroke * size / canvas;

  /// Reads an Icon Kit SVG (`symbols/<weight>/<name>.svg`): its `<path>` elements with their
  /// `fill`, `stroke` and `opacity`, and the group's `stroke-width`. Null when [svg] has no
  /// path (never throws).
  static AmalfiGlyphData? fromSvg(String name, String svg) {
    final attribute = RegExp(r'([a-zA-Z-]+)\s*=\s*"([^"]*)"');
    Map<String, String> attributes(String tag) => {
      for (final m in attribute.allMatches(tag)) m.group(1)!: m.group(2)!,
    };
    var stroke = regularStroke;
    final group = RegExp(r'<g\b([^>]*)>').firstMatch(svg);
    if (group != null) {
      final width = double.tryParse(
        attributes(group.group(1)!)['stroke-width'] ?? '',
      );
      if (width != null && width.isFinite && width >= 0) stroke = width;
    }
    final paths = <AmalfiGlyphPath>[];
    for (final m in RegExp(r'<path\b([^>]*?)/?>').allMatches(svg)) {
      final a = attributes(m.group(1)!);
      final data = a['d'];
      if (data == null || data.isEmpty) continue;
      final fill = a['fill'];
      final opacity = double.tryParse(a['opacity'] ?? '') ?? 1;
      paths.add(
        AmalfiGlyphPath(
          data,
          fill: fill != null && fill != 'none',
          stroke: a['stroke'] != 'none',
          opacity: opacity.isFinite ? opacity.clamp(0.0, 1.0) : 1,
        ),
      );
    }
    if (paths.isEmpty) return null;
    return AmalfiGlyphData(name, paths, strokeWidth: stroke);
  }

  @override
  bool operator ==(Object other) =>
      other is AmalfiGlyphData &&
      other.name == name &&
      other.strokeWidth == strokeWidth &&
      _listEquals(other.paths, paths);

  @override
  int get hashCode => Object.hash(name, strokeWidth, Object.hashAll(paths));

  @override
  String toString() => 'AmalfiGlyphData($name)';
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Draws [glyph] in a [size] × [size] box in [color], optionally turned by [turns] around
/// its centre.
///
/// [size] and [color] default to the ambient [IconTheme] (buttons and segments set it for
/// their glyphs), else 16 and `Text/Primary`. The stroke is the glyph's weight scaled to the
/// size; [strokeWidth] overrides it, in points at [size].
class AmalfiGlyph extends StatelessWidget {
  const AmalfiGlyph(
    this.glyph, {
    super.key,
    this.size,
    this.color,
    this.strokeWidth,
    this.turns = 0,
  });

  final AmalfiGlyphData glyph;

  /// The side of the box, in points.
  final double? size;

  /// The colour of the strokes and fills.
  final Color? color;

  /// The stroke width in points at [size]; null: the glyph's own, scaled.
  final double? strokeWidth;

  /// Clockwise turns around the centre (0.25 = 90°).
  final double turns;

  @override
  Widget build(BuildContext context) {
    final icons = IconTheme.of(context);
    final side = size ?? icons.size ?? 16;
    final paint =
        color ?? icons.color ?? AmalfiTheme.of(context).colors.textPrimary;
    final symbol = strokeWidth == null ? _font(glyph) : null;
    if (symbol != null) {
      // The Silica Symbols font: font size = icon box (`tokens.json` iconFont).
      Widget icon = Icon(symbol, size: side, color: paint);
      if (turns != 0)
        icon = Transform.rotate(angle: turns * 2 * math.pi, child: icon);
      return ExcludeSemantics(child: icon);
    }
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: side,
        child: CustomPaint(
          painter: AmalfiGlyphPainter(
            glyph: glyph,
            color: paint,
            strokeWidth: strokeWidth,
            turns: turns,
          ),
        ),
      ),
    );
  }
}

/// The bundled Silica Symbols glyph of [glyph] in the weight of its stroke, or null when the
/// font has none (an app's own glyph).
IconData? _font(AmalfiGlyphData glyph) => silicaSymbolData(
  glyph.name,
  weight: switch (glyph.strokeWidth) {
    < AmalfiGlyphData.regularStroke => AmalfiSymbolWeight.light,
    > AmalfiGlyphData.regularStroke => AmalfiSymbolWeight.semibold,
    _ => AmalfiSymbolWeight.regular,
  },
);

/// Paints [glyph] in [color] in the largest square centred in its size, optionally turned by
/// [turns]. [strokeWidth] (in points at the painted size) overrides the glyph's stroke.
class AmalfiGlyphPainter extends CustomPainter {
  const AmalfiGlyphPainter({
    required this.glyph,
    required this.color,
    this.strokeWidth,
    this.turns = 0,
  });

  final AmalfiGlyphData glyph;
  final Color color;
  final double? strokeWidth;
  final double turns;

  static final Map<String, Path> _cache = {};

  /// The parsed path of [data] (cached).
  static Path pathOf(String data) =>
      _cache.putIfAbsent(data, () => parseAmalfiGlyphPath(data));

  @override
  void paint(Canvas canvas, Size size) {
    final side = math.min(size.width, size.height);
    if (!side.isFinite || side <= 0) return;
    final scale = side / AmalfiGlyphData.canvas;
    canvas
      ..save()
      ..translate((size.width - side) / 2, (size.height - side) / 2);
    if (turns != 0) {
      canvas
        ..translate(side / 2, side / 2)
        ..rotate(turns * 2 * math.pi)
        ..translate(-side / 2, -side / 2);
    }
    canvas.scale(scale);
    final width = strokeWidth == null
        ? glyph.strokeWidth
        : strokeWidth! / scale;
    for (final p in glyph.paths) {
      final path = pathOf(p.data);
      final c = p.opacity >= 1
          ? color
          : color.withValues(alpha: color.a * p.opacity);
      if (p.fill) canvas.drawPath(path, Paint()..color = c);
      if (p.stroke && width > 0) {
        canvas.drawPath(
          path,
          Paint()
            ..color = c
            ..style = PaintingStyle.stroke
            ..strokeWidth = width
            ..strokeCap = StrokeCap.round
            ..strokeJoin = StrokeJoin.round,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(AmalfiGlyphPainter old) =>
      old.glyph != glyph ||
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.turns != turns;
}

final RegExp _token = RegExp(
  r'[MmLlHhVvCcQqAaZz]|[-+]?(?:\d+\.?\d*|\.\d+)(?:[eE][-+]?\d+)?',
);

final RegExp _command = RegExp(r'^[A-Za-z]$');

/// Parses SVG path [data] (absolute and relative `M L H V C Q A Z`) into a [Path]. Unknown or
/// truncated commands end the path where they start (never throws).
Path parseAmalfiGlyphPath(String data) {
  final path = Path();
  final tokens = [for (final m in _token.allMatches(data)) m.group(0)!];
  var i = 0;
  var command = '';
  var current = Offset.zero;
  var start = Offset.zero;

  double? number() {
    if (i >= tokens.length || _command.hasMatch(tokens[i])) return null;
    return double.tryParse(tokens[i++]);
  }

  while (i < tokens.length) {
    if (_command.hasMatch(tokens[i])) command = tokens[i++];
    if (command.isEmpty) break;
    final relative = command.toLowerCase() == command;
    Offset at(double x, double y) =>
        relative ? current + Offset(x, y) : Offset(x, y);
    switch (command.toUpperCase()) {
      case 'Z':
        path.close();
        current = start;
        command = '';
        continue;
      case 'M':
        final x = number(), y = number();
        if (x == null || y == null) return path;
        current = start = at(x, y);
        path.moveTo(current.dx, current.dy);
        // Further pairs are implicit line-tos.
        command = relative ? 'l' : 'L';
      case 'L':
        final x = number(), y = number();
        if (x == null || y == null) return path;
        current = at(x, y);
        path.lineTo(current.dx, current.dy);
      case 'H':
        final x = number();
        if (x == null) return path;
        current = Offset(relative ? current.dx + x : x, current.dy);
        path.lineTo(current.dx, current.dy);
      case 'V':
        final y = number();
        if (y == null) return path;
        current = Offset(current.dx, relative ? current.dy + y : y);
        path.lineTo(current.dx, current.dy);
      case 'C':
        final v = [for (var k = 0; k < 6; k++) number()];
        if (v.contains(null)) return path;
        final a = at(v[0]!, v[1]!), b = at(v[2]!, v[3]!), c = at(v[4]!, v[5]!);
        path.cubicTo(a.dx, a.dy, b.dx, b.dy, c.dx, c.dy);
        current = c;
      case 'Q':
        final v = [for (var k = 0; k < 4; k++) number()];
        if (v.contains(null)) return path;
        final a = at(v[0]!, v[1]!), b = at(v[2]!, v[3]!);
        path.quadraticBezierTo(a.dx, a.dy, b.dx, b.dy);
        current = b;
      case 'A':
        final v = [for (var k = 0; k < 7; k++) number()];
        if (v.contains(null)) return path;
        final end = at(v[5]!, v[6]!);
        path.arcToPoint(
          end,
          radius: Radius.elliptical(v[0]!.abs(), v[1]!.abs()),
          rotation: v[2]!,
          largeArc: v[3]! != 0,
          clockwise: v[4]! != 0,
        );
        current = end;
      default:
        return path;
    }
  }
  return path;
}

/// The Icon Kit glyphs the Amalfi controls draw (Regular, 24 pt), named as in silica-icons.
abstract final class AmalfiGlyphs {
  /// `checkmark`.
  static const AmalfiGlyphData checkmark = AmalfiGlyphData('checkmark', [
    AmalfiGlyphPath('M4.6 12.6 L9.4 17.6 L19.4 6.4'),
  ]);

  /// `minus`.
  static const AmalfiGlyphData minus = AmalfiGlyphData('minus', [
    AmalfiGlyphPath('M4 12 L20 12'),
  ]);

  /// `plus`.
  static const AmalfiGlyphData plus = AmalfiGlyphData('plus', [
    AmalfiGlyphPath('M12 4 L12 20'),
    AmalfiGlyphPath('M4 12 L20 12'),
  ]);

  /// `chevron-up`.
  static const AmalfiGlyphData chevronUp = AmalfiGlyphData('chevron-up', [
    AmalfiGlyphPath('M5.4 14.59 L12 9.41 L18.6 14.59'),
  ]);

  /// `chevron-down`.
  static const AmalfiGlyphData chevronDown = AmalfiGlyphData('chevron-down', [
    AmalfiGlyphPath('M5.4 9.41 L12 14.59 L18.6 9.41'),
  ]);

  /// `chevron-left`.
  static const AmalfiGlyphData chevronLeft = AmalfiGlyphData('chevron-left', [
    AmalfiGlyphPath('M14.59 5.4 L9.41 12 L14.59 18.6'),
  ]);

  /// `chevron-right`.
  static const AmalfiGlyphData chevronRight = AmalfiGlyphData('chevron-right', [
    AmalfiGlyphPath('M9.41 5.4 L14.59 12 L9.41 18.6'),
  ]);

  /// `chevron-up-down`.
  static const AmalfiGlyphData chevronUpDown =
      AmalfiGlyphData('chevron-up-down', [
        AmalfiGlyphPath('M8 9.5 L12 5.5 L16 9.5'),
        AmalfiGlyphPath('M8 14.5 L12 18.5 L16 14.5'),
      ]);

  /// `xmark`.
  static const AmalfiGlyphData xmark = AmalfiGlyphData('xmark', [
    AmalfiGlyphPath('M5.6 5.6 L18.4 18.4'),
    AmalfiGlyphPath('M18.4 5.6 L5.6 18.4'),
  ]);

  /// `search`.
  static const AmalfiGlyphData search = AmalfiGlyphData('search', [
    AmalfiGlyphPath(
      'M4.77 10.2A5.43 5.43 0 1 0 15.63 10.2A5.43 5.43 0 1 0 4.77 10.2Z',
    ),
    AmalfiGlyphPath('M14.04 14.04 L20.25 20.25'),
  ]);

  /// `warning`.
  static const AmalfiGlyphData warning = AmalfiGlyphData('warning', [
    AmalfiGlyphPath(
      'M10.4 4.4A1.85 1.85 0 0 1 13.6 4.4L21.0 17.5A1.85 1.85 0 0 1 19.4 20.3H4.6A1.85 1.85 0 0 1 3.0 17.5Z',
    ),
    AmalfiGlyphPath('M12 9.4 L12 13.6'),
    AmalfiGlyphPath(
      'M11.45 16.7A0.55 0.55 0 1 0 12.55 16.7A0.55 0.55 0 1 0 11.45 16.7Z',
      fill: true,
    ),
  ]);

  /// `lock`.
  static const AmalfiGlyphData lock = AmalfiGlyphData('lock', [
    AmalfiGlyphPath(
      'M7.15 12.01H16.85A2.4 2.4 0 0 1 19.25 14.41V18A2.4 2.4 0 0 1 16.85 20.4H7.15A2.4 2.4 0 0 1 4.75 18V14.41A2.4 2.4 0 0 1 7.15 12.01Z',
    ),
    AmalfiGlyphPath('M8.2 12.01V7.4A3.8 3.8 0 0 1 15.8 7.4V12.01'),
    AmalfiGlyphPath(
      'M11.4 16.21A0.6 0.6 0 1 0 12.6 16.21A0.6 0.6 0 1 0 11.4 16.21Z',
      fill: true,
    ),
  ]);

  /// `photo`.
  static const AmalfiGlyphData photo = AmalfiGlyphData('photo', [
    AmalfiGlyphPath(
      'M5.15 4.25H18.85A2.4 2.4 0 0 1 21.25 6.65V17.35A2.4 2.4 0 0 1 18.85 19.75H5.15A2.4 2.4 0 0 1 2.75 17.35V6.65A2.4 2.4 0 0 1 5.15 4.25Z',
    ),
    AmalfiGlyphPath(
      'M14.15 8.75A1.6 1.6 0 1 0 17.35 8.75A1.6 1.6 0 1 0 14.15 8.75Z',
    ),
    AmalfiGlyphPath('M2.75 17 L8.5 11.25 L13.25 16'),
    AmalfiGlyphPath('M11.6 14.35 L15.5 13.25 L21.25 17'),
  ]);

  /// `eyedropper`.
  static const AmalfiGlyphData eyedropper = AmalfiGlyphData('eyedropper', [
    AmalfiGlyphPath('M4.93 19.07L6.34 15.54L12 9.88'),
    AmalfiGlyphPath('M14.12 12L8.46 17.66L4.93 19.07'),
    AmalfiGlyphPath('M10.66 8.54L15.46 13.34'),
    AmalfiGlyphPath(
      'M11.47 9.35L15.18 5.64A2.25 2.25 0 0 1 18.36 8.82L14.65 12.53',
    ),
  ]);

  /// `doc`.
  static const AmalfiGlyphData doc = AmalfiGlyphData('doc', [
    AmalfiGlyphPath(
      'M12.47 2.75H7.97A2.2 2.2 0 0 0 5.77 4.95V19.05A2.2 2.2 0 0 0 7.97 21.25H16.03A2.2 2.2 0 0 0 18.23 19.05V8.51Z',
    ),
    AmalfiGlyphPath('M12.47 2.75 L12.47 8.51 L18.23 8.51'),
  ]);

  /// `folder`.
  static const AmalfiGlyphData folder = AmalfiGlyphData('folder', [
    AmalfiGlyphPath(
      'M2.75 6.88V16.22A2.4 2.4 0 0 0 5.15 18.62H18.85A2.4 2.4 0 0 0 21.25 16.22V9.58A2.4 2.4 0 0 0 18.85 7.18H11.2L9.6 5.18C9.3 4.78 9 4.68 8.5 4.68H4.95A2.2 2.2 0 0 0 2.75 6.88Z',
    ),
    AmalfiGlyphPath('M2.75 9.78 L21.25 9.78'),
  ]);

  /// `clock`.
  static const AmalfiGlyphData clock = AmalfiGlyphData('clock', [
    AmalfiGlyphPath(
      'M2.75 12A9.25 9.25 0 1 0 21.25 12A9.25 9.25 0 1 0 2.75 12Z',
    ),
    AmalfiGlyphPath('M12 6.28 L12 12 L16.24 15.18'),
  ]);

  /// `download`.
  static const AmalfiGlyphData download = AmalfiGlyphData('download', [
    AmalfiGlyphPath('M12 3.4 L12 15.4'),
    AmalfiGlyphPath('M7.4 10.8 L12 15.4 L16.6 10.8'),
    AmalfiGlyphPath('M4.4 20.4 L19.6 20.4'),
  ]);

  /// `music-note`.
  static const AmalfiGlyphData musicNote = AmalfiGlyphData('music-note', [
    AmalfiGlyphPath(
      'M4.75 17.25A2.25 2.25 0 1 0 9.25 17.25A2.25 2.25 0 1 0 4.75 17.25Z',
      fill: true,
    ),
    AmalfiGlyphPath(
      'M14.75 15.25A2.25 2.25 0 1 0 19.25 15.25A2.25 2.25 0 1 0 14.75 15.25Z',
      fill: true,
    ),
    AmalfiGlyphPath('M9.25 17.25 L9.25 6.25 L19.25 4.25 L19.25 15.25'),
    AmalfiGlyphPath('M9.25 9.75 L19.25 7.75'),
  ]);

  /// `sidebar`.
  static const AmalfiGlyphData sidebar = AmalfiGlyphData('sidebar', [
    AmalfiGlyphPath(
      'M5.15 6.57H18.85A2.4 2.4 0 0 1 21.25 8.97V15.03A2.4 2.4 0 0 1 18.85 17.43H5.15A2.4 2.4 0 0 1 2.75 15.03V8.97A2.4 2.4 0 0 1 5.15 6.57Z',
    ),
    AmalfiGlyphPath('M9.82 6.57 L9.82 17.43'),
    AmalfiGlyphPath('M5.4 9.47 L7.22 9.47'),
    AmalfiGlyphPath('M5.4 12.07 L7.22 12.07'),
  ]);

  /// `tag`.
  static const AmalfiGlyphData tag = AmalfiGlyphData('tag', [
    AmalfiGlyphPath(
      'M3.25 12L8.6 5.25H18.85A2.4 2.4 0 0 1 21.25 7.65V16.35A2.4 2.4 0 0 1 18.85 18.75H8.6Z',
    ),
    AmalfiGlyphPath(
      'M8.4 12A0.6 0.6 0 1 0 9.6 12A0.6 0.6 0 1 0 8.4 12Z',
      fill: true,
    ),
  ]);

  /// `star`.
  static const AmalfiGlyphData star = AmalfiGlyphData('star', [
    AmalfiGlyphPath(
      'M12 2.95 L14.22 9.79 L21.42 9.79 L15.6 14.02 L17.82 20.86 L12 16.63 L6.18 20.86 L8.4 14.02 L2.58 9.79 L9.78 9.79Z',
    ),
  ]);

  /// `gear`.
  static const AmalfiGlyphData gear = AmalfiGlyphData('gear', [
    AmalfiGlyphPath(
      'M10.21 2.77 L13.79 2.77 L13.62 5.25 L15.63 6.08 L17.26 4.21 L19.79 6.74 L17.92 8.37 L18.75 10.38 L21.23 10.21 L21.23 13.79 L18.75 13.62 L17.92 15.63 L19.79 17.26 L17.26 19.79 L15.63 17.92 L13.62 18.75 L13.79 21.23 L10.21 21.23 L10.38 18.75 L8.37 17.92 L6.74 19.79 L4.21 17.26 L6.08 15.63 L5.25 13.62 L2.77 13.79 L2.77 10.21 L5.25 10.38 L6.08 8.37 L4.21 6.74 L6.74 4.21 L8.37 6.08 L10.38 5.25Z',
    ),
    AmalfiGlyphPath(
      'M8.38 12A3.62 3.62 0 1 0 15.62 12A3.62 3.62 0 1 0 8.38 12Z',
    ),
  ]);

  /// `list-bullet`.
  static const AmalfiGlyphData listBullet = AmalfiGlyphData('list-bullet', [
    AmalfiGlyphPath(
      'M4.45 6A0.55 0.55 0 1 0 5.55 6A0.55 0.55 0 1 0 4.45 6Z',
      fill: true,
    ),
    AmalfiGlyphPath(
      'M4.45 12A0.55 0.55 0 1 0 5.55 12A0.55 0.55 0 1 0 4.45 12Z',
      fill: true,
    ),
    AmalfiGlyphPath(
      'M4.45 18A0.55 0.55 0 1 0 5.55 18A0.55 0.55 0 1 0 4.45 18Z',
      fill: true,
    ),
    AmalfiGlyphPath('M9 6 L20 6'),
    AmalfiGlyphPath('M9 12 L20 12'),
    AmalfiGlyphPath('M9 18 L20 18'),
  ]);

  /// `square-grid-2x2`.
  static const AmalfiGlyphData
  squareGrid2x2 = AmalfiGlyphData('square-grid-2x2', [
    AmalfiGlyphPath(
      'M5.35 3.75H8.9A1.6 1.6 0 0 1 10.5 5.35V8.9A1.6 1.6 0 0 1 8.9 10.5H5.35A1.6 1.6 0 0 1 3.75 8.9V5.35A1.6 1.6 0 0 1 5.35 3.75Z',
    ),
    AmalfiGlyphPath(
      'M5.35 13.5H8.9A1.6 1.6 0 0 1 10.5 15.1V18.65A1.6 1.6 0 0 1 8.9 20.25H5.35A1.6 1.6 0 0 1 3.75 18.65V15.1A1.6 1.6 0 0 1 5.35 13.5Z',
    ),
    AmalfiGlyphPath(
      'M15.1 3.75H18.65A1.6 1.6 0 0 1 20.25 5.35V8.9A1.6 1.6 0 0 1 18.65 10.5H15.1A1.6 1.6 0 0 1 13.5 8.9V5.35A1.6 1.6 0 0 1 15.1 3.75Z',
    ),
    AmalfiGlyphPath(
      'M15.1 13.5H18.65A1.6 1.6 0 0 1 20.25 15.1V18.65A1.6 1.6 0 0 1 18.65 20.25H15.1A1.6 1.6 0 0 1 13.5 18.65V15.1A1.6 1.6 0 0 1 15.1 13.5Z',
    ),
  ]);

  /// `share`.
  static const AmalfiGlyphData share = AmalfiGlyphData('share', [
    AmalfiGlyphPath(
      'M8.6 9.4H7.15A2.4 2.4 0 0 0 4.75 11.8V18.45A2.4 2.4 0 0 0 7.15 20.85H16.85A2.4 2.4 0 0 0 19.25 18.45V11.8A2.4 2.4 0 0 0 16.85 9.4H15.4',
    ),
    AmalfiGlyphPath('M12 3.2 L12 14.4'),
    AmalfiGlyphPath('M8.6 6.6 L12 3.2 L15.4 6.6'),
  ]);

  /// `ellipsis-circle`.
  static const AmalfiGlyphData ellipsisCircle =
      AmalfiGlyphData('ellipsis-circle', [
        AmalfiGlyphPath(
          'M2.75 12A9.25 9.25 0 1 0 21.25 12A9.25 9.25 0 1 0 2.75 12Z',
        ),
        AmalfiGlyphPath(
          'M7.4 12A0.5 0.5 0 1 0 8.4 12A0.5 0.5 0 1 0 7.4 12Z',
          fill: true,
        ),
        AmalfiGlyphPath(
          'M11.5 12A0.5 0.5 0 1 0 12.5 12A0.5 0.5 0 1 0 11.5 12Z',
          fill: true,
        ),
        AmalfiGlyphPath(
          'M15.6 12A0.5 0.5 0 1 0 16.6 12A0.5 0.5 0 1 0 15.6 12Z',
          fill: true,
        ),
      ]);

  /// `compose`.
  static const AmalfiGlyphData compose = AmalfiGlyphData('compose', [
    AmalfiGlyphPath(
      'M10.5 4.25H6.15A2.4 2.4 0 0 0 3.75 6.65V17.85A2.4 2.4 0 0 0 6.15 20.25H17.35A2.4 2.4 0 0 0 19.75 17.85V13.5',
    ),
    AmalfiGlyphPath(
      'M9.13 14.87L10.26 10.91L16.2 4.97A1 1 0 0 1 17.61 4.97L19.03 6.39A1 1 0 0 1 19.03 7.8L13.09 13.74L9.13 14.87Z',
    ),
    AmalfiGlyphPath('M10.26 10.91L13.09 13.74'),
  ]);

  /// `trash`.
  static const AmalfiGlyphData trash = AmalfiGlyphData('trash', [
    AmalfiGlyphPath('M3.6 6.4 L20.4 6.4'),
    AmalfiGlyphPath(
      'M9.1 6.4V5.2A1.7 1.7 0 0 1 10.8 3.5H13.2A1.7 1.7 0 0 1 14.9 5.2V6.4',
    ),
    AmalfiGlyphPath(
      'M5.6 6.4L6.6 18.9A2.1 2.1 0 0 0 8.7 20.8H15.3A2.1 2.1 0 0 0 17.4 18.9L18.4 6.4',
    ),
    AmalfiGlyphPath('M10 10 L10 16.8'),
    AmalfiGlyphPath('M14 10 L14 16.8'),
  ]);
}
