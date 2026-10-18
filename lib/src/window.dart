// The app window and the unified toolbar (windows.md, mustache-spec 1.2).
//
// With full-size content (Ossido's `silica-window-v1`, the embedder's `silica/window`
// channel) Ossido does not add its title bar: the app draws the toolbar at the top (52 pt)
// and Ossido puts the window buttons over it, centered in that band. Dragging the empty
// part of the bar moves the window (`WindowDragArea`).
//
// The toolbar capsules: 38 high with 7 pt above and below, radius 19; fill `#f6f6f6` →
// `#fdfdfd`, outline `#ebebeb` above, `#e8e7e8` below, `#c1c1c1` on the sides; the chosen segment
// is a 34 × 28 pill inset by 5 pt, `#e2e2e2` → `#e7e7e7`. The capsules themselves, their
// hover highlight, the press growth and the glow are in `toolbar.dart`.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'appearance.dart';
import 'double_tap.dart';
import 'toolbar.dart' show ToolbarGlassMetrics;
import 'windows.dart' show SilicaWindows;

/// Height of the unified toolbar.
const double toolbarHeight = 52;
const double toolbarCapsuleHeight = 38;

/// The right edge of the third window button on a 52 pt bar (titlebar.md: discs of 14 pt centred
/// at x 26, 49, 72): the bar items that share the bar with the buttons start after it.
const double windowButtonsRight = 79;

/// The app window, towards Ossido. Every call takes the window's `viewId` (0, the main
/// window, by default; `View.of(context).viewId` inside a window opened with
/// `SilicaWindows.openWindow`).
abstract final class SilicaWindow {
  static const MethodChannel channel = MethodChannel(
    'silica/window',
    JSONMethodCodec(),
  );

