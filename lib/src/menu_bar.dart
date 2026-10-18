// The app's menus in Silica's global menu bar (silica-menu-v1, silica-desktop#25).
//
// An app declares its menus with Flutter's own `PlatformMenuBar` items, or with
// `SilicaMenuBar`, which adds what Silica's bar knows: checkmarks, explicit enabled state,
// standard roles (About, Settings, Undo, Copy…, labelled by the bar in the user's language)
// and the system items the bar runs itself (Services, Hide, Quit, Minimize, Full screen…).
// `SilicaMenuDelegate` turns the items into the protocol's JSON model and sends it on the
// embedder's `silica/menu` channel whenever it changes; the item the user chooses in the bar
// comes back as `activated`. The keyboard shortcuts stay in the app: `SilicaMenuBar` binds the
// shortcuts of its enabled items while the app has the keyboard.
//
// Outside Silica (tests, other embedders) the channel does not answer: nothing is shown, and
// the shortcuts still work.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'app.dart';
import 'windows.dart';

/// The role of a top-level menu.
enum SilicaMenuRole {
  /// One of the app's own menus (File, Edit, View…).
  none(''),

  /// The app menu: the bar titles it with the app's name, in bold.
  app('app'),

  /// The Window menu: the bar shows Minimize, Fill, Move & Resize and Full screen first, then
  /// the app's items, then Bring All to Front and the list of the app's windows.
  window('window'),

  /// The Help menu: without items the bar shows Silica Help.
  help('help');

  const SilicaMenuRole(this.wire);

  /// The name in the protocol's model.
  final String wire;
}

/// The standard items the bar knows. With an action ([SilicaMenuItem.onSelected]) the app
/// runs them and the role gives the default label and shortcut; without one, the system roles
/// are run by the bar (Quit, Hide, Minimize…) and the others are shown disabled.
enum SilicaMenuItemRole {
  none(''),
  about('about'),
  settings('settings'),
  help('help'),
  undo('undo'),
  redo('redo'),
  cut('cut'),
  copy('copy'),
  paste('paste'),
  delete('delete'),
  selectAll('select_all'),

  /// The Services submenu (system).
  services('services'),
  hide('hide'),
  hideOthers('hide_others'),
  showAll('show_all'),
  quit('quit'),

  /// Closes the active window (system, ⌘W).
  close('close'),

  /// Closes every window of the app (⌥⌘W): [SilicaMenuItem.closeAll].
  closeAll('close_all'),
  minimize('minimize'),
  fullScreen('fullscreen'),
  bringAllToFront('bring_all_to_front');

  const SilicaMenuItemRole(this.wire);

  /// The name in the protocol's model.
  final String wire;
}

/// A top-level menu or a submenu, with a [role] for the top-level ones.
class SilicaMenu extends PlatformMenu {
  const SilicaMenu({
    required super.label,
    required super.menus,
    this.role = SilicaMenuRole.none,
    this.enabled = true,
    super.onOpen,
    super.onClose,
  });

  final SilicaMenuRole role;

  /// A disabled submenu shows its title gray and does not open.
  final bool enabled;
}

/// An item with the states Silica's bar shows: a checkmark, an explicit enabled state and a
/// standard [role]. An empty [label] takes the bar's label for the role.
class SilicaMenuItem extends PlatformMenuItem {
  const SilicaMenuItem({
    super.label = '',
    super.shortcut,
    super.onSelected,
    super.onSelectedIntent,
    this.checked = false,
    this.enabled = true,
    this.role = SilicaMenuItemRole.none,
    this.icon,
  });

  /// A system item the bar runs itself (Quit, Services, Hide, Minimize, Full screen…).
  const SilicaMenuItem.system(this.role, {this.enabled = true})
    : checked = false,
      icon = null,
      super(label: '');

