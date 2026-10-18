// Geometry assertions: a rendered widget against a kit master, exactly.

import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

import 'kit.dart';
import 'rendered_style.dart';

const double _epsilon = 1e-6;

/// Reports a mismatch of one aspect of the layer being checked.
typedef _Add = void Function(String aspect, String message);

/// The aspects a deviation can name after `#` (`Surface#shadows`).
const Set<String> kitAspects = {
  'frame',
  'fills',
  'gradients',
  'borders',
  'shadows',
  'innerShadows',
  'blurs',
  'corners',
  'text',
  'font',
  'color',
  'style',
  'token',
};

/// Checks the widget found by [root] against [master], exactly.
///
/// - The root's size is the master's size.
/// - For each entry of [layers] (a layer path of the master → a finder of the widget that
///   draws it): the frame of the finder's render box, relative to [root], is the layer's frame
///   in the master, on whole points.
/// - Shape layers: the style painted at or below the finder ([RenderedStyle.of]) has the
///   master's fills, borders, shadows, inner shadows, background blurs and corner radii (with
///   the smoothing), each colour checked against the Amalfi token of its swatch.
/// - Text layers: the text, family, size, weight, line height and colour, and the Amalfi text
///   style named by the layer's shared style.
/// - Symbol instances: the frame only (the nested master has its own test).
///
/// [deviations] lists what is known to differ from the kit, with the reason (a kit defect, a
/// decision of the design docs): the key is `<layer path>#<aspect>` with an aspect of
/// [kitAspects] (`Surface#shadows`, `#frame` for the root size); a bare path means its frame.
/// A deviation is not compared, but one that turns out to match is reported, so stale
/// entries do not pile up. Every mismatch is collected and reported at once.
void expectKitGeometry(
  WidgetTester tester,
  KitMaster master, {
  required Finder root,
  Map<String, Finder> layers = const {},
  Map<String, String> deviations = const {},
}) {
  final errors = <String>[];
  final allowed = <String, String>{};
  for (final MapEntry(:key, :value) in deviations.entries) {
    final normal = key.contains('#') ? key : '$key#frame';
    final aspect = normal.substring(normal.indexOf('#') + 1);
    if (!kitAspects.contains(aspect)) {
      errors.add(
        'deviation "$key": unknown aspect "$aspect" (one of $kitAspects)',
      );
    }
    allowed[normal] = value;
  }
  final used = <String>{};

  _Add reporter(String path) => (aspect, message) {
    final key = '$path#$aspect';
    if (allowed.containsKey(key)) {
      used.add(key);
    } else {
      errors.add(message);
    }
  };

  void frame(String path, Rect expected, Rect actual) {
    final add = reporter(path);
    if (!_sameRect(expected, actual)) {
      add('frame', '"$path": frame $actual, kit $expected');
    }
    if (!_wholePoints(actual)) {
      add('frame', '"$path": frame $actual is not on whole points');
    }
  }

  frame(
    '',
    Offset.zero & master.size,
    Offset.zero & _rootBox(tester, root).size,
  );

  for (final MapEntry(key: path, value: finder) in layers.entries) {
    final layer = master.maybeLayer(path);
    if (layer == null) {
      errors.add('"$path": no such layer in ${master.name}');
      continue;
    }
    if (finder.evaluate().length != 1) {
      errors.add(
        '"$path": the finder matches ${finder.evaluate().length} widgets, not 1',
      );
      continue;
    }
    final box = tester.renderObject<RenderBox>(finder);
    if (path.isNotEmpty) {
      final at = box.localToGlobal(
        Offset.zero,
        ancestor: _rootBox(tester, root),
      );
      frame(path, layer.rectInMaster, at & box.size);
    }
    switch (layer.type) {
      case KitLayerType.text:
        _checkText(tester, layer, finder, reporter(path));
      case KitLayerType.symbolInstance:
        break;
      default:
        final style = layer.style;
        if (style != null && !style.isEmpty) {
          // Light glass keeps its tint in a sibling `<name> tint` layer (the glass layer has
          // no fill of its own): the code's glass paints that tint once.
          _checkStyle(
            tester,
            layer,
            style,
            finder,
            reporter(path),
            tint: master.maybeLayer('$path tint')?.style,
          );
        }
    }
  }

  for (final MapEntry(:key, :value) in allowed.entries) {
    if (!used.contains(key)) {
      errors.add(
        'deviation "$key" ($value) did not occur: the widget matches the kit',
      );
    }
  }
  if (errors.isNotEmpty) {
    fail('${master.name} differs from the kit:\n  ${errors.join('\n  ')}');
  }
}

