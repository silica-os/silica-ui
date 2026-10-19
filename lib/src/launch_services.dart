// Launch Services: the app registry of the session (silica-daemon,
// `dev.frascella.Silica.Apps1`, silica-desktop docs/spec/launch-services.md). Which apps are
// installed, how each one starts, which app opens a type.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dbus.dart';

/// Where an app comes from.
enum SilicaInstalledAppKind {
  /// Part of the system image.
  system,

  /// A bundle in `/Applications` or `~/Applications`.
  bundle,

  /// A Flatpak app.
  flatpak,

  /// An AppImage file.
  appimage;

  static SilicaInstalledAppKind parse(String? name) => switch (name) {
    'bundle' => bundle,
    'flatpak' => flatpak,
    'appimage' => appimage,
    _ => system,
  };
}

/// An action of an app (a `[Desktop Action]` group).
@immutable
class SilicaAppAction {
  const SilicaAppAction({
    required this.id,
    required this.name,
    required this.exec,
  });

  final String id;
  final String name;

  /// The command line with its field codes.
  final String exec;
}

/// An app of the registry.
@immutable
class SilicaInstalledApp {
  const SilicaInstalledApp({
    required this.id,
    required this.name,
    this.kind = SilicaInstalledAppKind.system,
    this.path = '',
    this.location = 'xdg',
    this.names = const {},
    this.genericName = '',
    this.comment = '',
    this.version = '',
    this.exec = '',
    this.icon = '',
    this.silicaIcon = '',
    this.wmClass = '',
    this.keywords = const [],
    this.keywordsL10n = const {},
    this.categories = const [],
    this.mimeTypes = const [],
    this.urlSchemes = const [],
    this.types = const {},
    this.documentIcons = const {},
    this.actions = const [],
    this.permissions = const {},
    this.appKind = '',
    this.runtime = '',
    this.developer = '',
    this.desktopFile = '',
    this.noDisplay = false,
    this.terminal = false,
    this.share = false,
    this.isNew = false,
    this.added = 0,
    this.lastUsed = 0,
  });

  /// The app id (the Wayland app id of bundles; the desktop file id otherwise).
  final String id;
  final String name;
  final SilicaInstalledAppKind kind;

  /// The bundle folder, the AppImage file or the desktop entry file.
  final String path;

  /// `system`, `local` (/Applications), `user` (~/Applications), `volume` or `xdg`.
  final String location;

  /// Localized names by language.
  final Map<String, String> names;
  final String genericName;
  final String comment;
  final String version;

  /// The command line with its field codes (`%U`…).
  final String exec;

  /// The freedesktop icon (a name or a path).
  final String icon;

  /// The silica-icons folder or the `silica.assets` name.
  final String silicaIcon;
  final String wmClass;
  final List<String> keywords;

  /// Localized keywords by language.
  final Map<String, List<String>> keywordsL10n;
  final List<String> categories;
  final List<String> mimeTypes;
  final List<String> urlSchemes;

  /// Type → `editor` or `viewer` (bundles).
  final Map<String, String> types;

  /// Type → document icon name.
  final Map<String, String> documentIcons;
  final List<SilicaAppAction> actions;

  /// Bundles: `network`, `devices`, `filesystem`, `talk`, `background`.
  final Map<String, Object?> permissions;

  /// Bundles: `flutter` or `native`.
  final String appKind;
  final String runtime;
  final String developer;
  final String desktopFile;
  final bool noDisplay;
  final bool terminal;

  /// A target of the Share menu.
  final bool share;

  /// Installed since the registry started remembering and never launched.
  final bool isNew;

  /// Unix seconds.
  final int added;
  final int lastUsed;

  /// The name in [language] (`it_IT` falls back to `it`).
  String nameIn(String language) {
    final lang = language.split(RegExp('[.@]')).first;
    return names[lang] ?? names[lang.split('_').first] ?? name;
  }

  /// The keywords in [language], else the plain ones.
  List<String> keywordsIn(String language) {
    final lang = language.split(RegExp('[.@]')).first;
    return keywordsL10n[lang] ??
        keywordsL10n[lang.split('_').first] ??
        keywords;
  }

