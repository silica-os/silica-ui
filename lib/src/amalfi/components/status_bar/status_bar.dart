// The Status Bar (kit `Status Bar/*`, silica-desktop docs/design/amalfi/status-bar.md): the
// status cluster at the trailing end of the top edge, one component for every context. The menu
// bar nests it, and the lock screen places it where the menu bar keeps it, so nothing moves when
// the screen locks or unlocks.
//
// The bar is 32 tall; its items are 28 tall at y 2 and touch (gap 0), each with 8 pt of padding
// (16 pt between two glyphs). An item's hit area is the whole item extended to the bar's full
// height. Glyphs are Silica Symbols 20, labels `Body Emphasis`. One ink per context: `Text/Primary`
// of the appearance in the menu bar, on-photo white on the lock screen (with `shadows.onPhoto` in
// the light appearance). Under Increase contrast and Reduce transparency the cluster sits on a
// plate (`Glass/Lock Increase Contrast`, `Glass/Lock Reduce Transparency`).
//
// The items only draw: what they show (the Wi-Fi strength, the battery level, the input source)
// comes from whoever builds them.

import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../system_look.dart';
import '../../foundation/interaction.dart';
import '../../foundation/symbol.dart';
import '../../smooth_border.dart';
import '../../theme.dart';
import '../../token_types.dart';
import '../../tokens.g.dart';
import '../../whole_points.dart';

/// The measures of the Status Bar, in points.
abstract final class AmalfiStatusBarMetrics {
  /// The bar's height (the menu bar's).
  static const double height = 32;

  /// An item's height, and its top inside the bar.
  static const double itemHeight = 28;
  static const double itemTop = (height - itemHeight) / 2;

  /// The padding inside an item, on each side.
  static const double padding = 8;

  /// The glyph box (Silica Symbols Regular 20), and its top inside an item.
  static const double glyph = 20;
  static const double glyphTop = (itemHeight - glyph) / 2;

  /// The gap between a label and its glyph.
  static const double labelGap = 4;

  /// A one-glyph item's width.
  static const double glyphItemWidth = padding + glyph + padding;

  /// The cluster's trailing edge from the screen's right edge (the menu bar's padding).
  static const double trailing = 8;

  /// The radius of the Active capsule and of the plate.
  static const double radius = 14;
}

/// Where a Status Bar sits.
enum AmalfiStatusBarPlacement {
  /// Nested in the menu bar (`Status Bar/Bar/Menu Bar/*`).
  menuBar,

  /// On the lock screen, at the menu bar's place (`Status Bar/Bar/Lock Screen/*`).
  lockScreen,
}

/// The legibility treatment of a Status Bar (the kit's `Default`, `Increase Contrast` and
/// `Reduce Transparency` bars).
enum AmalfiStatusBarLegibility {
  /// Ink straight on the wallpaper.
  standard,

  /// On the `Glass/Lock Increase Contrast` plate, in `Text/Primary`.
  increaseContrast,

  /// On the opaque `Glass/Lock Reduce Transparency` plate, in `Text/Primary`.
  reduceTransparency;

  /// The treatment the system's accessibility settings ask for: Increase contrast first.
  static AmalfiStatusBarLegibility of(BuildContext context) {
    final look = SystemLookScope.of(context);
    if (look.increaseContrast) return increaseContrast;
    if (look.reduceTransparency) return reduceTransparency;
    return standard;
  }
}

/// How the items of a Status Bar draw: one ink, its shadows, the Active capsule, the plate.
@immutable
class AmalfiStatusBarStyle {
  const AmalfiStatusBarStyle({
    required this.ink,
    required this.shadows,
    required this.active,
    this.plate,
  });