  /// File › Close All (⌥⌘W): closes every window of the app, the main one included, asking
  /// each that asks before closing ([SilicaWindows.closeAll]). An empty [label] takes the
  /// bar's. Disabled when [enabled] is false (nothing to close).
  SilicaMenuItem.closeAll({String label = '', this.enabled = true})
    : checked = false,
      icon = null,
      role = SilicaMenuItemRole.closeAll,
      super(
        label: label,
        shortcut: const SingleActivator(
          LogicalKeyboardKey.keyW,
          meta: true,
          alt: true,
        ),
        onSelected: SilicaWindows.closeAll,
      );

  final bool checked;
  final bool enabled;
  final SilicaMenuItemRole role;

  /// The app icon the bar draws before the label (16 pt, `Icons/App/16`): a silica-icons name
  /// or the absolute path of an app's `icon/` folder (the `X-Silica-Icon` of its desktop entry).
  final String? icon;

  /// Whether the app runs something when it is chosen.
  bool get hasAction => onSelected != null || onSelectedIntent != null;
}

/// The menus of a typical Silica app, built from the standard roles. The labels of the
/// standard items come from the bar, in the user's language.
abstract final class SilicaMenus {
  static const SingleActivator _settings = SingleActivator(
    LogicalKeyboardKey.comma,
    meta: true,
  );

  /// The standard app menu of every Silica app (silica-ui#99): About <App> (always there and
  /// enabled: [onAbout], else the standard About panel, [SilicaApp.showAbout]), Settings… ⌘,
  /// only when there is a settings action ([onSettings], else [SilicaApp.onSettings]), the
  /// app's [items], Services, Hide ⌘H, Hide Others ⌥⌘H, Show All and Quit ⌘Q. [name] is the
  /// app's name (the bar shows it in bold); empty, [SilicaApp.info]'s.
  static SilicaMenu app(
    String name, {
    VoidCallback? onAbout,
    VoidCallback? onSettings,
    List<PlatformMenuItem> items = const [],
  }) {
    final settings = onSettings ?? SilicaApp.onSettings;
    final label = name.isEmpty ? SilicaApp.info.name : name;
    return SilicaMenu(
      label: label,
      role: SilicaMenuRole.app,
      menus: [
        PlatformMenuItemGroup(
          members: [
            SilicaMenuItem(
              role: SilicaMenuItemRole.about,
              // The panel names the app as its menu does (in the user's language).
              onSelected:
                  onAbout ??
                  () => unawaited(
                    SilicaApp.showAbout(name: label.isEmpty ? null : label),
                  ),
            ),
          ],
        ),
        if (settings != null || items.isNotEmpty)
          PlatformMenuItemGroup(
            members: [
              if (settings != null)
                SilicaMenuItem(
                  role: SilicaMenuItemRole.settings,
                  shortcut: _settings,
                  onSelected: settings,
                ),
              ...items,
            ],
          ),
        const PlatformMenuItemGroup(
          members: [SilicaMenuItem.system(SilicaMenuItemRole.services)],
        ),
        const PlatformMenuItemGroup(
          members: [
            SilicaMenuItem.system(SilicaMenuItemRole.hide),
            SilicaMenuItem.system(SilicaMenuItemRole.hideOthers),
            SilicaMenuItem.system(SilicaMenuItemRole.showAll),
          ],
        ),
        // No Quit in an app that has none (the file manager, [SilicaApp.quitEnabled]).
        if (SilicaApp.quitEnabled)
          const PlatformMenuItemGroup(
            members: [SilicaMenuItem.system(SilicaMenuItemRole.quit)],
          ),
      ],
    );
  }

