// Split views and dividers (CT-SP-01). Two panes side by side or stacked: one keeps its size,
// the other takes the rest. Dividers: thin (a 1 pt line, grabbed over 5 pt), thick (Terminal's
// split pane: 7 pt, with a center dot) or none (the sidebar, MU-11: no line towards the
// content). The sidebar behaviour (MU-11): minimum 135 pt, the content keeps at least 316,
// released between 191 and 209 it snaps to 200, dragged closer than 65 pt to the edge it hides.
// Not measured: the divider colors (provisional), the collapse animation (the sidebar's ⌃⌘S
// timing is used: ~240 ms hide, ~270 ms show).

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../double_tap.dart';
import 'common.dart';

enum SplitDividerStyle { none, thin, thick }

/// Which pane keeps its size when the view resizes.
enum SplitFixedPane { leading, trailing }

/// Snapping and hiding of the fixed pane while its divider is dragged.
@immutable
class SplitBehavior {
  const SplitBehavior({
    this.min = 0,
    this.max = double.infinity,
    this.otherMin = 0,
    this.snapFrom,
    this.snapTo,
    this.snapSize,
    this.collapseBelow,
  });

  /// The fixed pane between [min] and [max]; the other at least [otherMin].
  final double min;
  final double max;
  final double otherMin;

  /// Released between [snapFrom] and [snapTo], the pane takes [snapSize].
  final double? snapFrom;
  final double? snapTo;
  final double? snapSize;

  /// Dragged with the pointer closer than this to the outer edge, the pane collapses.
  final double? collapseBelow;

  /// The file manager sidebar (measured in silica-reference MU-11).
  static const SplitBehavior sidebar = SplitBehavior(
    min: 135,
    otherMin: 316,
    snapFrom: 191,
    snapTo: 209,
    snapSize: 200,
    collapseBelow: 65,
  );

  /// The size while dragging with the pointer at `pointer` from the outer edge, grabbed `grab` pt
  /// past the pane's edge (0: collapsed).
  double dragSize(double pointer, double total, {double grab = 0}) {
    final hide = collapseBelow;
    if (hide != null && pointer < hide) return 0;
    final upper = math.max(min, math.min(max, total - otherMin));
    return (pointer - grab).clamp(min, upper);
  }

  /// The size on release.
  double releaseSize(double size) {
    final from = snapFrom, to = snapTo, snap = snapSize;
    if (from != null && to != null && snap != null) {
      if (size >= from && size <= to) return snap;
    }
    return size;
  }
}

/// The divider colors. *Provisional: not measured.*
@immutable
class SplitColors {
  const SplitColors(this.line, this.thick, this.dot);
  final Color line;
  final Color thick;
  final Color dot;

  static const SplitColors light = SplitColors(
    Color(0xFFE5E5E5),
    Color(0xFFE3E3E3),
    Color(0xFFADADAD),
  );
  static const SplitColors dark = SplitColors(
    Color(0xFF363637),
    Color(0xFF2E2E2F),
    Color(0xFF6A6A6B),
  );

  static SplitColors of(BuildContext context) =>
      containerDark(context) ? dark : light;
}

/// Two panes with a divider. [size] is the size of the fixed pane: the view keeps it in its state
/// and reports changes; [collapsed] hides the fixed pane with an animation.
class SplitView extends StatefulWidget {
  const SplitView({
    super.key,
    required this.leading,
    required this.trailing,
    this.axis = Axis.horizontal,
    this.fixed = SplitFixedPane.leading,
    this.initialSize = 200,
    this.behavior = const SplitBehavior(min: 50, otherMin: 50),
    this.divider = SplitDividerStyle.thin,
    this.collapsed = false,
    this.onSizeChanged,
    this.onCollapsedChanged,
    this.semanticLabel,
  });

  final Widget leading;
  final Widget trailing;
  final Axis axis;
  final SplitFixedPane fixed;
  final double initialSize;
  final SplitBehavior behavior;
  final SplitDividerStyle divider;
  final bool collapsed;
  final ValueChanged<double>? onSizeChanged;
  final ValueChanged<bool>? onCollapsedChanged;

  /// The divider's accessibility label ("Sidebar width", localized by the app).
  final String? semanticLabel;

  static const Duration hide = Duration(milliseconds: 240);
  static const Duration show = Duration(milliseconds: 270);

  /// The grab area around a thin or invisible divider.
  static const double grip = 5;
  static const double thick = 7;

  @override
  State<SplitView> createState() => _SplitViewState();
}

