// The Segmented Control, Icon + Label (kit `Segments/Icon + Label Item/*`,
// `Segments/Control/One <N> Icon + Label/*`; docs/design/amalfi/components.md): the segmented
// control for switching the panes of a window, settings windows always use it.
//
// A Glass/Regular capsule track (52 tall, padding 4) of N equal panes, each a 20 pt glyph over a
// Caption label, 44 tall. Rest: no fill. Selected: `Surface/Control` with a 1 pt `Line/Border`
// inside and the level 1 shadow, glyph in `Accent/Amalfi`. Hover: `Line/Separator`. Pressed:
// `Line/Border`. Disabled: the pane at 35 %. Hover, press and selection change in one frame.

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/foundation.dart';
import '../../glass.dart';
import '../../smooth_border.dart';
import '../../theme.dart';
import '../../tokens.g.dart';
import '../../whole_points.dart';
import 'segment.dart';

/// One pane of [AmalfiIconLabelSegmentedControl].
@immutable
class AmalfiIconLabelSegment {
  const AmalfiIconLabelSegment({
    required this.label,
    required this.symbol,
    this.enabled = true,
  });

  /// The pane's name, under the glyph (never truncated or wrapped).
  final String label;

  /// The Icon Kit symbol name of the glyph (`gear`).
  final String symbol;

  final bool enabled;
}

/// The measures of the Segmented Control, Icon + Label bar.
abstract final class AmalfiIconLabelMetrics {
  static const double barHeight = 52;
  static const double padding = 4;
  static const double paneHeight = 44;
  static const double minPaneWidth = 72;
  static const double glyph = 20;
  static const double labelTop = 26;

  /// The width of every pane for [labels]: the longest label at Caption plus 24, rounded up to
  /// a multiple of 8, at least [minPaneWidth].
  static double paneWidth(BuildContext context, Iterable<String> labels) {
    var widest = 0.0;
    for (final l in labels) {
      final w = amalfiSegmentLabelWidth(context, l, AmalfiType.caption());
      if (w > widest) widest = w;
    }
    final w = ceilToWholePoints(widest + 24, 8);
    return w < minPaneWidth ? minPaneWidth : w;
  }

  /// The bar width for [count] panes of [paneWidth].
  static double barWidth(int count, double paneWidth) =>
      count * paneWidth + 2 * padding;
}

/// The Segmented Control, Icon + Label bar: 2 to 7 panes, one chosen ([selected]); [onChanged] receives the new
/// index. Null [onChanged] disables the bar.
class AmalfiIconLabelSegmentedControl extends StatefulWidget {
  const AmalfiIconLabelSegmentedControl({
    super.key,
    required this.tabs,
    required this.selected,
    this.onChanged,
    this.paneWidth,
    this.opaque = false,
  });

  /// The width of every pane; null: [AmalfiIconLabelMetrics.paneWidth] of the labels.
  final double? paneWidth;

  final List<AmalfiIconLabelSegment> tabs;
  final int selected;
  final ValueChanged<int>? onChanged;

  /// Whether the glass is drawn without blur (see [AmalfiGlass.opaque]).
  final bool opaque;

  @override
  State<AmalfiIconLabelSegmentedControl> createState() =>
      _AmalfiIconLabelSegmentedControlState();
}

