// Color well and color picker.
//
// Measured (CT-DP-03, INV-B gallery): the well is a 44 × 28 capsule with the color, the default
// style with a light ring. Provisional: the swatch inset 3 with a hairline; pressed and "picking"
// states (accent border); the picker panel (measured about 264 × 450 with a mode toolbar, a
// wheel, brightness and opacity sliders and swatches, CT-DP-04; silica_ui draws a 160 pt wheel,
// the sliders and a row of swatches in the menu panel color).

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'input_style.dart';
import 'slider.dart';

/// The color well measurements: a 44 × 28 capsule (CT-DP-03); the inset provisional.
abstract final class ColorWellMetrics {
  static const Size size = Size(44, 28);
  static const double radius = 14;
  static const double inset = 3;
}

/// A color well: tap to pick the color in a [SilicaColorPicker] shown below it.
class SilicaColorWell extends StatefulWidget {
  const SilicaColorWell({
    super.key,
    required this.color,
    required this.onChanged,
    this.labels = const ColorPickerLabels(),
    this.showsAlpha = true,
    this.enabled = true,
    this.focusNode,
    this.semanticLabel,
  });

  final Color color;
  final ValueChanged<Color>? onChanged;
  final ColorPickerLabels labels;
  final bool showsAlpha;
  final bool enabled;
  final FocusNode? focusNode;
  final String? semanticLabel;

  @override
  State<SilicaColorWell> createState() => _SilicaColorWellState();
}

class _SilicaColorWellState extends State<SilicaColorWell> {
  bool _pressed = false;
  bool _focused = false;
  OverlayEntry? _panel;
  final ValueNotifier<Color> _current = ValueNotifier(const Color(0x00000000));

  bool get _enabled => widget.enabled && widget.onChanged != null;

  @override
  void didUpdateWidget(SilicaColorWell old) {
    super.didUpdateWidget(old);
    _current.value = widget.color;
  }

  @override
  void dispose() {
    _panel?.remove();
    _current.dispose();
    super.dispose();
  }

