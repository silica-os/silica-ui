// The layered icons of the silica-icons repo (specification: docs/icon-format.md of that repo):
// where they are installed, the icon.json manifest, the special folders. The icons are
// user or system files (CC BY-SA 4.0 license), not assets of this repository.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' show Color, Offset, Rect;

/// `app`: the shell clips the body and adds edge and shadow; `file`: free shape.
enum IconKind { app, file }

/// The six themes of an app icon (icon-format.md, "Themes"): Default (here `light`), Dark,
/// Clear Light and Clear Dark, Tinted Light and Tinted Dark. [key] is the theme's key in the
/// manifest's `rendered` map.
enum IconAppearance {
  light('default'),
  dark('dark'),
  clear('clear'),
  clearDark('clear-dark'),
  tinted('tinted'),
  tintedDark('tinted-dark');

  const IconAppearance(this.key);

  final String key;

  /// Dark, Clear Dark and Tinted Dark: they take the `-dark` layers.
  bool get isDark =>
      this == IconAppearance.dark ||
      this == IconAppearance.clearDark ||
      this == IconAppearance.tintedDark;

  bool get isClear =>
      this == IconAppearance.clear || this == IconAppearance.clearDark;

  bool get isTinted =>
      this == IconAppearance.tinted || this == IconAppearance.tintedDark;

  /// The `appearance` argument of `Thumbnails1.AppIcon`: 0 light, 1 clear, 2 tinted, plus 4 for
  /// the dark forms.
  int get serviceWord => switch (this) {
    IconAppearance.light => 0,
    IconAppearance.clear => 1,
    IconAppearance.tinted => 2,
    IconAppearance.dark => 4,
    IconAppearance.clearDark => 5,
    IconAppearance.tintedDark => 6,
  };
}

/// The tint of the Tinted renders in silica-icons (icon-format.md, `rendered`): with this tint
/// the shell uses the PNGs, with any other one it composes the SVG layers.
const Color defaultIconTint = Color(0xFF0A84FF);

/// An SVG layer on the 1024 canvas, with the variant for dark themes if there is one.
class IconLayer {
  const IconLayer(
    this.path, {
    this.darkPath,
    this.shadow = false,
    this.role,
    this.when,
  });

  /// The role in the manifest (`back`, `middle`, `front`…).
  final String? role;

  /// A condition the composer evaluates (`not-empty`: the sheet of a folder with items); a plain
  /// drawing of the icon leaves such a layer out.
  final String? when;

  final String path;
  final String? darkPath;

  /// The shell draws a neutral shadow under the layer (`"shadow": "neutral"`).
  final bool shadow;

  String pathFor({required bool dark}) => dark ? darkPath ?? path : path;
}

/// A text drawn by the shell (month and day of the calendar).
class IconText {
  const IconText({
    required this.size,
    required this.weight,
    required this.tracking,
    required this.color,
    required this.darkColor,
    required this.box,
    this.maxWidth,
    this.upper = false,
    this.lower = false,
    this.font = 'Inter',
    this.format = '',
    this.refresh = 'midnight',
  });

  final double size;
  final int weight;
  final double tracking;
  final Color color;
  final Color darkColor;

  /// Box on the 1024 canvas; the text is centered.
  final Rect box;
  final double? maxWidth;
  final bool upper;
  final bool lower;
  final String font;

  /// Month style of a calendar month: `short` (three letters), `long` or `narrow`; empty for a
  /// day or the full name (older icons).
  final String format;

  /// `midnight`: redrawn at local midnight; `never`.
  final String refresh;
}

/// Content updated at runtime.
sealed class IconDynamic {
  const IconDynamic();
}

/// Hands rotating around (512, 512), with the cap on top.
class ClockHands extends IconDynamic {
  const ClockHands({
    required this.hour,
    required this.minute,
    required this.second,
    required this.cap,
  });

  final IconLayer hour;
  final IconLayer minute;
  final IconLayer? second;
  final IconLayer cap;
}

/// Month and day written on the foreground.
class CalendarText extends IconDynamic {
  const CalendarText({required this.month, required this.day});

  final IconText month;
  final IconText day;
}

/// What a dynamic layer of a format 2 icon draws (`dynamic.kind` in `icon.json`).
enum DynamicKind {
  clockHand('clock-hand'),
  clockCap('clock-cap'),
  calendarMonth('calendar-month'),
  calendarDay('calendar-day');

