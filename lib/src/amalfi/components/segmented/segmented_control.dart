// The segmented control (kit `Segments/Control/One|Any <n> Text|Icon/*`): a Glass/Regular
// track holding items ([AmalfiSegmentItem]) 4 inside it; select one (a radio group) or select
// any (each item on or off).
//
// Selection: a `Surface/Control` capsule under the chosen item; with select one it slides to
// the new item with `spring.morph` (`motion.md`, segmented control). Hover: `Line/Separator`
// on the item under the pointer. Disabled: the whole control at 35 %
// (`AmalfiStates.disabledOpacity`), the selection kept visible (user decisions 2026-10-16).
//
// Pressed: the lens (`lens.dart`, the lens rule of [AmalfiLens]); only select-one controls
// grow it (action segments keep a flat pressed highlight). Pointer down on an enabled item
// grows a Glass/Clear capsule
// over it with `spring.snappy`; while the pointer drags, the lens follows it 1:1 along the
// track; on release over the control the item under the lens is chosen, the lens slides onto
// it with `spring.morph` and fades out with `fade.quick`. Releasing outside cancels. The kit
// draws the lens under the items: their labels stay sharp over it.

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/foundation.dart';
import '../../glass.dart';
import '../../theme.dart';
import '../../tokens.g.dart';
import '../tooltips/tooltip_region.dart';
import 'lens.dart';
import 'metrics.dart';
import 'segment.dart';
import 'segment_item.dart';

/// How many items of an [AmalfiSegmentedControl] can be chosen.
enum AmalfiSegmentedSelection {
  /// Exactly one (a radio group): the arrows choose the next or previous item.
  one,

  /// Any number, each item on or off by itself: Space toggles the focused item.
  any,
}

/// A segmented control: items on a Glass/Regular track, of which one
/// ([AmalfiSegmentedSelection.one]) or any number ([AmalfiSegmentedSelection.any]) are chosen
/// (kit `Segments/Control/*`).
///
/// [selected] holds the chosen indices; [onChanged] receives the new set when the user changes
/// it (with select one, always a single index), and null disables the control. Text items
/// share one width: the kit's for [size], or the widest label's plus
/// [AmalfiSegmentMetrics.textItemPadding] on each side. While pressed, a select-one control
/// grows a lens of Glass/Clear over the item and follows the pointer (`materials.md`, lens rule, [AmalfiLens]); it
/// reaches [AmalfiLens.outset] beyond the item on each side and [AmalfiLens.rise] above and
/// below it, outside the control's layout bounds; a select-any control draws the pressed item
/// flat instead (`Line/Border`) and toggles it on release over it. A disabled control ([onChanged] null) is
/// drawn at 35 % ([AmalfiStates.disabledOpacity]) with its selection.
///
/// Keyboard: with select one the arrows choose the next or previous enabled item; with select
/// any they move the focus and Space or Enter toggles the focused item.
class AmalfiSegmentedControl extends StatefulWidget {
  const AmalfiSegmentedControl({
    super.key,
    required this.segments,
    required this.selected,
    this.onChanged,
    this.selection = AmalfiSegmentedSelection.one,
    this.size = AmalfiControlSize.regular,
    this.toolbar = false,
    this.textItemWidth,
    this.opaque = false,
    this.focusNode,
    this.autofocus = false,
  });

  /// The items, leading to trailing.
  final List<AmalfiSegment> segments;

  /// The chosen items.
  final Set<int> selected;

  /// Called with the new selection; null: the control is disabled.
  final ValueChanged<Set<int>>? onChanged;

  /// Select one or select any.
  final AmalfiSegmentedSelection selection;

  final AmalfiControlSize size;

  /// A control of a toolbar: with [size] large it is 36 high, like the other toolbar items
  /// (`Titlebars/Piece/Segmented`), not 32.
  final bool toolbar;