  void _toggle() {
    if (_panel != null) {
      _close();
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    final overlay = Overlay.of(context);
    final overlayBox = overlay.context.findRenderObject() as RenderBox?;
    if (box == null || overlayBox == null) return;
    final at = overlayBox.globalToLocal(
      box.localToGlobal(Offset(0, box.size.height + 4)),
    );
    _current.value = widget.color;
    _panel = OverlayEntry(
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _close,
            ),
          ),
          Positioned(
            left: at.dx,
            top: at.dy,
            child: ValueListenableBuilder<Color>(
              valueListenable: _current,
              builder: (context, color, _) => SilicaColorPicker(
                color: color,
                labels: widget.labels,
                showsAlpha: widget.showsAlpha,
                onChanged: (c) {
                  _current.value = c;
                  widget.onChanged?.call(c);
                },
              ),
            ),
          ),
        ],
      ),
    );
    overlay.insert(_panel!);
    setState(() {});
  }

  void _close() {
    _panel?.remove();
    _panel = null;
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = InputColors.of(context);
    final active = WindowActiveScope.of(context);
    final picking = _panel != null;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      value: _hex(widget.color),
      enabled: _enabled,
      onTap: _enabled ? _toggle : null,
      child: Focus(
        focusNode: widget.focusNode,
        canRequestFocus: _enabled,
        onFocusChange: (f) => setState(() => _focused = f),
        onKeyEvent: (node, event) {
          if (_enabled &&
              event is KeyDownEvent &&
              (event.logicalKey == LogicalKeyboardKey.space ||
                  event.logicalKey == LogicalKeyboardKey.enter)) {
            _toggle();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: GestureDetector(
          onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: _enabled
              ? (_) {
                  setState(() => _pressed = false);
                  _toggle();
                }
              : null,
          onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
          child: FocusRing(
            visible: _focused,
            radius: ColorWellMetrics.radius,
            width: InputMetrics.controlRing,
            inset: InputMetrics.controlRingInset,
            color: colors.focusRingControl,
            child: Opacity(
              opacity: widget.enabled ? 1 : 0.5,
              child: Container(
                key: const ValueKey('colorWell'),
                width: ColorWellMetrics.size.width,
                height: ColorWellMetrics.size.height,
                padding: const EdgeInsets.all(ColorWellMetrics.inset),
                decoration: BoxDecoration(
                  color: _pressed ? colors.bezelPressed : colors.bezel,
                  borderRadius: BorderRadius.circular(ColorWellMetrics.radius),
                  border: Border.all(
                    color: picking
                        ? colors.accentFor(active: active)
                        : colors.bezelBorder,
                    width: picking ? 2 : 0.5,
                  ),
                ),
                child: CustomPaint(
                  painter: SwatchPainter(widget.color, colors.bezelBorder),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _hex(Color c) {
  String two(double v) =>
      (v * 255).round().clamp(0, 255).toRadixString(16).padLeft(2, '0');
  return '#${two(c.r)}${two(c.g)}${two(c.b)}'.toUpperCase();
}

/// A swatch: the color over a checkerboard where it is transparent, with a hairline.
class SwatchPainter extends CustomPainter {
  SwatchPainter(this.color, this.border);
  final Color color;
  final Color border;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(2));
    canvas.save();
    canvas.clipRRect(rrect);
    if (color.a < 1) {
      const s = 4.0;
      final light = Paint()..color = const Color(0xFFFFFFFF);
      final dark = Paint()..color = const Color(0xFFCCCCCC);
      for (var y = 0.0; y < size.height; y += s) {
        for (var x = 0.0; x < size.width; x += s) {
          final odd = ((x / s).floor() + (y / s).floor()).isOdd;
          canvas.drawRect(Rect.fromLTWH(x, y, s, s), odd ? dark : light);
        }
      }
    }
    canvas.drawRect(rect, Paint()..color = color);
    canvas.restore();
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }

  @override
  bool shouldRepaint(SwatchPainter old) =>
      old.color != color || old.border != border;
}

/// The accessibility labels of the color picker.
@immutable
class ColorPickerLabels {
  const ColorPickerLabels({this.wheel, this.brightness, this.opacity});

  final String? wheel;
  final String? brightness;
  final String? opacity;
}

/// The color picker panel: a hue and saturation wheel, brightness and opacity, swatches.
class SilicaColorPicker extends StatelessWidget {
  const SilicaColorPicker({
    super.key,
    required this.color,
    required this.onChanged,
    this.labels = const ColorPickerLabels(),
    this.showsAlpha = true,
    this.swatches = defaultSwatches,
    this.wheel = 160,
  });

  final Color color;
  final ValueChanged<Color> onChanged;
  final ColorPickerLabels labels;
  final bool showsAlpha;
  final List<Color> swatches;
  final double wheel;

  /// The label dot colors (mustache.md › MU-62, light) and black, gray, white.
  static const List<Color> defaultSwatches = [
    Color(0xFFFF6663),
    Color(0xFFFFA356),
    Color(0xFFFFD54C),
    Color(0xFF65D27B),
    Color(0xFF49A0FF),
    Color(0xFFD859E7),
    Color(0xFFA5A5A9),
    Color(0xFF000000),
    Color(0xFFFFFFFF),
  ];

  @override
  Widget build(BuildContext context) {
    final colors = InputColors.of(context);
    final hsv = HSVColor.fromColor(color);
    void setHsv(HSVColor next) => onChanged(next.toColor());
    return Container(
      width: wheel + 24,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.panel,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.fieldBorder),
        boxShadow: [
          BoxShadow(
            color: colors.knobShadow,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            label: labels.wheel,
            value: _hex(color),
            child: GestureDetector(
              key: const ValueKey('colorWheel'),
              onPanDown: (d) => setHsv(_wheelAt(d.localPosition, hsv)),
              onPanUpdate: (d) => setHsv(_wheelAt(d.localPosition, hsv)),
              child: CustomPaint(
                size: Size.square(wheel),
                painter: ColorWheelPainter(hsv),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SilicaSlider(
            key: const ValueKey('colorBrightness'),
            value: hsv.value,
            width: wheel,
            size: SliderSize.small,
            semanticLabel: labels.brightness,
            onChanged: (v) => setHsv(hsv.withValue(v)),
          ),
          if (showsAlpha) ...[
            const SizedBox(height: 8),
            SilicaSlider(
              key: const ValueKey('colorOpacity'),
              value: hsv.alpha,
              width: wheel,
              size: SliderSize.small,
              semanticLabel: labels.opacity,
              onChanged: (v) => setHsv(hsv.withAlpha(v)),
            ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (final s in swatches)
                GestureDetector(
                  onTap: () => onChanged(s),
                  child: Semantics(
                    button: true,
                    label: _hex(s),
                    selected: s.toARGB32() == color.toARGB32(),
                    child: SizedBox(
                      width: 14,
                      height: 14,
                      child: CustomPaint(
                        painter: SwatchPainter(s, colors.bezelBorder),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  HSVColor _wheelAt(Offset p, HSVColor hsv) {
    final r = wheel / 2;
    final d = p - Offset(r, r);
    var hue = math.atan2(d.dy, d.dx) * 180 / math.pi;
    if (hue < 0) hue += 360;
    final sat = (d.distance / r).clamp(0.0, 1.0);
    return HSVColor.fromAHSV(
      hsv.alpha,
      hue,
      sat,
      hsv.value == 0 ? 1 : hsv.value,
    );
  }
}

/// Paints the hue (angle) and saturation (radius) wheel at the color's brightness, with the
/// marker at the color.
class ColorWheelPainter extends CustomPainter {
  ColorWheelPainter(this.hsv);
  final HSVColor hsv;

  @override
  void paint(Canvas canvas, Size size) {
    final r = size.shortestSide / 2;
    final c = Offset(r, r);
    final rect = Rect.fromCircle(center: c, radius: r);
    final hues = [
      for (var i = 0; i <= 6; i++)
        HSVColor.fromAHSV(1, (i * 60) % 360, 1, hsv.value).toColor(),
    ];
    canvas.drawCircle(
      c,
      r,
      Paint()..shader = SweepGradient(colors: hues).createShader(rect),
    );
    final white = HSVColor.fromAHSV(1, 0, 0, hsv.value).toColor();
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          colors: [white, white.withValues(alpha: 0)],
        ).createShader(rect),
    );
    final a = hsv.hue * math.pi / 180;
    final at = c + Offset(math.cos(a), math.sin(a)) * hsv.saturation * r;
    canvas.drawCircle(
      at,
      5,
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawCircle(
      at,
      6,
      Paint()
        ..color = const Color(0x66000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.5,
    );
  }

  @override
  bool shouldRepaint(ColorWheelPainter old) => old.hsv != hsv;
}