  /// The style of a bar at [placement] with [legibility], in [brightness].
  factory AmalfiStatusBarStyle.resolve({
    required AmalfiStatusBarPlacement placement,
    required AmalfiStatusBarLegibility legibility,
    required Brightness brightness,
  }) {
    final colors = AmalfiColors.of(brightness);
    final dark = brightness == Brightness.dark;
    final plate = switch (legibility) {
      AmalfiStatusBarLegibility.standard => null,
      AmalfiStatusBarLegibility.increaseContrast =>
        AmalfiMaterials.lock.increaseContrast(brightness),
      AmalfiStatusBarLegibility.reduceTransparency =>
        AmalfiMaterials.lock.reduceTransparency(brightness),
    };
    final onPhoto =
        placement == AmalfiStatusBarPlacement.lockScreen && plate == null;
    return AmalfiStatusBarStyle(
      // On the photo the lock screen's ink is the dark appearance's primary in both
      // appearances (the kit nests the Dark items in the Light bar).
      ink: onPhoto ? AmalfiColors.dark.textPrimary : colors.textPrimary,
      shadows: onPhoto && !dark ? AmalfiShadows.onPhoto : const [],
      active: legibility == AmalfiStatusBarLegibility.reduceTransparency
          ? (dark ? colors.surfaceControl : colors.surfaceControlPressed)
          : colors.menuBarSelection,
      plate: plate,
    );
  }

  /// The colour of every glyph and label.
  final Color ink;

  /// The shadows under every glyph and label (`shadows.onPhoto`); empty: none.
  final List<Shadow> shadows;

  /// The Active capsule's colour (`Menu Bar/Selection`; opaque under Reduce transparency).
  final Color active;

  /// The plate behind the cluster; null: none.
  final AmalfiGlassVariant? plate;

  /// The nearest bar's style; without a bar, the menu bar's in the theme's appearance.
  static AmalfiStatusBarStyle of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<_AmalfiStatusBarScope>()
          ?.style ??
      AmalfiStatusBarStyle.resolve(
        placement: AmalfiStatusBarPlacement.menuBar,
        legibility: AmalfiStatusBarLegibility.standard,
        brightness: AmalfiTheme.of(context).brightness,
      );

  @override
  bool operator ==(Object other) =>
      other is AmalfiStatusBarStyle &&
      other.ink == ink &&
      _sameShadows(other.shadows, shadows) &&
      other.active == active &&
      other.plate == plate;

  @override
  int get hashCode => Object.hash(ink, Object.hashAll(shadows), active, plate);

  static bool _sameShadows(List<Shadow> a, List<Shadow> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

class _AmalfiStatusBarScope extends InheritedWidget {
  const _AmalfiStatusBarScope({required this.style, required super.child});

  final AmalfiStatusBarStyle style;

  @override
  bool updateShouldNotify(_AmalfiStatusBarScope old) => old.style != style;
}

/// The Status Bar: [items] in a row, leading to trailing, touching, 32 tall; under Increase
/// contrast and Reduce transparency on a plate as wide as the items. The caller places it with
/// its trailing edge [AmalfiStatusBarMetrics.trailing] from the screen's right edge.
class AmalfiStatusBar extends StatelessWidget {
  const AmalfiStatusBar({
    super.key,
    required this.placement,
    this.legibility,
    required this.items,
  });

  final AmalfiStatusBarPlacement placement;

  /// The treatment; null: what the system's accessibility settings ask for.
  final AmalfiStatusBarLegibility? legibility;

  /// The items ([AmalfiStatusItem] and its kinds).
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    final style = AmalfiStatusBarStyle.resolve(
      placement: placement,
      legibility: legibility ?? AmalfiStatusBarLegibility.of(context),
      brightness: AmalfiTheme.of(context).brightness,
    );
    final row = Row(mainAxisSize: MainAxisSize.min, children: items);
    return _AmalfiStatusBarScope(
      style: style,
      child: SizedBox(
        height: AmalfiStatusBarMetrics.height,
        child: style.plate == null || items.isEmpty
            ? row
            : Stack(
                children: [
                  Positioned(
                    left: 0,
                    right: 0,
                    top: AmalfiStatusBarMetrics.itemTop,
                    height: AmalfiStatusBarMetrics.itemHeight,
                    child: AmalfiStatusBarPlate(
                      key: const ValueKey('amalfi status bar plate'),
                      variant: style.plate!,
                    ),
                  ),
                  row,
                ],
              ),
      ),
    );
  }
}

/// The plate behind a Status Bar under Increase contrast and Reduce transparency: a capsule of
/// radius 14 with the variant's fill, its 1 pt rim inside and its rim light along the top.
class AmalfiStatusBarPlate extends StatelessWidget {
  const AmalfiStatusBarPlate({super.key, required this.variant});