  /// [menus] with the standard menus every app has, built here once (silica-ui#99): the app
  /// menu first ([app], when the app gives none), the Window menu (the bar fills in Minimize,
  /// Zoom, Tile, Bring All to Front and the window list) and the Help menu (with the bar's
  /// search field) last. The app's own versions of them are kept as they are.
  static List<PlatformMenuItem> withStandard(List<PlatformMenuItem> menus) {
    SilicaMenuRole roleOf(PlatformMenuItem item) =>
        item is SilicaMenu ? item.role : SilicaMenuRole.none;
    final roles = menus.map(roleOf).toSet();
    final out = [if (!roles.contains(SilicaMenuRole.app)) app(''), ...menus];
    if (!roles.contains(SilicaMenuRole.window)) {
      final help = out.indexWhere((m) => roleOf(m) == SilicaMenuRole.help);
      out.insert(help < 0 ? out.length : help, window(''));
    }
    if (!roles.contains(SilicaMenuRole.help)) out.add(help(''));
    return out;
  }

  /// The Edit menu with the standard items: a null action leaves the item disabled. [label]
  /// is the menu's title in the app's language; [items] come after the standard ones.
  static SilicaMenu edit(
    String label, {
    VoidCallback? undo,
    VoidCallback? redo,
    VoidCallback? cut,
    VoidCallback? copy,
    VoidCallback? paste,
    VoidCallback? delete,
    VoidCallback? selectAll,
    List<PlatformMenuItem> items = const [],
  }) {
    SilicaMenuItem item(
      SilicaMenuItemRole role,
      VoidCallback? action, [
      SingleActivator? shortcut,
    ]) => SilicaMenuItem(
      role: role,
      shortcut: shortcut,
      onSelected: action,
      enabled: action != null,
    );
    return SilicaMenu(
      label: label,
      menus: [
        PlatformMenuItemGroup(
          members: [
            item(SilicaMenuItemRole.undo, undo, _meta(LogicalKeyboardKey.keyZ)),
            item(
              SilicaMenuItemRole.redo,
              redo,
              const SingleActivator(
                LogicalKeyboardKey.keyZ,
                meta: true,
                shift: true,
              ),
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            item(SilicaMenuItemRole.cut, cut, _meta(LogicalKeyboardKey.keyX)),
            item(SilicaMenuItemRole.copy, copy, _meta(LogicalKeyboardKey.keyC)),
            item(
              SilicaMenuItemRole.paste,
              paste,
              _meta(LogicalKeyboardKey.keyV),
            ),
            item(SilicaMenuItemRole.delete, delete),
            item(
              SilicaMenuItemRole.selectAll,
              selectAll,
              _meta(LogicalKeyboardKey.keyA),
            ),
          ],
        ),
        if (items.isNotEmpty) PlatformMenuItemGroup(members: items),
      ],
    );
  }

  /// The Edit menu for apps with text fields: the standard items act on the focused field
  /// through Flutter's text editing intents.
  static SilicaMenu textEdit(
    String label, {
    List<PlatformMenuItem> items = const [],
  }) {
    const cause = SelectionChangedCause.keyboard;
    SilicaMenuItem item(
      SilicaMenuItemRole role,
      Intent intent, [
      SingleActivator? shortcut,
    ]) => SilicaMenuItem(
      role: role,
      shortcut: shortcut,
      onSelectedIntent: intent,
    );
    return SilicaMenu(
      label: label,
      menus: [
        PlatformMenuItemGroup(
          members: [
            item(
              SilicaMenuItemRole.undo,
              const UndoTextIntent(cause),
              _meta(LogicalKeyboardKey.keyZ),
            ),
            item(
              SilicaMenuItemRole.redo,
              const RedoTextIntent(cause),
              const SingleActivator(
                LogicalKeyboardKey.keyZ,
                meta: true,
                shift: true,
              ),
            ),
          ],
        ),
        PlatformMenuItemGroup(
          members: [
            item(
              SilicaMenuItemRole.cut,
              const CopySelectionTextIntent.cut(cause),
              _meta(LogicalKeyboardKey.keyX),
            ),
            item(
              SilicaMenuItemRole.copy,
              CopySelectionTextIntent.copy,
              _meta(LogicalKeyboardKey.keyC),
            ),
            item(
              SilicaMenuItemRole.paste,
              const PasteTextIntent(cause),
              _meta(LogicalKeyboardKey.keyV),
            ),
            item(
              SilicaMenuItemRole.delete,
              const DeleteCharacterIntent(forward: true),
            ),
            item(
              SilicaMenuItemRole.selectAll,
              const SelectAllTextIntent(cause),
              _meta(LogicalKeyboardKey.keyA),
            ),
          ],
        ),
        if (items.isNotEmpty) PlatformMenuItemGroup(members: items),
      ],
    );
  }

  /// The Window menu: the app's [items] (with Close first when [close]); the bar puts its system
  /// items before them and the window list after. [label] is the title in the app's language.
  static SilicaMenu window(
    String label, {
    bool close = false,
    List<PlatformMenuItem> items = const [],
  }) => SilicaMenu(
    label: label,
    role: SilicaMenuRole.window,
    menus: [
      if (close) const SilicaMenuItem.system(SilicaMenuItemRole.close),
      ...items,
    ],
  );

  /// The Help menu: the app's help (⌘?) when [onHelp] is given, then [items]; empty, the bar
  /// shows Silica Help.
  static SilicaMenu help(
    String label, {
    VoidCallback? onHelp,
    List<PlatformMenuItem> items = const [],
  }) => SilicaMenu(
    label: label,
    role: SilicaMenuRole.help,
    menus: [
      if (onHelp != null)
        SilicaMenuItem(
          role: SilicaMenuItemRole.help,
          shortcut: const CharacterActivator('?', meta: true),
          onSelected: onHelp,
        ),
      ...items,
    ],
  );

  static SingleActivator _meta(LogicalKeyboardKey key) =>
      SingleActivator(key, meta: true);
}

/// The model's name of a key: `A`, `1`, `,`, `Left`, `Return`, `F5`…
String silicaMenuKeyName(LogicalKeyboardKey key) {
  final named = <LogicalKeyboardKey, String>{
    LogicalKeyboardKey.arrowLeft: 'Left',
    LogicalKeyboardKey.arrowRight: 'Right',
    LogicalKeyboardKey.arrowUp: 'Up',
    LogicalKeyboardKey.arrowDown: 'Down',
    LogicalKeyboardKey.enter: 'Return',
    LogicalKeyboardKey.numpadEnter: 'Return',
    LogicalKeyboardKey.escape: 'Escape',
    LogicalKeyboardKey.backspace: 'Backspace',
    LogicalKeyboardKey.delete: 'Delete',
    LogicalKeyboardKey.tab: 'Tab',
    LogicalKeyboardKey.space: 'Space',
    LogicalKeyboardKey.pageUp: 'PageUp',
    LogicalKeyboardKey.pageDown: 'PageDown',
    LogicalKeyboardKey.home: 'Home',
    LogicalKeyboardKey.end: 'End',
  }[key];
  if (named != null) return named;
  final label = key.keyLabel;
  return label.length == 1 ? label.toUpperCase() : label.replaceAll(' ', '');
}

/// The model of a shortcut, null if it has no key.
Map<String, Object?>? silicaMenuShortcut(MenuSerializableShortcut? shortcut) {
  if (shortcut == null) return null;
  final s = shortcut.serializeForMenu();
  final trigger = s.trigger;
  final key = trigger != null ? silicaMenuKeyName(trigger) : s.character;
  if (key == null || key.isEmpty) return null;
  return {
    'key': key,
    if (s.meta ?? false) 'meta': true,
    if (s.control ?? false) 'ctrl': true,
    if (s.alt ?? false) 'alt': true,
    if (s.shift ?? false) 'shift': true,
  };
}

String _providedRole(PlatformProvidedMenuItemType type) => switch (type) {
  PlatformProvidedMenuItemType.about => 'about',
  PlatformProvidedMenuItemType.quit => 'quit',
  PlatformProvidedMenuItemType.servicesSubmenu => 'services',
  PlatformProvidedMenuItemType.hide => 'hide',
  PlatformProvidedMenuItemType.hideOtherApplications => 'hide_others',
  PlatformProvidedMenuItemType.showAllApplications => 'show_all',
  PlatformProvidedMenuItemType.minimizeWindow => 'minimize',
  PlatformProvidedMenuItemType.toggleFullScreen => 'fullscreen',
  PlatformProvidedMenuItemType.arrangeWindowsInFront => 'bring_all_to_front',
  // Not offered in Silica: the bar leaves them out.
  _ => '',
};

/// The [PlatformMenuDelegate] of Silica's global menu bar: it sends the menus of
/// `PlatformMenuBar` (and `SilicaMenuBar`) to the bar on `silica/menu` and runs the item the
/// user chooses there. Installed by [SilicaMenuBar], or by hand with [install].
class SilicaMenuDelegate extends PlatformMenuDelegate {
  SilicaMenuDelegate({MethodChannel? channel})
    : channel = channel ?? SilicaMenuDelegate.defaultChannel {
    this.channel.setMethodCallHandler(_handle);
  }

