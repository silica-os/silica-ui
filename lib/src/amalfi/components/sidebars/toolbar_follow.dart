// Toolbar items that follow a sidebar reveal (`components.md` Sidebar show/hide, measured):
// every leading toolbar element, the sidebar toggle included, sits at
// x(t) = max(x when closed, edge(t) + offset when open), frame by frame, with no fade and no
// jump; trailing items and the window buttons do not move.

import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../titlebars/pieces.dart';

/// The position rule of the leading toolbar items during a sidebar reveal.
abstract final class AmalfiToolbarFollow {
  /// The sidebar toggle's offset from the sidebar's trailing edge when open: x = width - 52
  /// (188 for a 240 sidebar).
  static const double toggleOffset = -52;

  /// The sidebar toggle's x when the sidebar is closed: right of the window buttons.
  static const double toggleClosedX = AmalfiToolbarPieceMetrics.controlsWidth;

  /// The x of an item: [closedX] once the sidebar is closed, [offset] from the content
  /// [edge] (the sidebar's visible width) while it is open.
  static double x({
    required double edge,
    required double closedX,
    required double offset,
  }) => math.max(closedX, edge + offset);

  /// Like [x], relative to the [edge]: the leading inset of a toolbar section that starts at
  /// the content edge (Finder-style back/forward and title move as one block).
  static double inset({
    required double edge,
    required double closedX,
    required double offset,
  }) => x(edge: edge, closedX: closedX, offset: offset) - edge;

  /// The x of the sidebar toggle for a sidebar [edge] (its visible width).
  static double toggleX(double edge) =>
      x(edge: edge, closedX: toggleClosedX, offset: toggleOffset);
}

/// Places [child] (a toolbar piece) in a [Stack] over the toolbar at
/// [AmalfiToolbarFollow.x]; with the defaults it is the sidebar toggle.
class AmalfiToolbarFollower extends StatelessWidget {
  const AmalfiToolbarFollower({
    super.key,
    required this.edge,
    required this.child,
    this.closedX = AmalfiToolbarFollow.toggleClosedX,
    this.offset = AmalfiToolbarFollow.toggleOffset,
    this.height = AmalfiToolbarMetrics.toolbarHeight,
  });

  /// The sidebar's visible width now (`width * progress`).
  final double edge;
  final double closedX;
  final double offset;
  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) => Positioned(
    left: AmalfiToolbarFollow.x(edge: edge, closedX: closedX, offset: offset),
    top: 0,
    height: height,
    child: Align(alignment: Alignment.centerLeft, child: child),
  );
}
