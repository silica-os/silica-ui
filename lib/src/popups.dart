// Menus and popovers as surfaces of their own (silica-desktop#4): an `xdg_popup` of the app's
// window, drawn by its own Flutter view, so it can extend past the window's edge as the menus
// of the reference desktop do. Ossido keeps it on the output (flip and slide), gives it the
// pointer and the keyboard (a grab), and ends it with a press outside (`popup_done`).
//
// Apps do not use this directly: [showAmalfiMenu], [showAmalfiPopover], the pop-up and
// pull-down buttons and their submenus use it when the system offers it, and draw inside the
// window as before when it does not (tests, another embedder, an app not started with
// `--multi-window`).
//
//     final popup = await SilicaPopups.show(
//       parent: View.of(context).viewId,
//       size: const Size(180, 240),
//       anchorRect: buttonRect, // global, in the parent's coordinates
//     );
//     // Build its content in `View(view: popup.view, child: …)`, for example with
//     // `ViewAnchor`, and close it with `popup.close()`.

import 'dart:async';
import 'dart:ui' show FlutterView;

import 'package:flutter/widgets.dart';

import 'windows.dart';

/// An edge or corner of a rectangle: where a popup hangs from ([SilicaPopups.show]'s anchor)
/// or the way it grows (its gravity).
enum SilicaPopupEdge {
  center('center'),
  top('top'),
  bottom('bottom'),
  left('left'),
  right('right'),
  topLeft('top-left'),
  topRight('top-right'),
  bottomLeft('bottom-left'),
  bottomRight('bottom-right');

  const SilicaPopupEdge(this.wire);

  /// The name on `silica/window`.
  final String wire;
}

/// How Ossido keeps a popup on the output when it would leave it: it flips to the other side
/// of its anchor, or slides along the edge.
enum SilicaPopupAdjust { slideX, slideY, flipX, flipY }

/// A popup, from [SilicaPopups.show].
class SilicaPopupController {
  SilicaPopupController._(this.view, this.placement);

  /// The popup's view in the engine: build its content in a `View(view: …)`.
  final FlutterView view;
  int get viewId => view.viewId;

  /// Where Ossido put the popup, relative to its parent's top left corner, after flipping
  /// and sliding it onto the output; null if the embedder did not say.
  final Rect? placement;

  final Completer<void> _closed = Completer<void>();

  /// Completes when the popup is gone: closed with [close], by a press outside it, or with
  /// the window it hangs from.
  Future<void> get closed => _closed.future;

  /// Whether the popup is still open.
  bool get isOpen => !_closed.isCompleted;

  /// Gives the popup a new size (its content grew or shrank: a popover's Show All…), kept
  /// where it hangs from its anchor. False when the system cannot (an older Silica).
  Future<bool> resize(Size size) async {
    if (!isOpen || size.isEmpty || !size.isFinite) return false;
    final done = await SilicaWindows.invoke<Object?>('resizePopup', {
      'viewId': viewId,
      'width': size.width,
      'height': size.height,
    });
    return done == true;
  }

  /// Closes the popup (and the popups that hang from it).
  Future<void> close() async {
    if (!isOpen) return;
    await SilicaWindows.invoke<Object?>('closeWindow', {'viewId': viewId});
  }

  void _gone() {
    if (!_closed.isCompleted) _closed.complete();
  }
}

/// Opens popups (silica-desktop#4); see the library comment.
abstract final class SilicaPopups {
  static final Map<int, SilicaPopupController> _open = {};
  static Future<bool>? _probe;
  static bool? _available;

  /// Finds the view of a popup in tests, where the engine has only one.
  @visibleForTesting
  static FlutterView? Function(int viewId)? debugViewResolver;

  /// Whether the system offers popups: null until the first answer. [probe] asks.
  static bool? get available => _available;

  /// Asks the embedder whether it offers popups (once). Apps do not need to call it:
  /// silica_ui does at start and when the first menu opens.
  static Future<bool> probe() => _probe ??= _ask();

  static Future<bool> _ask() async {
    final answer = await SilicaWindows.invoke<Object?>('popupsAvailable');
    return _available = answer == true;
  }

