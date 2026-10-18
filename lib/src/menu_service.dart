// The system menu service (silica-desktop#241, `docs/spec/menus.md` of silica-desktop):
// under Silica the shell draws every context menu and pop-up button. The app describes the
// menu (rows, an anchor in its window), Ossido positions it, owns its dismissal and hands the
// shell the rows; the choice comes back as the id of a row.
//
// Apps do not use this directly: [showAmalfiMenu], [AmalfiPopUpButton] and
// [AmalfiPullDownButton] use it when the system offers it and draw the menu inside the window
// otherwise (tests, another compositor).

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'amalfi/components/menus/menu.dart';

/// The rows of a menu in the service's form, and the actions behind their ids.
class ServiceMenu {
  ServiceMenu._(this.rows, this._actions, this.selectedId);

  /// The rows, in order, as the embedder sends them (`kind`, `id`, `label`, `flags`, `icon`,
  /// `key`, `modifiers`).
  final List<Map<String, Object?>> rows;
  final Map<int, VoidCallback?> _actions;

  /// The id of the row for `selectedIndex` given to [ServiceMenu.from], 0 for none.
  final int selectedId;

  static const int _item = 0, _separator = 1, _section = 2;
  static const int _begin = 3, _end = 4;

  /// Flattens [entries]. Widget icons cannot cross the process boundary: only
  /// [AmalfiMenuAction.iconName] does. [selectedIndex] is an index of the top level.
  factory ServiceMenu.from(
    List<AmalfiMenuEntry> entries, {
    int? selectedIndex,
  }) {
    final rows = <Map<String, Object?>>[];
    final actions = <int, VoidCallback?>{};
    var next = 0;
    var selected = 0;
    void level(List<AmalfiMenuEntry> list, int depth, bool top) {
      for (var i = 0; i < list.length; i++) {
        final entry = list[i];
        switch (entry) {
          case AmalfiMenuDivider():
            rows.add({'kind': _separator});
          case AmalfiMenuSection():
            rows.add({'kind': _section, 'label': entry.label});
          case AmalfiMenuAction():
            final flags =
                (entry.enabled && entry.selectable ? 0 : 1) |
                (entry.checked ? 2 : 0) |
                (entry.destructive ? 8 : 0);
            final children = entry.submenu;
            if (children != null && depth < 4) {
              rows.add({
                'kind': _begin,
                'label': entry.label,
                'flags': flags,
                'icon': entry.iconName ?? '',
              });
              level(children, depth + 1, false);
              rows.add({'kind': _end});
            } else {
              final id = ++next;
              actions[id] = entry.onSelected;
              if (top && i == selectedIndex) selected = id;
              final shortcut = _parseShortcut(entry.shortcut);
              rows.add({
                'kind': _item,
                'id': id,
                'label': entry.label,
                'flags': flags,
                'icon': entry.iconName ?? '',
                'key': shortcut.key,
                'modifiers': shortcut.modifiers,
              });
            }
        }
      }
    }

    level(entries, 0, true);
    return ServiceMenu._(rows, actions, selected);
  }

  /// Whether a row can be chosen at all.
  bool get hasItems => _actions.isNotEmpty;

  /// Runs the action of row [id].
  void run(int id) => _actions[id]?.call();

  /// `⌃⌥⇧⌘` then the key, as the menus write a shortcut.
  static ({String key, int modifiers}) _parseShortcut(String? text) {
    if (text == null || text.isEmpty) return (key: '', modifiers: 0);
    var modifiers = 0;
    var at = 0;
    final runes = text.runes.toList();
    while (at < runes.length) {
      final bit = switch (String.fromCharCode(runes[at])) {
        '⌘' => 1,
        '⌃' => 2,
        '⌥' => 4,
        '⇧' => 8,
        _ => 0,
      };
      if (bit == 0) break;
      modifiers |= bit;
      at++;
    }
    return (key: String.fromCharCodes(runes.skip(at)), modifiers: modifiers);
  }
}

/// A menu the service shows.
class ServiceMenuHandle {
  ServiceMenuHandle._(this._token, this.result);

  final int _token;

  /// The id of the chosen row, null when the menu ended without a choice. Completes once.
  final Future<int?> result;

  /// Ends the menu from the app's side (the widget went away).
  Future<void> cancel() => SilicaMenuService._cancel(_token);
}

abstract final class SilicaMenuService {
  static const MethodChannel channel = MethodChannel(
    'silica/popupmenu',
    JSONMethodCodec(),
  );

  static bool? _available;
  static Future<bool>? _probe;
  static final Map<int, Completer<int?>> _pending = {};
  static int _token = 0;
  static bool _listening = false;

  /// Whether the system offers the service: null until the first answer. [probe] asks.
  static bool? get available => _available;

  /// Asks the embedder whether it offers the service (once). silica_ui does it at start.
  static Future<bool> probe() => _probe ??= _ask();

  static Future<bool> _ask() async {
    _listen();
    try {
      return _available =
          await channel.invokeMethod<Object?>('available') == true;
    } on MissingPluginException {
      return _available = false;
    } on PlatformException {
      return _available = false;
    }
  }

  static void _listen() {
    if (_listening) return;
    _listening = true;
    channel.setMethodCallHandler(_handle);
  }

  static Future<Object?> _handle(MethodCall call) async {
    if (call.method != 'result') return null;
    final args = call.arguments;
    if (args is! Map || args['token'] is! int) return null;
    final id = args['id'];
    _pending.remove(args['token'])?.complete(id is int ? id : null);
    return null;
  }

  /// Shows [menu] on view [viewId], anchored on [anchor] (the view's logical pixels): a
  /// 0 x 0 rectangle at the pointer for a context menu, the control for a pop-up button
  /// ([popUp], with [ServiceMenu.selectedId] aligned over it) or a pull-down (below the
  /// control). Null when the system refuses (then the caller draws the menu itself).
  static Future<ServiceMenuHandle?> show({
    required int viewId,
    required ServiceMenu menu,
    required Rect anchor,
    bool popUp = false,
  }) async {
    if (!menu.hasItems) return null;
    _listen();
    final token = ++_token;
    final completer = _pending[token] = Completer<int?>();
    bool shown;
    try {
      shown =
          await channel.invokeMethod<Object?>('show', {
            'token': token,
            'viewId': viewId,
            'kind': popUp ? 1 : 0,
            'anchor': [anchor.left, anchor.top, anchor.width, anchor.height],
            'selected': popUp ? menu.selectedId : 0,
            'rows': menu.rows,
          }) ==
          true;
    } on MissingPluginException {
      shown = false;
    } on PlatformException {
      shown = false;
    }
    if (!shown) {
      _pending.remove(token);
      return null;
    }
    return ServiceMenuHandle._(
      token,
      completer.future.then((id) {
        if (id != null) menu.run(id);
        return id;
      }),
    );
  }

  static Future<void> _cancel(int token) async {
    final completer = _pending.remove(token);
    if (completer == null) return;
    try {
      await channel.invokeMethod<Object?>('cancel', {'token': token});
    } on MissingPluginException {
      // Outside Silica.
    }
    if (!completer.isCompleted) completer.complete(null);
  }

  /// Back to the initial state (tests).
  @visibleForTesting
  static void reset() {
    for (final completer in _pending.values) {
      if (!completer.isCompleted) completer.complete(null);
    }
    _pending.clear();
    _available = null;
    _probe = null;
    _token = 0;
  }
}
