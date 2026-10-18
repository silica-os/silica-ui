// The system look: the Appearance choices of Settings that every app follows live (accent,
// highlight, sidebar icon size, scroll bars, click in the scroll bar, icon style).
//
// The source is silica-daemon's `System1` state (`look.*` keys, typed, over the embedder's
// `silica/dbus` channel): Settings tells the daemon, the daemon keeps the values for the whole
// session. The state is read once a second (one small call, nothing is notified when nothing
// changed) so that the loader does not take the channel's single signal handler away from the
// shell or the app. Outside Silica (no channel, no daemon) the look stays the default.
//
// [SystemLookScope] is installed by [SilicaAppearanceScope]; an app that has none puts it at
// its root. Everything below follows: the Amalfi controls (accent, selection), the sidebars
// (icon size), the scroll bars (style and click), [SilicaIcon] (icon style).

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'appearance.dart' show SilicaAppearance;
import 'controls/control_base.dart';
import 'dbus.dart';

/// When scroll bars show (Appearance › show scroll bars).
enum SystemScrollBars {
  /// Overlay with a trackpad, always with a mouse. Silica has one overlay style.
  automatic,
  whenScrolling,
  always;

  static SystemScrollBars parse(Object? name) =>
      values.where((v) => v.name == name).firstOrNull ?? automatic;
}

/// What a click in the scroll bar's track does.
enum SystemScrollClick {
  /// Scrolls one page toward the click.
  page,

  /// Jumps to the spot clicked.
  spot;

  static SystemScrollClick parse(Object? name) =>
      values.where((v) => v.name == name).firstOrNull ?? page;
}

/// The size of the rows of a sidebar.
enum SystemSidebarIconSize {
  small,
  medium,
  large;

  static SystemSidebarIconSize parse(Object? name) =>
      values.where((v) => v.name == name).firstOrNull ?? medium;

  /// The row height, the icon side and the text size (null: the sidebar's own), in pt. Medium is
  /// the Amalfi sidebar's;
  /// small and large are provisional (unmeasured).
  ({double row, double icon, double? text}) get metrics => switch (this) {
    small => (row: 28, icon: 16, text: 13),
    medium => (row: 32, icon: 20, text: null),
    large => (row: 40, icon: 24, text: 16),
  };
}

/// The style of the icons (Appearance › icon and widget style).
enum SystemIconStyle {
  standard('default'),
  dark('dark'),
  clear('clear'),
  tinted('tinted');

  const SystemIconStyle(this.wire);

  /// The value on the wire.
  final String wire;

  static SystemIconStyle parse(Object? name) =>
      values.where((v) => v.wire == name).firstOrNull ?? standard;
}

/// The look chosen in Settings.
@immutable
class SystemLook {
  const SystemLook({
    this.accent = SilicaAccent.multicolor,
    this.highlight,
    this.sidebarIconSize = SystemSidebarIconSize.medium,
    this.scrollBars = SystemScrollBars.automatic,
    this.scrollClick = SystemScrollClick.page,
    this.iconStyle = SystemIconStyle.standard,
    this.folderColour,
    this.glass = 0.5,
    this.windowTint = false,
    this.keyboardNavigation = false,
    this.doubleClickMs = 300,
    this.reduceTransparency = false,
    this.reduceMotion = false,
    this.increaseContrast = false,
  });

  /// The accent of the controls.
  final SilicaAccent accent;

  /// The text highlight colour; null: the accent.
  final SilicaAccent? highlight;

  final SystemSidebarIconSize sidebarIconSize;
  final SystemScrollBars scrollBars;
  final SystemScrollClick scrollClick;
  final SystemIconStyle iconStyle;

  /// The colour of the folders; null: automatic.
  final SilicaAccent? folderColour;

  /// The opacity of the glass, 0-1 (applied by the compositor).
  final double glass;

  /// Windows tinted with the wallpaper colour (applied by the compositor).
  final bool windowTint;

  /// Tab reaches every control, not only text fields and lists (Settings › Keyboard).
  final bool keyboardNavigation;

  /// The longest time between the two clicks of a double click, in milliseconds (Settings ›
  /// Mouse; 300 by default).
  final int doubleClickMs;

  /// Glass is drawn opaque (Settings › Accessibility › Display).
  final bool reduceTransparency;

  /// Animations are skipped: [MediaQuery.disableAnimations] is true under the scope.
  final bool reduceMotion;

  /// The high-contrast palette (Settings › Accessibility › Display › Increase Contrast).
  final bool increaseContrast;

