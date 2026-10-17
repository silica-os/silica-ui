// The appearance override: an app or a window that is always dark (Clock) or always light,
// whatever the system appearance is, as `NSApp.appearance` / `NSWindow.appearance` do on
// macOS.
//
// The override has two levels, as on macOS: the window's ([SilicaAppearanceScope.appearance])
// and the app's ([SilicaApp.appearance]). The window's wins unless it is
// [SilicaAppearance.system], in which case the app's applies, and when that is `system` too,
// the system's.
//
// Every component of the library reads the brightness through [SilicaAppearance.isDark], the
// only place that decides it. Under a scope with an override the colors, tokens, menus and
// alerts of the library resolve against it, and so does `MediaQuery.platformBrightness` (for
// the widgets of the app that read it). The override is also sent to the embedder for the
// window (`silica-window-v1` › `set_appearance`), so Ossido draws the traffic lights, the
// title bar, the shadow and the glass of the window in the same appearance.

import 'package:flutter/widgets.dart';

import 'system_look.dart' show SystemLookScope;
import 'window.dart' show SilicaWindow;

/// How an app or a window picks between the light and the dark appearance.
enum SilicaAppearance {
  /// Follow the system (`MediaQuery.platformBrightness`), the default.
  system,

  /// Always light.
  light,

  /// Always dark.
  dark;

  /// The brightness this appearance forces; null for [system].
  Brightness? get brightness => switch (this) {
    SilicaAppearance.system => null,
    SilicaAppearance.light => Brightness.light,
    SilicaAppearance.dark => Brightness.dark,
  };

  /// The value on the wire (`silica/window` › `setAppearance`).
  String get wireName => name;

  /// Whether what is drawn under [context] is dark: the override of the closest
  /// [SilicaAppearanceScope] (or the app's), otherwise the system's. The library reads the
  /// brightness only here; an app that draws its own colors should too.
  static bool isDark(BuildContext context) =>
      brightnessOf(context) == Brightness.dark;

  /// The brightness in effect under [context] (see [isDark]).
  static Brightness brightnessOf(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<_ResolvedAppearance>();
    final forced = scope?.brightness;
    if (forced != null) return forced;
    return MediaQuery.maybePlatformBrightnessOf(context) ?? Brightness.light;
  }
}

/// The app-level override (`SilicaApp.appearance`), listened to by the scopes.
final ValueNotifier<SilicaAppearance> appAppearance = ValueNotifier(
  SilicaAppearance.system,
);

/// How many scopes are in the tree: with none, the app-level setter tells the embedder itself.
int activeAppearanceScopes = 0;

/// The brightness in effect under it, for [SilicaAppearance.isDark].
class _ResolvedAppearance extends InheritedWidget {
  const _ResolvedAppearance({required this.brightness, required super.child});

  /// Null: no override, the system's.
  final Brightness? brightness;

  @override
  bool updateShouldNotify(_ResolvedAppearance old) =>
      old.brightness != brightness;
}

/// Gives the widgets below it the [appearance] of the window (or, when it is `system`, the
/// app's [SilicaApp.appearance], or the system's).
///
/// Put one at the root of the app, above the `WidgetsApp`, so that the overlays (menus,
/// alerts) are under it too:
///
/// ```dart
/// SilicaAppearanceScope(
///   appearance: SilicaAppearance.dark, // Clock is always dark
///   child: MyApp(),
/// )
/// ```
///
/// It also sends the effective appearance to the embedder for the window.
class SilicaAppearanceScope extends StatefulWidget {
  const SilicaAppearanceScope({
    super.key,
    this.appearance = SilicaAppearance.system,
    required this.child,
  });

  /// The window's appearance; `system` leaves it to the app's.
  final SilicaAppearance appearance;

  final Widget child;

  @override
  State<SilicaAppearanceScope> createState() => _SilicaAppearanceScopeState();
}

class _SilicaAppearanceScopeState extends State<SilicaAppearanceScope> {
  SilicaAppearance? _sent;

  /// The window (view) the scope is in: its own override in Ossido (silica-desktop#146).
  int _viewId = 0;

  SilicaAppearance get _effective =>
      widget.appearance != SilicaAppearance.system
      ? widget.appearance
      : appAppearance.value;

  @override
  void initState() {
    super.initState();
    activeAppearanceScopes++;
    appAppearance.addListener(_appChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final viewId = View.maybeOf(context)?.viewId ?? 0;
    if (viewId != _viewId) _sent = null;
    _viewId = viewId;
    _send();
  }

  @override
  void didUpdateWidget(SilicaAppearanceScope old) {
    super.didUpdateWidget(old);
    _send();
  }

  @override
  void dispose() {
    appAppearance.removeListener(_appChanged);
    activeAppearanceScopes--;
    super.dispose();
  }

  void _appChanged() {
    _send();
    setState(() {});
  }

  /// Tells the embedder when the effective appearance changes.
  void _send() {
    final effective = _effective;
    if (_sent == effective) return;
    _sent = effective;
    SilicaWindow.setAppearance(effective, viewId: _viewId);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = _effective.brightness;
    Widget child = widget.child;
    if (brightness != null) {
      // The widgets of the app that read `MediaQuery.platformBrightness` follow too.
      final media = MediaQuery.maybeOf(context);
      if (media != null) {
        child = MediaQuery(
          data: media.copyWith(platformBrightness: brightness),
          child: child,
        );
      }
    }
    return _ResolvedAppearance(
      brightness: brightness,
      child: SystemLookScope(child: child),
    );
  }
}