RenderBox _rootBox(WidgetTester tester, Finder root) =>
    tester.renderObject<RenderBox>(root);

bool _same(double a, double b) => (a - b).abs() < _epsilon;

bool _sameRect(Rect a, Rect b) =>
    _same(a.left, b.left) &&
    _same(a.top, b.top) &&
    _same(a.width, b.width) &&
    _same(a.height, b.height);

bool _whole(double v) => _same(v, v.roundToDouble());

bool _wholePoints(Rect r) =>
    _whole(r.left) && _whole(r.top) && _whole(r.width) && _whole(r.height);

String _hex(Color c) =>
    '#${c.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';

/// The colour a kit fill or border should be painted with: its swatch's token when it has
/// one (checked against the raw colour), else the raw colour.
Color _expectedColor(Color raw, KitSwatch? swatch, String what, _Add add) {
  if (swatch == null) return raw;
  final token = swatch.resolve();
  if (token == null) {
    add('token', '$what: swatch $swatch is not an Amalfi colour token');
    return raw;
  }
  if (token != raw) {
    add(
      'token',
      '$what: swatch $swatch is ${_hex(token)} in the tokens but ${_hex(raw)} in the kit',
    );
  }
  return token;
}

void _checkStyle(
  WidgetTester tester,
  KitLayer layer,
  KitStyle kit,
  Finder finder,
  _Add add, {
  KitStyle? tint,
}) {
  final p = '"${layer.path}"';
  final r = RenderedStyle.of(tester, finder);
  if (r == null) {
    add(
      'style',
      '$p: no painted style found at or below the widget (register an extractor '
          'with RenderedStyle.register)',
    );
    return;
  }
  final what = '$p (${r.source})';

  var flat = kit.fills.where((f) => f.gradient == null).toList();
  // Sketch draws a layer's shadow only for a layer with a fill, so the Light glass layers carry
  // a ~1% white fill in the kit; the code does not paint it, and the tint is the sibling's.
  final placeholder =
      flat.length == 1 &&
      flat.first.swatch == null &&
      flat.first.color != null &&
      flat.first.color!.a <= 0.02 &&
      flat.first.color!.r > 0.99 &&
      flat.first.color!.g > 0.99 &&
      flat.first.color!.b > 0.99;
  if ((flat.isEmpty || placeholder) && tint != null) {
    flat = tint.fills.where((f) => f.gradient == null).toList();
  }
  if (flat.length != r.fills.length) {
    add('fills', '$what: ${r.fills.length} fills, kit ${flat.length}');
  } else {
    for (var i = 0; i < flat.length; i++) {
      final want = _expectedColor(
        flat[i].color!,
        flat[i].swatch,
        '$what fill $i',
        add,
      );
      if (r.fills[i] != want) {
        add('fills', '$what: fill $i ${_hex(r.fills[i])}, kit ${_hex(want)}');
      }
    }
  }
  final gradients = kit.fills.where((f) => f.gradient != null).toList();
  if (gradients.length != r.gradients.length) {
    add(
      'gradients',
      '$what: ${r.gradients.length} gradients, kit ${gradients.length}',
    );
  } else {
    for (var i = 0; i < gradients.length; i++) {
      final g = gradients[i].gradient!;
      final rg = r.gradients[i];
      final colors = g.stops.map((s) => s.$2).toList();
      final stops = g.stops.map((s) => s.$1).toList();
      if (!listEquals(rg.colors, colors) ||
          !listEquals(rg.stops ?? _evenStops(colors.length), stops)) {
        add(
          'gradients',
          '$what: gradient $i ${rg.colors}/${rg.stops}, kit $colors/$stops',
        );
      }
    }
  }

  if (kit.borders.length != r.borders.length) {
    add(
      'borders',
      '$what: ${r.borders.length} borders, kit ${kit.borders.length}',
    );
  } else {
    for (var i = 0; i < kit.borders.length; i++) {
      final b = kit.borders[i];
      final rb = r.borders[i];
      final want = _expectedColor(b.color, b.swatch, '$what border $i', add);
      if (rb.color != want ||
          !_same(rb.width, b.thickness) ||
          !_same(rb.strokeAlign, b.position.strokeAlign)) {
        add(
          'borders',
          '$what: border $i ${_hex(rb.color)} ${rb.width} align ${rb.strokeAlign}, '
              'kit ${_hex(want)} ${b.thickness} ${b.position.name}',
        );
      }
      // Dashes (pattern, line end, join): compared when the kit's border has a non-empty
      // dash pattern; a solid border checks colour, width and position only.
      final kitDashes = b.dashPattern;
      if (kitDashes != null &&
          !listEquals(_pattern(rb.dashPattern), _pattern(kitDashes))) {
        add(
          'borders',
          '$what: border $i dashes ${rb.dashPattern ?? 'none (solid)'}, kit $kitDashes',
        );
      } else if (kitDashes != null &&
          (rb.lineEnd != b.lineEnd || rb.lineJoin != b.lineJoin)) {
        add(
          'borders',
          '$what: border $i line end ${rb.lineEnd} join ${rb.lineJoin}, '
              'kit ${b.lineEnd} ${b.lineJoin}',
        );
      }
    }
  }

  void shadows(
    String kind,
    String aspect,
    List<KitShadow> kit,
    List<BoxShadow> rendered,
  ) {
    if (kit.length != rendered.length) {
      add(aspect, '$what: ${rendered.length} $kind, kit ${kit.length}');
      return;
    }
    for (var i = 0; i < kit.length; i++) {
      final k = kit[i];
      final s = rendered[i];
      if (s.color != k.color ||
          s.offset != k.offset ||
          !_same(s.blurRadius, k.blur) ||
          !_same(s.spreadRadius, k.spread)) {
        add(
          aspect,
          '$what: $kind $i ${_hex(s.color)} ${s.offset} blur ${s.blurRadius} '
          'spread ${s.spreadRadius}, kit ${_hex(k.color)} ${k.offset} blur ${k.blur} '
          'spread ${k.spread}',
        );
      }
    }
  }

  shadows('shadows', 'shadows', kit.shadows, r.shadows);
  shadows('inner shadows', 'innerShadows', kit.innerShadows, r.innerShadows);

  // Background blurs (a plain material) and, since the kit gave Regular and Thick real glass,
  // `Glass` blurs (blur, saturation, brightness, edge refraction). The lens of Glass/Clear is
  // also a `Glass` blur, drawn by the lens itself, and is not compared here.
  final clearChroma = AmalfiMaterials.clear.refraction!.chromaticAberration;
  bool isLens(KitBlur b) =>
      _same(_num(b.raw['chromaticAberration']), clearChroma);
  final backgrounds = kit.blurs.where((b) => b.type == 'Background').toList();
  final glasses = kit.blurs
      .where((b) => b.type == 'Glass' && !isLens(b))
      .toList();
  final renderedBackgrounds = r.blurs.where((b) => b.glass == null).toList();
  final renderedGlasses = r.blurs.where((b) => b.glass != null).toList();
  if (backgrounds.length != renderedBackgrounds.length) {
    add(
      'blurs',
      '$what: ${renderedBackgrounds.length} background blurs, kit ${backgrounds.length}',
    );
  } else {
    for (var i = 0; i < backgrounds.length; i++) {
      final k = backgrounds[i];
      final b = renderedBackgrounds[i];
      if (!_same(k.radius, b.radius) || !_same(k.saturation, b.saturation)) {
        add(
          'blurs',
          '$what: background blur $i ${b.radius} × saturation ${b.saturation}, '
              'kit ${k.radius} × ${k.saturation}',
        );
      }
    }
  }
  if (glasses.length != renderedGlasses.length) {
    add(
      'blurs',
      '$what: ${renderedGlasses.length} glass blurs, kit ${glasses.length}',
    );
  } else {
    for (var i = 0; i < glasses.length; i++) {
      final k = glasses[i];
      final b = renderedGlasses[i];
      final g = b.glass!;
      final want = [
        b.radius,
        b.saturation,
        b.brightness,
        g.distortion,
        g.depth,
        g.chromaticAberration,
      ];
      final have = [
        k.radius,
        k.saturation,
        k.brightness,
        _num(k.raw['distortion']),
        _num(k.raw['depth']),
        _num(k.raw['chromaticAberration']),
      ];
      final same = [
        for (var j = 0; j < want.length; j++) _same(have[j], want[j]),
      ].every((x) => x);
      if (!same && !_knownKitGlass(have, want)) {
        add(
          'blurs',
          '$what: glass blur $i (σ, saturation, brightness, distortion, depth, '
              'chromatic aberration) $want, kit $have',
        );
      }
    }
  }

  // Corners, as drawn: each radius clamped to half the shorter side.
  final half = math.min(layer.frame.width, layer.frame.height) / 2;
  List<double> drawn(List<double> radii) => radii.isEmpty
      ? const [0, 0, 0, 0]
      : [for (final x in radii) math.min(x, half)];
  final kitRadii = drawn(kit.corners?.radii ?? const []);
  final radii = drawn(r.radii);
  if (kitRadii.length != radii.length ||
      [for (var i = 0; i < radii.length; i++) _same(kitRadii[i], radii[i])]
          .contains(false)) {
    add('corners', '$what: corner radii $radii, kit $kitRadii');
  }
  // The smoothing only shows on corners that are not half a capsule.
  final smoothCorners = kitRadii.any((x) => x > 0 && x < half - _epsilon);
  final kitSmoothing = kit.corners?.smoothing ?? 0;
  if (smoothCorners && !_same(kitSmoothing, r.smoothing)) {
    add('corners', '$what: corner smoothing ${r.smoothing}, kit $kitSmoothing');
  }
}