class _AmalfiIconLabelSegmentedControlState
    extends State<AmalfiIconLabelSegmentedControl> {
  int? _hovered;
  int? _pressed;
  bool _focused = false;

  bool _can(int i) =>
      widget.onChanged != null &&
      i >= 0 &&
      i < widget.tabs.length &&
      widget.tabs[i].enabled;

  int _indexAt(double x, double paneWidth) {
    final i = ((x - AmalfiIconLabelMetrics.padding) / paneWidth).floor();
    return i.clamp(0, widget.tabs.length - 1);
  }

  void _step(int step) {
    for (
      var i = widget.selected + step;
      i >= 0 && i < widget.tabs.length;
      i += step
    ) {
      if (_can(i)) {
        widget.onChanged?.call(i);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.tabs;
    if (tabs.isEmpty) return const SizedBox.shrink();
    final n = tabs.length;
    final pw =
        widget.paneWidth ??
        AmalfiIconLabelMetrics.paneWidth(context, tabs.map((t) => t.label));
    final width = AmalfiIconLabelMetrics.barWidth(n, pw);
    const pad = AmalfiIconLabelMetrics.padding;
    const ph = AmalfiIconLabelMetrics.paneHeight;
    final enabled = widget.onChanged != null;
    final selected = widget.selected.clamp(0, n - 1);

    final layers = <Widget>[
      Positioned.fill(
        child: AmalfiGlass(
          key: const ValueKey('amalfi-icon-label-track'),
          material: AmalfiMaterials.regular,
          radius: AmalfiIconLabelMetrics.barHeight / 2,
          opaque: widget.opaque,
          kind: AmalfiGlassKind.control,
          child: const SizedBox.expand(),
        ),
      ),
    ];
    for (var i = 0; i < n; i++) {
      final t = tabs[i];
      final chosen = i == selected;
      final down = _pressed == i && t.enabled && enabled;
      final hot = _hovered == i && t.enabled && enabled;
      final pane = AmalfiIconLabelItem(
        key: ValueKey('amalfi-icon-label-$i'),
        tab: t,
        index: i,
        width: pw,
        selected: chosen,
        hovered: hot,
        pressed: down,
      );
      layers.add(
        Positioned(
          left: pad + i * pw,
          top: pad,
          child: Semantics(
            button: true,
            enabled: _can(i),
            selected: chosen,
            inMutuallyExclusiveGroup: true,
            label: t.label,
            onTap: _can(i) ? () => widget.onChanged?.call(i) : null,
            child: ExcludeSemantics(child: pane),
          ),
        ),
      );
    }
    if (_focused && enabled) {
      layers.add(
        Positioned(
          left: pad + selected * pw,
          top: pad,
          width: pw,
          height: ph,
          child: AmalfiFocusHalo(radius: ph / 2),
        ),
      );
    }

    return FocusableActionDetector(
      enabled: enabled,
      onShowFocusHighlight: (on) {
        if (on != _focused) setState(() => _focused = on);
      },
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowLeft): _StepIntent(-1),
        SingleActivator(LogicalKeyboardKey.arrowRight): _StepIntent(1),
      },
      actions: {
        _StepIntent: CallbackAction<_StepIntent>(
          onInvoke: (i) {
            final rtl = Directionality.of(context) == TextDirection.rtl;
            _step(rtl ? -i.step : i.step);
            return null;
          },
        ),
      },
      child: MouseRegion(
        onHover: (e) {
          final i = _indexAt(e.localPosition.dx, pw);
          final h = _can(i) ? i : null;
          if (h != _hovered) setState(() => _hovered = h);
        },
        onExit: (_) {
          if (_hovered != null) setState(() => _hovered = null);
        },
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: (e) {
            if (e.buttons & kPrimaryButton == 0) return;
            final i = _indexAt(e.localPosition.dx, pw);
            if (_can(i)) setState(() => _pressed = i);
          },
          onPointerUp: (e) {
            final p = _pressed;
            if (p == null) return;
            setState(() => _pressed = null);
            final inside =
                e.localPosition.dy >= 0 &&
                e.localPosition.dy <= AmalfiIconLabelMetrics.barHeight &&
                _indexAt(e.localPosition.dx, pw) == p &&
                e.localPosition.dx >= 0 &&
                e.localPosition.dx <= width;
            if (inside && p != widget.selected) widget.onChanged?.call(p);
          },
          onPointerCancel: (_) {
            if (_pressed != null) setState(() => _pressed = null);
          },
          child: SizedBox(
            width: width,
            height: AmalfiIconLabelMetrics.barHeight,
            child: Stack(clipBehavior: Clip.none, children: layers),
          ),
        ),
      ),
    );
  }
}

/// One pane of the bar drawn in a given state (kit `Segmented Control, Icon + Label/Item/*`). The bar lays its
/// panes out and drives their state; [index] only names the pane's parts for tests.
class AmalfiIconLabelItem extends StatelessWidget {
  const AmalfiIconLabelItem({
    super.key,
    required this.tab,
    required this.width,
    this.index = 0,
    this.selected = false,
    this.hovered = false,
    this.pressed = false,
  });

  final AmalfiIconLabelSegment tab;
  final double width;
  final int index;
  final bool selected;
  final bool hovered;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    final theme = AmalfiTheme.of(context);
    final colors = theme.colors;
    const ph = AmalfiIconLabelMetrics.paneHeight;
    final i = index;
    final pw = width;
    final t = tab;
    final chosen = selected;
    final on = t.enabled;
    final down = pressed && on;
    final hot = hovered && on;
    final decoration = chosen
        ? AmalfiShapeDecoration(
            color: colors.surfaceControl,
            shape: AmalfiSmoothBorder(
              radius: ph / 2,
              side: BorderSide(
                color: colors.lineBorder,
                strokeAlign: BorderSide.strokeAlignInside,
              ),
            ),
            shadows: theme.shadows.level1,
          )
        : AmalfiShapeDecoration(
            color: down
                ? colors.lineBorder
                : hot
                ? colors.lineSeparator
                : null,
            shape: AmalfiSmoothBorder(radius: ph / 2),
          );
    Widget pane = SizedBox(
      width: pw,
      height: ph,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: DecoratedBox(
              key: ValueKey('amalfi-icon-label-background-$i'),
              decoration: decoration,
            ),
          ),
          Positioned(
            left: (pw - AmalfiIconLabelMetrics.glyph) / 2,
            top: 4,
            child: SizedBox(
              key: ValueKey('amalfi-icon-label-glyph-$i'),
              width: AmalfiIconLabelMetrics.glyph,
              // The kit's glyph box is the symbol font's line height, 21.
              height: AmalfiIconLabelMetrics.glyph + 1,
              child: AmalfiSymbol(
                t.symbol,
                size: AmalfiIconLabelMetrics.glyph,
                color: chosen ? colors.accentAmalfi : colors.textPrimary,
              ),
            ),
          ),
          Positioned(
            left: 0,
            top: AmalfiIconLabelMetrics.labelTop,
            width: pw,
            height: 14,
            child: Text(
              t.label,
              key: ValueKey('amalfi-icon-label-label-$i'),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.visible,
              textAlign: TextAlign.center,
              style: AmalfiType.caption(color: colors.textPrimary),
            ),
          ),
        ],
      ),
    );
    if (!on) {
      pane = Opacity(opacity: AmalfiStates.disabledOpacity, child: pane);
    }
    return pane;
  }
}

class _StepIntent extends Intent {
  const _StepIntent(this.step);
  final int step;
}