  static const MethodChannel defaultChannel = MethodChannel(
    'silica/menu',
    JSONMethodCodec(),
  );

  /// Makes this delegate the binding's (once): `PlatformMenuBar` then publishes to Silica's
  /// bar.
  static SilicaMenuDelegate install() {
    final binding = WidgetsBinding.instance;
    final current = binding.platformMenuDelegate;
    if (current is SilicaMenuDelegate) return current;
    final delegate = SilicaMenuDelegate();
    binding.platformMenuDelegate = delegate;
    return delegate;
  }

  final MethodChannel channel;

  /// The items with an action of the model shown now and of the one before (a choice made
  /// in the bar just before a change still reaches its item), by id.
  Map<int, PlatformMenuItem> _items = {};
  Map<int, PlatformMenuItem> _previous = {};

  /// The model last sent, with ids by position only, and its generation (part of the ids).
  String? _sent;
  int _generation = 0;
  bool _clearPending = false;
  BuildContext? _lockedContext;

  /// The ids are generation × 65536 + position: the protocol allows 4096 items.
  static const int _slots = 65536;

  /// The model sent last (tests, diagnostics).
  @visibleForTesting
  Map<String, Object?>? lastModel;

  @override
  void setMenus(List<PlatformMenuItem> menus) {
    _clearPending = false;
    // Every app has the standard app, Window and Help menus, whatever it declares.
    final topLevelMenus = SilicaMenus.withStandard(menus);
    final positional = <PlatformMenuItem>[];
    final canonical = _model(topLevelMenus, positional, 0);
    final text = jsonEncode(canonical);
    if (text == _sent) {
      // The same menus: only the actions are new (closures of the new build).
      _items = {
        for (var i = 0; i < positional.length; i++)
          _generation * _slots + i: positional[i],
      };
      return;
    }
    _generation = _generation % 32767 + 1;
    final items = <PlatformMenuItem>[];
    final model = _model(topLevelMenus, items, _generation * _slots);
    _previous = _items;
    _items = {
      for (var i = 0; i < items.length; i++) _generation * _slots + i: items[i],
    };
    _sent = text;
    lastModel = model;
    unawaited(_invoke('setMenus', model));
  }