  final AmalfiGlassVariant variant;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: ShapeDecoration(
      color: variant.fill,
      shape: AmalfiSmoothBorder(
        radius: AmalfiStatusBarMetrics.radius,
        side: BorderSide(
          color: variant.rimInside,
          strokeAlign: BorderSide.strokeAlignInside,
        ),
      ),
    ),
    child: variant.rimLight == null
        ? const SizedBox.expand()
        : CustomPaint(
            painter: _RimLightPainter(variant.rimLight!),
            child: const SizedBox.expand(),
          ),
  );
}

/// The rim light of a plate: an inner shadow (0, 1, blur 1) along the top edge.
class _RimLightPainter extends CustomPainter {
  const _RimLightPainter(this.color);

  final Color color;

  static const AmalfiSmoothBorder _shape = AmalfiSmoothBorder(
    radius: AmalfiStatusBarMetrics.radius,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final outline = _shape.getOuterPath(rect);
    final ring = Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect.inflate(4))
      ..addPath(outline, const Offset(0, 1));
    canvas
      ..save()
      ..clipPath(outline)
      ..drawPath(
        ring,
        Paint()
          ..color = color
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 0.5),
      )
      ..restore();
  }

  @override
  bool shouldRepaint(_RimLightPainter old) => old.color != color;
}

/// A Status Bar item (kit `Status Bar/Item/*`): [child] with 8 pt of padding, 28 tall at y 2 of
/// a 32 pt hit area; the `Menu Bar/Selection` capsule (radius 14, the full item) while [active]
/// or pressed. Return and Space activate it with the keyboard focus. Without [onPressed] it only
/// shows.
class AmalfiStatusItem extends StatelessWidget {
  const AmalfiStatusItem({
    super.key,
    this.boxKey,
    required this.label,
    this.value,
    this.active = false,
    this.onPressed,
    this.width,
    required this.child,
  });

  /// A key for the visible 28 pt box (to find where the item is drawn).
  final Key? boxKey;

  /// What a screen reader reads: the item's name ("Battery").
  final String label;

  /// And its value ("84 percent"); null: none.
  final String? value;

  /// Its menu or panel is open: the Active capsule, read as expanded.
  final bool active;

  final VoidCallback? onPressed;

  /// The item's width; null: the child's plus the padding.
  final double? width;