  /// Full-size content with a toolbar `toolbar` high (0: back to Ossido's
  /// title bar). True if Ossido offers it.
  static Future<bool> setFullSizeContent(
    double toolbar, {
    int viewId = 0,
  }) async {
    SilicaWindows.listen();
    try {
      final reply = await channel.invokeMethod<Object?>('setFullSizeContent', {
        'toolbarHeight': toolbar,
        ..._view(viewId),
      });
      return reply == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// Overrides the system appearance for this window in Ossido (`silica-window-v1` ›
  /// `set_appearance`): the traffic lights, the plain title bar and its title, the shadow, the
  /// glass the window declares and the arrangement popover. [SilicaAppearanceScope] and
  /// `SilicaApp.appearance` call it; true if Ossido offers it.
  static Future<bool> setAppearance(
    SilicaAppearance appearance, {
    int viewId = 0,
  }) => _call('setAppearance', {
    'appearance': appearance.wireName,
    ..._view(viewId),
  });

  /// Chooses the window size (logical pixels). True if Silica applied it.
  static Future<bool> setSize(Size size, {int viewId = 0}) => _call('setSize', {
    'width': size.width,
    'height': size.height,
    ..._view(viewId),
  });

  /// Limits for resizing the window; `null` for no limit. `min` = `max` makes the window
  /// fixed-size: Ossido disables the zoom button. True if Silica applied them.
  static Future<bool> setSizeLimits({Size? min, Size? max, int viewId = 0}) =>
      _call('setSizeLimits', {
        if (min != null) 'minWidth': min.width,
        if (min != null) 'minHeight': min.height,
        if (max != null) 'maxWidth': max.width,
        if (max != null) 'maxHeight': max.height,
        ..._view(viewId),
      });

  /// A fixed-size window of `size` (limits and size together).
  static Future<bool> setFixedSize(Size size, {int viewId = 0}) async =>
      await setSizeLimits(min: size, max: size, viewId: viewId) &&
      await setSize(size, viewId: viewId);

  /// The `viewId` argument: left out for the main window, as an earlier embedder expects.
  static Map<String, Object> _view(int viewId) =>
      viewId == 0 ? const {} : {'viewId': viewId};

  static Future<bool> _call(String method, Map<String, Object?> args) async {
    SilicaWindows.listen();
    try {
      return await channel.invokeMethod<Object?>(method, args) == true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  /// The window's identifier for another app (`"wayland:<handle>"`, an xdg-foreign v2 export
  /// that lives as long as the window): the `parent_window` of xdg-desktop-portal, so that the
  /// Open and Save dialogs attach to this window (they open over it, stay above it and give it
  /// the focus back). Null outside Silica or with an embedder or compositor without it.
  static Future<String?> exportHandle({int viewId = 0}) async {
    try {
      final reply = await channel.invokeMethod<Object?>(
        'exportHandle',
        viewId == 0 ? null : _view(viewId),
      );
      return reply is String && reply.startsWith('wayland:') ? reply : null;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Tests: the environment to read the user's choice from.
  @visibleForTesting
  static Map<String, String>? debugEnvironment;

  /// Zooms the window (xdg_toplevel `set_maximized`), or puts it back when it is zoomed.
  /// True if Silica applied it.
  static Future<bool> zoom({int viewId = 0}) => _call('zoom', _view(viewId));

  /// Minimizes the window to the Dock. True if Silica applied it.
  static Future<bool> minimize({int viewId = 0}) =>
      _call('minimize', _view(viewId));

  /// What a double click on the empty part of the title bar does, from the user's choice in
  /// Settings › Desktop & Dock (`titleBarDoubleClick` in `silica/dock.json`: `zoom`, the
  /// default, `minimize` or `none`).
  static TitleBarDoubleClick titleBarDoubleClick({Map<String, String>? env}) {
    final e = env ?? debugEnvironment ?? Platform.environment;
    final home = e['HOME'] ?? '';
    final config = e['XDG_CONFIG_HOME'] ?? '$home/.config';
    try {
      final json = jsonDecode(
        File('$config/silica/dock.json').readAsStringSync(),
      );
      if (json is Map) {
        return switch (json['titleBarDoubleClick']) {
          'minimize' => TitleBarDoubleClick.minimize,
          'none' => TitleBarDoubleClick.none,
          _ => TitleBarDoubleClick.zoom,
        };
      }
    } on FileSystemException {
      // The default.
    } on FormatException {
      // Likewise.
    }
    return TitleBarDoubleClick.zoom;
  }

  /// Runs the user's double click action on the window.
  static Future<bool> doubleClickTitleBar({int viewId = 0}) =>
      switch (titleBarDoubleClick()) {
        TitleBarDoubleClick.zoom => zoom(viewId: viewId),
        TitleBarDoubleClick.minimize => minimize(viewId: viewId),
        TitleBarDoubleClick.none => Future.value(false),
      };

  /// Moves the window with the pointer pressed (from the toolbar).
  static Future<void> startMove({int viewId = 0}) async {
    try {
      await channel.invokeMethod<Object?>(
        'startMove',
        viewId == 0 ? null : _view(viewId),
      );
    } on MissingPluginException {
      // Outside Silica the window does not move from here.
    } on PlatformException {
      // Likewise.
    }
  }
}

/// The action of a double click on the title bar (Settings › Desktop & Dock).
enum TitleBarDoubleClick { zoom, minimize, none }

/// The empty part of the toolbar: dragging it moves the window. A press that lands on an
/// interactive widget inside `child` (a button, a segmented control, a search field: anything
/// that listens to pointers) never starts a move: it belongs to that control, as on macOS.
///
/// The decision is made at the press by hit-testing, so controls need no opt-out. The move
/// itself is the client request (`xdg_toplevel.move` with the press serial), as xdg-shell
/// intends; Ossido does not start moves on its own in the toolbar.
class WindowDragArea extends StatefulWidget {
  const WindowDragArea({super.key, required this.child});
  final Widget child;

  @override
  State<WindowDragArea> createState() => _WindowDragAreaState();
}

class _WindowDragAreaState extends State<WindowDragArea> {
  final GlobalKey _content = GlobalKey();

  /// Whether the press lands on a widget inside the content that handles pointers.
  bool _onControl(PointerDownEvent event) {
    final root = _content.currentContext?.findRenderObject();
    if (root == null) return false;
    final result = HitTestResult();
    WidgetsBinding.instance.hitTestInView(result, event.position, event.viewId);
    for (final entry in result.path) {
      final target = entry.target;
      if (target is! RenderObject || !_within(target, root)) continue;
      if (target is RenderPointerListener &&
          target.onPointerDown != null &&
          !_passesThrough(target, root)) {
        return true;
      }
    }
    return false;
  }

  /// Whether [node] sits inside a [WindowDragThrough] below [root].
  static bool _passesThrough(RenderObject node, RenderObject root) {
    for (
      RenderObject? n = node;
      n != null && !identical(n, root);
      n = n.parent
    ) {
      if (n is _RenderDragThrough) return true;
    }
    return false;
  }

  static bool _within(RenderObject node, RenderObject root) {
    for (RenderObject? n = node; n != null; n = n.parent) {
      if (identical(n, root)) return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => RawGestureDetector(
    behavior: HitTestBehavior.translucent,
    gestures: {
      _EmptyAreaDoubleTap:
          GestureRecognizerFactoryWithHandlers<_EmptyAreaDoubleTap>(
            () => _EmptyAreaDoubleTap(_onControl),
            (r) {
              r.isControl = _onControl;
              r.onDoubleTap = () => SilicaWindow.doubleClickTitleBar(
                viewId: View.maybeOf(context)?.viewId ?? 0,
              );
            },
          ),
      _EmptyAreaPan: GestureRecognizerFactoryWithHandlers<_EmptyAreaPan>(
        () => _EmptyAreaPan(_onControl),
        (r) {
          r.isControl = _onControl;
          // The window the bar belongs to (several windows, silica-desktop#146).
          r.onStart = (_) => SilicaWindow.startMove(
            viewId: View.maybeOf(context)?.viewId ?? 0,
          );
        },
      ),
    },
    child: KeyedSubtree(key: _content, child: widget.child),
  );
}

/// Marks [child] as part of the drag area although it listens to pointers: a press on it
/// still starts a window move when it turns into a drag, and stays a click otherwise. For
/// click-only pieces that cover bar text, such as a document title with a menu.
class WindowDragThrough extends SingleChildRenderObjectWidget {
  const WindowDragThrough({super.key, super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderDragThrough();
}

class _RenderDragThrough extends RenderProxyBox {}

/// A double tap that ignores the presses that fall on a control.
class _EmptyAreaDoubleTap extends SilicaDoubleTapRecognizer {
  _EmptyAreaDoubleTap(this.isControl);
  bool Function(PointerDownEvent event) isControl;

  @override
  bool isPointerAllowed(PointerDownEvent event) =>
      !isControl(event) && super.isPointerAllowed(event);
}

/// A pan that ignores the presses that fall on a control.
class _EmptyAreaPan extends PanGestureRecognizer {
  _EmptyAreaPan(this.isControl);
  bool Function(PointerDownEvent event) isControl;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (isControl(event)) return;
    super.addAllowedPointer(event);
  }
}

/// The toolbar colors (mustache-spec 1.2; states from mustache.md M6 › MU-07, measured at
/// the center of the pill, outside the glyph).
@immutable
class ToolbarColors {
  const ToolbarColors({
    required this.fill,
    required this.fillBarHover,
    required this.fillInactive,
    required this.borderTop,
    required this.borderBottom,
    required this.borderSide,
    required this.hover,
    required this.hoverInactive,
    required this.pressed,
    required this.chosen,
    required this.chosenHover,
    required this.chosenPressed,
    required this.chosenInactive,
    required this.chosenHoverInactive,
    required this.disabledPressed,
    required this.separator,
    required this.icon,
    required this.iconPressed,
    required this.iconInactive,
    required this.iconDisabled,
    required this.title,
    required this.titleInactive,
    this.glow = const Color(0x00FFFFFF),
  });

  /// The capsule fill at rest; with the pointer in the bar (in dark +7 levels);
  /// in the inactive window.
  final Color fill;
  final Color fillBarHover;
  final Color fillInactive;
  final Color borderTop;
  final Color borderBottom;
  final Color borderSide;

  /// The pill under the pointer (active and inactive) and pressed.
  final Color hover;
  final Color hoverInactive;
  final Color pressed;

  /// The chosen segment: at rest, under the pointer, pressed; in the inactive window.
  final Color chosen;
  final Color chosenHover;
  final Color chosenPressed;
  final Color chosenInactive;
  final Color chosenHoverInactive;

  /// No longer drawn: a pressed disabled segment shows only the pressed glow ([glow]) and the
  /// growth, without a pill (TITLEBAR-GLASS). Kept for API stability.
  final Color? disabledPressed;
  final Color separator;
  final Color icon;
  final Color iconPressed;
  final Color iconInactive;
  final Color iconDisabled;
  final Color title;
  final Color titleInactive;

  /// The pressed glow at the pointer (TITLEBAR-GLASS): +22 levels over the dark capsule
  /// (white at 12 %), fading as a Gaussian with σ = [ToolbarGlassMetrics.glowSigma]. In light the
  /// glow is not visible (≤ 1 level): transparent.
  final Color glow;

  static const ToolbarColors light = ToolbarColors(
    fill: Color(0xFFF8F8F8),
    fillBarHover: Color(0xFFF8F8F8),
    fillInactive: Color(0xFFF0F0F0),
    borderTop: Color(0xFFEBEBEB),
    borderBottom: Color(0xFFE8E7E8),
    borderSide: Color(0xFFC1C1C1),
    hover: Color(0xFFEEEEEE),
    hoverInactive: Color(0xFFE6E6E6),
    pressed: Color(0xFFE8E8E8),
    chosen: Color(0xFFE5E5E5),
    chosenHover: Color(0xFFDBDBDB),
    chosenPressed: Color(0xFFD2D2D2),
    chosenInactive: Color(0xFFDCDCDC),
    chosenHoverInactive: Color(0xFFD2D2D2),
    disabledPressed: null,
    separator: Color(0xFFC7C7C7),
    icon: Color(0xFF000000),
    iconPressed: Color(0xFF232323),
    iconInactive: Color(0xFFA4A4A4),
    iconDisabled: Color(0xFFADADAD),
    title: Color(0xFF4D4D4D),
    titleInactive: Color(0xFFBEBEBE),
  );

  /// Dark: capsule `#434344` (`#4a4a4b` with the pointer in the bar), outline
  /// `#79797b` / `#6c6e6e` / `#131313`, separator `#7a7a7a`, title `#e9e9e9` / `#646464`.
  static const ToolbarColors dark = ToolbarColors(
    fill: Color(0xFF434344),
    fillBarHover: Color(0xFF4A4A4B),
    fillInactive: Color(0xFF424243),
    borderTop: Color(0xFF79797B),
    borderBottom: Color(0xFF6C6E6E),
    borderSide: Color(0xFF131313),
    hover: Color(0xFF5E5E5F),
    hoverInactive: Color(0xFF565657),
    pressed: Color(0xFF737374),
    chosen: Color(0xFF575758),
    chosenHover: Color(0xFF727273),
    chosenPressed: Color(0xFF757576),
    chosenInactive: Color(0xFF565657),
    chosenHoverInactive: Color(0xFF6A6A6B),
    disabledPressed: Color(0xFF626264),
    separator: Color(0xFF7A7A7A),
    icon: Color(0xFFFFFFFF),
    iconPressed: Color(0xFFF8F8F8),
    iconInactive: Color(0xFF757576),
    iconDisabled: Color(0xFF787879),
    title: Color(0xFFE9E9E9),
    titleInactive: Color(0xFF646464),
    glow: Color(0x1FFFFFFF),
  );

  /// Following the appearance in effect (the override, otherwise the system's).
  static ToolbarColors of(BuildContext context) =>
      SilicaAppearance.isDark(context) ? dark : light;
}

/// The bar state the controls read: the active window and the pointer in the bar
/// (in dark the capsules lighten by 7 levels).
class ToolbarScope extends InheritedWidget {
  const ToolbarScope({
    super.key,
    required super.child,
    this.active = true,
    this.hovered = false,
  });

  final bool active;
  final bool hovered;

  static ToolbarScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ToolbarScope>();

  @override
  bool updateShouldNotify(ToolbarScope old) =>
      old.active != active || old.hovered != hovered;
}

/// Tells the toolbar capsules that content scrolls under them (`ScrollUnderToolbar`): they show it
/// refracted at their edges (mustache-spec R1.9).
class ToolbarOverContent extends InheritedWidget {
  const ToolbarOverContent({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ToolbarOverContent>() != null;

  @override
  bool updateShouldNotify(ToolbarOverContent old) => false;
}
