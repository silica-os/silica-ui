// Scrollers (CT-SC-01, CT-SC-02, CT-SC-03). Measured: the track is 11 pt wide with semicircular
// ends (radius 5.5) and a 4 pt margin on each side inside a 19 pt gutter; track light `#f3f3f3`,
// dark `#313132`; thumb light `#7a7a7a`, dark `#a2a2a2`, at least 11 × 20 (MU-24, MU-98). The
// always-visible style keeps the track without a thumb when the content fits (launcher.md).
// Not measured (C-01, S-05, P-01): the thin overlay thumb while scrolling, the hover growth, the
// fade timing and the elasticity at the ends: provisional values below.

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import '../../amalfi/components/scrollbars.dart';
import 'common.dart';

/// Overlay (shown while scrolling, the default with a trackpad) or always visible (legacy).
enum ScrollerStyle { overlay, legacy }

abstract final class ScrollerMetrics {
  static const double track = 11;
  static const double gutter = 19;
  static const double margin = 4;
  static const double minThumb = 20;

  /// The overlay thumb at rest while scrolling, without a track. *Provisional.*
  static const double thinThumb = 7;

  /// How long an overlay scroller stays after the last scroll, and its fade. *Provisional.*
  static const Duration timeToFade = Duration(milliseconds: 1000);
  static const Duration fade = Duration(milliseconds: 300);
}

@immutable
class ScrollerColors {
  const ScrollerColors(this.track, this.thumb);
  final Color track;
  final Color thumb;

  static const ScrollerColors light = ScrollerColors(
    Color(0xFFF3F3F3),
    Color(0xFF7A7A7A),
  );
  static const ScrollerColors dark = ScrollerColors(
    Color(0xFF313132),
    Color(0xFFA2A2A2),
  );

  static ScrollerColors of(BuildContext context) =>
      containerDark(context) ? dark : light;
}

/// A scroller around a scrollable `child`. The overlay style shows a thin thumb while scrolling
/// and the full 11 pt track with the pointer over it; the legacy style is always there.
class SilicaScrollbar extends StatefulWidget {
  const SilicaScrollbar({
    super.key,
    required this.child,
    this.controller,
    this.style = ScrollerStyle.overlay,
    this.axis = Axis.vertical,
    this.notificationPredicate = defaultScrollNotificationPredicate,
  });

  final Widget child;
  final ScrollController? controller;
  final ScrollerStyle style;
  final Axis axis;
  final ScrollNotificationPredicate notificationPredicate;

  @override
  State<SilicaScrollbar> createState() => _SilicaScrollbarState();
}

class _SilicaScrollbarState extends State<SilicaScrollbar> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final colors = ScrollerColors.of(context);
    final legacy = widget.style == ScrollerStyle.legacy;
    final wide = legacy || _hover;
    final thickness = wide ? ScrollerMetrics.track : ScrollerMetrics.thinThumb;
    final margin = legacy
        ? ScrollerMetrics.margin
        : (ScrollerMetrics.gutter - thickness) / 2;
    return MouseRegion(
      // The full track with the pointer over the scroller's gutter.
      onHover: (e) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize) return;
        final p = e.localPosition;
        final over = widget.axis == Axis.vertical
            ? p.dx >= box.size.width - ScrollerMetrics.gutter
            : p.dy >= box.size.height - ScrollerMetrics.gutter;
        if (over != _hover) setState(() => _hover = over);
      },
      onExit: (_) {
        if (_hover) setState(() => _hover = false);
      },
      child: RawScrollbar(
        key: ValueKey(legacy ? 'scroller legacy' : 'scroller overlay'),
        controller: widget.controller,
        notificationPredicate: widget.notificationPredicate,
        thumbVisibility: wide,
        trackVisibility: wide,
        thickness: thickness,
        radius: Radius.circular(thickness / 2),
        trackRadius: const Radius.circular(ScrollerMetrics.track / 2),
        thumbColor: colors.thumb,
        trackColor: colors.track,
        trackBorderColor: const Color(0x00000000),
        crossAxisMargin: margin,
        mainAxisMargin: 2,
        minThumbLength: ScrollerMetrics.minThumb,
        fadeDuration: ScrollerMetrics.fade,
        timeToFade: ScrollerMetrics.timeToFade,
        interactive: true,
        scrollbarOrientation: widget.axis == Axis.vertical
            ? ScrollbarOrientation.right
            : ScrollbarOrientation.bottom,
        child: widget.child,
      ),
    );
  }
}

/// The scroll behavior of Silica apps: elastic ends and the Amalfi scroll bar on every
/// scrollable, in the style chosen in Settings (Appearance › show scroll bars) unless [style]
/// forces one. Use it in `ScrollConfiguration` or `WidgetsApp.scrollBehavior`.
class SilicaScrollBehavior extends ScrollBehavior {
  const SilicaScrollBehavior({this.style});

  /// Null: the system look's.
  final ScrollerStyle? style;

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };

  /// Elastic at the ends. *Provisional: the elasticity is not measured (P-01).*
  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => AmalfiScrollbar(
    axis: axisDirectionToAxis(details.direction),
    style: switch (style) {
      null => null,
      ScrollerStyle.overlay => AmalfiScrollbarStyle.overlay,
      ScrollerStyle.legacy => AmalfiScrollbarStyle.legacy,
    },
    child: child,
  );

  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) => child;
}
