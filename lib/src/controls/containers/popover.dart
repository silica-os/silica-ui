// Popovers inside a window (CT-PO-01…04; MU-62): a rounded body (radius ~18) with an arrow
// towards the control it opens from (the measured TIP-01 outline: 32 × 11 pt on the top and bottom
// edges, 39 × 12 pt on the sides), a dark 1 px border and the
// menu shadow. Light body `#f8f8f9` → `#f6f6f7`, dark `#474748` → `#505051`. The arrow goes on any
// edge ([TipEdge]); the popover goes on the preferred side of its anchor and flips when it does
// not fit, sliding along the edge to stay in the window while the arrow keeps pointing at the
// anchor's center. Transient popovers close on a click outside, on Esc and when the window loses
// focus; semi-transient ones stay when the window loses focus; application-defined ones close
// only from the app. Measured only below the anchor (arrow on top): other edges, the fade and the
// arrow gap are provisional.

import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../glass.dart' show TipEdge;
import '../../tip_outline.dart';
import 'common.dart';

enum PopoverBehavior { transient, semitransient, applicationDefined }

abstract final class PopoverMetrics {
  static const double radius = 18;

  /// The tip on the top and bottom edges (TIP-01, [TipOutline.popover]).
  static const double tipDepth = 11;
  static const double tipBase = 32;

  /// The tip on the left and right edges (TIP-01, [TipOutline.popoverSide]).
  static const double sideTipDepth = 12;
  static const double sideTipBase = 39;

  static bool _side(TipEdge edge) =>
      edge == TipEdge.left || edge == TipEdge.right;

  /// The tip's depth away from `edge`.
  static double depthOn(TipEdge edge) => _side(edge) ? sideTipDepth : tipDepth;

  /// The tip's base along `edge`.
  static double baseOn(TipEdge edge) => _side(edge) ? sideTipBase : tipBase;

  /// The measured outline for `edge`.
  static TipOutline outlineOn(TipEdge edge) =>
      _side(edge) ? TipOutline.popoverSide : TipOutline.popover;

  /// Between the apex and the anchor. *Provisional.*
  static const double gap = 1;

  /// The closest the body gets to the window edges. *Provisional.*
  static const double margin = 8;

  /// Fade in and out. *Provisional.*
  static const Duration fade = Duration(milliseconds: 120);
}

@immutable
class PopoverColors {
  const PopoverColors(this.top, this.bottom, this.border, this.shadow);
  final Color top;
  final Color bottom;
  final Color border;
  final Color shadow;

  static const PopoverColors light = PopoverColors(
    Color(0xFFF8F8F9),
    Color(0xFFF6F6F7),
    Color(0x26000000),
    Color(0x33000000),
  );
  static const PopoverColors dark = PopoverColors(
    Color(0xFF474748),
    Color(0xFF505051),
    Color(0xDB000000),
    Color(0x42000000),
  );

  static PopoverColors of(BuildContext context) =>
      containerDark(context) ? dark : light;
}

/// The outline of a popover body of `size` with the arrow on `edge`, its center `tip` pt along
/// that edge (from the left or the top). The arrow is outside `size`.
Path popoverPath(Size size, TipEdge edge, double tip) {
  const r = PopoverMetrics.radius;
  final body = Path()
    ..addRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(r)),
    );
  // The measured outline on the top edge pointing up, then turned onto its edge.
  final arrow = PopoverMetrics.outlineOn(
    edge,
  ).path().transform((Matrix4.identity()..scaleByDouble(1, -1, 1, 1)).storage);
  final placed = switch (edge) {
    TipEdge.top => arrow.shift(Offset(tip, 0)),
    TipEdge.bottom => arrow.transform(
      (Matrix4.identity()
            ..translateByDouble(tip, size.height, 0, 1)
            ..scaleByDouble(1, -1, 1, 1))
          .storage,
    ),
    TipEdge.left => arrow.transform(
      (Matrix4.identity()
            ..translateByDouble(0, tip, 0, 1)
            ..rotateZ(-math.pi / 2))
          .storage,
    ),
    TipEdge.right => arrow.transform(
      (Matrix4.identity()
            ..translateByDouble(size.width, tip, 0, 1)
            ..rotateZ(math.pi / 2))
          .storage,
    ),
  };
  return Path.combine(PathOperation.union, body, placed);
}