  /// Opens a popup of [size] (logical pixels) hanging from [anchorRect], a rectangle of the
  /// window (or popup) with view id [parent], in that view's logical pixels. The popup hangs
  /// from [anchor] of the rectangle and grows towards [gravity]; [adjust] says how Ossido
  /// keeps it on the output. With [grab] (the default) it takes the pointer and the keyboard,
  /// and a press outside it closes it. Null when the system cannot open it ([available]
  /// false, the parent is not open, too many windows).
  static Future<SilicaPopupController?> show({
    required int parent,
    required Size size,
    required Rect anchorRect,
    SilicaPopupEdge anchor = SilicaPopupEdge.bottomLeft,
    SilicaPopupEdge gravity = SilicaPopupEdge.bottomRight,
    Set<SilicaPopupAdjust> adjust = const {
      SilicaPopupAdjust.slideX,
      SilicaPopupAdjust.slideY,
      SilicaPopupAdjust.flipX,
      SilicaPopupAdjust.flipY,
    },
    bool grab = true,
  }) async {
    SilicaWindows.listen();
    final reply = await SilicaWindows.invoke<Object?>('openPopup', {
      'parent': parent,
      'width': size.width,
      'height': size.height,
      'anchorRect': [
        anchorRect.left,
        anchorRect.top,
        anchorRect.width,
        anchorRect.height,
      ],
      'anchor': anchor.wire,
      'gravity': gravity.wire,
      'adjust': [for (final a in adjust) a.name],
      'grab': grab,
    });
    final int? id;
    Rect? placement;
    if (reply is int) {
      id = reply;
    } else if (reply is Map && reply['viewId'] is int) {
      id = reply['viewId'] as int;
      num? number(String key) {
        final value = reply[key];
        return value is num ? value : null;
      }

      final x = number('x'), y = number('y');
      final w = number('width'), h = number('height');
      if (x != null && y != null && w != null && h != null) {
        placement = Rect.fromLTWH(
          x.toDouble(),
          y.toDouble(),
          w.toDouble(),
          h.toDouble(),
        );
      }
    } else {
      return null;
    }
    FlutterView? view = debugViewResolver?.call(id);
    for (final candidate in WidgetsBinding.instance.platformDispatcher.views) {
      if (candidate.viewId == id) view ??= candidate;
    }
    if (view == null) {
      // The embedder opened it but the engine has no such view: do not leave it open.
      unawaited(SilicaWindows.invoke<Object?>('closeWindow', {'viewId': id}));
      return null;
    }
    final popup = SilicaPopupController._(view, placement);
    _open[id] = popup;
    return popup;
  }

  /// A popup is gone (`windowClosed`, from [SilicaWindows]).
  static void closedView(Object? id) {
    final popup = _open.remove(id);
    popup?._gone();
  }

  /// Back to the initial state (tests; [SilicaWindows.reset] calls it).
  static void reset() {
    for (final popup in [..._open.values]) {
      popup._gone();
    }
    _open.clear();
    _probe = null;
    _available = null;
    debugViewResolver = null;
  }
}

/// Where a popup's content draws: tells the menus below that they are in a popup of their
/// own (their glass comes from the compositor, their submenus are popups too).
class SilicaPopupScope extends InheritedWidget {
  const SilicaPopupScope({
    super.key,
    required this.viewId,
    required this.overlay,
    required super.child,
  });

  /// The popup's view id, the parent of the popups opened from inside it.
  final int viewId;

  /// The overlay of the window the popup belongs to, where popups are put and measured: the
  /// popup's own tree has none above it (`Overlay.of` does not cross into a view).
  final OverlayState overlay;

  /// The popup the widgets under [context] are drawn in; null in a window.
  static SilicaPopupScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SilicaPopupScope>();

  @override
  bool updateShouldNotify(SilicaPopupScope old) =>
      old.viewId != viewId || old.overlay != overlay;
}

/// The overlay popups of the widgets under [context] go into: the root overlay of their
/// window, also when they are in a popup of their own.
OverlayState? rootOverlayOf(BuildContext context) =>
    Overlay.maybeOf(context, rootOverlay: true) ??
    SilicaPopupScope.maybeOf(context)?.overlay;

/// Measures what [builder] builds when it can take all the room it wants (at most
/// [maxSize]), without showing it: in an overlay entry that is laid out and never drawn.
/// Null when there is no overlay above [context] (or no [overlay] given).
Future<Size?> measureInOverlay(
  BuildContext context,
  Widget Function(BuildContext context) builder, {
  Size maxSize = const Size(double.infinity, double.infinity),
  OverlayState? overlay,
}) {
  overlay ??= rootOverlayOf(context);
  if (overlay == null) return Future.value();
  final done = Completer<Size?>();
  final key = GlobalKey();
  late final OverlayEntry entry;
  void finish(Size? size) {
    if (done.isCompleted) return;
    entry.remove();
    entry.dispose();
    done.complete(size);
  }

  entry = OverlayEntry(
    builder: (context) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final box = key.currentContext?.findRenderObject();
        finish(box is RenderBox && box.hasSize ? box.size : null);
      });
      return Offstage(
        child: Align(
          alignment: Alignment.topLeft,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxSize.width,
              maxHeight: maxSize.height,
            ),
            child: KeyedSubtree(key: key, child: builder(context)),
          ),
        ),
      );
    },
  );
  overlay.insert(entry);
  WidgetsBinding.instance.ensureVisualUpdate();
  return done.future;
}