  /// The look from the daemon's `State()` dictionary (`look.*` keys); a missing or odd value is
  /// the default.
  static SystemLook fromState(Map<Object?, Object?> state) {
    Object? get(String key) => state['look.$key'];
    final glass = get('glass');
    return SystemLook(
      accent: parseAccent(get('accent')) ?? SilicaAccent.multicolor,
      highlight: parseAccent(get('highlight')),
      sidebarIconSize: SystemSidebarIconSize.parse(get('sidebarIconSize')),
      scrollBars: SystemScrollBars.parse(get('scrollBars')),
      scrollClick: SystemScrollClick.parse(get('scrollClick')),
      iconStyle: SystemIconStyle.parse(get('iconStyle')),
      folderColour: parseAccent(get('folderColour')),
      glass: glass is num && glass.isFinite
          ? glass.toDouble().clamp(0.0, 1.0)
          : 0.5,
      windowTint: get('windowTint') == true,
      keyboardNavigation: get('keyboardNavigation') == true,
      reduceTransparency: get('reduceTransparency') == true,
      reduceMotion: get('reduceMotion') == true,
      increaseContrast: get('increaseContrast') == true,
      doubleClickMs: switch (get('doubleClickMs')) {
        final num n when n.isFinite => n.round().clamp(150, 1000),
        _ => 300,
      },
    );
  }

  /// An accent by name (`multicolour` and `multicolor` both); null for `automatic` and unknown
  /// names.
  static SilicaAccent? parseAccent(Object? name) {
    if (name == 'multicolour') return SilicaAccent.multicolor;
    return SilicaAccent.values.where((v) => v.name == name).firstOrNull;
  }

  /// The colour of [accent] for the Amalfi controls; null for the multicolour accent (the
  /// Amalfi blue stays).
  static Color? amalfiColor(SilicaAccent accent, {required bool dark}) =>
      accent == SilicaAccent.multicolor
      ? null
      : AccentColors.of(accent, dark: dark).plain;

  @override
  bool operator ==(Object other) =>
      other is SystemLook &&
      other.accent == accent &&
      other.highlight == highlight &&
      other.sidebarIconSize == sidebarIconSize &&
      other.scrollBars == scrollBars &&
      other.scrollClick == scrollClick &&
      other.iconStyle == iconStyle &&
      other.folderColour == folderColour &&
      other.glass == glass &&
      other.windowTint == windowTint &&
      other.keyboardNavigation == keyboardNavigation &&
      other.doubleClickMs == doubleClickMs &&
      other.reduceTransparency == reduceTransparency &&
      other.reduceMotion == reduceMotion &&
      other.increaseContrast == increaseContrast;

  @override
  int get hashCode => Object.hash(
    accent,
    highlight,
    sidebarIconSize,
    scrollBars,
    scrollClick,
    iconStyle,
    folderColour,
    glass,
    windowTint,
    keyboardNavigation,
    doubleClickMs,
    reduceTransparency,
    reduceMotion,
    increaseContrast,
  );

  @override
  String toString() =>
      'SystemLook($accent, highlight: $highlight, $sidebarIconSize, $scrollBars, '
      '$scrollClick, $iconStyle)';
}

/// Follows the look in silica-daemon and tells whoever listens when it changes.
///
/// The state is read once when the first [SystemLookScope] appears, then follows the daemon's
/// `Changed` signal (the whole state, in every emission) and a daemon that appears later
/// (`NameOwnerChanged`). The channel is [SilicaDBus]'s, shared with the app and the shell.
abstract final class SilicaSystemLook {
  /// The look in effect.
  static final ValueNotifier<SystemLook> notifier = ValueNotifier(
    const SystemLook(),
  );

  static SystemLook get current => notifier.value;

  static const String _name = 'dev.frascella.Silica';
  static const String _path = '/dev/frascella/Silica/System1';
  static const String _interface = 'dev.frascella.Silica.System1';

  static StreamSubscription<SilicaDBusSignal>? _changed;
  static StreamSubscription<SilicaDBusSignal>? _owner;
  static SilicaDBus _bus = SilicaDBus.instance;
  static int _users = 0;
  static int _epoch = 0;