  const DynamicKind(this.key);
  final String key;
}

enum ClockUnit { hour, minute, second }

/// A layer of a format 2 app icon that the host draws live on top of the icon the service
/// composes (docs/icon-format.md of silica-icons, "Dynamic layers"): the service leaves it out.
class DynamicLayer {
  const DynamicLayer({
    required this.layer,
    required this.kind,
    this.unit,
    this.pivot = const Offset(512, 512),
    this.minSize = 0,
    this.clearMode = 'ramp',
    this.tintedMode = 'ramp',
    this.text,
  });

  /// The text a calendar layer draws live (`calendar-month`, `calendar-day`) instead of its SVG,
  /// which is the text at the design pose (OCT 16), for the fallback.
  final IconText? text;

  /// The layer's SVG on the 1024 canvas (drawn pointing to 12 for a hand).
  final IconLayer layer;
  final DynamicKind kind;
  final ClockUnit? unit;

  /// The hand turns around this canvas point.
  final Offset pivot;

  /// Drawn only when the icon canvas in pt is at least this.
  final double minSize;

  /// The modes of the layer in Clear and Tinted (`hide` leaves it out).
  final String clearMode;
  final String tintedMode;
}

class LayeredIcon {
  const LayeredIcon({
    required this.id,
    required this.kind,
    required this.layers,
    this.dynamic,
    this.rendered = const {},
    this.format = 1,
    this.dir,
    this.dynamicLayers = const [],
  });

  /// 1: background and foreground drawn here; 2: composed by the thumbnail service
  /// (`Thumbnails1.AppIcon`), the bundled `icon.png` / `icon-dark.png` (in [rendered]) being the
  /// fallback and [dynamicLayers] drawn live.
  final int format;

  /// The icon folder (format 2: what the service is asked for).
  final String? dir;

  /// The layers a format 2 icon draws live.
  final List<DynamicLayer> dynamicLayers;

  final String id;
  final IconKind kind;

  /// From bottom to top: for apps the background and the foregrounds, for files the artwork.
  final List<IconLayer> layers;
  final IconDynamic? dynamic;

  /// The whole icon as designed (relief, shadows and glass baked in), a 1024 PNG per theme
  /// (manifest `rendered`, silica-icons ≥ 0.6). Empty in older packs: the layers are used.
  final Map<IconAppearance, String> rendered;

  /// The rendered PNG of [appearance], if the pack has one.
  String? renderedFor(IconAppearance appearance) => rendered[appearance];
}

final RegExp _idPattern = RegExp(r'^[a-z0-9][a-z0-9-]{0,63}$');
final RegExp _filePattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}\.svg$');
final RegExp _pngPattern = RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}\.png$');

/// Reads `icon.json` of the folder `dir`; null if the manifest is invalid or a file is missing.
LayeredIcon? parseManifest(String dir, String text, {int depth = 0}) {
  Object? json;
  try {
    json = jsonDecode(text);
  } on FormatException {
    return null;
  }
  if (json is Map && json['format'] == 2) return _parseFormat2(dir, json);
  if (json is! Map || json['format'] != 1) return null;
  final id = json['id'];
  if (id is! String || !_idPattern.hasMatch(id)) return null;
  final kind = switch (json['kind']) {
    'app' => IconKind.app,
    'file' => IconKind.file,
    _ => null,
  };
  if (kind == null) return null;
  final variants = json['variants'];
  final darkMap = variants is Map ? variants['dark'] : null;

  String? file(Object? name) =>
      name is String &&
          _filePattern.hasMatch(name) &&
          File('$dir/$name').existsSync()
      ? '$dir/$name'
      : null;

  final layers = <IconLayer>[];
  final rawLayers = json['layers'];
  if (rawLayers is! List || rawLayers.isEmpty || rawLayers.length > 5)
    return null;
  for (final raw in rawLayers) {
    if (raw is! Map) return null;
    final role = raw['role'];
    if (role is! String) return null;
    // A layer borrowed from another icon of the pack (`"icon": "file-generic"`): the sheet
    // of the type icons. Its layers take this place; one level deep, no cycles.
    final ref = raw['icon'];
    if (ref is String && raw['file'] == null) {
      final borrowed = depth == 0 ? _borrowedLayers(dir, ref) : null;
      if (borrowed == null) return null;
      layers.addAll(borrowed);
      continue;
    }
    final path = file(raw['file']);
    if (path == null) return null;
    layers.add(
      IconLayer(
        path,
        darkPath: darkMap is Map ? file(darkMap[role]) : null,
        shadow: raw['shadow'] == 'neutral' || raw['shadow'] == 'chromatic',
        role: role,
        when: raw['when'] is String ? raw['when'] as String : null,
      ),
    );
  }
  return LayeredIcon(
    id: id,
    kind: kind,
    layers: layers,
    dynamic: _parseDynamic(json['dynamic'], file, dir),
    rendered: _parseRendered(json['rendered'], dir),
  );
}

