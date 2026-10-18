// Where a pop-up button's menu and a pull-down's menu go (docs/spec/menus.md "Pop-up button",
// measured, silica-reference#107), and how long they take. One source for the in-window
// fallback (`AmalfiPopUpButton`, `AmalfiPullDownButton`) and the shell's menu service.

import 'dart:math' as math;

import 'package:flutter/animation.dart';

/// The measures of the menu of a pop-up or pull-down button, in points.
abstract final class AmalfiPopUpMenuMetrics {
  /// The padding of the menu above the first row and below the last.
  static const double padding = 5;

  /// The gap kept to the output's edges (the top, the bottom of the usable area, the right).
  static const double screenMargin = 6;

  /// A pop-up menu's left edge, left of the control's, per control class.
  static double leftOfControl(AmalfiPopUpControl control) =>
      control == AmalfiPopUpControl.small ? 11 : 12;

  /// The row height of the menu per control class: 24, 22, 19.
  static double rowHeight(AmalfiPopUpControl control) => switch (control) {
    AmalfiPopUpControl.regular => 24,
    AmalfiPopUpControl.small => 22,
    AmalfiPopUpControl.mini => 19,
  };

  /// How far below the control's top the selected row's top sits: 3 for a mini control.
  static double rowTopInControl(AmalfiPopUpControl control, double height) =>
      switch (control) {
        AmalfiPopUpControl.mini => 3,
        // Taller controls than the measured 24 keep the row centred on them.
        AmalfiPopUpControl.regular => math.max(0, (height - 24) / 2),
        AmalfiPopUpControl.small => 0,
      };

  /// A pull-down's gap below its control.
  static const double pullDownGap = 3;

  /// A pull-down's left edge, left of the control's.
  static const double pullDownLeft = 5;

  /// A pull-down is this much narrower than its control (it grows with longer rows).
  static const double pullDownNarrower = 4;

  /// The scroll-arrow strip at a cut end: about one row.
  static const double arrowStrip = 24;

  /// The menu appears complete in one frame.
  static const Duration open = Duration.zero;

  /// Esc: an opacity-only fade, ease-out (half the contrast gone at 80 ms).
  static const Duration fadeOut = Duration(milliseconds: 190);

  /// The opacity at [t] (0..1 through the fade) of a fade that is ease-out in the amount
  /// that goes: use as `Animation` curve on a controller that runs 1 to 0.
  static const Curve fadeCurve = _FadeOutCurve();

  /// After a choice the row blinks once and the fade starts this long after the click
  /// (done ~345 ms after it: this plus [fadeOut]).
  static const Duration chooseFadeDelay = Duration(milliseconds: 150);
}

class _FadeOutCurve extends Curve {
  const _FadeOutCurve();

  // The controller runs 1 to 0; the amount faded is ease-out of the time elapsed.
  @override
  double transformInternal(double t) => Curves.easeOut.flipped.transform(t);
}

/// The class of a control for the measures above, by its height: 16 (mini), 20 (small), 24
/// and above (regular).
enum AmalfiPopUpControl {
  mini,
  small,
  regular;

  static AmalfiPopUpControl ofHeight(double height) => height <= 17
      ? mini
      : height <= 21
      ? small
      : regular;
}

/// Where a menu goes: [top] and [left] of its rectangle on the output, the [height] shown,
/// the [scroll] offset of its rows and which ends show a scroll-arrow strip.
class AmalfiMenuPlacement {
  const AmalfiMenuPlacement({
    required this.left,
    required this.top,
    required this.height,
    this.scroll = 0,
    this.arrowTop = false,
    this.arrowBottom = false,
    this.flipped = false,
  });

  final double left;
  final double top;

  /// The height of the menu on the output (the rows' height when everything shows).
  final double height;

  /// How far the rows are scrolled up at the start.
  final double scroll;

  /// Whether the top / the bottom end is cut and shows a scroll-arrow strip.
  final bool arrowTop;
  final bool arrowBottom;

  /// Whether the menu opened above the control instead.
  final bool flipped;

  Offset get topLeft => Offset(left, top);

  /// A pop-up button's menu: the selected row's top on the control's top.
  ///
  /// [selectedTop] is the selected row's top inside the menu (padding included), [height] the
  /// menu's full height, [width] its width, [first] whether the selected row is the first one
  /// (or none is selected). [bounds] is the output (its usable part).
  static AmalfiMenuPlacement popUp({
    required Rect control,
    required Rect bounds,
    required double width,
    required double height,
    required double selectedTop,
    bool first = false,
  }) {
    const m = AmalfiPopUpMenuMetrics.screenMargin;
    final kind = AmalfiPopUpControl.ofHeight(control.height);
    final left = _fitX(
      control.left - AmalfiPopUpMenuMetrics.leftOfControl(kind),
      width,
      bounds,
    );
    final rowTop =
        control.top +
        AmalfiPopUpMenuMetrics.rowTopInControl(kind, control.height);
    final top = rowTop - selectedTop;
    final minY = bounds.top + m, maxY = bounds.bottom - m;
    if (first && top + height > maxY) {
      // No room below with the first item selected: the menu opens above the control.
      return _cut(
        left,
        control.top - height,
        height,
        minY,
        maxY,
        flipped: true,
      );
    }
    return _cut(left, top, height, minY, maxY);
  }

  /// A pull-down's menu: 3 below the control, or above it without room.
  static AmalfiMenuPlacement pullDown({
    required Rect control,
    required Rect bounds,
    required double width,
    required double height,
  }) {
    const m = AmalfiPopUpMenuMetrics.screenMargin;
    final left = _fitX(
      control.left - AmalfiPopUpMenuMetrics.pullDownLeft,
      width,
      bounds,
    );
    final minY = bounds.top + m, maxY = bounds.bottom - m;
    final below = control.bottom + AmalfiPopUpMenuMetrics.pullDownGap;
    if (below + height <= maxY) {
      return AmalfiMenuPlacement(left: left, top: below, height: height);
    }
    if (control.top - height >= minY) {
      return AmalfiMenuPlacement(
        left: left,
        top: control.top - height,
        height: height,
        flipped: true,
      );
    }
    // Neither fits: the larger side, scrolled.
    return maxY - below >= control.top - minY
        ? _cut(left, below, height, below, maxY)
        : _cut(
            left,
            control.top - height,
            height,
            minY,
            control.top,
            flipped: true,
          );
  }

  static double _fitX(double x, double width, Rect bounds) {
    const m = AmalfiPopUpMenuMetrics.screenMargin;
    final right = bounds.right - m;
    if (x + width > right) x = right - width;
    return math.max(bounds.left + m, x);
  }

  /// The menu at [top], cut to [minY]..[maxY]: the rows out of view are scrolled away.
  static AmalfiMenuPlacement _cut(
    double left,
    double top,
    double height,
    double minY,
    double maxY, {
    bool flipped = false,
  }) {
    final from = math.max(top, minY);
    final to = math.max(from, math.min(top + height, maxY));
    return AmalfiMenuPlacement(
      left: left,
      top: from,
      height: to - from,
      scroll: from - top,
      arrowTop: from > top,
      arrowBottom: to < top + height,
      flipped: flipped,
    );
  }
}
