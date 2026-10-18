// Menus and popovers as popups of their own (silica-desktop#4): the way [showAmalfiMenu],
// [showAmalfiPopover], the pop-up buttons and the submenus put their content on a surface
// that can extend past the app's window. See `popups.dart`.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show FlutterView;

import 'package:flutter/widgets.dart';

import '../../popups.dart';
import '../glass.dart';
import '../theme.dart';

/// The room a popup may take on its output, in logical pixels, less a margin; unbounded where
/// the display is not known (tests).
Size _roomOf(FlutterView view) {
  try {
    final display = view.display;
    final ratio = display.devicePixelRatio;
    if (ratio <= 0) return const Size(double.infinity, double.infinity);
    final size = display.size / ratio;
    return Size(math.max(1, size.width - 16), math.max(1, size.height - 16));
  } on Object {
    return const Size(double.infinity, double.infinity);
  }
}

/// Shows what [builder] builds as a popup hanging from [anchor] (a rectangle in global
/// coordinates of the view [context] is in), and completes with its controller once it is
/// open, or null when the system offers no popups (then the caller draws it in the window).
///
/// The content is measured first, in the window's overlay (never drawn), so the popup has its
/// size from its first frame; [builder] is called with a null `placement` then, and with where
/// Ossido put the popup (relative to the window, after flipping and sliding it onto the
/// output) when it is shown. Its glass comes from the compositor. `dismiss` closes the popup.
/// [overlay] is where the content is measured and the popup put when the widgets around
/// [context] have no root overlay (a shell layer, silica-desktop#222).
/// The popup goes away with a press outside it, and its controller's `closed` tells.
Future<SilicaPopupController?> showAmalfiAsPopup({
  required BuildContext context,
  required Rect anchor,
  required Widget Function(
    BuildContext context,
    VoidCallback dismiss,
    Rect? placement,
  )
  builder,
  SilicaPopupEdge anchorEdge = SilicaPopupEdge.bottomLeft,
  SilicaPopupEdge gravity = SilicaPopupEdge.bottomRight,
  Set<SilicaPopupAdjust> adjust = const {
    SilicaPopupAdjust.slideX,
    SilicaPopupAdjust.slideY,
  },
  OverlayState? overlay,
}) async {
  if (SilicaPopups.available != true) {
    if (SilicaPopups.available == null) unawaited(SilicaPopups.probe());
    return null;
  }
  final view = View.maybeOf(context);
  final host = overlay ?? rootOverlayOf(context);
  if (view == null || host == null) return null;
  final brightness = AmalfiTheme.of(context).brightness;
  final direction = Directionality.maybeOf(context) ?? TextDirection.ltr;
  Widget themed(Widget child) => Directionality(
    textDirection: direction,
    child: AmalfiTheme(brightness: brightness, child: child),
  );

  final measured = await measureInOverlay(
    context,
    (c) => themed(builder(c, () {}, null)),
    maxSize: _roomOf(view),
    overlay: host,
  );
  if (measured == null || !host.mounted) return null;
  final size = Size(
    measured.width.ceilToDouble(),
    measured.height.ceilToDouble(),
  );
  if (size.isEmpty) return null;

  final popup = await SilicaPopups.show(
    parent: view.viewId,
    size: size,
    anchorRect: anchor,
    anchor: anchorEdge,
    gravity: gravity,
    adjust: adjust,
  );
  if (popup == null) return null;
  if (!host.mounted) {
    unawaited(popup.close());
    return null;
  }
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => ViewAnchor(
      view: View(
        view: popup.view,
        child: SilicaPopupScope(
          viewId: popup.viewId,
          overlay: host,
          child: AmalfiGlassBackendScope(
            backend: AmalfiGlassBackend.compositor,
            child: themed(
              Align(
                alignment: Alignment.topLeft,
                child: Builder(
                  builder: (c) => builder(c, popup.close, popup.placement),
                ),
              ),
            ),
          ),
        ),
      ),
      // The window's content goes (its overlay is torn down): the popup must not outlive it.
      child: _PopupLife(popup: popup),
    ),
  );
  host.insert(entry);
  unawaited(
    popup.closed.whenComplete(() {
      entry.remove();
      entry.dispose();
    }),
  );
  return popup;
}

/// Sits where the popup's entry is in the window's overlay and closes the popup when the entry
/// goes without it: the overlay is disposed with the window's content, and the popup (a surface
/// of the compositor) would stay on the screen with nothing to close it (silica-os/mustache#25).
class _PopupLife extends StatefulWidget {
  const _PopupLife({required this.popup});

  final SilicaPopupController popup;

  @override
  State<_PopupLife> createState() => _PopupLifeState();
}

class _PopupLifeState extends State<_PopupLife> {
  @override
  void dispose() {
    if (widget.popup.isOpen) unawaited(widget.popup.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
