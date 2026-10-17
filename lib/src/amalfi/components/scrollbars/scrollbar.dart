// The scroll bar of a scroll view (kit `Scrollbars/Overlay|Legacy`), with its behaviour:
//
// - Overlay: hidden at rest, and always when the content fits (nothing to scroll: no thumb, no
//   track, not even under the pointer); scrolling shows the thin bar, which fades out a moment after the
//   scrolling stops; the pointer over the bar's strip shows it expanded (track and wider
//   thumb), and keeps it while dragging. The reference does not measure the timing: showing
//   uses `fade.quick`, hiding `fade.standard` after [AmalfiScrollbar.hideDelay] (assumption).
// - Legacy: always there beside the content; no thumb when everything is visible.
//
// In both, dragging the thumb scrolls 1:1 and a click on the track pages toward it.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../../../system_look.dart';
import '../../tokens.g.dart';
import 'scrollbar_track.dart';

/// Adds an Amalfi scroll bar to the scroll view [child] (along [axis], on its end edge: the
/// right in left-to-right text, or the bottom).
///
/// The bar follows the scroll notifications of depth [notificationDepth] for [axis] (0: the
/// scroll view right under it). [padding] keeps the bar's ends clear along its axis (top and
/// bottom for a vertical bar), for instance for the other bar of a two-way area.
class AmalfiScrollbar extends StatefulWidget {
  const AmalfiScrollbar({
    super.key,
    required this.child,
    this.axis = Axis.vertical,
    this.style,
    this.notificationDepth = 0,
    this.padding = EdgeInsets.zero,
    this.statesController,
    this.enabled = true,
  });

  final Widget child;
  final Axis axis;

  /// Null: the system look's (Appearance › show scroll bars: always is the legacy bar, the
  /// others the overlay one).
  final AmalfiScrollbarStyle? style;
  final int notificationDepth;
  final EdgeInsets padding;

  /// The interaction states of the bar: [WidgetState.hovered] shows it expanded (overlay) or
  /// highlighted (legacy), [WidgetState.dragged] dragged; set states in it to show them
  /// without a pointer (an overlay bar with states stays visible). Null: its own.
  final WidgetStatesController? statesController;

  /// Whether the bar responds to the pointer; disabled, it is dimmed whole (legacy: still
  /// shown beside the content) and does not scroll.
  final bool enabled;

  /// How long an overlay bar stays after the scrolling stops (assumption: unmeasured).
  static const Duration hideDelay = Duration(milliseconds: 1000);

  @override
  State<AmalfiScrollbar> createState() => _AmalfiScrollbarState();
}