  @override
  void clearMenus() {
    // PlatformMenuBar clears and sets again when it starts: the bar should not blink.
    _clearPending = true;
    scheduleMicrotask(() {
      if (!_clearPending) return;
      _clearPending = false;
      _sent = null;
      lastModel = null;
      _previous = _items;
      _items = {};
      unawaited(_invoke('clearMenus'));
    });
  }

  @override
  bool debugLockDelegate(BuildContext context) {
    assert(() {
      if (_lockedContext != null && _lockedContext != context) return false;
      _lockedContext = context;
      return true;
    }());
    return true;
  }

  @override
  bool debugUnlockDelegate(BuildContext context) {
    assert(() {
      if (_lockedContext != null && _lockedContext != context) return false;
      _lockedContext = null;
      return true;
    }());
    return true;
  }

  /// Runs the item with this id, if it still exists; returns whether it did.
  bool activate(int id) {
    final item = _items[id] ?? _previous[id];
    if (item == null) return false;
    _run(item);
    return true;
  }

  Future<Object?> _handle(MethodCall call) async {
    if (call.method == 'activated' && call.arguments is int) {
      activate(call.arguments as int);
    }
    return null;
  }

  Future<void> _invoke(String method, [Object? args]) async {
    try {
      await channel.invokeMethod<Object?>(method, args);
    } on MissingPluginException {
      // Outside Silica: no bar to publish to.
    } on PlatformException catch (e) {
      debugPrint('silica/menu: $e');
    }
  }