/// Where a popover of `size` goes for an `anchor` inside `bounds`: the body's rectangle, the edge
/// of its arrow and the arrow's center along that edge.
({Rect rect, TipEdge edge, double tip}) placePopover({
  required Rect anchor,
  required Size size,
  required Rect bounds,
  TipEdge preferred = TipEdge.bottom,
}) {
  const space = PopoverMetrics.tipDepth + PopoverMetrics.gap;
  const sideSpace = PopoverMetrics.sideTipDepth + PopoverMetrics.gap;
  final m = PopoverMetrics.margin;
  // `preferred` is the side of the anchor the popover goes to.
  bool fits(TipEdge side) => switch (side) {
    TipEdge.bottom => anchor.bottom + space + size.height <= bounds.bottom - m,
    TipEdge.top => anchor.top - space - size.height >= bounds.top + m,
    TipEdge.right => anchor.right + sideSpace + size.width <= bounds.right - m,
    TipEdge.left => anchor.left - sideSpace - size.width >= bounds.left + m,
  };
  final opposite = switch (preferred) {
    TipEdge.bottom => TipEdge.top,
    TipEdge.top => TipEdge.bottom,
    TipEdge.left => TipEdge.right,
    TipEdge.right => TipEdge.left,
  };
  final side = fits(preferred) || !fits(opposite) ? preferred : opposite;
  const minTip = PopoverMetrics.radius + PopoverMetrics.tipBase / 2;
  const minSideTip = PopoverMetrics.radius + PopoverMetrics.sideTipBase / 2;
  double slide(double center, double length, double lo, double hi) {
    final start = (center - length / 2).clamp(
      lo + m,
      math.max(lo + m, hi - m - length),
    );
    return start.toDouble();
  }

  switch (side) {
    case TipEdge.bottom:
    case TipEdge.top:
      final left = slide(
        anchor.center.dx,
        size.width,
        bounds.left,
        bounds.right,
      );
      final top = side == TipEdge.bottom
          ? anchor.bottom + space
          : anchor.top - space - size.height;
      final tip = (anchor.center.dx - left).clamp(
        minTip,
        math.max(minTip, size.width - minTip),
      );
      return (
        rect: Rect.fromLTWH(left, top, size.width, size.height),
        // Below the anchor the arrow is on the body's top edge.
        edge: side == TipEdge.bottom ? TipEdge.top : TipEdge.bottom,
        tip: tip.toDouble(),
      );
    case TipEdge.left:
    case TipEdge.right:
      final top = slide(
        anchor.center.dy,
        size.height,
        bounds.top,
        bounds.bottom,
      );
      final left = side == TipEdge.right
          ? anchor.right + sideSpace
          : anchor.left - sideSpace - size.width;
      final tip = (anchor.center.dy - top).clamp(
        minSideTip,
        math.max(minSideTip, size.height - minSideTip),
      );
      return (
        rect: Rect.fromLTWH(left, top, size.width, size.height),
        edge: side == TipEdge.right ? TipEdge.left : TipEdge.right,
        tip: tip.toDouble(),
      );
  }
}

/// The popover body: background, border, shadow and arrow, around `child`.
class PopoverPanel extends StatelessWidget {
  const PopoverPanel({
    super.key,
    required this.child,
    this.edge = TipEdge.top,
    this.tip,
  });

  final Widget child;
  final TipEdge edge;

  /// The arrow's center along its edge; null: centered.
  final double? tip;

  @override
  Widget build(BuildContext context) {
    final colors = PopoverColors.of(context);
    return CustomPaint(
      painter: _PopoverPainter(colors, edge, tip),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(PopoverMetrics.radius),
        child: child,
      ),
    );
  }
}

class _PopoverPainter extends CustomPainter {
  const _PopoverPainter(this.colors, this.edge, this.tip);
  final PopoverColors colors;
  final TipEdge edge;
  final double? tip;

  @override
  void paint(Canvas canvas, Size size) {
    final along = edge == TipEdge.top || edge == TipEdge.bottom
        ? size.width
        : size.height;
    final path = popoverPath(size, edge, tip ?? along / 2);
    canvas
      ..save()
      ..clipPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect((Offset.zero & size).inflate(60)),
          path,
        ),
      )
      ..drawPath(
        path.shift(const Offset(0, 4)),
        Paint()
          ..color = colors.shadow
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            Shadow.convertRadiusToSigma(16),
          ),
      )
      ..restore()
      ..drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [colors.top, colors.bottom],
          ).createShader(Offset.zero & size),
      )
      ..drawPath(
        path,
        Paint()
          ..color = colors.border
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
  }

  @override
  bool shouldRepaint(_PopoverPainter old) =>
      old.colors != colors || old.edge != edge || old.tip != tip;
}