  /// Whether this app may be moved to the Trash (not part of the system).
  bool get removable =>
      kind == SilicaInstalledAppKind.bundle ||
      kind == SilicaInstalledAppKind.appimage ||
      kind == SilicaInstalledAppKind.flatpak;

  /// The app from an `a{sv}` of properties (as the channel delivers it).
  static SilicaInstalledApp? fromProperties(Object? properties) {
    if (properties is! Map) return null;
    final p = properties.cast<Object?, Object?>();
    String s(String key) => p[key] is String ? p[key] as String : '';
    bool b(String key) => p[key] == true;
    int i(String key) => p[key] is int ? p[key] as int : 0;
    List<String> list(String key) => [
      for (final item in (p[key] is List ? p[key] as List : const []))
        if (item is String) item,
    ];
    Map<String, String> map(String key) => {
      if (p[key] case final Map m)
        for (final e in m.entries)
          if (e.key is String && e.value is String)
            e.key as String: e.value as String,
    };
    final id = s('id');
    if (id.isEmpty) return null;
    return SilicaInstalledApp(
      id: id,
      name: s('name').isEmpty ? id : s('name'),
      kind: SilicaInstalledAppKind.parse(s('kind')),
      path: s('path'),
      location: s('location').isEmpty ? 'xdg' : s('location'),
      names: map('names'),
      genericName: s('generic_name'),
      comment: s('comment'),
      version: s('version'),
      exec: s('exec'),
      icon: s('icon'),
      silicaIcon: s('silica_icon'),
      wmClass: s('wm_class'),
      keywords: list('keywords'),
      keywordsL10n: {
        for (final e in map('keywords_l10n').entries)
          e.key: [
            for (final w in e.value.split(';'))
              if (w.isNotEmpty) w,
          ],
      },
      categories: list('categories'),
      mimeTypes: list('mime_types'),
      urlSchemes: list('url_schemes'),
      types: map('types'),
      documentIcons: map('document_icons'),
      actions: [
        for (final a
            in (p['actions'] is List ? p['actions'] as List : const []))
          if (a is List &&
              a.length >= 3 &&
              a[0] is String &&
              a[1] is String &&
              a[2] is String)
            SilicaAppAction(
              id: a[0] as String,
              name: a[1] as String,
              exec: a[2] as String,
            ),
      ],
      permissions: p['permissions'] is Map
          ? (p['permissions'] as Map).cast<String, Object?>()
          : const {},
      appKind: s('app_kind'),
      runtime: s('runtime'),
      developer: s('developer'),
      desktopFile: s('desktop_file'),
      noDisplay: b('no_display'),
      terminal: b('terminal'),
      share: b('share'),
      isNew: b('new'),
      added: i('added'),
      lastUsed: i('last_used'),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is SilicaInstalledApp &&
      other.id == id &&
      other.name == name &&
      other.kind == kind &&
      other.path == path &&
      other.exec == exec &&
      other.isNew == isNew &&
      other.silicaIcon == silicaIcon &&
      other.noDisplay == noDisplay;

  @override
  int get hashCode =>
      Object.hash(id, name, kind, path, exec, isNew, silicaIcon, noDisplay);
}

/// What changed in the registry.
enum SilicaAppsChange { added, removed, changed, defaultChanged }

/// A change of the registry: the app id (and the type, for a new default).
@immutable
class SilicaAppsEvent {
  const SilicaAppsEvent(this.change, this.id, {this.type});

  final SilicaAppsChange change;
  final String id;
  final String? type;
}

/// The registry over the embedder's `silica/dbus` channel. Outside Silica (no channel, no
/// daemon) every call answers "not there" (null or empty), so callers keep a fallback.
abstract final class SilicaApps {
  static const String _name = 'dev.frascella.Silica';
  static const String _path = '/dev/frascella/Silica/Apps1';
  static const String interface = 'dev.frascella.Silica.Apps1';

  static Future<List<Object?>?> _call(
    String method,
    String signature,
    List<Object?> args,
  ) async {
    try {
      return await SilicaDBus.instance.call(
        destination: _name,
        path: _path,
        interface: interface,
        method: method,
        signature: signature,
        args: args,
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Every app; null when the service is not there.
  static Future<List<SilicaInstalledApp>?> list() async {
    final reply = await _call('List', '', const []);
    if (reply == null || reply.isEmpty) return null;
    return parseList(reply.first);
  }

  /// The apps of a `List` reply, `a(ssssa{sv})`: the properties carry everything; malformed
  /// items are skipped.
  static List<SilicaInstalledApp> parseList(Object? reply) {
    if (reply is! List) return const [];
    return [
      for (final item in reply)
        if (item is List && item.length >= 5)
          if (SilicaInstalledApp.fromProperties(item[4]) case final app?) app,
    ];
  }

  /// One app; null when unknown or the service is not there.
  static Future<SilicaInstalledApp?> get(String id) async {
    final reply = await _call('Get', 's', [id]);
    if (reply == null || reply.isEmpty) return null;
    return SilicaInstalledApp.fromProperties(reply.first);
  }

  /// The ids of the apps that open [type], the default first.
  static Future<List<String>> appsFor(String type) async {
    final reply = await _call('AppsFor', 's', [type]);
    final first = reply == null || reply.isEmpty ? null : reply.first;
    return [
      for (final id in (first is List ? first : const []))
        if (id is String) id,
    ];
  }

  /// The default app of [type]; null when none or no service.
  static Future<String?> defaultFor(String type) async {
    final reply = await _call('DefaultFor', 's', [type]);
    final first = reply == null || reply.isEmpty ? null : reply.first;
    return first is String && first.isNotEmpty ? first : null;
  }

  /// Makes [id] the default app of [type]. False when refused or no service.
  static Future<bool> setDefault(String type, String id) async =>
      await _call('SetDefault', 'ss', [type, id]) != null;

  /// Starts [id] with [uris]; the pid, or null when it could not start.
  static Future<int?> open(
    String id, {
    List<String> uris = const [],
    String? activationToken,
  }) async {
    final reply = await _call('Open', 'sasa{sv}', [
      id,
      uris,
      {'activation_token': ?activationToken},
    ]);
    final first = reply == null || reply.isEmpty ? null : reply.first;
    return first is int ? first : null;
  }

  /// Opens each URI with its default app.
  static Future<int?> openUris(List<String> uris) async {
    final reply = await _call('OpenUris', 'as', [uris]);
    final first = reply == null || reply.isEmpty ? null : reply.first;
    return first is int ? first : null;
  }

  /// The caller started [id] itself (clears its "new" mark).
  static Future<void> noteLaunched(String id) async {
    await _call('NoteLaunched', 's', [id]);
  }

  /// Removes a Flatpak app. False for other kinds (they are moved to the Trash).
  static Future<bool> uninstall(String id) async {
    final reply = await _call('Uninstall', 's', [id]);
    return reply != null && reply.isNotEmpty && reply.first == true;
  }

  /// The changes of the registry.
  static Stream<SilicaAppsEvent> events() => SilicaDBus.instance
      .signals(interface: interface, path: _path)
      .map(parseSignal)
      .where((e) => e != null)
      .cast<SilicaAppsEvent>()
      .handleError((Object _) {});

  /// A signal of the service as an event; null for other members.
  static SilicaAppsEvent? parseSignal(SilicaDBusSignal signal) {
    final args = signal.args;
    String arg(int i) =>
        i < args.length && args[i] is String ? args[i] as String : '';
    return switch (signal.member) {
      'Added' => SilicaAppsEvent(SilicaAppsChange.added, arg(0)),
      'Removed' => SilicaAppsEvent(SilicaAppsChange.removed, arg(0)),
      'Changed' => SilicaAppsEvent(SilicaAppsChange.changed, arg(0)),
      'DefaultChanged' => SilicaAppsEvent(
        SilicaAppsChange.defaultChanged,
        arg(1),
        type: arg(0),
      ),
      _ => null,
    };
  }
}
