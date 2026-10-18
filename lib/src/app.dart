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

import 'about.dart';
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

  static SilicaAppInfo _info = const SilicaAppInfo(name: '');

  /// What the app says about itself (name, version, copyright, icon): the About panel shows
  /// it and the standard app menu is named after it (silica-ui#99). Set once at start.
  static SilicaAppInfo get info => _info;
  static set info(SilicaAppInfo value) => _info = value;

  /// App › Settings… (⌘,): the app's settings window. The standard app menu has the item only
  /// when it is set (never a disabled placeholder).
  static VoidCallback? onSettings;

  /// App › About <App>: the standard About panel ([showSilicaAbout]) of [info], named [name]
  /// when given (the app menu's name, in the user's language).
  static Future<void> showAbout({String? name}) async {
    await showSilicaAbout(
      info: name == null ? null : info.copyWith(name: name),
    );
  }

  static String? _iconFolder;
  static bool _iconFolderAsked = false;

  /// The `icon/` folder installed next to the app's bundle (the embedder says where the bundle
  /// is); null outside Silica, on an older embedder or without one.
  static Future<String?> iconFolder() async {
    if (_iconFolderAsked) return _iconFolder;
    _iconFolderAsked = true;
    final bundle = await askBundle(channel);
    _iconFolder = bundle == null ? null : iconFolderNextTo(bundle);
    return _iconFolder;
  }

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

  static bool _stayWindowless = false;
  static bool _reopenOpensFiles = false;

  /// Called from [onReopen]: the app answers this reopen without a window for now (a document
  /// app showing its Open panel, APP-LC): the hidden window is not shown, neither after
  /// [onReopen] nor by the embedder's own timer. If a document is chosen later the app builds
  /// its window and calls [openWindow].
  static void stayWindowless() {
    _stayWindowless = true;
    unawaited(_invoke('stayWindowless'));
  }

  /// During [onReopen]: whether files follow this reopen ([onOpen], a second launch with
  /// documents), so a document app has something to show and asks for nothing.
  static bool get reopenOpensFiles => _reopenOpensFiles;

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
          _stayWindowless = false;
          _reopenOpensFiles = args['files'] == true;
          try {
            await build();
          } finally {
            _reopenOpensFiles = false;
          }
          if (_stayWindowless) {
            _stayWindowless = false;
            return true;
          }
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
    _stayWindowless = false;
    _reopenOpensFiles = false;
    _info = const SilicaAppInfo(name: '');
    onSettings = null;
    _iconFolder = null;
    _iconFolderAsked = false;
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
    this.chooseDocument,
    this.startsWithDocument = true,
    this.windowlessBuilder,
  });

  /// Builds the window's content; called again for every new window.
  final WidgetBuilder builder;

  /// After the window closed, with the app still running.
  final VoidCallback? onClosed;

  /// Before the new window is built (an app can reset or reload what it shows).
  final Future<void> Function()? onReopen;

  /// A document app with nothing to show asks for its document first, as the reference does
  /// (APP-LC): its Open panel alone, no empty window. Called at launch when
  /// [startsWithDocument] is false, at every reopen and by the `open` callback of
  /// [windowlessBuilder]; the window is built and shown only when it answers true (a document
  /// was chosen), otherwise the app stays running with no window.
  final Future<bool> Function()? chooseDocument;

  /// Whether the app was launched with a document to show. Without one, and with
  /// [chooseDocument], the window is not shown at launch: [chooseDocument] runs instead.
  final bool startsWithDocument;

  /// What the app has while it has no window (the menus a windowless app still offers: File ›
  /// Open…); `open` runs [chooseDocument] and shows the window when a document is chosen.
  final Widget Function(BuildContext context, Future<void> Function() open)?
  windowlessBuilder;

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
    if (widget.chooseDocument != null && !widget.startsWithDocument) {
      // No document: the window goes before its first frame and only the Open panel shows.
      _open = false;
      unawaited(SilicaApp.closeWindow());
      unawaited(_openDocument());
    }
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
    final opensFiles = SilicaApp.reopenOpensFiles;
    await widget.onReopen?.call();
    if (!mounted) return;
    if (widget.chooseDocument != null && !opensFiles) {
      // The Open panel alone: the hidden window stays hidden while it is up, and the new
      // window shows only if a document is chosen.
      SilicaApp.stayWindowless();
      unawaited(_openDocument());
      return;
    }
    setState(() {
      _open = true;
      _generation++;
    });
  }

  bool _choosing = false;

  /// Asks for a document while there is no window, and shows the new window when one is
  /// chosen (launch without a document, File › Open… of [SilicaAppWindow.windowlessBuilder]).
  Future<void> _openDocument() async {
    final choose = widget.chooseDocument;
    if (choose == null || _open || _choosing) return;
    _choosing = true;
    final chosen = await choose();
    _choosing = false;
    if (!chosen || !mounted || _open) return;
    setState(() {
      _open = true;
      _generation++;
    });
    // Shown after the frame that draws it.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      unawaited(SilicaApp.openWindow());
    });
    SchedulerBinding.instance.scheduleFrame();
  }

  @override
  Widget build(BuildContext context) {
    if (_open) {
      return KeyedSubtree(
        key: ValueKey(_generation),
        child: Builder(builder: widget.builder),
      );
    }
    final windowless = widget.windowlessBuilder;
    return windowless == null
        ? const SizedBox.shrink()
        : Builder(builder: (context) => windowless(context, _openDocument));
  }
}