/// A format 2 app icon: the layers are listed (their SVGs are what the service composes and the
/// host draws live), the flat fallback PNGs go in `rendered`. Null when the manifest is invalid
/// or the light fallback is missing.
LayeredIcon? _parseFormat2(String dir, Map json) {
  final id = json['id'];
  if (id is! String || !_idPattern.hasMatch(id) || json['kind'] != 'app') {
    return null;
  }
  String? png(Object? name) =>
      name is String &&
          _pngPattern.hasMatch(name) &&
          File('$dir/$name').existsSync()
      ? '$dir/$name'
      : null;
  final fallback = json['fallback'];
  final light = png(fallback is Map ? fallback['light'] : 'icon.png');
  if (light == null) return null;
  final dark = png(fallback is Map ? fallback['dark'] : 'icon-dark.png');
  final raw = json['layers'];
  if (raw is! List || raw.isEmpty || raw.length > 9) return null;
  final layers = <IconLayer>[];
  final dynamicLayers = <DynamicLayer>[];
  double? number(Object? v) => v is num && v.isFinite ? v.toDouble() : null;
  String mode(Object? spec) =>
      spec is Map && spec['mode'] is String ? spec['mode'] as String : 'ramp';
  for (final item in raw) {
    if (item is! Map) return null;
    final layerId = item['id'];
    final role = item['role'];
    if (layerId is! String ||
        !_idPattern.hasMatch(layerId) ||
        role is! String) {
      return null;
    }
    final path = '$dir/layers/$layerId.svg';
    if (!File(path).existsSync()) return null;
    final darkPath = '$dir/layers/$layerId-dark.svg';
    final layer = IconLayer(
      path,
      darkPath: File(darkPath).existsSync() ? darkPath : null,
      shadow: role == 'body' || role == 'dynamic',
      role: role,
    );
    layers.add(layer);
    final dyn = item['dynamic'];
    if (dyn is! Map) continue;
    final kind = DynamicKind.values
        .where((k) => k.key == dyn['kind'])
        .firstOrNull;
    if (kind == null) return null;
    final unit = ClockUnit.values
        .where((u) => u.name == dyn['unit'])
        .firstOrNull;
    if (kind == DynamicKind.clockHand && unit == null) return null;
    final isText =
        kind == DynamicKind.calendarMonth || kind == DynamicKind.calendarDay;
    final text = isText ? _parseText(dyn) : null;
    if (isText && text == null) return null;
    final pivot = dyn['pivot'];
    final px = pivot is List && pivot.length == 2 ? number(pivot[0]) : null;
    final py = pivot is List && pivot.length == 2 ? number(pivot[1]) : null;
    dynamicLayers.add(
      DynamicLayer(
        layer: layer,
        kind: kind,
        unit: unit,
        pivot: Offset(px ?? 512, py ?? 512),
        minSize: number(item['min_size']) ?? 0,
        clearMode: mode(item['clear']),
        tintedMode: mode(item['tinted']),
        text: text,
      ),
    );
  }
  return LayeredIcon(
    id: id,
    kind: IconKind.app,
    layers: layers,
    format: 2,
    dir: dir,
    dynamicLayers: dynamicLayers,
    rendered: {IconAppearance.light: light, IconAppearance.dark: dark ?? light},
  );
}

/// The layers of the sibling icon `ref` (same group folder as [dir]), or null.
List<IconLayer>? _borrowedLayers(String dir, String ref) {
  if (!_idPattern.hasMatch(ref)) return null;
  final slash = dir.lastIndexOf('/');
  if (slash < 0) return null;
  final manifest = File('${dir.substring(0, slash)}/$ref/icon.json');
  try {
    if (!manifest.existsSync()) return null;
    return parseManifest(
      manifest.parent.path,
      manifest.readAsStringSync(),
      depth: 1,
    )?.layers;
  } on FileSystemException {
    return null;
  }
}