class _AmalfiScrollbarState extends State<AmalfiScrollbar>
    with TickerProviderStateMixin {
  WidgetStatesController? _ownStates;
  WidgetStatesController get _states =>
      widget.statesController ?? (_ownStates ??= WidgetStatesController());

  late final AnimationController _shown = AnimationController(
    vsync: this,
    duration: AmalfiFades.quick.duration,
    reverseDuration: AmalfiFades.standard.duration,
  )..addListener(_repaint);
  late final AnimationController _expanded = AnimationController(
    vsync: this,
    duration: AmalfiFades.quick.duration,
  )..addListener(_repaint);

  ScrollMetrics? _metrics;
  ScrollPosition? _position;
  Timer? _hide;
  double? _dragFrom;
  double _dragPixels = 0;

  AmalfiScrollbarStyle _style = AmalfiScrollbarStyle.overlay;
  SystemScrollClick _click = SystemScrollClick.page;

  bool get _overlay => _style == AmalfiScrollbarStyle.overlay;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final look = SystemLookScope.of(context);
    _click = look.scrollClick;
    _style =
        widget.style ??
        (look.scrollBars == SystemScrollBars.always
            ? AmalfiScrollbarStyle.legacy
            : AmalfiScrollbarStyle.overlay);
  }

  void _repaint() => _update(() {});

  /// setState that is safe during layout: a scroll view that changes its extents tells its
  /// bar while it lays out (it may start a ballistic scroll), and the bar rebuilds right after
  /// the frame instead.
  void _update(VoidCallback change) {
    if (!mounted) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      change();
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(change);
    }
  }

  @override
  void initState() {
    super.initState();
    _states.addListener(_statesChanged);
    if (_held) {
      // Shown in its states from the first frame.
      _expanded.value = 1;
      _shown.value = 1;
    }
  }

  @override
  void didUpdateWidget(AmalfiScrollbar old) {
    super.didUpdateWidget(old);
    if (old.statesController != widget.statesController) {
      (old.statesController ?? _ownStates)?.removeListener(_statesChanged);
      _states.addListener(_statesChanged);
      _statesChanged();
    }
  }

  @override
  void dispose() {
    _hide?.cancel();
    _states.removeListener(_statesChanged);
    _ownStates?.dispose();
    _shown.dispose();
    _expanded.dispose();
    super.dispose();
  }

  Set<WidgetState> get _current => _states.value;
  bool get _held =>
      _current.contains(WidgetState.hovered) ||
      _current.contains(WidgetState.dragged);

  void _statesChanged() {
    final expand =
        _current.contains(WidgetState.hovered) ||
        _current.contains(WidgetState.dragged);
    if (expand) {
      _expanded.forward();
      _show();
    } else {
      _expanded.reverse();
      _scheduleHide();
    }
    _repaint();
  }

  void _show() {
    _hide?.cancel();
    _shown.forward();
  }

  void _scheduleHide() {
    _hide?.cancel();
    if (!_overlay || _held) return;
    _hide = Timer(AmalfiScrollbar.hideDelay, () {
      if (mounted && !_held) _shown.reverse();
    });
  }

  void _set(WidgetState state, bool on) {
    if (_current.contains(state) != on) _states.update(state, on);
  }

  bool _onNotification(Notification n) {
    if (n is ScrollMetricsNotification) {
      if (n.depth == widget.notificationDepth &&
          n.metrics.axis == widget.axis) {
        _position = Scrollable.maybeOf(n.context)?.position ?? _position;
        _update(() => _metrics = n.metrics);
      }
    } else if (n is ScrollNotification) {
      if (n.depth == widget.notificationDepth &&
          n.metrics.axis == widget.axis) {
        _position =
            Scrollable.maybeOf(n.context ?? context)?.position ?? _position;
        _update(() => _metrics = n.metrics);
        if (n is ScrollUpdateNotification || n is ScrollStartNotification) {
          _show();
        } else if (n is ScrollEndNotification) {
          _scheduleHide();
        }
      }
    }
    return false;
  }

  /// The thumb's offset and extent on a track [length] long; null when all is visible.
  (double, double)? _thumb(double length) {
    final m = _metrics;
    if (m == null || !m.hasContentDimensions || !m.hasViewportDimension) {
      return null;
    }
    final range = m.maxScrollExtent - m.minScrollExtent;
    if (range <= 0 || length <= 0) return null;
    final content = range + m.viewportDimension;
    final extent = (length * m.viewportDimension / content)
        .clamp(math.min(AmalfiScrollbarMetrics.minThumb, length), length)
        .toDouble();
    final f = ((m.pixels - m.minScrollExtent) / range).clamp(0.0, 1.0);
    return (f * (length - extent), extent);
  }

  /// All the content is visible: known from the metrics, which an overlay bar waits for.
  bool get _fits {
    final m = _metrics;
    if (m == null || !m.hasContentDimensions || !m.hasViewportDimension) {
      return false;
    }
    return m.maxScrollExtent - m.minScrollExtent <= 0;
  }

  double _along(Offset local) =>
      widget.axis == Axis.vertical ? local.dy : local.dx;

  void _down(Offset local, double length) {
    final thumb = _thumb(length);
    final position = _position;
    if (thumb == null || position == null || !position.hasPixels) return;
    final at = _along(local);
    final (offset, extent) = thumb;
    if (at >= offset && at <= offset + extent) {
      _dragFrom = at;
      _dragPixels = position.pixels;
      _set(WidgetState.dragged, true);
    } else {
      // Page toward the click, or (Appearance › click in the scroll bar) jump to the spot: the
      // thumb centres on the click.
      final room = length - extent;
      final spot = room <= 0
          ? position.pixels
          : position.minScrollExtent +
                ((at - extent / 2) / room).clamp(0.0, 1.0) *
                    (position.maxScrollExtent - position.minScrollExtent);
      final page = position.viewportDimension * (at < offset ? -1 : 1);
      final target =
          (_click == SystemScrollClick.spot ? spot : position.pixels + page)
              .clamp(position.minScrollExtent, position.maxScrollExtent);
      unawaited(
        position.animateTo(
          target,
          duration: AmalfiFades.quick.duration,
          curve: AmalfiFades.quick.curve,
        ),
      );
    }
  }

  void _drag(Offset local, double length) {
    final from = _dragFrom;
    final thumb = _thumb(length);
    final position = _position;
    if (from == null || thumb == null || position == null) return;
    final (_, extent) = thumb;
    final room = length - extent;
    if (room <= 0) return;
    final range = position.maxScrollExtent - position.minScrollExtent;
    final target = (_dragPixels + (_along(local) - from) * range / room).clamp(
      position.minScrollExtent,
      position.maxScrollExtent,
    );
    position.jumpTo(target);
  }

  void _up() {
    _dragFrom = null;
    _set(WidgetState.dragged, false);
  }

  @override
  Widget build(BuildContext context) {
    final vertical = widget.axis == Axis.vertical;
    final thickness = AmalfiScrollbarMetrics.thicknessOf(_style);
    final rtl = Directionality.maybeOf(context) == TextDirection.rtl;
    final padding = vertical
        ? EdgeInsets.only(
            top: widget.padding.top,
            bottom: widget.padding.bottom,
          )
        : EdgeInsets.only(
            left: widget.padding.left,
            right: widget.padding.right,
          );

    final bar = Padding(
      padding: padding,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final length = vertical
              ? constraints.maxHeight
              : constraints.maxWidth;
          final thumb = length.isFinite ? _thumb(length) : null;
          final visible =
              widget.enabled &&
              (!_overlay || (!_fits && (_shown.value > 0 || _held)));
          final face = AmalfiScrollbarTrack(
            axis: widget.axis,
            style: _style,
            expansion: AmalfiFades.quick.curve.transform(_expanded.value),
            hovered: _current.contains(WidgetState.hovered),
            dragging: _current.contains(WidgetState.dragged),
            thumbOffset: thumb?.$1 ?? 0,
            thumbExtent: thumb?.$2,
            enabled: widget.enabled,
          );
          return MouseRegion(
            opaque: false,
            onEnter: widget.enabled
                ? (_) => _set(WidgetState.hovered, true)
                : null,
            onExit: (_) => _set(WidgetState.hovered, false),
            child: GestureDetector(
              behavior: visible
                  ? HitTestBehavior.opaque
                  : HitTestBehavior.translucent,
              onPanDown: visible ? (d) => _down(d.localPosition, length) : null,
              onPanUpdate: visible
                  ? (d) => _drag(d.localPosition, length)
                  : null,
              onPanEnd: (_) => _up(),
              onPanCancel: _up,
              child: _overlay
                  ? Opacity(
                      opacity: _fits
                          ? 0
                          : _held
                          ? 1
                          : AmalfiFades.quick.curve.transform(_shown.value),
                      child: face,
                    )
                  : face,
            ),
          );
        },
      ),
    );

    final sized = SizedBox(
      width: vertical ? thickness : null,
      height: vertical ? null : thickness,
      child: bar,
    );

    final content = NotificationListener<Notification>(
      onNotification: _onNotification,
      child: widget.child,
    );

    if (_overlay) {
      return Stack(
        children: [
          content,
          Positioned(
            top: vertical ? 0 : null,
            bottom: 0,
            left: vertical ? (rtl ? 0 : null) : 0,
            right: vertical ? (rtl ? null : 0) : 0,
            child: sized,
          ),
        ],
      );
    }
    final children = [Expanded(child: content), sized];
    return vertical
        ? Row(
            textDirection: rtl ? TextDirection.rtl : TextDirection.ltr,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          );
  }
}
