// The app's lifecycle in Silica (silica-desktop#142, measured on the reference in APP-LC), on
// the embedder's `silica/app` channel.
//
// Closing an app's last window does not end the app: the window goes away and the app keeps
// running with no window, frontmost, with its Dock dot. A reopen (a click in the Dock,
// launching the app again) asks the app for a NEW window: a document app shows its Open
// panel, Mail its main window. The closed window never comes back as it was (that would be
// minimizing). Single-window utilities (Calculator, Clock, Settings) end with their last
// window instead (`quitWhenLastWindowCloses`). Only Quit ends an app; the file manager has
// none (`quitEnabled = false`).
//
// The simplest use is `SilicaAppWindow`, which drops the window's widgets when it closes and
// builds them again from scratch on a reopen.

import 'dart:async';

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'appearance.dart';
import 'window.dart' show SilicaWindow;
import 'menu_service.dart' show SilicaMenuService;
import 'popups.dart' show SilicaPopups;
import 'windows.dart' show SilicaWindows;

/// The app's lifecycle in Silica.
abstract final class SilicaApp {
  static const MethodChannel channel = MethodChannel(
    'silica/app',
    JSONMethodCodec(),
  );

  static bool _quitWhenLastWindowCloses = false;
  static bool _quitEnabled = true;
  static bool _listening = false;
  static VoidCallback? _onLastWindowClosed;
  static Future<void> Function()? _onReopen;

  /// The app-wide appearance override, as `NSApp.appearance` on macOS: [SilicaAppearance.dark]
  /// for an app that is always dark (Clock). A window's own
  /// `SilicaAppearanceScope.appearance` wins over it; `system` (the default) follows the
  /// system. The scopes of the app follow a change, and the embedder is told for the window
  /// (when the app has no `SilicaAppearanceScope`, it is sent here).
  static SilicaAppearance get appearance => appAppearance.value;
  static set appearance(SilicaAppearance value) {
    if (appAppearance.value == value) return;
    appAppearance.value = value;
    if (activeAppearanceScopes == 0) {
      // Every window of the app (several windows, silica-desktop#146).
      SilicaWindow.setAppearance(value);
      for (final window in SilicaWindows.open.value) {
        SilicaWindow.setAppearance(value, viewId: window.viewId);
      }
    }
  }

  /// Called when the last window has closed and the app keeps running: drop what belonged
  /// to that window (its document, its terminal session).
  static VoidCallback? get onLastWindowClosed => _onLastWindowClosed;
  static set onLastWindowClosed(VoidCallback? callback) {
    _onLastWindowClosed = callback;
    _listen();
  }

  /// Called when the app, running with no window, is asked for one (the Dock, the Launcher,
  /// Faro, a second launch): build the new window. When the future completes the window is
  /// shown, after the next frame. Setting it tells the embedder the app answers reopens;
  /// without it the embedder brings the hidden window back as it was.
  static Future<void> Function()? get onReopen => _onReopen;
  static set onReopen(Future<void> Function()? callback) {
    _onReopen = callback;
    _listen();
    unawaited(
      _invoke('setHandlesReopen', <String, Object?>{'value': callback != null}),
    );
  }

  /// Called with the arguments (files) of a second launch of the running app: Open With, a
  /// share target. The embedder has already brought a window forward (after [onReopen] when
  /// the app had none).
  static void Function(List<String> args)? get onOpen => _onOpen;
  static set onOpen(void Function(List<String> args)? callback) {
    _onOpen = callback;
    _listen();
  }

  static void Function(List<String> args)? _onOpen;

  /// Whether the app ends with its last window: false by default; true for single-window
  /// utilities (Calculator, Clock, Settings on the reference).
  static bool get quitWhenLastWindowCloses => _quitWhenLastWindowCloses;
  static set quitWhenLastWindowCloses(bool value) {
    _quitWhenLastWindowCloses = value;
    unawaited(
      _invoke('setQuitWhenLastWindowCloses', <String, Object?>{'value': value}),
    );
  }

  /// Whether Quit ends the app: false for the file manager, which has no Quit (DOCK-02).
  static bool get quitEnabled => _quitEnabled;
  static set quitEnabled(bool value) {
    _quitEnabled = value;
    unawaited(_invoke('setQuitEnabled', <String, Object?>{'value': value}));
  }