/// `rendered`: theme key → PNG in the icon's folder. Unknown keys, names outside the folder and
/// missing files are skipped (that theme falls back to the layers).
Map<IconAppearance, String> _parseRendered(Object? raw, String dir) {
  if (raw is! Map) return const {};
  final rendered = <IconAppearance, String>{};
  for (final appearance in IconAppearance.values) {
    final name = raw[appearance.key];
    if (name is String &&
        _pngPattern.hasMatch(name) &&
        File('$dir/$name').existsSync()) {
      rendered[appearance] = '$dir/$name';
    }
  }
  return rendered;
}

IconDynamic? _parseDynamic(
  Object? raw,
  String? Function(Object?) file,
  String dir,
) {
  if (raw is! Map) return null;
  IconLayer? layer(Object? name) {
    if (name is! String) return null;
    final path = file(name);
    if (path == null) return null;
    final dot = name.lastIndexOf('.');
    return IconLayer(
      path,
      darkPath: file('${name.substring(0, dot)}-dark${name.substring(dot)}'),
    );
  }

  switch (raw['type']) {
    case 'clock':
      final hands = raw['hands'];
      if (hands is! List) return null;
      final byName = <String, IconLayer>{};
      for (final hand in hands) {
        if (hand is! Map || hand['unit'] is! String) continue;
        if (layer(hand['file']) case final l?)
          byName[hand['unit'] as String] = l;
      }
      final hour = byName['hour'];
      final minute = byName['minute'];
      final cap = layer(raw['cap']);
      if (hour == null || minute == null || cap == null) return null;
      return ClockHands(
        hour: hour,
        minute: minute,
        second: byName['second'],
        cap: cap,
      );
    case 'calendar':
      final month = _parseText(raw['month']);
      final day = _parseText(raw['day']);
      if (month == null || day == null) return null;
      return CalendarText(month: month, day: day);
    default:
      return null;
  }
}

IconText? _parseText(Object? raw) {
  if (raw is! Map) return null;
  double? number(Object? v) => v is num && v.isFinite ? v.toDouble() : null;
  final size = number(raw['size']);
  final box = raw['box'];
  final color = _parseColor(raw['color']);
  if (size == null || size <= 0 || size > 1024 || color == null) return null;
  if (box is! List || box.length != 4) return null;
  final b = [for (final v in box) number(v)];
  if (b.contains(null)) return null;
  return IconText(
    size: size,
    weight: (number(raw['weight']) ?? 400).round().clamp(100, 900),
    tracking: number(raw['tracking']) ?? 0,
    color: color,
    darkColor: _parseColor(raw['dark_color']) ?? color,
    box: Rect.fromLTWH(b[0]!, b[1]!, b[2]!, b[3]!),
    maxWidth: number(raw['max_width']),
    upper: raw['case'] == 'upper',
    lower: raw['case'] == 'lower',
    font: raw['font'] is String ? raw['font'] as String : 'Inter',
    format: raw['format'] is String ? raw['format'] as String : '',
    refresh: raw['refresh'] == 'never' ? 'never' : 'midnight',
  );
}

Color? _parseColor(Object? raw) {
  if (raw is! String ||
      !RegExp(r'^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$').hasMatch(raw)) {
    return null;
  }
  final rgb = int.parse(raw.substring(1, 7), radix: 16);
  final alpha = raw.length == 9 ? int.parse(raw.substring(7), radix: 16) : 0xFF;
  return Color((alpha << 24) | rgb);
}

/// The folders with the icons, most important first: `SILICA_ICONS_DIR` (development), then
/// `silica/icons` in the XDG data folders.
List<String> silicaIconDirs(Map<String, String> env) => [
  if (env['SILICA_ICONS_DIR'] case final dir? when dir.isNotEmpty) dir,
  for (final dir in xdgDataDirs(env)) '$dir/silica/icons',
];

final Map<String, LayeredIcon?> _cache = {};