  /// Starts following the daemon (counted: every [SystemLookScope] asks, the last to leave
  /// stops it). The first read is immediate.
  static void acquire() {
    if (_users++ > 0) return;
    unawaited(refresh());
    _changed = _bus
        .signals(
          sender: _name,
          path: _path,
          interface: _interface,
          member: 'Changed',
        )
        .listen(
          _onChanged,
          onError: (Object _) {
            // Outside Silica there are no signals: the default look stays.
          },
        );
    _owner = _bus
        .signals(
          sender: 'org.freedesktop.DBus',
          interface: 'org.freedesktop.DBus',
          member: 'NameOwnerChanged',
        )
        .listen((signal) {
          // The daemon (re)started: read its state.
          if (signal.args.isNotEmpty && signal.args.first == _name) {
            unawaited(refresh());
          }
        }, onError: (Object _) {});
  }

  static void release() {
    if (_users == 0 || --_users > 0) return;
    unawaited(_changed?.cancel());
    unawaited(_owner?.cancel());
    _changed = null;
    _owner = null;
  }

  static void _onChanged(SilicaDBusSignal signal) {
    final first = signal.args.isEmpty ? null : signal.args.first;
    if (first is Map) _take(first, _epoch);
  }

  // A daemon without the look (older) says nothing: the look stays. A read that started before
  // the look was set here ([apply]) is dropped.
  static void _take(Map<Object?, Object?> state, int epoch) {
    if (state.containsKey('look.accent') && epoch == _epoch) {
      notifier.value = SystemLook.fromState(state);
    }
  }

  /// Sets the look now (Settings, as soon as a control is touched, before the daemon has it).
  static void apply(SystemLook look) {
    _epoch++;
    notifier.value = look;
  }

  /// Reads the daemon's state once.
  static Future<void> refresh() async {
    final epoch = _epoch;
    try {
      final reply = await _bus.call(
        destination: _name,
        path: _path,
        interface: _interface,
        method: 'State',
      );
      final first = reply.isEmpty ? null : reply.first;
      if (first is Map) _take(first, epoch);
    } on MissingPluginException {
      // Outside Silica: the default look.
    } on PlatformException {
      // No daemon (yet): NameOwnerChanged brings it.
    }
  }

  /// Back to the initial state, with [bus] as the channel (tests).
  @visibleForTesting
  static void reset({SilicaDBus? bus}) {
    unawaited(_changed?.cancel());
    unawaited(_owner?.cancel());
    _changed = null;
    _owner = null;
    _users = 0;
    _epoch = 0;
    _bus = bus ?? SilicaDBus.instance;
    notifier.value = const SystemLook();
  }
}

/// Gives the widgets below it the system look, live, and the accent of the controls
/// ([ControlAccent]) when no app accent is set above. Read with [SystemLookScope.of].
class SystemLookScope extends StatefulWidget {
  const SystemLookScope({super.key, required this.child});

  final Widget child;

  /// The look in effect under [context]; the default look without a scope.
  static SystemLook of(BuildContext context) => maybeOf(context) ?? _default;

  /// The look of the closest scope; null when there is none.
  static SystemLook? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_LookInherited>()?.look;

  static const SystemLook _default = SystemLook();

  @override
  State<SystemLookScope> createState() => _SystemLookScopeState();
}

class _SystemLookScopeState extends State<SystemLookScope> {
  @override
  void initState() {
    super.initState();
    SilicaSystemLook.acquire();
  }

  @override
  void dispose() {
    SilicaSystemLook.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<SystemLook>(
    valueListenable: SilicaSystemLook.notifier,
    builder: (context, look, _) {
      Widget child = widget.child;
      // An app's own accent (Clock's orange) above this scope stays.
      if (context.getInheritedWidgetOfExactType<ControlAccent>() == null) {
        child = ControlAccent.palette(accent: look.accent, child: child);
      }
      // Selected text in the highlight colour (automatic: the toolkit's own). The widget is
      // always there, so that a change never rebuilds the tree below.
      final highlight = look.highlight;
      final dark = SilicaAppearance.isDark(context);
      final color = highlight == null
          ? null
          : SystemLook.amalfiColor(highlight, dark: dark);
      child = DefaultSelectionStyle.merge(
        selectionColor: color?.withAlpha(dark ? 0x66 : 0x55),
        child: child,
      );
      // Reduce Motion: the widgets below see MediaQuery.disableAnimations (the wrapper is
      // always there, so a change never rebuilds the tree below).
      final media = MediaQuery.maybeOf(context);
      if (media != null) {
        child = MediaQuery(
          data: media.copyWith(
            disableAnimations: media.disableAnimations || look.reduceMotion,
          ),
          child: child,
        );
      }
      return _LookInherited(look: look, child: child);
    },
  );
}

class _LookInherited extends InheritedWidget {
  const _LookInherited({required this.look, required super.child});

  final SystemLook look;

  @override
  bool updateShouldNotify(_LookInherited old) => old.look != look;
}