  /// The content, laid out from x 8 inside the item.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final style = AmalfiStatusBarStyle.of(context);
    Widget box(bool on) => SizedBox(
      height: AmalfiStatusBarMetrics.height,
      child: Center(
        widthFactor: 1,
        child: SizedBox(
          key: boxKey,
          width: width,
          height: AmalfiStatusBarMetrics.itemHeight,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: on ? style.active : null,
              shape: const AmalfiSmoothBorder(
                radius: AmalfiStatusBarMetrics.radius,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AmalfiStatusBarMetrics.padding,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
    final press = onPressed;
    return Semantics(
      button: press != null,
      label: label,
      value: value,
      expanded: press == null ? null : active,
      excludeSemantics: true,
      onTap: press,
      child: press == null
          ? box(active)
          : AmalfiInteraction(
              onActivate: press,
              activators: const {
                SingleActivator(LogicalKeyboardKey.space):
                    AmalfiActivateIntent(),
                SingleActivator(LogicalKeyboardKey.enter):
                    AmalfiActivateIntent(),
                SingleActivator(LogicalKeyboardKey.numpadEnter):
                    AmalfiActivateIntent(),
              },
              builder: (context, state) =>
                  box(active || state.pressed || state.focused),
            ),
    );
  }
}

/// The glyph of an item: Silica Symbols Regular 20 in the bar's ink, with its shadows.
class AmalfiStatusGlyph extends StatelessWidget {
  const AmalfiStatusGlyph(this.symbol, {super.key, this.fallback});

  /// The symbol's name (`wifi`, `battery-50`, `control-center`).
  final String symbol;

  /// Drawn when the symbol is in neither the bundled font nor the installed icons.
  final Widget? fallback;

  @override
  Widget build(BuildContext context) {
    final style = AmalfiStatusBarStyle.of(context);
    final glyph = AmalfiSymbol(
      symbol,
      size: AmalfiStatusBarMetrics.glyph,
      color: style.ink,
      fallback: fallback,
    );
    return SizedBox.square(
      dimension: AmalfiStatusBarMetrics.glyph,
      child: style.shadows.isEmpty
          ? glyph
          : _Shadowed(shadows: style.shadows, child: glyph),
    );
  }
}

/// The shadows of on-photo ink under a glyph: the glyph's own alpha, blurred and offset.
class _Shadowed extends StatelessWidget {
  const _Shadowed({required this.shadows, required this.child});

  final List<Shadow> shadows;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      for (final s in shadows)
        Positioned.fill(
          child: IgnorePointer(
            child: Transform.translate(
              offset: s.offset,
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(
                  sigmaX: s.blurSigma,
                  sigmaY: s.blurSigma,
                  tileMode: TileMode.decal,
                ),
                child: ColorFiltered(
                  colorFilter: ColorFilter.mode(s.color, BlendMode.srcIn),
                  child: ExcludeSemantics(child: child),
                ),
              ),
            ),
          ),
        ),
      child,
    ],
  );
}

/// A label of an item: `Body Emphasis` (Inter 13/18, 500) in the bar's ink, in a box rounded up
/// to the 4 pt grid (the kit's label boxes).
class AmalfiStatusLabel extends StatelessWidget {
  const AmalfiStatusLabel(
    this.text, {
    super.key,
    this.alignment = Alignment.centerLeft,
    this.tabular = false,
  });

  final String text;

  /// Tabular figures (the battery's percentage, so that the item keeps its width).
  final bool tabular;

  /// Where the text sits in its rounded box (the battery's is right-aligned).
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final style = AmalfiStatusBarStyle.of(context);
    return AmalfiWholePoints(
      step: AmalfiGrid.base,
      heightStep: 1,
      alignment: alignment,
      child: Text(
        text,
        maxLines: 1,
        softWrap: false,
        textAlign: alignment.x > 0 ? TextAlign.right : TextAlign.left,
        style: AmalfiType.bodyEmphasis(color: style.ink).copyWith(
          fontFeatures: tabular ? const [FontFeature.tabularFigures()] : null,
          shadows: style.shadows.isEmpty ? null : style.shadows,
        ),
      ),
    );
  }
}

/// A one-glyph item (kit `Status Bar/Item/Glyph/{Rest,Active}`): 36 × 28, the glyph 20 at x 8,
/// y 4. Bluetooth, Wi-Fi, Sound, Search, Control Center.
class AmalfiStatusGlyphItem extends StatelessWidget {
  const AmalfiStatusGlyphItem({
    super.key,
    this.boxKey,
    required this.symbol,
    required this.label,
    this.value,
    this.active = false,
    this.onPressed,
    this.fallback,
  });

  final Key? boxKey;

  /// The symbol: the state is the glyph (`wifi-slash`, `volume-slash`), never a dimmed ink.
  final String symbol;
  final String label;
  final String? value;
  final bool active;
  final VoidCallback? onPressed;

  /// Drawn when the symbol is not installed.
  final Widget? fallback;