  Map<String, Object?> _model(
    List<PlatformMenuItem> menus,
    List<PlatformMenuItem> items,
    int base,
  ) {
    final top = <Map<String, Object?>>[];
    for (final menu in menus) {
      if (menu is! PlatformMenu) continue;
      top.add({
        'label': menu.label,
        if (menu is SilicaMenu && menu.role != SilicaMenuRole.none)
          'role': menu.role.wire,
        'items': _entries(menu.menus, items, base),
      });
    }
    return {'menus': top};
  }

  List<Map<String, Object?>> _entries(
    List<PlatformMenuItem> list,
    List<PlatformMenuItem> items,
    int base,
  ) {
    final out = <Map<String, Object?>>[];
    void separator() {
      if (out.isNotEmpty && out.last['separator'] != true) {
        out.add({'separator': true});
      }
    }

    for (final item in list) {
      if (item is PlatformMenuItemGroup) {
        separator();
        out.addAll(_entries(item.members, items, base));
        separator();
        continue;
      }
      if (item is PlatformMenu) {
        out.add({
          'label': item.label,
          'enabled': item is! SilicaMenu || item.enabled,
          'items': _entries(item.menus, items, base),
        });
        continue;
      }
      if (item is PlatformProvidedMenuItem) {
        final role = _providedRole(item.type);
        if (role.isNotEmpty) out.add({'role': role, 'enabled': item.enabled});
        continue;
      }
      final silica = item is SilicaMenuItem ? item : null;
      final action = item.onSelected != null || item.onSelectedIntent != null;
      int? id;
      if (action) {
        id = base + items.length;
        items.add(item);
      }
      final role = silica?.role ?? SilicaMenuItemRole.none;
      // Without an action only a system item can be chosen: the bar runs it.
      final enabled =
          (silica?.enabled ?? true) && (action || _system.contains(role));
      out.add({
        'id': ?id,
        'label': item.label,
        'enabled': enabled,
        if (silica?.checked ?? false) 'checked': true,
        if (silica?.icon case final icon?) 'icon': icon,
        if (role != SilicaMenuItemRole.none) 'role': role.wire,
        'shortcut': ?silicaMenuShortcut(item.shortcut),
      });
    }
    while (out.isNotEmpty && out.last['separator'] == true) {
      out.removeLast();
    }
    return out;
  }

  static const Set<SilicaMenuItemRole> _system = {
    SilicaMenuItemRole.services,
    SilicaMenuItemRole.hide,
    SilicaMenuItemRole.hideOthers,
    SilicaMenuItemRole.showAll,
    SilicaMenuItemRole.quit,
    SilicaMenuItemRole.close,
    SilicaMenuItemRole.minimize,
    SilicaMenuItemRole.fullScreen,
    SilicaMenuItemRole.bringAllToFront,
  };