/// A dash pattern with an odd count repeated to an even one, as SVG and Sketch read it.
List<double>? _pattern(List<double>? p) =>
    p == null || p.isEmpty ? null : (p.length.isOdd ? [...p, ...p] : p);

List<double> _evenStops(int n) => [
  for (var i = 0; i < n; i++) n == 1 ? 0 : i / (n - 1),
];

/// A kit icon is a text layer in the Silica Symbols font (its text is the symbol name, its
/// font size the icon box). The controls paint the same symbols as vector glyphs
/// ([AmalfiGlyph], from the same drawings): the glyph is the layer's symbol, painted at the
/// font size in the font colour.
void _checkSymbolGlyph(KitLayer layer, Finder finder, _Add add) {
  final p = '"${layer.path}"';
  final font = layer.font!;
  final texts = find.descendant(
    of: finder,
    matching: find.byType(RichText),
    matchRoot: true,
  );
  if (texts.evaluate().isNotEmpty) {
    // Painted from the bundled font: the codepoint of the symbol, at the font size.
    final span = (texts.evaluate().first.widget as RichText).text;
    final style = span.style;
    final codepoint = silicaSymbolCodepoints[layer.text];
    if (layer.text != null &&
        span.toPlainText() != String.fromCharCode(codepoint ?? 0)) {
      add('text', '$p: symbol "${span.toPlainText()}", kit "${layer.text}"');
    }
    if (style?.fontSize != font.size) {
      add('font', '$p: symbol size ${style?.fontSize}, kit ${font.size}');
    }
    if (font.color != null && style?.color != font.color) {
      add('color', '$p: colour ${style?.color}, kit ${_hex(font.color!)}');
    }
    return;
  }
  final painters = find.descendant(
    of: finder,
    matching: find.byWidgetPredicate(
      (w) => w is CustomPaint && w.painter is AmalfiGlyphPainter,
    ),
    matchRoot: true,
  );
  if (painters.evaluate().isEmpty) {
    add('text', '$p: no symbol at or below the widget');
    return;
  }
  final painter =
      (painters.evaluate().first.widget as CustomPaint).painter!
          as AmalfiGlyphPainter;
  if (layer.text != null && painter.glyph.name != layer.text) {
    add('text', '$p: symbol "${painter.glyph.name}", kit "${layer.text}"');
  }
  final size = painters.evaluate().first.size;
  if (size != null && !_same(size.width, font.size ?? 0)) {
    add('font', '$p: symbol size ${size.width}, kit ${font.size}');
  }
  if (font.color != null && painter.color != font.color) {
    add('color', '$p: colour ${_hex(painter.color)}, kit ${_hex(font.color!)}');
  }
}