  @override
  Widget build(BuildContext context) => AmalfiStatusItem(
    boxKey: boxKey,
    label: label,
    value: value,
    active: active,
    onPressed: onPressed,
    width: AmalfiStatusBarMetrics.glyphItemWidth,
    child: Center(child: AmalfiStatusGlyph(symbol, fallback: fallback)),
  );
}

/// The battery item (kit `Status Bar/Item/Battery/Rest`): the [percentage] label right-aligned
/// in its box (so that the glyph does not move as the value changes), 4 pt, the battery glyph;
/// without a label, the glyph alone in a glyph item.
class AmalfiStatusBatteryItem extends StatelessWidget {
  const AmalfiStatusBatteryItem({
    super.key,
    this.boxKey,
    required this.level,
    this.charging = false,
    this.percentage,
    required this.label,
    this.value,
    this.active = false,
    this.onPressed,
    this.fallback,
  });

  final Key? boxKey;

  /// The charge, 0–1.
  final double level;
  final bool charging;

  /// The percentage as the locale writes it (`84%`); null: not shown.
  final String? percentage;
  final String label;
  final String? value;
  final bool active;
  final VoidCallback? onPressed;
  final Widget? fallback;

  /// The symbol of a [level] (0–1): `battery`, `battery-50`, `battery-10`, `battery-0`, and
  /// `battery-charging` while charging.
  static String symbolFor(double level, {bool charging = false}) => charging
      ? 'battery-charging'
      : level < 0.05
      ? 'battery-0'
      : level < 0.3
      ? 'battery-10'
      : level < 0.8
      ? 'battery-50'
      : 'battery';

  @override
  Widget build(BuildContext context) {
    final symbol = symbolFor(level, charging: charging);
    final text = percentage;
    if (text == null) {
      return AmalfiStatusGlyphItem(
        boxKey: boxKey,
        symbol: symbol,
        label: label,
        value: value,
        active: active,
        onPressed: onPressed,
        fallback: fallback,
      );
    }
    return AmalfiStatusItem(
      boxKey: boxKey,
      label: label,
      value: value,
      active: active,
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AmalfiStatusLabel(
            text,
            alignment: Alignment.centerRight,
            tabular: true,
          ),
          const SizedBox(width: AmalfiStatusBarMetrics.labelGap),
          AmalfiStatusGlyph(symbol, fallback: fallback),
        ],
      ),
    );
  }
}

/// The input source item (kit `Status Bar/Item/Input Source/Rest`): the source's name, 4 pt,
/// the `keyboard` glyph.
class AmalfiStatusInputSourceItem extends StatelessWidget {
  const AmalfiStatusInputSourceItem({
    super.key,
    this.boxKey,
    required this.source,
    required this.label,
    this.active = false,
    this.onPressed,
  });

  final Key? boxKey;

  /// The source's name (`Italian`).
  final String source;
  final String label;
  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => AmalfiStatusItem(
    boxKey: boxKey,
    label: label,
    value: source,
    active: active,
    onPressed: onPressed,
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AmalfiStatusLabel(source),
        const SizedBox(width: AmalfiStatusBarMetrics.labelGap),
        const AmalfiStatusGlyph('keyboard'),
      ],
    ),
  );
}

/// The clock item (kit `Status Bar/Item/Clock/Rest`): the date and time (`Fri 16 Oct  09:41`,
/// two spaces before the time), centred, 8 pt of padding.
class AmalfiStatusClockItem extends StatelessWidget {
  const AmalfiStatusClockItem({
    super.key,
    this.boxKey,
    required this.text,
    required this.label,
    this.active = false,
    this.onPressed,
  });

  final Key? boxKey;

  /// The date and time as the bar writes them.
  final String text;
  final String label;
  final bool active;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => AmalfiStatusItem(
    boxKey: boxKey,
    label: label,
    value: text,
    active: active,
    onPressed: onPressed,
    child: Center(
      widthFactor: 1,
      child: AmalfiStatusLabel(text, alignment: Alignment.center),
    ),
  );
}