/// The icon `id` (folder `apps/<id>` or `files/<id>`), or null.
LayeredIcon? findSilicaIcon(String id, {Map<String, String>? env}) {
  if (!_idPattern.hasMatch(id)) return null;
  final environment = env ?? Platform.environment;
  if (env == null && _cache.containsKey(id)) return _cache[id];
  LayeredIcon? found;
  search:
  for (final base in silicaIconDirs(environment)) {
    for (final group in ['apps', 'files']) {
      final manifest = File('$base/$group/$id/icon.json');
      if (!manifest.existsSync()) continue;
      try {
        found = parseManifest(
          manifest.parent.path,
          manifest.readAsStringSync(),
        );
      } on FileSystemException {
        found = null;
      }
      if (found != null) break search;
    }
  }
  if (env == null) _cache[id] = found;
  return found;
}

/// The data folders according to the XDG Base Directory specification: the user's first.
List<String> xdgDataDirs(Map<String, String> env) {
  final home = env['HOME'] ?? '';
  final dataHome = env['XDG_DATA_HOME'] ?? '$home/.local/share';
  final dataDirs = (env['XDG_DATA_DIRS'] ?? '/usr/local/share:/usr/share')
      .split(':')
      .where((d) => d.isNotEmpty);
  return [dataHome, ...dataDirs];
}

/// The xdg-user-dirs folders (`~/.config/user-dirs.dirs`), by key: DESKTOP,
/// DOCUMENTS, DOWNLOAD, MUSIC, PICTURES, VIDEOS, TEMPLATES, PUBLICSHARE. An entry equal to the
/// home is disabled (xdg-user-dirs specification) and does not appear.
Map<String, String> xdgUserDirs(Map<String, String> env) {
  final home = _trimSlash(env['HOME'] ?? '');
  if (home.isEmpty) return const {};
  final config = env['XDG_CONFIG_HOME'] ?? '$home/.config';
  final dirs = <String, String>{};
  try {
    final file = File('$config/user-dirs.dirs');
    if (!file.existsSync() || file.lengthSync() > 64 * 1024) return dirs;
    final line = RegExp(r'^XDG_([A-Z]{1,32})_DIR="([^"]*)"\s*$');
    for (final text in file.readAsLinesSync()) {
      final m = line.firstMatch(text.trim());
      if (m == null) continue;
      var value = m[2]!;
      if (value.startsWith(r'$HOME')) {
        value = '$home${value.substring(5)}';
      } else if (!value.startsWith('/')) {
        continue;
      }
      value = _trimSlash(value);
      if (value.isEmpty || value == home || value.contains('/../')) continue;
      dirs[m[1]!] = value;
    }
  } on FileSystemException {
    return dirs;
  } on FormatException {
    return dirs;
  }
  return dirs;
}

String _trimSlash(String path) {
  var p = path;
  while (p.length > 1 && p.endsWith('/')) {
    p = p.substring(0, p.length - 1);
  }
  return p;
}

/// The special folder key of `path` (for `folders` of the generic folder): the keys
/// of xdg-user-dirs, then `HOME`, `APPLICATIONS` (`~/Applications` and `applications` in the
/// XDG data folders) and `LIBRARY` (`~/.local/share`). `SHARED` and `NETWORK` have no
/// path: they are passed by whoever knows the folder. Null for any other folder.
String? specialFolderKey(String path, {Map<String, String>? env}) {
  final environment = env ?? Platform.environment;
  final p = _trimSlash(path);
  if (p.isEmpty) return null;
  final home = _trimSlash(environment['HOME'] ?? '');
  for (final MapEntry(:key, :value) in xdgUserDirs(environment).entries) {
    if (value == p) return key;
  }
  if (home.isNotEmpty && p == home) return 'HOME';
  final data = xdgDataDirs(environment).map(_trimSlash).toList();
  if ((home.isNotEmpty && p == '$home/Applications') ||
      data.any((d) => p == '$d/applications')) {
    return 'APPLICATIONS';
  }
  if (home.isNotEmpty && p == '$home/.local/share') return 'LIBRARY';
  return null;
}

/// The `symbols/` folder of the first silica-icons folder that has one (the folder pickers list
/// the symbols from it); null when there is none.
String? silicaSymbolsDir({Map<String, String>? env}) {
  for (final base in silicaIconDirs(env ?? Platform.environment)) {
    final dir = '$base/symbols';
    try {
      if (Directory(dir).existsSync()) return dir;
    } on FileSystemException {
      continue;
    }
  }
  return null;
}