/// Shows `builder`'s content in a popover of `size` next to the widget it wraps. Open it with
/// [PopoverAnchorState.show] (a `GlobalKey<PopoverAnchorState>`) or with [open].
class PopoverAnchor extends StatefulWidget {
  const PopoverAnchor({
    super.key,
    required this.child,
    required this.builder,
    required this.size,
    this.preferredEdge = TipEdge.bottom,
    this.behavior = PopoverBehavior.transient,
    this.open,
    this.onClosed,
    this.semanticLabel,
  });

  final Widget child;
  final WidgetBuilder builder;
  final Size size;

  /// The side of the anchor the popover goes to.
  final TipEdge preferredEdge;
  final PopoverBehavior behavior;

  /// Driven by the app: shown while true. Null: [PopoverAnchorState.show] and `hide`.
  final bool? open;
  final VoidCallback? onClosed;
  final String? semanticLabel;

  @override
  State<PopoverAnchor> createState() => PopoverAnchorState();
}

class PopoverAnchorState extends State<PopoverAnchor>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  final OverlayPortalController _portal = OverlayPortalController();
  final FocusScopeNode _focus = FocusScopeNode();
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: PopoverMetrics.fade,
  );

  bool get isOpen => _portal.isShowing;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (widget.open ?? false) {
      WidgetsBinding.instance.addPostFrameCallback((_) => show());
    }
  }

  @override
  void didUpdateWidget(PopoverAnchor old) {
    super.didUpdateWidget(old);
    final open = widget.open;
    if (open != null && open != old.open) open ? show() : hide();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _fade.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed &&
        widget.behavior == PopoverBehavior.transient) {
      hide();
    }
  }

  void show() {
    if (!mounted || _portal.isShowing) return;
    _portal.show();
    _fade.forward(from: 0);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  void hide() {
    if (!_portal.isShowing || _fade.status == AnimationStatus.reverse) return;
    _fade.reverse().whenComplete(() {
      if (!mounted) return;
      _portal.hide();
      widget.onClosed?.call();
    });
  }

  void toggle() => isOpen ? hide() : show();

  @override
  Widget build(BuildContext context) => OverlayPortal(
    controller: _portal,
    overlayChildBuilder: _overlay,
    child: Semantics(label: widget.semanticLabel, child: widget.child),
  );

  Widget _overlay(BuildContext overlayContext) {
    final box = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (box == null || overlay == null || !box.attached) {
      return const SizedBox.shrink();
    }
    final anchor = box.localToGlobal(Offset.zero, ancestor: overlay) & box.size;
    final place = placePopover(
      anchor: anchor,
      size: widget.size,
      bounds: Offset.zero & overlay.size,
      preferred: widget.preferredEdge,
    );
    final dismissible = widget.behavior != PopoverBehavior.applicationDefined;
    return Stack(
      children: [
        if (dismissible)
          Positioned.fill(
            child: Listener(
              key: const ValueKey('popover outside'),
              behavior: HitTestBehavior.translucent,
              onPointerDown: (e) {
                if (!place.rect.contains(e.localPosition)) hide();
              },
            ),
          ),
        Positioned.fromRect(
          rect: place.rect,
          child: FadeTransition(
            opacity: _fade,
            child: FocusScope(
              node: _focus,
              child: Shortcuts(
                shortcuts: const {
                  SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
                },
                child: Actions(
                  actions: {
                    DismissIntent: CallbackAction<DismissIntent>(
                      onInvoke: (_) {
                        if (dismissible) hide();
                        return null;
                      },
                    ),
                  },
                  child: Focus(
                    autofocus: true,
                    child: Semantics(
                      scopesRoute: true,
                      namesRoute: true,
                      explicitChildNodes: true,
                      label: widget.semanticLabel,
                      child: PopoverPanel(
                        key: const ValueKey('popover'),
                        edge: place.edge,
                        tip: place.tip,
                        child: Builder(builder: widget.builder),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