void _checkText(WidgetTester tester, KitLayer layer, Finder finder, _Add add) {
  final p = '"${layer.path}"';
  final paragraphs = find.descendant(
    of: finder,
    matching: find.byType(RichText),
    matchRoot: true,
  );
  final editables = find.descendant(
    of: finder,
    matching: find.byType(EditableText),
    matchRoot: true,
  );
  final String text;
  final TextStyle? style;
  final symbol = layer.font?.family == 'Silica Symbols';
  if (symbol) {
    _checkSymbolGlyph(layer, finder, add);
    return;
  }
  if (paragraphs.evaluate().isNotEmpty) {
    final span = tester.renderObject<RenderParagraph>(paragraphs.first).text;
    text = span.toPlainText();
    style = span.style;
  } else if (editables.evaluate().isNotEmpty) {
    // An editable value: its text (or the bullets of obscured text) and its style.
    final editable = tester.widget<EditableText>(editables.first);
    text = editable.obscureText
        ? editable.obscuringCharacter * editable.controller.text.length
        : editable.controller.text;
    style = editable.style;
  } else {
    add('text', '$p: no text at or below the widget');
    return;
  }
  final font = layer.font;
  if (style == null || font == null) {
    add(
      'text',
      '$p: ${style == null ? 'the text has no style' : 'the kit layer has no font'}',
    );
    return;
  }
  if (layer.text != null && text != layer.text) {
    add('text', '$p: text "$text", kit "${layer.text}"');
  }
  final family = style.fontFamily?.replaceFirst(
    RegExp(r'^packages/[^/]+/'),
    '',
  );
  if (family != font.family) {
    add('font', '$p: family $family, kit ${font.family}');
  }
  if (!_same(style.fontSize ?? -1, font.size ?? -2)) {
    add('font', '$p: size ${style.fontSize}, kit ${font.size}');
  }
  final weight = font.fontWeight;
  if (weight == null) {
    add('font', '$p: kit weight ${font.weight} has no Amalfi equivalent');
  } else if ((style.fontWeight ?? FontWeight.w400) != weight) {
    add('font', '$p: weight ${style.fontWeight}, kit $weight (${font.weight})');
  }
  final lineHeight = style.height == null || style.fontSize == null
      ? null
      : style.height! * style.fontSize!;
  if (font.lineHeight != null &&
      (lineHeight == null || !_same(lineHeight, font.lineHeight!))) {
    add('font', '$p: line height $lineHeight, kit ${font.lineHeight}');
  }
  if (font.color != null && style.color != font.color) {
    add(
      'color',
      '$p: colour ${style.color == null ? null : _hex(style.color!)}, kit ${_hex(font.color!)}',
    );
  }
  final ref = layer.textStyle;
  if (layer.sharedStyle != null && ref == null) {
    add(
      'style',
      '$p: text style "${layer.sharedStyle}" is not an Amalfi text style',
    );
  }
  if (ref != null) {
    final t = ref.style;
    if (t.family != font.family ||
        !_same(t.size, font.size ?? -1) ||
        (t.lineHeight != null &&
            !_same(t.lineHeight!, font.lineHeight ?? -1)) ||
        (ref.weight ?? t.weight) != weight) {
      add(
        'style',
        '$p: the kit font differs from the token ${t.name} '
            '(${t.family} ${t.size}/${t.lineHeight} ${t.weight})',
      );
    }
    final c = ref.color;
    if (c == null) {
      add(
        'color',
        '$p: colour token ${ref.colorToken} is not an Amalfi colour',
      );
    } else if (font.color != null && c != font.color) {
      add(
        'color',
        '$p: colour token ${ref.colorToken} is ${_hex(c)}, kit ${_hex(font.color!)}',
      );
    }
  }
}

double _num(Object? v) => v is num ? v.toDouble() : 0;

/// Kit-side deviations of the `Glass` blur of Regular and Thick from tokens.json (see
/// `docs/amalfi-checklist/kit-issues.md`), accepted exactly as they are in the kit at the
/// recorded commit; any other difference fails. Fields: σ, saturation, brightness,
/// distortion, depth, chromatic aberration.
bool _knownKitGlass(List<double> kit, List<double> tokens) {
  bool is_(List<double> x) =>
      [for (var i = 0; i < x.length; i++) _same(kit[i], x[i])].every((b) => b);
  // Thick: the kit has saturation 1 and no chromatic aberration (Sketch cannot draw it).
  final thick = AmalfiMaterials.thick;
  if (_same(tokens[0], thick.backgroundBlur) &&
      _same(tokens[3], thick.refraction!.distortion)) {
    return is_([tokens[0], 1, tokens[2], tokens[3], tokens[4], 0]);
  }
  // Regular, dark: the kit has σ 10, saturation 1, distortion 0.5, depth 0.5, no chromatic
  // aberration (the light master has the token values).
  return is_([10, 1, AmalfiMaterials.regular.brightnessDark, 0.5, 0.5, 0]);
}