  static void _run(PlatformMenuItem item) {
    item.onSelected?.call();
    final intent = item.onSelectedIntent;
    final context = FocusManager.instance.primaryFocus?.context;
    if (intent != null && context != null) {
      Actions.maybeInvoke(context, intent);
    }
  }
}

/// The shortcuts of the enabled items with an action, for the app's own key handling.
Map<ShortcutActivator, VoidCallback> silicaMenuShortcuts(
  List<PlatformMenuItem> menus,
) {
  final out = <ShortcutActivator, VoidCallback>{};
  void walk(List<PlatformMenuItem> list) {
    for (final item in list) {
      if (item is PlatformMenu) {
        if (item is! SilicaMenu || item.enabled) walk(item.menus);
        continue;
      }
      if (item is PlatformMenuItemGroup) {
        walk(item.members);
        continue;
      }
      final shortcut = item.shortcut;
      final action = item.onSelected != null || item.onSelectedIntent != null;
      final enabled = item is! SilicaMenuItem || item.enabled;
      if (shortcut is ShortcutActivator && action && enabled) {
        out.putIfAbsent(
          shortcut as ShortcutActivator,
          () =>
              () => SilicaMenuDelegate._run(item),
        );
      }
    }
  }

  walk(menus);
  return out;
}

/// The menus of an app with no window ([SilicaAppWindow.windowlessBuilder]: File › Open… of a
/// document app whose Open panel was cancelled). Unlike [SilicaMenuBar] it does not hold the
/// menu delegate: it publishes after each frame, so the next window's [SilicaMenuBar] takes the
/// bar over in the same frame, and the closed window's bar going away does not clear these.
/// No keyboard shortcuts: with no window the app has no keyboard focus.
class SilicaWindowlessMenuBar extends StatefulWidget {
  const SilicaWindowlessMenuBar({
    super.key,
    required this.menus,
    this.child = const SizedBox.shrink(),
  });

  final List<PlatformMenuItem> menus;
  final Widget child;

  @override
  State<SilicaWindowlessMenuBar> createState() =>
      _SilicaWindowlessMenuBarState();
}

class _SilicaWindowlessMenuBarState extends State<SilicaWindowlessMenuBar> {
  @override
  Widget build(BuildContext context) {
    // After the frame: past the closed window's bar clearing the menus (a microtask after the
    // frame, cancelled by a newer setMenus).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      SilicaMenuDelegate.install().setMenus(widget.menus);
    });
    return widget.child;
  }
}

/// The app's menus in Silica's menu bar, with their shortcuts working inside the app.
///
/// ```dart
/// SilicaMenuBar(
///   menus: [
///     SilicaMenus.app('Calculator', onAbout: showAbout),
///     SilicaMenus.edit('Edit', copy: copy, paste: paste),
///     SilicaMenu(label: 'View', menus: [
///       SilicaMenuItem(label: 'Basic', checked: basic,
///           shortcut: SingleActivator(LogicalKeyboardKey.digit1, meta: true),
///           onSelected: () => setMode(basic)),
///     ]),
///     SilicaMenus.window('Window', close: true),
///     SilicaMenus.help('Help'),
///   ],
///   child: ...,
/// )
/// ```
///
/// Rebuild it with new items whenever a state changes (a checkmark, an enabled item): the
/// bar is updated only when the menus really change. One per app, near the root.
class SilicaMenuBar extends StatefulWidget {
  const SilicaMenuBar({
    super.key,
    required this.menus,
    required this.child,
    this.shortcuts = true,
  });

  final List<PlatformMenuItem> menus;
  final Widget child;

  /// Whether the items' shortcuts are bound inside the app (true unless the app already
  /// handles those keys itself).
  final bool shortcuts;

  @override
  State<SilicaMenuBar> createState() => _SilicaMenuBarState();
}

class _SilicaMenuBarState extends State<SilicaMenuBar> {
  @override
  void initState() {
    super.initState();
    SilicaMenuDelegate.install();
  }

  @override
  Widget build(BuildContext context) => PlatformMenuBar(
    menus: widget.menus,
    // The windows the menus open (About <App>) need a host, also in apps that have none.
    child: SilicaWindowHost(
      child: widget.shortcuts
          ? CallbackShortcuts(
              bindings: silicaMenuShortcuts(widget.menus),
              child: widget.child,
            )
          : widget.child,
    ),
  );
}