class _SplitViewState extends State<SplitView>
    with SingleTickerProviderStateMixin {
  late double _size = widget.initialSize;
  late bool _collapsed = widget.collapsed;
  late final AnimationController _open = AnimationController(
    vsync: this,
    duration: SplitView.show,
    reverseDuration: SplitView.hide,
    value: widget.collapsed ? 0 : 1,
  )..addListener(() => setState(() {}));
  double _total = 0;

  @override
  void didUpdateWidget(SplitView old) {
    super.didUpdateWidget(old);
    if (widget.collapsed != old.collapsed && widget.collapsed != _collapsed) {
      _setCollapsed(widget.collapsed, notify: false);
    }
  }

  @override
  void dispose() {
    _open.dispose();
    super.dispose();
  }

  void _setCollapsed(bool collapsed, {bool notify = true}) {
    _collapsed = collapsed;
    if (collapsed) {
      _open.reverse();
    } else {
      _open.forward();
    }
    if (notify) widget.onCollapsedChanged?.call(collapsed);
  }

  bool get _horizontal => widget.axis == Axis.horizontal;
  bool get _leadingFixed => widget.fixed == SplitFixedPane.leading;

  /// Where the pointer took the divider, from the pane's edge.
  double _grab = 0;

  double _pointer(Offset local) {
    final along = _horizontal ? local.dx : local.dy;
    return _leadingFixed ? along : _total - along;
  }

  void _start(Offset local) => _grab = _collapsed ? 0 : _pointer(local) - _size;

  void _drag(Offset local) {
    final size = widget.behavior.dragSize(_pointer(local), _total, grab: _grab);
    setState(() {
      if (size == 0) {
        if (!_collapsed) _setCollapsed(true);
      } else {
        if (_collapsed) _setCollapsed(false);
        _size = size;
      }
    });
  }

  void _release() {
    final size = widget.behavior.releaseSize(_size);
    setState(() => _size = size);
    widget.onSizeChanged?.call(size);
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final grow = _horizontal
        ? (_leadingFixed
              ? LogicalKeyboardKey.arrowRight
              : LogicalKeyboardKey.arrowLeft)
        : (_leadingFixed
              ? LogicalKeyboardKey.arrowDown
              : LogicalKeyboardKey.arrowUp);
    final shrink = _horizontal
        ? (_leadingFixed
              ? LogicalKeyboardKey.arrowLeft
              : LogicalKeyboardKey.arrowRight)
        : (_leadingFixed
              ? LogicalKeyboardKey.arrowUp
              : LogicalKeyboardKey.arrowDown);
    if (key != grow && key != shrink) return KeyEventResult.ignored;
    final b = widget.behavior;
    setState(
      () => _size = (_size + (key == grow ? 10 : -10)).clamp(
        b.min,
        math.max(b.min, math.min(b.max, _total - b.otherMin)),
      ),
    );
    widget.onSizeChanged?.call(_size);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final colors = SplitColors.of(context);
    final thickness = switch (widget.divider) {
      SplitDividerStyle.none => 0.0,
      SplitDividerStyle.thin => 1.0,
      SplitDividerStyle.thick => SplitView.thick,
    };
    return LayoutBuilder(
      builder: (context, box) {
        _total = _horizontal ? box.maxWidth : box.maxHeight;
        final shown = Curves.easeInOut.transform(_open.value);
        final fixedSize = _size * shown;
        final dividerSize = thickness * shown;
        final fixedPane = SizedBox(
          width: _horizontal ? fixedSize : null,
          height: _horizontal ? null : fixedSize,
          child: ClipRect(
            child: OverflowBox(
              alignment: _leadingFixed
                  ? AlignmentDirectional.topEnd
                  : AlignmentDirectional.topStart,
              minWidth: _horizontal ? _size : null,
              maxWidth: _horizontal ? _size : null,
              minHeight: _horizontal ? null : _size,
              maxHeight: _horizontal ? null : _size,
              child: _leadingFixed ? widget.leading : widget.trailing,
            ),
          ),
        );
        final other = Expanded(
          child: _leadingFixed ? widget.trailing : widget.leading,
        );
        final divider = _Divider(
          axis: widget.axis,
          style: widget.divider,
          size: dividerSize,
          colors: colors,
        );
        final children = _leadingFixed
            ? [fixedPane, divider, other]
            : [other, divider, fixedPane];
        final grabAt = _leadingFixed
            ? fixedSize + dividerSize / 2
            : _total - fixedSize - dividerSize / 2;
        final grab = math.max(SplitView.grip, thickness);
        return Stack(
          children: [
            Positioned.fill(
              child: Flex(
                direction: widget.axis,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: children,
              ),
            ),
            Positioned(
              left: _horizontal ? grabAt - grab / 2 : 0,
              right: _horizontal ? null : 0,
              top: _horizontal ? 0 : grabAt - grab / 2,
              bottom: _horizontal ? 0 : null,
              width: _horizontal ? grab : null,
              height: _horizontal ? null : grab,
              child: Semantics(
                label: widget.semanticLabel,
                value: '${_size.round()}',
                slider: true,
                child: Focus(
                  onKeyEvent: _key,
                  child: MouseRegion(
                    cursor: _horizontal
                        ? SystemMouseCursors.resizeLeftRight
                        : SystemMouseCursors.resizeUpDown,
                    child: SilicaDoubleTap(
                      onDoubleTap: () => _setCollapsed(!_collapsed),
                      behavior: HitTestBehavior.opaque,
                      child: GestureDetector(
                        key: const ValueKey('split divider'),
                        behavior: HitTestBehavior.opaque,
                        dragStartBehavior: DragStartBehavior.down,
                        onPanStart: (d) {
                          final box = context.findRenderObject() as RenderBox?;
                          if (box != null) {
                            _start(box.globalToLocal(d.globalPosition));
                          }
                        },
                        onPanUpdate: (d) {
                          final box = context.findRenderObject() as RenderBox?;
                          if (box != null) {
                            _drag(box.globalToLocal(d.globalPosition));
                          }
                        },
                        onPanEnd: (_) => _release(),
                        onPanCancel: _release,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider({
    required this.axis,
    required this.style,
    required this.size,
    required this.colors,
  });

  final Axis axis;
  final SplitDividerStyle style;
  final double size;
  final SplitColors colors;

  @override
  Widget build(BuildContext context) {
    final horizontal = axis == Axis.horizontal;
    return SizedBox(
      width: horizontal ? size : null,
      height: horizontal ? null : size,
      child: switch (style) {
        SplitDividerStyle.none => null,
        SplitDividerStyle.thin => ColoredBox(color: colors.line),
        SplitDividerStyle.thick => ColoredBox(
          color: colors.thick,
          child: Center(
            child: Container(
              width: 3,
              height: 3,
              decoration: BoxDecoration(
                color: colors.dot,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      },
    );
  }
}