  /// The least width of every text item, in place of the size's kit width: a control widened
  /// to fit its window, such as the six profile sub-tabs of the Terminal settings (80 each,
  /// 488 wide). Items stay wider when a label needs it.
  final double? textItemWidth;

  /// Whether the glass is drawn without blur (see [AmalfiGlass.opaque]).
  final bool opaque;

  final FocusNode? focusNode;
  final bool autofocus;

  @override
  State<AmalfiSegmentedControl> createState() => _AmalfiSegmentedControlState();
}

class _AmalfiSegmentedControlState extends State<AmalfiSegmentedControl>
    with TickerProviderStateMixin {
  /// 0: no lens, 1: the full lens (`spring.snappy`).
  late final AnimationController _presence = AnimationController.unbounded(
    vsync: this,
  )..addListener(_repaint);

  /// The x of the lens centre, in the control.
  late final AnimationController _lensX = AnimationController.unbounded(
    vsync: this,
  )..addListener(_repaint);

  /// The lens's opacity (it fades out once released).
  late final AnimationController _lensOpacity = AnimationController(
    vsync: this,
    duration: AmalfiFades.quick.duration,
  )..addListener(_repaint);

  /// 0 → 1: the selection capsule (select one) from [_thumbFrom] to the chosen item.
  late final AnimationController _thumb = AnimationController.unbounded(
    vsync: this,
    value: 1,
  )..addListener(_repaint);
  Rect? _thumbFrom;
  int? _thumbIndex;

  int? _pointer;

  /// The item pressed in a select-any control (no lens), while the pointer stays on it.
  int? _pressedItem;
  bool _pressedInside = false;
  double _grab = 0;
  int? _hovered;
  bool _focused = false;
  int _focusIndex = 0;

  /// Whether a lens is up (pressed, or settling after a release).
  bool _lensUp = false;

  List<Rect> _items = const [];
  double _width = 0;

  bool get _enabled => widget.onChanged != null;

  bool get _reduced => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  bool _canChoose(int i) =>
      _enabled &&
      i >= 0 &&
      i < widget.segments.length &&
      widget.segments[i].enabled;

  void _repaint() => setState(() {});

  /// Runs [controller] to [target] with [spring], landing exactly on it (a spring stops
  /// within its tolerance, a hair short of the target).
  void _spring(
    AnimationController controller,
    SpringDescription spring,
    double target,
  ) {
    controller
        .animateWith(SpringSimulation(spring, controller.value, target, 0))
        .then((_) {
          if (mounted) controller.value = target;
        });
  }

  @override
  void initState() {
    super.initState();
    _thumbIndex = _single(widget.selected);
    if (_thumbIndex case final i?) _focusIndex = i;
  }

  int? _single(Set<int> selected) =>
      widget.selection == AmalfiSegmentedSelection.one && selected.isNotEmpty
      ? selected.first
      : null;

  @override
  void didUpdateWidget(AmalfiSegmentedControl old) {
    super.didUpdateWidget(old);
    final n = widget.segments.length;
    if (_focusIndex >= n) _focusIndex = 0;
    if (_hovered case final h? when h >= n) _hovered = null;
    if (_pressedItem case final p?
        when p >= n || widget.selection != AmalfiSegmentedSelection.any) {
      _pressedItem = null;
      _pointer = null;
    }
    final next = _single(widget.selected);
    if (next != _thumbIndex) {
      final from = _thumbRect();
      _thumbIndex = next;
      if (next != null && next < n) _focusIndex = next;
      if (from != null && next != null && !_reduced) {
        _thumbFrom = from;
        _thumb.value = 0;
        _spring(_thumb, AmalfiSprings.morph, 1);
      } else {
        _thumbFrom = null;
        _thumb.value = 1;
      }
    }
  }

  @override
  void dispose() {
    _presence.dispose();
    _lensX.dispose();
    _lensOpacity.dispose();
    _thumb.dispose();
    super.dispose();
  }

  /// The selection capsule of select one, as drawn now; null: none.
  Rect? _thumbRect() {
    final i = _thumbIndex;
    if (i == null || i >= _items.length) return null;
    final to = _items[i];
    final from = _thumbFrom;
    if (from == null) return to;
    return Rect.lerp(from, to, _thumb.value) ?? to;
  }

  int? _indexAtX(double x) {
    if (_items.isEmpty) return null;
    var best = 0;
    var distance = double.infinity;
    for (var i = 0; i < _items.length; i++) {
      final r = _items[i];
      if (x >= r.left && x < r.right) return i;
      final d = math.min((x - r.left).abs(), (x - r.right).abs());
      if (d < distance) {
        distance = d;
        best = i;
      }
    }
    return best;
  }

  int? _indexAt(Offset local) {
    final h = AmalfiSegmentSizeMetrics.of(
      widget.size,
      toolbar: widget.toolbar,
    ).height;
    if (local.dy < 0 || local.dy > h || _items.isEmpty) return null;
    if (local.dx < 0 || local.dx > _width) return null;
    return _indexAtX(local.dx);
  }

  void _choose(int i) {
    if (!_canChoose(i)) return;
    final Set<int> next;
    switch (widget.selection) {
      case AmalfiSegmentedSelection.one:
        if (widget.selected.length == 1 && widget.selected.contains(i)) return;
        next = {i};
      case AmalfiSegmentedSelection.any:
        next = {...widget.selected};
        if (!next.remove(i)) next.add(i);
    }
    widget.onChanged?.call(next);
  }

  // Pointer.

  void _down(PointerDownEvent e) {
    if (!mounted) return;
    if (_pointer != null || e.buttons & kPrimaryButton == 0) return;
    final i = _indexAt(e.localPosition);
    if (i == null || !_canChoose(i)) return;
    _pointer = e.pointer;
    _focusIndex = i;
    if (widget.selection == AmalfiSegmentedSelection.any) {
      // Select any has no lens: a flat pressed item, toggled on release over it.
      setState(() {
        _pressedItem = i;
        _pressedInside = true;
      });
      return;
    }
    final centre = _items[i].center.dx;
    _grab = centre - e.localPosition.dx;
    _lensX.stop();
    _lensX.value = centre;
    _lensOpacity.stop();
    _lensOpacity.value = 1;
    if (!_lensUp) _presence.value = 0;
    _lensUp = true;
    if (_reduced) {
      _presence.value = 1;
    } else {
      _spring(_presence, AmalfiSprings.snappy, 1);
    }
    setState(() {});
  }

  /// The x range the lens centre can travel: the first to the last item's centre.
  double _clampX(double x) {
    if (_items.isEmpty) return x;
    final lo = _items.first.center.dx, hi = _items.last.center.dx;
    return x.clamp(math.min(lo, hi), math.max(lo, hi));
  }

  void _move(PointerMoveEvent e) {
    if (!mounted) return;
    if (e.pointer != _pointer) return;
    if (_pressedItem case final p?) {
      final inside = _indexAt(e.localPosition) == p;
      if (inside != _pressedInside) setState(() => _pressedInside = inside);
      return;
    }
    _lensX.value = _clampX(e.localPosition.dx + _grab);
  }

  void _up(PointerUpEvent e) {
    if (!mounted) return;
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (_pressedItem case final p?) {
      setState(() => _pressedItem = null);
      if (_indexAt(e.localPosition) == p) _choose(p);
      return;
    }
    final inside = _indexAt(e.localPosition) != null;
    final target = inside ? _indexAtX(_lensX.value) : null;
    if (target != null && _canChoose(target)) {
      _focusIndex = target;
      _choose(target);
      _settle(target);
    } else {
      _settle(null);
    }
  }

  void _cancel(PointerCancelEvent e) {
    if (!mounted) return;
    if (e.pointer != _pointer) return;
    _pointer = null;
    if (_pressedItem != null) {
      setState(() => _pressedItem = null);
      return;
    }
    _settle(null);
  }

  /// Slides the lens onto [target] (if any) and fades it out.
  void _settle(int? target) {
    if (_reduced) {
      _hideLens();
      return;
    }
    if (target != null && target < _items.length) {
      _spring(_lensX, AmalfiSprings.morph, _items[target].center.dx);
    }
    _lensOpacity
        .animateTo(
          0,
          duration: AmalfiFades.quick.duration,
          curve: AmalfiFades.quick.curve,
        )
        .whenCompleteOrCancel(() {
          if (mounted && _pointer == null && _lensOpacity.value == 0) {
            _hideLens();
          }
        });
  }

  void _hideLens() {
    _presence.stop();
    _lensX.stop();
    _presence.value = 0;
    _lensOpacity.value = 0;
    _lensUp = false;
    setState(() {});
  }

  void _hover(PointerHoverEvent e) {
    if (!mounted) return;
    final i = _indexAt(e.localPosition);
    final h = i != null && _canChoose(i) ? i : null;
    if (h != _hovered) setState(() => _hovered = h);
  }

  void _exit(PointerExitEvent e) {
    if (!mounted) return;
    if (_hovered != null) setState(() => _hovered = null);
  }

  // Keyboard.

  void _step(int step) {
    final n = widget.segments.length;
    for (var i = _focusIndex + step; i >= 0 && i < n; i += step) {
      if (_canChoose(i)) {
        setState(() => _focusIndex = i);
        if (widget.selection == AmalfiSegmentedSelection.one) _choose(i);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = AmalfiTheme.of(context);
    final m = AmalfiSegmentSizeMetrics.of(widget.size, toolbar: widget.toolbar);
    final segments = widget.segments;
    final n = segments.length;
    final h = m.height;
    const pad = AmalfiSegmentMetrics.trackPadding;
    final rtl = Directionality.of(context) == TextDirection.rtl;

    // Text items share the widest width.
    var textWidth = widget.textItemWidth ?? m.textItemWidth;
    for (final s in segments) {
      if (!s.isIcon) {
        final w = AmalfiSegmentItem.preferredWidth(
          context,
          s,
          widget.size,
          toolbar: widget.toolbar,
        );
        if (w > textWidth) textWidth = w;
      }
    }
    final items = <Rect>[];
    var x = pad;
    for (final s in segments) {
      final w = s.isIcon ? m.iconItemWidth : textWidth;
      items.add(Rect.fromLTWH(x, pad, w, m.itemHeight));
      x += w;
    }
    final width = x + pad;
    if (rtl) {
      for (var i = 0; i < n; i++) {
        final r = items[i];
        items[i] = Rect.fromLTWH(width - r.right, r.top, r.width, r.height);
      }
    }
    _items = items;
    _width = width;

    final one = widget.selection == AmalfiSegmentedSelection.one;
    final layers = <Widget>[
      Positioned.fill(
        child: AmalfiGlass(
          key: const ValueKey('amalfi-segmented-track'),
          material: AmalfiMaterials.regular,
          radius: h / 2,
          opaque: widget.opaque,
          kind: AmalfiGlassKind.control,
          child: const SizedBox.expand(),
        ),
      ),
    ];

    // The sliding selection of select one, under the lens.
    final thumb = one ? _thumbRect() : null;
    if (thumb != null) {
      layers.add(
        Positioned.fromRect(
          rect: thumb,
          child: DecoratedBox(
            key: const ValueKey('amalfi-segmented-thumb'),
            decoration: AmalfiSegmentItem.selectionDecoration(
              theme,
              m.itemHeight,
            ),
          ),
        ),
      );
    }

    // The lens.
    final presence = _presence.value;
    final lensOn = _lensUp && n > 0 && _lensOpacity.value > 0;
    final lensCentre = _lensX.value;
    if (lensOn) {
      final under = _indexAtX(lensCentre) ?? 0;
      final rect = amalfiSegmentLensRect(
        item: items[under],
        centreX: lensCentre,
        presence: presence,
      );
      layers.add(
        Positioned.fromRect(
          rect: rect,
          child: AmalfiSegmentLens(
            opacity: _lensOpacity.value,
            opaque: widget.opaque,
          ),
        ),
      );
    }

    // The items.
    for (var i = 0; i < n; i++) {
      final s = segments[i];
      final chosen = widget.selected.contains(i);
      final magnification = lensOn
          ? amalfiSegmentLensMagnification(
              itemCentreX: items[i].center.dx,
              itemWidth: items[i].width,
              lensCentreX: lensCentre,
              presence: presence * _lensOpacity.value,
            )
          : 1.0;
      Widget item = AmalfiSegmentItem(
        key: ValueKey('amalfi-segmented-item-$i'),
        // A disabled control dims as a whole: its items are not dimmed again.
        segment: _enabled ? s : _undimmed(s),
        size: widget.size,
        toolbar: widget.toolbar,
        selected: chosen,
        hovered: _hovered == i && _pointer == null && !chosen,
        pressed: _pressedItem == i && _pressedInside,
        showSelection: !one,
        width: items[i].width,
        magnification: magnification,
      );
      if (s.tooltip case final tip?) {
        item = AmalfiTooltipRegion(message: tip, child: item);
      }
      layers.add(
        Positioned.fromRect(
          rect: items[i],
          child: Semantics(
            button: true,
            enabled: _canChoose(i),
            selected: chosen,
            inMutuallyExclusiveGroup: one ? true : null,
            label: s.semanticsLabel,
            onTap: _canChoose(i) ? () => _choose(i) : null,
            child: ExcludeSemantics(child: item),
          ),
        ),
      );
    }

    if (_focused && n > 0 && _focusIndex < n) {
      layers.add(
        Positioned.fromRect(
          rect: items[_focusIndex],
          child: AmalfiFocusHalo(radius: m.itemHeight / 2),
        ),
      );
    }

    return FocusableActionDetector(
      enabled: _enabled,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      onShowFocusHighlight: (on) {
        if (on != _focused) setState(() => _focused = on);
      },
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.arrowLeft): _StepIntent(-1),
        SingleActivator(LogicalKeyboardKey.arrowRight): _StepIntent(1),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      actions: {
        _StepIntent: CallbackAction<_StepIntent>(
          onInvoke: (intent) {
            _step(rtl ? -intent.step : intent.step);
            return null;
          },
        ),
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _choose(_focusIndex);
            return null;
          },
        ),
      },
      child: MouseRegion(
        onHover: _hover,
        onExit: _exit,
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: _cancel,
          child: SizedBox(
            width: width,
            height: h,
            child: _enabled
                ? Stack(clipBehavior: Clip.none, children: layers)
                : Opacity(
                    opacity: AmalfiStates.disabledOpacity,
                    child: Stack(clipBehavior: Clip.none, children: layers),
                  ),
          ),
        ),
      ),
    );
  }
}

/// [s] drawn as enabled (inside a disabled control, which dims as a whole).
AmalfiSegment _undimmed(AmalfiSegment s) {
  if (s.enabled) return s;
  if (s.icon case final icon?) {
    return AmalfiSegment.icon(
      icon,
      semanticLabel: s.semanticsLabel,
      tooltip: s.tooltip,
    );
  }
  return AmalfiSegment.text(
    s.label ?? '',
    semanticLabel: s.semanticLabel,
    tooltip: s.tooltip,
  );
}

/// Chooses (select one) or focuses (select any) the next ([step] 1) or previous (-1) item.
class _StepIntent extends Intent {
  const _StepIntent(this.step);

  final int step;
}