  /// Shows the app's window again once the next frame is drawn (after a reopen; the
  /// embedder also shows it by itself if the app takes too long).
  static Future<void> openWindow() => _invoke('openWindow');

  /// Closes the app's window from inside (its last tab closed, the shell exited): as the
  /// close button, the app keeps running unless it quits with its last window.
  static Future<void> closeWindow() => _invoke('closeWindow');

  /// Ends the app (Quit in its menu, Cmd+Q). Ignored when [quitEnabled] is false.
  static Future<void> quit() => _invoke('quit');

  /// Whether the app is running with no window.
  static Future<bool> isHidden() async =>
      await _invoke<bool>('isHidden') ?? false;

  /// A call from the embedder; returns whether it was understood (for tests).
  static Future<bool> handle(String method, Object? args) async {
    switch (method) {
      case 'lastWindowClosed':
        _onLastWindowClosed?.call();
        return true;
      case 'reopen':
        final windowless = args is Map && args['windowless'] == true;
        final build = _onReopen;
        if (windowless && build != null) {
          await build();
          // The window is shown after the frame that draws it.
          SchedulerBinding.instance.addPostFrameCallback((_) {
            unawaited(openWindow());
          });
          SchedulerBinding.instance.scheduleFrame();
        }
        return true;
      case 'open':
        final list = args is Map ? args['args'] : null;
        if (list is List) {
          _onOpen?.call([
            for (final a in list)
              if (a is String) a,
          ]);
        }
        return true;
    }
    return false;
  }

  static void _listen() {
    if (_listening) return;
    _listening = true;
    channel.setMethodCallHandler((call) async {
      await handle(call.method, call.arguments);
      return null;
    });
  }

  static Future<T?> _invoke<T>(String method, [Object? args]) async {
    try {
      return await channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      // Outside Silica (tests, another embedder): nothing to do.
      return null;
    } on PlatformException {
      return null;
    }
  }

  /// Back to the initial state (tests).
  @visibleForTesting
  static void reset() {
    _quitWhenLastWindowCloses = false;
    _quitEnabled = true;
    appAppearance.value = SilicaAppearance.system;
    _onLastWindowClosed = null;
    _onReopen = null;
  }
}

/// The app's window content with the reference's lifecycle: when the last window closes its
/// widgets are dropped (their state with them), and a reopen builds them again from scratch
/// with [builder], a new window. App-wide state that should survive (Mail's accounts and
/// selected mailbox) lives outside [builder], in the app's model.
class SilicaAppWindow extends StatefulWidget {
  const SilicaAppWindow({
    super.key,
    required this.builder,
    this.onClosed,
    this.onReopen,
  });

  /// Builds the window's content; called again for every new window.
  final WidgetBuilder builder;

  /// After the window closed, with the app still running.
  final VoidCallback? onClosed;

  /// Before the new window is built (an app can reset or reload what it shows).
  final Future<void> Function()? onReopen;

  @override
  State<SilicaAppWindow> createState() => _SilicaAppWindowState();
}

class _SilicaAppWindowState extends State<SilicaAppWindow> {
  int _generation = 0;
  bool _open = true;

  @override
  void initState() {
    super.initState();
    SilicaApp.onLastWindowClosed = _closed;
    SilicaApp.onReopen = _reopen;
    // Whether menus and popovers can be surfaces of their own (silica-desktop#4).
    unawaited(SilicaPopups.probe());
    unawaited(SilicaMenuService.probe());
  }

  @override
  void dispose() {
    if (SilicaApp.onReopen == _reopen) SilicaApp.onReopen = null;
    if (SilicaApp.onLastWindowClosed == _closed) {
      SilicaApp.onLastWindowClosed = null;
    }
    super.dispose();
  }

  void _closed() {
    if (!mounted) return;
    setState(() => _open = false);
    widget.onClosed?.call();
  }

  Future<void> _reopen() async {
    await widget.onReopen?.call();
    if (!mounted) return;
    setState(() {
      _open = true;
      _generation++;
    });
  }

  @override
  Widget build(BuildContext context) => _open
      ? KeyedSubtree(
          key: ValueKey(_generation),
          child: Builder(builder: widget.builder),
        )
      : const SizedBox.shrink();
}
