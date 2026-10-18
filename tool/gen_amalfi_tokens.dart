// Generates `lib/src/amalfi/tokens.g.dart` from the Amalfi design tokens: `tool/amalfi/tokens.json`
// (colours, type, spacing, sizes, radii, shadows, materials, window controls) and the token
// tables of `tool/amalfi/motion.md` (springs, fades, delays).
//
// Usage, from the package root:
//
//   dart run tool/gen_amalfi_tokens.dart          writes the generated file
//   dart run tool/gen_amalfi_tokens.dart --check  exits 1 when the committed file is stale
//
// Pure Dart, no network. The output goes through `dart format` (the same SDK), so the
// generated file passes the format gate. Input that the generator does not understand
// (an unknown key, a malformed colour, a missing table) stops it with a message naming the
// token: it never guesses.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

const String tokensPath = 'tool/amalfi/tokens.json';
const String motionPath = 'tool/amalfi/motion.md';
const String pubspecPath = 'pubspec.yaml';
const String outputPath = 'lib/src/amalfi/tokens.g.dart';

/// Input the generator cannot turn into tokens.
class TokenError implements Exception {
  TokenError(this.message);

  final String message;

  @override
  String toString() => message;
}

Future<void> main(List<String> args) async {
  final check = args.contains('--check');
  final unknown = args.where((a) => a != '--check').toList();
  if (unknown.isNotEmpty) {
    stderr.writeln(
      'gen_amalfi_tokens: unknown arguments: ${unknown.join(' ')}',
    );
    stderr.writeln('usage: dart run tool/gen_amalfi_tokens.dart [--check]');
    exitCode = 64;
    return;
  }
  final String source;
  try {
    source = await formatDart(
      generate(
        tokensJson: _read(tokensPath),
        motionMarkdown: _read(motionPath),
        fontFamilies: fontFamiliesOf(_read(pubspecPath)),
      ),
    );
  } on TokenError catch (e) {
    stderr.writeln('gen_amalfi_tokens: $e');
    exitCode = 65;
    return;
  }
  final out = File(outputPath);
  if (check) {
    final current = out.existsSync() ? out.readAsStringSync() : null;
    if (current != source) {
      stderr.writeln(
        'gen_amalfi_tokens: $outputPath is stale; run '
        '`dart run tool/gen_amalfi_tokens.dart` and commit the result',
      );
      exitCode = 1;
    }
    return;
  }
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(source);
}

String _read(String path) {
  final file = File(path);
  if (!file.existsSync()) {
    throw TokenError('$path not found (run from the package root)');
  }
  return file.readAsStringSync();
}

/// The font families declared in [pubspec] (`- family: <name>`).
Set<String> fontFamiliesOf(String pubspec) => {
  for (final m in RegExp(
    r'^\s*-\s*family:\s*(.+?)\s*$',
    multiLine: true,
  ).allMatches(pubspec))
    m.group(1)!,
};

/// Formats [source] with `dart format` of the running SDK (or `dart` on the PATH when not
/// running on the Dart VM, as under `flutter test`).
Future<String> formatDart(String source) async {
  final exe = Platform.resolvedExecutable;
  final dart = RegExp(r'(^|[/\\])dart(\.exe)?$').hasMatch(exe) ? exe : 'dart';
  final Process process;
  try {
    process = await Process.start(dart, ['format', '--language-version=3.9']);
  } on ProcessException catch (e) {
    throw TokenError('cannot run `$dart format`: ${e.message}');
  }
  process.stdin.write(source);
  await process.stdin.close();
  final out = process.stdout.transform(utf8.decoder).join();
  final err = process.stderr.transform(utf8.decoder).join();
  final code = await process.exitCode;
  if (code != 0) {
    throw TokenError(
      '`dart format` failed on the generated code:\n${await err}',
    );
  }
  return out;
}

// ---------------------------------------------------------------------------------------------
// Reading the JSON.

String _kind(Object? v) => switch (v) {
  null => 'null',
  String() => 'a string',
  num() => 'a number',
  bool() => 'a boolean',
  List() => 'a list',
  Map() => 'an object',
  _ => v.runtimeType.toString(),
};

Map<String, Object?> _object(Object? v, String path) {
  if (v is Map<String, Object?>) return v;
  throw TokenError('$path: expected an object, got ${_kind(v)}');
}

Object? _field(Map<String, Object?> map, String key, String path) {
  if (!map.containsKey(key)) throw TokenError('$path: missing "$key"');
  return map[key];
}

double _number(Object? v, String path) {
  if (v is num) return v.toDouble();
  throw TokenError('$path: expected a number, got ${_kind(v)}');
}

String _string(Object? v, String path) {
  if (v is String) return v;
  throw TokenError('$path: expected a string, got ${_kind(v)}');
}

bool _boolean(Object? v, String path) {
  if (v is bool) return v;
  throw TokenError('$path: expected true or false, got ${_kind(v)}');
}

List<Object?> _list(Object? v, String path) {
  if (v is List<Object?>) return v;
  throw TokenError('$path: expected a list, got ${_kind(v)}');
}

void _onlyKeys(Map<String, Object?> map, Set<String> allowed, String path) {
  for (final key in map.keys) {
    if (!allowed.contains(key)) {
      throw TokenError(
        '$path: unknown key "$key" (known: ${allowed.join(', ')}); '
        'teach tool/gen_amalfi_tokens.dart about it',
      );
    }
  }
}

final _hexColor = RegExp(r'^#([0-9A-Fa-f]{6})([0-9A-Fa-f]{2})?$');

/// A `#RRGGBB` or `#RRGGBBAA` colour as ARGB.
int _color(Object? v, String path) {
  final s = _string(v, path);
  final m = _hexColor.firstMatch(s);
  if (m == null) {
    throw TokenError('$path: expected #RRGGBB or #RRGGBBAA, got "$s"');
  }
  final rgb = int.parse(m.group(1)!, radix: 16);
  final alpha = m.group(2) == null ? 0xFF : int.parse(m.group(2)!, radix: 16);
  return (alpha << 24) | rgb;
}

String _argb(int argb) =>
    '0x${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';

String _colorLiteral(int argb) => 'Color(${_argb(argb)})';

/// `#RRGGBBAA` for docs.
String _hexDoc(int argb) {
  final rgb = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
  final a = (argb >>> 24).toRadixString(16).padLeft(2, '0');
  return '#${rgb.toUpperCase()}${a.toUpperCase()}';
}

String _num(double v) {
  if (v == v.roundToDouble() && v.abs() < 1e15) return v.toInt().toString();
  return v.toString();
}

String _dartString(String s) =>
    "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'").replaceAll(r'$', r'\$')}'";

/// Dart's reserved words and the built-in identifiers that cannot name a member.
const _reserved = {
  'assert',
  'break',
  'case',
  'catch',
  'class',
  'const',
  'continue',
  'default',
  'do', //
  'else',
  'enum',
  'extends',
  'false',
  'final',
  'finally',
  'for',
  'if',
  'in',
  'is',
  'new',
  'null',
  'rethrow',
  'return',
  'super',
  'switch',
  'this',
  'throw',
  'true',
  'try',
  'var',
  'void', 'while', 'with', 'await', 'yield',
};

/// `Accent/Amalfi Pressed` → `accentAmalfiPressed`, `ANSI Red` → `ansiRed`,
/// `smallControl` → `smallControl`.
String _camel(String name, String path) {
  final words = _splitCamel(
    name,
  ).split(RegExp(r'[^A-Za-z0-9]+')).where((w) => w.isNotEmpty).toList();
  if (words.isEmpty)
    throw TokenError('$path: "$name" has no letters or digits');
  final b = StringBuffer(words.first.toLowerCase());
  for (final w in words.skip(1)) {
    b
      ..write(w[0].toUpperCase())
      ..write(w.substring(1).toLowerCase());
  }
  final id = b.toString();
  if (!RegExp(r'^[a-z][A-Za-z0-9]*$').hasMatch(id) || _reserved.contains(id)) {
    throw TokenError(
      '$path: "$name" gives "$id", not a valid Dart member name',
    );
  }
  return id;
}

String _pascal(String name, String path) {
  final c = _camel(name, path);
  return c[0].toUpperCase() + c.substring(1);
}

void _unique(Map<String, String> seen, String id, String token, String path) {
  final other = seen[id];
  if (other != null) {
    throw TokenError(
      '$path: "$token" and "$other" both map to the Dart name "$id"',
    );
  }
  seen[id] = token;
}

/// Doc comment lines, wrapped at 80 columns (a longer word stays whole).
void _doc(StringBuffer o, String text, {String indent = '  '}) {
  final width = 80 - indent.length - 4;
  for (final paragraph in text.split('\n')) {
    if (paragraph.isEmpty) {
      o.writeln('$indent///');
      continue;
    }
    var line = StringBuffer();
    for (final word in paragraph.split(' ')) {
      if (line.isNotEmpty && line.length + 1 + word.length > width) {
        o.writeln('$indent/// $line');
        line = StringBuffer();
      }
      if (line.isNotEmpty) line.write(' ');
      line.write(word);
    }
    o.writeln('$indent/// $line');
  }
}

// ---------------------------------------------------------------------------------------------
// The generator.

/// The generated library (unformatted) from [tokensJson], [motionMarkdown] and the
/// [fontFamilies] the package declares. Deterministic: the same input gives the same output.
String generate({
  required String tokensJson,
  required String motionMarkdown,
  required Set<String> fontFamilies,
}) {
  final Object? decoded;
  try {
    decoded = jsonDecode(tokensJson);
  } on FormatException catch (e) {
    throw TokenError('$tokensPath: not valid JSON: ${e.message}');
  }
  final root = _object(decoded, tokensPath);
  _onlyKeys(root, {
    r'$schema',
    'name',
    'source',
    'unit',
    'colors',
    'typography',
    'grid',
    'spacing',
    'controlHeights',
    'controlIcons',
    'radii',
    'shadows',
    'focus',
    'materials',
    'states',
    'windowControls',
    'switch',
    'iconFont',
  }, tokensPath);
  final schema = _string(_field(root, r'$schema', tokensPath), r'$schema');
  if (schema != 'silica-amalfi-tokens/1') {
    throw TokenError('$tokensPath: unsupported \$schema "$schema"');
  }

  final o = StringBuffer();
  o
    ..writeln('// GENERATED CODE - DO NOT EDIT BY HAND.')
    ..writeln('//')
    ..writeln(
      '// Generated by tool/gen_amalfi_tokens.dart from $tokensPath and',
    )
    ..writeln('// $motionPath; edit those and run')
    ..writeln('// `dart run tool/gen_amalfi_tokens.dart`.')
    ..writeln('//')
    ..writeln(
      '// ${_string(_field(root, 'name', tokensPath), 'name')}, '
      'unit: ${_string(_field(root, 'unit', tokensPath), 'unit')}.',
    )
    ..writeln(
      '// Source: ${_string(_field(root, 'source', tokensPath), 'source')}.',
    )
    ..writeln()
    ..writeln("import 'package:flutter/widgets.dart';")
    ..writeln()
    ..writeln("import 'token_types.dart';")
    ..writeln();

  final colors = _Colors.read(
    _object(_field(root, 'colors', tokensPath), 'colors'),
  );
  colors.write(o);
  _writeTypography(
    o,
    _object(_field(root, 'typography', tokensPath), 'typography'),
    colors,
    fontFamilies,
  );
  _writeGrid(o, _object(_field(root, 'grid', tokensPath), 'grid'));
  _writeSpacing(o, _object(_field(root, 'spacing', tokensPath), 'spacing'));
  _writeControls(
    o,
    _object(_field(root, 'controlHeights', tokensPath), 'controlHeights'),
    _object(_field(root, 'controlIcons', tokensPath), 'controlIcons'),
  );
  _writeRadii(o, _object(_field(root, 'radii', tokensPath), 'radii'));
  final shadowLevels = _writeShadows(
    o,
    _object(_field(root, 'shadows', tokensPath), 'shadows'),
    colors,
  );
  _writeFocus(o, _object(_field(root, 'focus', tokensPath), 'focus'), colors);
  _writeStates(
    o,
    _object(_field(root, 'states', tokensPath), 'states'),
    colors,
  );
  _writeMaterials(
    o,
    _object(_field(root, 'materials', tokensPath), 'materials'),
    colors,
    shadowLevels,
  );
  _writeWindowControls(
    o,
    _object(_field(root, 'windowControls', tokensPath), 'windowControls'),
  );
  _writeSwitch(o, _object(_field(root, 'switch', tokensPath), 'switch'));
  _writeMotion(o, motionMarkdown);
  return o.toString();
}

// Colours ------------------------------------------------------------------------------------

class _App {
  _App(this.name, this.className, this.field);

  final String name;
  final String className;
  final String field;

  /// Token (without prefix) → member name, in order.
  final Map<String, String> members = {};

  /// Brightness ('light' / 'dark') → token → ARGB.
  final Map<String, Map<String, int>> values = {};
}

class _Colors {
  _Colors(this.system, this.systemValues, this.apps);

  /// Token → member name, in the order of `colors.light`.
  final Map<String, String> system;

  /// 'light' / 'dark' → token → ARGB.
  final Map<String, Map<String, int>> systemValues;

  final Map<String, _App> apps;

  static const _members = {
    'brightness',
    'light',
    'dark',
    'of',
    'byName',
    'palette',
    'app',
    'tokenNames',
    'appNames',
  };

  static const _appMembers = {
    'brightness',
    'light',
    'dark',
    'app',
    'appearances',
    'tokenNames',
  };

  static _Colors read(Map<String, Object?> colors) {
    _onlyKeys(colors, {'light', 'dark'}, 'colors');
    final system = <String, String>{};
    final systemValues = <String, Map<String, int>>{'light': {}, 'dark': {}};
    final apps = <String, _App>{};
    final seen = <String, String>{for (final m in _members) m: '(member)'};
    final classes = <String, String>{};
    for (final scheme in const ['light', 'dark']) {
      final map = _object(_field(colors, scheme, 'colors'), 'colors.$scheme');
      for (final MapEntry(:key, :value) in map.entries) {
        final path = 'colors.$scheme["$key"]';
        final argb = _color(value, path);
        final parts = key.split('/');
        if (parts.first == 'App') {
          if (parts.length != 3 || parts[1].isEmpty || parts[2].isEmpty) {
            throw TokenError('$path: app tokens are named App/<App>/<Token>');
          }
          final app = apps.putIfAbsent(parts[1], () {
            final className = 'Amalfi${_pascal(parts[1], path)}Colors';
            _unique(classes, className, parts[1], path);
            final field = _camel(parts[1], path);
            _unique(seen, field, 'App/${parts[1]}', path);
            return _App(parts[1], className, field);
          });
          final values = app.values.putIfAbsent(scheme, () => {});
          values[parts[2]] = argb;
          if (!app.members.containsKey(parts[2])) {
            final id = _camel(parts[2], path);
            if (_appMembers.contains(id) || app.members.containsValue(id)) {
              throw TokenError(
                '$path: "${parts[2]}" gives the Dart name "$id", already used',
              );
            }
            app.members[parts[2]] = id;
          }
        } else {
          if (parts.length != 2 || parts.any((p) => p.isEmpty)) {
            throw TokenError('$path: colour tokens are named <Group>/<Name>');
          }
          systemValues[scheme]![key] = argb;
          if (scheme == 'light') {
            final id = _camel(key, path);
            _unique(seen, id, key, path);
            system[key] = id;
          }
        }
      }
    }
    final light = systemValues['light']!.keys.toSet();
    final dark = systemValues['dark']!.keys.toSet();
    if (light.length != dark.length || !light.containsAll(dark)) {
      throw TokenError(
        'colors: light and dark differ outside App/*: '
        'only light ${light.difference(dark).toList()}, '
        'only dark ${dark.difference(light).toList()}',
      );
    }
    for (final app in apps.values) {
      final schemes = app.values.values.map((v) => v.keys.toSet()).toList();
      if (schemes.length == 2 &&
          (schemes[0].length != schemes[1].length ||
              !schemes[0].containsAll(schemes[1]))) {
        throw TokenError(
          'colors: App/${app.name} has different tokens in light and dark: '
          '${schemes[0].difference(schemes[1]).toList()} / '
          '${schemes[1].difference(schemes[0]).toList()}',
        );
      }
    }
    return _Colors(system, systemValues, apps);
  }

  /// The ARGB of a system token in [scheme]; fails when it does not exist.
  int value(String scheme, String token, String path) {
    final v = systemValues[scheme]?[token];
    if (v == null) throw TokenError('$path: no colour token "$token"');
    return v;
  }

  String member(String token, String path) {
    final id = system[token];
    if (id == null) throw TokenError('$path: no colour token "$token"');
    return id;
  }

  /// The scheme whose palette [app] uses in [scheme] (its own, or its only one).
  static String appScheme(_App app, String scheme) =>
      app.values.containsKey(scheme) ? scheme : app.values.keys.first;

  void write(StringBuffer o) {
    final appList = apps.values.toList();
    for (final app in appList) {
      _writeApp(o, app);
    }

    o.writeln(
      '/// The Amalfi colours of one appearance: every colour token of `tokens.json`',
    );
    o.writeln(
      '/// as a typed field, plus the per-app palettes (`App/<App>/<Token>`).',
    );
    o.writeln('///');
    o.writeln('/// ```dart');
    o.writeln('/// final colors = AmalfiTheme.of(context).colors;');
    o.writeln('/// colors.accentAmalfi;                  // Accent/Amalfi');
    o.writeln(
      "/// colors.byName('Text/Secondary');      // by the token's name",
    );
    o.writeln(
      "/// colors.app('Mail', 'Flag');           // an app's palette, by name",
    );
    o.writeln('/// colors.mail.flag;                     // the same, typed');
    o.writeln('/// ```');
    o.writeln('///');
    o.writeln('/// Field names are the token names in lower camel case');
    o.writeln(
      '/// (`Accent/Amalfi Pressed` → `accentAmalfiPressed`, `Shadow/1` → `shadow1`).',
    );
    o.writeln(
      '/// An app with a single appearance has the same palette in both instances',
    );
    o.writeln('/// (see [AmalfiAppColors]).');
    o.writeln('final class AmalfiColors {');
    o.writeln('  const AmalfiColors._({');
    o.writeln('    required this.brightness,');
    for (final id in system.values) {
      o.writeln('    required this.$id,');
    }
    for (final app in appList) {
      o.writeln('    required this.${app.field},');
    }
    o.writeln('  });');
    o.writeln();
    o.writeln('  /// The appearance of these colours.');
    o.writeln('  final Brightness brightness;');
    for (final MapEntry(key: token, value: id) in system.entries) {
      o.writeln();
      _doc(
        o,
        '`$token`: light `${_hexDoc(systemValues['light']![token]!)}`, '
        'dark `${_hexDoc(systemValues['dark']![token]!)}`.',
      );
      o.writeln('  final Color $id;');
    }
    for (final app in appList) {
      o.writeln();
      _doc(o, 'The palette of ${app.name} (`App/${app.name}/*`).');
      o.writeln('  final ${app.className} ${app.field};');
    }
    for (final scheme in const ['light', 'dark']) {
      o.writeln();
      _doc(o, 'The $scheme appearance.');
      o.writeln('  static const AmalfiColors $scheme = AmalfiColors._(');
      o.writeln('    brightness: Brightness.$scheme,');
      for (final MapEntry(key: token, value: id) in system.entries) {
        o.writeln('    $id: ${_colorLiteral(systemValues[scheme]![token]!)},');
      }
      for (final app in appList) {
        o.writeln(
          '    ${app.field}: ${app.className}.${appScheme(app, scheme)},',
        );
      }
      o.writeln('  );');
    }
    o.writeln();
    _doc(o, 'The colours of [brightness].');
    o.writeln(
      '  static AmalfiColors of(Brightness brightness) => switch (brightness) {',
    );
    o.writeln('    Brightness.light => light,');
    o.writeln('    Brightness.dark => dark,');
    o.writeln('  };');
    o.writeln();
    _doc(
      o,
      'These colours with the accent replaced: [accent] for `Accent/Amalfi`, [pressed] for\n'
      '`Accent/Amalfi Pressed` and [soft] for `Accent/Amalfi Soft` (the accent chosen in the\n'
      'system settings).',
    );
    o.writeln(
      '  AmalfiColors withAccent(Color accent, Color pressed, Color soft) =>',
    );
    o.writeln('      AmalfiColors._(');
    o.writeln('        brightness: brightness,');
    for (final id in system.values) {
      final value = switch (id) {
        'accentAmalfi' => 'accent',
        'accentAmalfiPressed' => 'pressed',
        'accentAmalfiSoft' => 'soft',
        _ => id,
      };
      o.writeln('        $id: $value,');
    }
    for (final app in appList) {
      o.writeln('        ${app.field}: ${app.field},');
    }
    o.writeln('      );');
    o.writeln();
    _doc(
      o,
      'Every colour token name, apps included, in the order of `tokens.json`.',
    );
    o.writeln('  static const List<String> tokenNames = [');
    for (final token in system.keys) {
      o.writeln('    ${_dartString(token)},');
    }
    for (final app in appList) {
      for (final token in app.members.keys) {
        o.writeln('    ${_dartString('App/${app.name}/$token')},');
      }
    }
    o.writeln('  ];');
    o.writeln();
    _doc(o, 'The apps with a palette.');
    o.writeln('  static const List<String> appNames = [');
    for (final app in appList) {
      o.writeln('    ${_dartString(app.name)},');
    }
    o.writeln('  ];');
    o.writeln();
    _doc(
      o,
      'The colour of the token named [token] (`Text/Primary`, `App/Mail/Flag`); null\n'
      'when there is no such token.',
    );
    o.writeln('  Color? byName(String token) => switch (token) {');
    for (final MapEntry(key: token, value: id) in system.entries) {
      o.writeln('    ${_dartString(token)} => $id,');
    }
    for (final app in appList) {
      for (final MapEntry(key: token, value: id) in app.members.entries) {
        o.writeln(
          '    ${_dartString('App/${app.name}/$token')} => ${app.field}.$id,',
        );
      }
    }
    o.writeln('    _ => null,');
    o.writeln('  };');
    o.writeln();
    _doc(
      o,
      'The palette of [app] (`Mail`, `Mission Control`); null when it has none.',
    );
    o.writeln('  AmalfiAppColors? palette(String app) => switch (app) {');
    for (final app in appList) {
      o.writeln('    ${_dartString(app.name)} => ${app.field},');
    }
    o.writeln('    _ => null,');
    o.writeln('  };');
    o.writeln();
    _doc(
      o,
      'The colour [token] of the palette of [app] (`app(\'Mail\', \'Flag\')`); null when\n'
      'there is no such app or token.',
    );
    o.writeln(
      '  Color? app(String app, String token) => palette(app)?[token];',
    );
    o.writeln('}');
    o.writeln();
  }

  void _writeApp(StringBuffer o, _App app) {
    final schemes = app.values.keys.toList();
    final single = schemes.length == 1;
    _doc(
      o,
      'The palette of ${app.name} (`App/${app.name}/*`)'
      '${single ? ': ${schemes.single} only' : ''}.',
      indent: '',
    );
    o.writeln('final class ${app.className} extends AmalfiAppColors {');
    o.writeln('  const ${app.className}._({');
    o.writeln('    required this.brightness,');
    for (final id in app.members.values) {
      o.writeln('    required this.$id,');
    }
    o.writeln('  });');
    o.writeln();
    o.writeln('  @override');
    o.writeln('  final Brightness brightness;');
    for (final MapEntry(key: token, value: id) in app.members.entries) {
      o.writeln();
      _doc(
        o,
        '`App/${app.name}/$token`: '
        '${schemes.map((s) => '$s `${_hexDoc(app.values[s]![token]!)}`').join(', ')}.',
      );
      o.writeln('  final Color $id;');
    }
    for (final scheme in schemes) {
      o.writeln();
      _doc(o, 'The $scheme palette.');
      o.writeln(
        '  static const ${app.className} $scheme = ${app.className}._(',
      );
      o.writeln('    brightness: Brightness.$scheme,');
      for (final MapEntry(key: token, value: id) in app.members.entries) {
        o.writeln('    $id: ${_colorLiteral(app.values[scheme]![token]!)},');
      }
      o.writeln('  );');
    }
    o.writeln();
    o.writeln('  @override');
    o.writeln("  String get app => ${_dartString(app.name)};");
    o.writeln();
    o.writeln('  @override');
    o.writeln(
      '  Set<Brightness> get appearances => '
      'const {${schemes.map((s) => 'Brightness.$s').join(', ')}};',
    );
    o.writeln();
    o.writeln('  @override');
    o.writeln('  List<String> get tokenNames => const [');
    for (final token in app.members.keys) {
      o.writeln('    ${_dartString(token)},');
    }
    o.writeln('  ];');
    o.writeln();
    o.writeln('  @override');
    o.writeln('  Color? operator [](String token) => switch (token) {');
    for (final MapEntry(key: token, value: id) in app.members.entries) {
      o.writeln('    ${_dartString(token)} => $id,');
    }
    o.writeln('    _ => null,');
    o.writeln('  };');
    o.writeln('}');
    o.writeln();
  }
}

// Typography ---------------------------------------------------------------------------------

void _writeTypography(
  StringBuffer o,
  Map<String, Object?> typography,
  _Colors colors,
  Set<String> fontFamilies,
) {
  if (typography.isEmpty) throw TokenError('typography: no text styles');
  final seen = <String, String>{
    for (final m in const ['tokens', 'tokenNamed', 'byName']) m: '(member)',
  };
  final styles = <(String, String)>[];
  o.writeln(
    '/// The Amalfi text styles: Inter for the interface, JetBrains Mono for',
  );
  o.writeln('/// monospaced text, both served by this package.');
  o.writeln('///');
  o.writeln(
    '/// Each style is a [TextStyle] factory (`AmalfiType.body(color: …)`) and a',
  );
  o.writeln('/// token with its raw values (`AmalfiType.bodyToken`).');
  o.writeln('abstract final class AmalfiType {');
  for (final MapEntry(key: name, value: raw) in typography.entries) {
    final path = 'typography["$name"]';
    final style = _object(raw, path);
    _onlyKeys(style, {
      'family',
      'size',
      'lineHeight',
      'weight',
      'colors',
      'use',
      'note',
    }, path);
    final family = _string(_field(style, 'family', path), '$path.family');
    if (!fontFamilies.contains(family)) {
      throw TokenError(
        '$path.family: "$family" is not a font family of $pubspecPath '
        '(declared: ${fontFamilies.join(', ')})',
      );
    }
    final size = _number(_field(style, 'size', path), '$path.size');
    // A null (or absent) line height is the font's natural one.
    final rawLineHeight = style['lineHeight'];
    final lineHeight = rawLineHeight == null
        ? null
        : _number(rawLineHeight, '$path.lineHeight');
    final rawUse = style['use'];
    final use = rawUse == null ? null : _string(rawUse, '$path.use');
    final weight = _number(_field(style, 'weight', path), '$path.weight');
    if (size <= 0 || (lineHeight != null && lineHeight <= 0)) {
      throw TokenError('$path: size and lineHeight must be positive');
    }
    if (weight != weight.roundToDouble() ||
        weight < 100 ||
        weight > 900 ||
        weight % 100 != 0) {
      throw TokenError(
        '$path.weight: expected 100, 200, … 900, got ${_num(weight)}',
      );
    }
    final colorTokens = [
      for (final (i, c) in _list(
        _field(style, 'colors', path),
        '$path.colors',
      ).indexed)
        _string(c, '$path.colors[$i]'),
    ];
    for (final c in colorTokens) {
      colors.member(c, '$path.colors');
    }
    final id = _camel(name, path);
    _unique(seen, id, name, path);
    _unique(seen, '${id}Token', name, path);
    styles.add((name, id));
    o.writeln();
    _doc(
      o,
      '`$name`: $family ${_num(size)}/${lineHeight == null ? 'natural' : _num(lineHeight)}, '
      'weight ${_num(weight)}.${use == null ? '' : ' Use: $use.'}',
    );
    o.writeln('  static const AmalfiTextToken ${id}Token = AmalfiTextToken(');
    o.writeln('    name: ${_dartString(name)},');
    o.writeln('    family: ${_dartString(family)},');
    o.writeln('    size: ${_num(size)},');
    o.writeln(
      '    lineHeight: ${lineHeight == null ? 'null' : _num(lineHeight)},',
    );
    o.writeln('    weight: FontWeight.w${_num(weight)},');
    o.writeln('    colorTokens: [');
    for (final c in colorTokens) {
      o.writeln('      ${_dartString(c)},');
    }
    o.writeln('    ],');
    o.writeln('  );');
    o.writeln();
    _doc(o, '`$name` in [color] (none: inherited).');
    o.writeln(
      '  static TextStyle $id({Color? color}) => ${id}Token.style(color: color);',
    );
  }
  o.writeln();
  _doc(o, 'Every text style token, in the order of `tokens.json`.');
  o.writeln('  static const List<AmalfiTextToken> tokens = [');
  for (final (_, id) in styles) {
    o.writeln('    ${id}Token,');
  }
  o.writeln('  ];');
  o.writeln();
  _doc(
    o,
    'The token of the style named [name] (`Title 1`); null when there is none.',
  );
  o.writeln(
    '  static AmalfiTextToken? tokenNamed(String name) => switch (name) {',
  );
  for (final (name, id) in styles) {
    o.writeln('    ${_dartString(name)} => ${id}Token,');
  }
  o.writeln('    _ => null,');
  o.writeln('  };');
  o.writeln();
  _doc(o, 'The style named [name] in [color]; null when there is none.');
  o.writeln('  static TextStyle? byName(String name, {Color? color}) =>');
  o.writeln('      tokenNamed(name)?.style(color: color);');
  o.writeln('}');
  o.writeln();
}

// Grid, spacing, controls, radii -------------------------------------------------------------

void _writeGrid(StringBuffer o, Map<String, Object?> grid) {
  _onlyKeys(grid, {'base', 'rule'}, 'grid');
  final base = _number(_field(grid, 'base', 'grid'), 'grid.base');
  if (base <= 0) throw TokenError('grid.base: must be positive');
  final rule = _string(_field(grid, 'rule', 'grid'), 'grid.rule');
  o.writeln('/// The layout grid.');
  o.writeln('abstract final class AmalfiGrid {');
  _doc(o, 'The grid step in points: $rule.');
  o.writeln('  static const double base = ${_num(base)};');
  o.writeln();
  _doc(o, '[value] rounded to the nearest multiple of [base].');
  o.writeln(
    '  static double snap(double value) => (value / base).roundToDouble() * base;',
  );
  o.writeln('}');
  o.writeln();
}

void _writeSpacing(StringBuffer o, Map<String, Object?> spacing) {
  o.writeln(
    '/// Spacing steps and the padding of windows and panels, in points.',
  );
  o.writeln('abstract final class AmalfiSpacing {');
  final seen = <String, String>{};
  var first = true;
  void constant(String token, String id, Object? raw, String path) {
    _unique(seen, id, token, path);
    if (!first) o.writeln();
    first = false;
    _doc(o, '`spacing.$token`.');
    o.writeln('  static const double $id = ${_num(_number(raw, path))};');
  }

  for (final MapEntry(:key, :value) in spacing.entries) {
    final path = 'spacing.$key';
    if (value is Map<String, Object?>) {
      for (final MapEntry(key: sub, value: v) in value.entries) {
        constant(
          '$key.$sub',
          _camel('$key ${_splitCamel(sub)}', '$path.$sub'),
          v,
          '$path.$sub',
        );
      }
    } else {
      constant(key, _camel(key, path), value, path);
    }
  }
  o.writeln('}');
  o.writeln();
}

/// `regularWindow` → `regular Window`, so that [_camel] keeps the word boundary.
String _splitCamel(String s) =>
    s.replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (m) => '${m[1]} ${m[2]}');

void _writeControls(
  StringBuffer o,
  Map<String, Object?> heights,
  Map<String, Object?> icons,
) {
  String? note;
  final sizes = <String, double>{};
  final extraHeights = <String, double>{};
  for (final MapEntry(:key, :value) in heights.entries) {
    if (key == 'note') {
      note = _string(value, 'controlHeights.note');
    } else if (key == 'toolbar') {
      // Not one of the four control sizes: toolbar items are 36 in a 52 bar.
      extraHeights[key] = _number(value, 'controlHeights.$key');
    } else {
      sizes[key] = _number(value, 'controlHeights.$key');
    }
  }
  if (sizes.isEmpty) throw TokenError('controlHeights: no sizes');
  String? iconNote;
  final iconSizes = <String, double>{};
  for (final MapEntry(:key, :value) in icons.entries) {
    if (key == 'note') {
      iconNote = _string(value, 'controlIcons.note');
    } else {
      iconSizes[key] = _number(value, 'controlIcons.$key');
    }
  }
  for (final size in sizes.keys) {
    if (!iconSizes.containsKey(size)) {
      throw TokenError(
        'controlIcons: missing "$size" (every control height has an icon size)',
      );
    }
  }
  o.writeln(
    '/// The one control scale of Amalfi: height and icon size of every control.',
  );
  if (note != null) {
    o.writeln('///');
    _doc(o, '${note[0].toUpperCase()}${note.substring(1)}.', indent: '');
  }
  if (iconNote != null) {
    o.writeln('///');
    _doc(
      o,
      'Icon sizes: ${iconNote[0].toLowerCase()}${iconNote.substring(1)}.',
      indent: '',
    );
  }
  o.writeln('enum AmalfiControlSize {');
  for (final MapEntry(key: name, value: height) in sizes.entries) {
    final id = _camel(name, 'controlHeights.$name');
    _doc(
      o,
      '`$name`: ${_num(height)} pt high, ${_num(iconSizes[name]!)} pt icons.',
    );
    o.writeln(
      '  $id(height: ${_num(height)}, iconSize: ${_num(iconSizes[name]!)}),',
    );
  }
  o.writeln('  ;');
  o.writeln();
  o.writeln(
    '  const AmalfiControlSize({required this.height, required this.iconSize});',
  );
  o.writeln();
  o.writeln('  /// The control height in points.');
  o.writeln('  final double height;');
  o.writeln();
  o.writeln('  /// The size of an icon inside the control, in points.');
  o.writeln('  final double iconSize;');
  o.writeln('}');
  o.writeln();
  if (extraHeights.isNotEmpty) {
    o.writeln(
      '/// Control heights that are not a control size (`controlHeights`).',
    );
    o.writeln('abstract final class AmalfiControlHeights {');
    for (final (i, MapEntry(:key, :value)) in extraHeights.entries.indexed) {
      if (i > 0) o.writeln();
      _doc(o, '`controlHeights.$key`, in points.');
      o.writeln(
        '  static const double ${_camel(key, 'controlHeights.$key')} = '
        '${_num(value)};',
      );
    }
    o.writeln('}');
    o.writeln();
  }
  final extra = iconSizes.keys.where((k) => !sizes.containsKey(k)).toList();
  if (extra.isNotEmpty) {
    o.writeln(
      '/// Control icon sizes that are not a control size (`controlIcons`).',
    );
    o.writeln('abstract final class AmalfiControlIcons {');
    for (final (i, name) in extra.indexed) {
      if (i > 0) o.writeln();
      _doc(o, '`controlIcons.$name`, in points.');
      o.writeln(
        '  static const double ${_camel(name, 'controlIcons.$name')} = '
        '${_num(iconSizes[name]!)};',
      );
    }
    o.writeln('}');
    o.writeln();
  }
}

void _writeRadii(StringBuffer o, Map<String, Object?> radii) {
  final style = _string(
    _field(radii, 'cornerStyle', 'radii'),
    'radii.cornerStyle',
  );
  final smoothing = RegExp(r'smoothing ([0-9.]+)').firstMatch(style);
  final smoothingValue = smoothing == null
      ? null
      : double.tryParse(smoothing.group(1)!);
  if (smoothingValue == null || smoothingValue < 0 || smoothingValue > 1) {
    throw TokenError(
      'radii.cornerStyle: expected "… smoothing <0–1> …", got "$style"',
    );
  }
  _doc(
    o,
    'Corner radii, in points. Corners are $style: draw them with '
    '`AmalfiSmoothBorder` (smoothing [smoothing]).',
    indent: '',
  );
  o.writeln('abstract final class AmalfiRadii {');
  _doc(o, 'The smoothing of every rounded corner (0: circular arcs).');
  o.writeln('  static const double smoothing = ${_num(smoothingValue)};');
  for (final MapEntry(:key, :value) in radii.entries) {
    if (key == 'cornerStyle') continue;
    final path = 'radii.$key';
    final id = _camel(key, path);
    if (id == 'smoothing')
      throw TokenError('$path: clashes with radii.cornerStyle');
    o.writeln();
    if (value is String) {
      if (value.replaceAll(' ', '') != 'height/2') {
        throw TokenError(
          '$path: the only formula understood is "height/2", got "$value"',
        );
      }
      _doc(o, '`$key`: half the [height] of the shape.');
      o.writeln('  static double $id(double height) => height / 2;');
    } else {
      _doc(o, '`$key`.');
      o.writeln('  static const double $id = ${_num(_number(value, path))};');
    }
  }
  o.writeln('}');
  o.writeln();
}

// Shadows, focus, states ---------------------------------------------------------------------

/// Writes the shadows; returns the levels.
Set<int> _writeShadows(
  StringBuffer o,
  Map<String, Object?> shadows,
  _Colors colors,
) {
  _onlyKeys(shadows, {'light', 'dark', 'use'}, 'shadows');
  final use = _object(_field(shadows, 'use', 'shadows'), 'shadows.use');
  final levels = <String, Map<int, String>>{};
  Set<int>? keys;
  for (final scheme in const ['light', 'dark']) {
    final map = _object(_field(shadows, scheme, 'shadows'), 'shadows.$scheme');
    final out = <int, String>{};
    for (final MapEntry(:key, :value) in map.entries) {
      final path = 'shadows.$scheme.$key';
      final level = int.tryParse(key);
      if (level == null || level < 1)
        throw TokenError('$path: levels are 1, 2, 3, …');
      final s = _object(value, path);
      _onlyKeys(s, {'color', 'x', 'y', 'blur', 'spread'}, path);
      final color = _color(_field(s, 'color', path), '$path.color');
      final token = 'Shadow/$level';
      if (colors.systemValues[scheme]!.containsKey(token) &&
          colors.value(scheme, token, path) != color) {
        throw TokenError(
          '$path.color ${_hexDoc(color)} differs from colors.$scheme["$token"] '
          '${_hexDoc(colors.value(scheme, token, path))}',
        );
      }
      final x = s.containsKey('x') ? _number(s['x'], '$path.x') : 0.0;
      final y = s.containsKey('y') ? _number(s['y'], '$path.y') : 0.0;
      final blur = _number(_field(s, 'blur', path), '$path.blur');
      final spread = s.containsKey('spread')
          ? _number(s['spread'], '$path.spread')
          : 0.0;
      out[level] =
          'BoxShadow(color: ${_colorLiteral(color)}, '
          'offset: Offset(${_num(x)}, ${_num(y)}), blurRadius: ${_num(blur)}'
          '${spread == 0 ? '' : ', spreadRadius: ${_num(spread)}'})';
    }
    final k = out.keys.toSet();
    if (keys != null && (k.length != keys.length || !k.containsAll(keys))) {
      throw TokenError('shadows: light and dark have different levels');
    }
    keys = k;
    levels[scheme] = out;
  }
  final sorted = (keys ?? <int>{}).toList()..sort();
  if (sorted.isEmpty) throw TokenError('shadows: no levels');
  for (final key in use.keys) {
    if (!sorted.contains(int.tryParse(key))) {
      throw TokenError('shadows.use.$key: no such level');
    }
  }
  o.writeln('/// The drop shadows of one appearance, by elevation level.');
  o.writeln('final class AmalfiShadows {');
  o.writeln('  const AmalfiShadows._({');
  o.writeln('    required this.brightness,');
  for (final l in sorted) {
    o.writeln('    required this.level$l,');
  }
  o.writeln('  });');
  o.writeln();
  o.writeln('  /// The appearance of these shadows.');
  o.writeln('  final Brightness brightness;');
  for (final l in sorted) {
    o.writeln();
    final u = use['$l'];
    _doc(o, 'Level $l${u == null ? '' : ': ${_string(u, 'shadows.use.$l')}'}.');
    o.writeln('  final List<BoxShadow> level$l;');
  }
  for (final scheme in const ['light', 'dark']) {
    o.writeln();
    _doc(o, 'The $scheme appearance.');
    o.writeln('  static const AmalfiShadows $scheme = AmalfiShadows._(');
    o.writeln('    brightness: Brightness.$scheme,');
    for (final l in sorted) {
      o.writeln('    level$l: [${levels[scheme]![l]}],');
    }
    o.writeln('  );');
  }
  o.writeln();
  _doc(o, 'The shadows of [brightness].');
  o.writeln(
    '  static AmalfiShadows of(Brightness brightness) => switch (brightness) {',
  );
  o.writeln('    Brightness.light => light,');
  o.writeln('    Brightness.dark => dark,');
  o.writeln('  };');
  o.writeln();
  _doc(o, 'The shadow of [level]; null when there is no such level.');
  o.writeln('  List<BoxShadow>? level(int level) => switch (level) {');
  for (final l in sorted) {
    o.writeln('    $l => level$l,');
  }
  o.writeln('    _ => null,');
  o.writeln('  };');
  o.writeln('}');
  o.writeln();
  return sorted.toSet();
}

void _writeSwitch(StringBuffer o, Map<String, Object?> sw) {
  _onlyKeys(sw, {'thumbInset', 'pressedStretch', 'note', 'lens'}, 'switch');
  final inset = _number(
    _field(sw, 'thumbInset', 'switch'),
    'switch.thumbInset',
  );
  final stretch = _number(
    _field(sw, 'pressedStretch', 'switch'),
    'switch.pressedStretch',
  );
  final note = sw['note'];
  // `lens`: how far the lens reaches beyond the thumb, per control size ("thumb + 8").
  final lens = <String, double>{};
  final lensRaw = sw['lens'];
  if (lensRaw != null) {
    if (lensRaw is! Map<String, Object?>) {
      throw TokenError('switch.lens: expected an object');
    }
    for (final MapEntry(:key, :value) in lensRaw.entries) {
      final text = _string(value, 'switch.lens.$key');
      final m = RegExp(r'^thumb \+ (\d+(?:\.\d+)?)$').firstMatch(text);
      if (m == null) {
        throw TokenError(
          'switch.lens.$key: expected "thumb + <points>", got "$text"',
        );
      }
      lens[key] = double.parse(m[1]!);
    }
  }
  o.writeln('/// The switch thumb (`switch`).');
  if (note != null) {
    final text = _string(note, 'switch.note');
    o.writeln('///');
    _doc(o, '${text[0].toUpperCase()}${text.substring(1)}.', indent: '');
  }
  o.writeln('abstract final class AmalfiSwitchTokens {');
  _doc(o, 'The inset of the thumb from the track on every side, in points.');
  o.writeln('  static const double thumbInset = ${_num(inset)};');
  o.writeln();
  _doc(o, 'How far a pressed thumb stretches toward the middle, in points.');
  o.writeln('  static const double pressedStretch = ${_num(stretch)};');
  for (final MapEntry(:key, :value) in lens.entries) {
    o.writeln();
    _doc(
      o,
      'How far the lens reaches beyond the thumb at the `$key` size, in points '
      '(`switch.lens.$key`).',
    );
    o.writeln(
      '  static const double lens${key[0].toUpperCase()}${key.substring(1)} = ${_num(value)};',
    );
  }
  o.writeln('}');
  o.writeln();
}

void _writeFocus(StringBuffer o, Map<String, Object?> focus, _Colors colors) {
  _onlyKeys(focus, {'halo', 'color', 'follows'}, 'focus');
  final halo = _number(_field(focus, 'halo', 'focus'), 'focus.halo');
  final token = _string(_field(focus, 'color', 'focus'), 'focus.color');
  final member = colors.member(token, 'focus.color');
  final follows = _string(_field(focus, 'follows', 'focus'), 'focus.follows');
  _doc(
    o,
    'The keyboard focus halo, drawn as wide as [halo]; it follows the $follows.',
    indent: '',
  );
  o.writeln('abstract final class AmalfiFocus {');
  _doc(o, 'The halo width in points.');
  o.writeln('  static const double halo = ${_num(halo)};');
  o.writeln();
  _doc(o, 'The colour token of the halo.');
  o.writeln('  static const String colorToken = ${_dartString(token)};');
  o.writeln();
  _doc(o, 'The halo colour in [colors] (`$token`).');
  o.writeln('  static Color color(AmalfiColors colors) => colors.$member;');
  o.writeln('}');
  o.writeln();
}

void _writeStates(StringBuffer o, Map<String, Object?> states, _Colors colors) {
  o.writeln(
    '/// Interaction states: overlays drawn over a control, and the disabled look.',
  );
  o.writeln('abstract final class AmalfiStates {');
  var first = true;
  for (final MapEntry(:key, :value) in states.entries) {
    final path = 'states.$key';
    if (!first) o.writeln();
    first = false;
    if (value is String) {
      final m = RegExp(
        r'^(?:content|whole control) at ([0-9.]+) ?% opacity',
      ).firstMatch(value);
      final pct = m == null ? null : double.tryParse(m.group(1)!);
      if (key != 'disabled' || pct == null) {
        throw TokenError('$path: cannot read "$value"');
      }
      _doc(o, 'The opacity of a disabled control: $value.');
      o.writeln('  static const double disabledOpacity = ${_num(pct / 100)};');
      continue;
    }
    final map = _object(value, path);
    _onlyKeys(map, {'light', 'dark'}, path);
    final id = _camel(key, path);
    final light = _color(_field(map, 'light', path), '$path.light');
    final dark = _color(_field(map, 'dark', path), '$path.dark');
    // The same overlay is also a colour token (`State/Hover Overlay`): they must agree.
    final token =
        'State/${_splitCamel(key).split(' ').map((w) => w[0].toUpperCase() + w.substring(1)).join(' ')}';
    if (colors.system.containsKey(token) &&
        (colors.value('light', token, path) != light ||
            colors.value('dark', token, path) != dark)) {
      throw TokenError('$path differs from the colour token "$token"');
    }
    _doc(o, '`$key`: light `${_hexDoc(light)}`, dark `${_hexDoc(dark)}`.');
    o.writeln(
      '  static Color $id(Brightness brightness) => switch (brightness) {',
    );
    o.writeln('    Brightness.light => ${_colorLiteral(light)},');
    o.writeln('    Brightness.dark => ${_colorLiteral(dark)},');
    o.writeln('  };');
  }
  o.writeln('}');
  o.writeln();
}

// Materials ----------------------------------------------------------------------------------

void _writeMaterials(
  StringBuffer o,
  Map<String, Object?> materials,
  _Colors colors,
  Set<int> shadowLevels,
) {
  final ids = <(String, String)>[];
  final seen = <String, String>{'all': '(member)', 'byName': '(member)'};
  o.writeln(
    '/// The glass materials as plain data (`docs/design/amalfi/materials.md`).',
  );
  o.writeln('abstract final class AmalfiMaterials {');
  final strips = <(String, String, double, double, String, String)>[];
  for (final MapEntry(key: name, value: raw) in materials.entries) {
    final path = 'materials["$name"]';
    final m = _object(raw, path);
    if (name.startsWith('Blur/')) {
      // A blur strip: background blur and a tint, no glass (refraction, rim, shadow).
      _onlyKeys(m, {
        'backgroundBlur',
        'saturation',
        'tint',
        'refraction',
        'specularHighlights',
        'rimInside',
        'rimLight',
        'shadow',
        'use',
      }, path);
      for (final none in const [
        'refraction',
        'rimInside',
        'rimLight',
        'shadow',
      ]) {
        if (m[none] != null) {
          throw TokenError('$path.$none: a blur strip has none');
        }
      }
      if (m['specularHighlights'] != false &&
          m.containsKey('specularHighlights')) {
        throw TokenError('$path.specularHighlights: a blur strip has none');
      }
      final tint = _object(_field(m, 'tint', path), '$path.tint');
      _onlyKeys(tint, {'light', 'dark'}, '$path.tint');
      strips.add((
        name,
        _camel(name.substring(5), path),
        _number(_field(m, 'backgroundBlur', path), '$path.backgroundBlur'),
        m.containsKey('saturation')
            ? _number(m['saturation'], '$path.saturation')
            : 1.0,
        _colorLiteral(_color(_field(tint, 'light', path), '$path.tint.light')),
        _colorLiteral(_color(_field(tint, 'dark', path), '$path.tint.dark')),
      ));
      continue;
    }
    _onlyKeys(m, {
      'use',
      'backgroundBlur',
      'blur',
      'saturation',
      'tint',
      'rimInside',
      'rimLight',
      'shadow',
      'lens',
      'refraction',
      'specularHighlights',
      'brightness',
    }, path);
    if (m.containsKey('backgroundBlur') == m.containsKey('blur')) {
      throw TokenError(
        '$path: give exactly one of "backgroundBlur" and "blur"',
      );
    }
    final blur = _number(
      m['backgroundBlur'] ?? m['blur'],
      '$path.backgroundBlur',
    );
    final saturation = m.containsKey('saturation')
        ? _number(m['saturation'], '$path.saturation')
        : 1.0;
    String? tintLight;
    String? tintDark;
    final tint = m['tint'];
    if (tint != null) {
      final t = _object(tint, '$path.tint');
      _onlyKeys(t, {'light', 'dark'}, '$path.tint');
      tintLight = _colorLiteral(
        _color(_field(t, 'light', '$path.tint'), '$path.tint.light'),
      );
      tintDark = _colorLiteral(
        _color(_field(t, 'dark', '$path.tint'), '$path.tint.dark'),
      );
    }
    final rimInside = _object(_field(m, 'rimInside', path), '$path.rimInside');
    _onlyKeys(rimInside, {'width', 'light', 'dark'}, '$path.rimInside');
    final rimLight = _object(_field(m, 'rimLight', path), '$path.rimLight');
    _onlyKeys(rimLight, {'innerShadow', 'light', 'dark'}, '$path.rimLight');
    final inner = _object(
      _field(rimLight, 'innerShadow', '$path.rimLight'),
      '$path.rimLight.innerShadow',
    );
    _onlyKeys(inner, {'x', 'y', 'blur'}, '$path.rimLight.innerShadow');
    int? shadowLevel;
    final shadow = m['shadow'];
    if (shadow != null) {
      final s = _string(shadow, '$path.shadow');
      final level = RegExp(r'^shadows\.(\d+)$').firstMatch(s);
      shadowLevel = level == null ? null : int.tryParse(level.group(1)!);
      if (shadowLevel == null || !shadowLevels.contains(shadowLevel)) {
        throw TokenError(
          '$path.shadow: expected "shadows.<level>" of a level, got "$s"',
        );
      }
    }
    final lens = m.containsKey('lens')
        ? _boolean(m['lens'], '$path.lens')
        : false;
    String refraction = 'null';
    final r = m['refraction'];
    if (r != null) {
      final rr = _object(r, '$path.refraction');
      const keys = [
        'distortion',
        'depth',
        'chromaticAberration',
        'magnification',
      ];
      _onlyKeys(rr, keys.toSet(), '$path.refraction');
      // The magnification belongs to a lens; the edge refraction of Regular and Thick has none.
      if (!lens && rr.containsKey('magnification')) {
        throw TokenError('$path.refraction: only a lens magnifies');
      }
      refraction =
          'AmalfiRefraction(${keys.map((k) => '$k: ${_num(k == 'magnification' && !rr.containsKey(k) ? 1 : _number(_field(rr, k, '$path.refraction'), '$path.refraction.$k'))}').join(', ')})';
    }
    if (lens && r == null) {
      throw TokenError('$path: a lens has a refraction');
    }
    var brightnessLight = 1.0;
    var brightnessDark = 1.0;
    final b = m['brightness'];
    if (b != null) {
      final bb = _object(b, '$path.brightness');
      _onlyKeys(bb, {'light', 'dark'}, '$path.brightness');
      brightnessLight = _number(
        _field(bb, 'light', '$path.brightness'),
        '$path.brightness.light',
      );
      brightnessDark = _number(
        _field(bb, 'dark', '$path.brightness'),
        '$path.brightness.dark',
      );
    }
    // The glass colours are also colour tokens: they must agree.
    void agree(String? literal, String token, String scheme) {
      final want = _colorLiteral(colors.value(scheme, token, path));
      if (literal != null && literal != want) {
        throw TokenError(
          '$path: $scheme value $literal differs from colors.$scheme["$token"]',
        );
      }
    }

    final insideLight = _colorLiteral(
      _color(
        _field(rimInside, 'light', '$path.rimInside'),
        '$path.rimInside.light',
      ),
    );
    final insideDark = _colorLiteral(
      _color(
        _field(rimInside, 'dark', '$path.rimInside'),
        '$path.rimInside.dark',
      ),
    );
    final lightLight = _colorLiteral(
      _color(
        _field(rimLight, 'light', '$path.rimLight'),
        '$path.rimLight.light',
      ),
    );
    final lightDark = _colorLiteral(
      _color(_field(rimLight, 'dark', '$path.rimLight'), '$path.rimLight.dark'),
    );
    agree(insideLight, 'Glass/Rim Dark', 'light');
    agree(insideDark, 'Glass/Rim Dark', 'dark');
    agree(lightLight, 'Glass/Rim Light', 'light');
    agree(lightDark, 'Glass/Rim Light', 'dark');

    final id = _camel(
      name.startsWith('Glass/') ? name.substring(6) : name,
      path,
    );
    _unique(seen, id, name, path);
    ids.add((name, id));
    o.writeln();
    _doc(o, '`$name`.');
    o.writeln('  static const AmalfiGlassMaterial $id = AmalfiGlassMaterial(');
    o.writeln('    name: ${_dartString(name)},');
    o.writeln('    backgroundBlur: ${_num(blur)},');
    o.writeln('    saturation: ${_num(saturation)},');
    o.writeln('    tintLight: ${tintLight ?? 'null'},');
    o.writeln('    tintDark: ${tintDark ?? 'null'},');
    o.writeln(
      '    rimInsideWidth: ${_num(_number(_field(rimInside, 'width', '$path.rimInside'), '$path.rimInside.width'))},',
    );
    o.writeln('    rimInsideLight: $insideLight,');
    o.writeln('    rimInsideDark: $insideDark,');
    o.writeln(
      '    rimLightOffset: Offset('
      '${_num(inner.containsKey('x') ? _number(inner['x'], '$path.rimLight.innerShadow.x') : 0)}, '
      '${_num(inner.containsKey('y') ? _number(inner['y'], '$path.rimLight.innerShadow.y') : 0)}),',
    );
    o.writeln(
      '    rimLightBlur: ${_num(_number(_field(inner, 'blur', '$path.rimLight.innerShadow'), '$path.rimLight.innerShadow.blur'))},',
    );
    o.writeln('    rimLightLight: $lightLight,');
    o.writeln('    rimLightDark: $lightDark,');
    o.writeln('    shadowLevel: ${shadowLevel ?? 'null'},');
    o.writeln('    lens: $lens,');
    o.writeln('    refraction: $refraction,');
    o.writeln(
      '    specularHighlights: ${m.containsKey('specularHighlights') ? _boolean(m['specularHighlights'], '$path.specularHighlights') : false},',
    );
    o.writeln('    brightnessLight: ${_num(brightnessLight)},');
    o.writeln('    brightnessDark: ${_num(brightnessDark)},');
    o.writeln('  );');
  }
  o.writeln();
  _doc(o, 'Every material, in the order of `tokens.json`.');
  o.writeln('  static const List<AmalfiGlassMaterial> all = [');
  for (final (_, id) in ids) {
    o.writeln('    $id,');
  }
  o.writeln('  ];');
  o.writeln();
  _doc(
    o,
    'The material named [name] (`Glass/Thick`); null when there is none.',
  );
  o.writeln(
    '  static AmalfiGlassMaterial? byName(String name) => switch (name) {',
  );
  for (final (name, id) in ids) {
    o.writeln('    ${_dartString(name)} => $id,');
  }
  o.writeln('    _ => null,');
  o.writeln('  };');
  o.writeln('}');
  o.writeln();
  if (strips.isNotEmpty) {
    o.writeln('/// The blur strips: a background blur and a tint, no glass.');
    o.writeln('abstract final class AmalfiBlurs {');
    for (final (name, id, blur, saturation, light, dark) in strips) {
      o.writeln();
      _doc(o, '`$name`.');
      o.writeln('  static const AmalfiBlurStrip $id = AmalfiBlurStrip(');
      o.writeln('    name: ${_dartString(name)},');
      o.writeln('    backgroundBlur: ${_num(blur)},');
      o.writeln('    saturation: ${_num(saturation)},');
      o.writeln('    tintLight: $light,');
      o.writeln('    tintDark: $dark,');
      o.writeln('  );');
    }
    o.writeln('}');
    o.writeln();
  }
}

// Window controls ----------------------------------------------------------------------------

void _writeWindowControls(StringBuffer o, Map<String, Object?> wc) {
  const path = 'windowControls';
  _onlyKeys(wc, {
    'note',
    'dot',
    'firstCentreX',
    'pitch',
    'close',
    'minimise',
    'zoom',
  }, path);
  final note = wc.containsKey('note')
      ? _string(wc['note'], '$path.note')
      : null;
  _doc(
    o,
    'The window controls (close, minimise, zoom) at rest in an active light window.',
    indent: '',
  );
  if (note != null) {
    o.writeln('///');
    _doc(o, 'Values: $note.', indent: '');
  }
  o.writeln('abstract final class AmalfiWindowControls {');
  for (final (key, doc) in const [
    ('dot', 'The disc size in points.'),
    ('firstCentreX', 'The x of the first disc centre, in points.'),
    ('pitch', 'The distance between disc centres, in points.'),
  ]) {
    _doc(o, doc);
    o.writeln(
      '  static const double $key = ${_num(_number(_field(wc, key, path), '$path.$key'))};',
    );
    o.writeln();
  }
  for (final (i, key) in const ['close', 'minimise', 'zoom'].indexed) {
    final p = '$path.$key';
    final c = _object(_field(wc, key, path), p);
    _onlyKeys(c, {'fill', 'rim'}, p);
    final fill = _list(_field(c, 'fill', p), '$p.fill');
    if (fill.length != 2) throw TokenError('$p.fill: expected [top, bottom]');
    final rim = _string(_field(c, 'rim', p), '$p.rim');
    final rm = RegExp(
      r'^(#[0-9A-Fa-f]{6}(?:[0-9A-Fa-f]{2})?)\s+([0-9.]+)$',
    ).firstMatch(rim);
    final rimWidth = rm == null ? null : double.tryParse(rm.group(2)!);
    if (rm == null || rimWidth == null) {
      throw TokenError('$p.rim: expected "#RRGGBB <width>", got "$rim"');
    }
    if (i > 0) o.writeln();
    _doc(o, 'The $key button.');
    o.writeln('  static const AmalfiWindowControl $key = AmalfiWindowControl(');
    o.writeln('    top: ${_colorLiteral(_color(fill[0], '$p.fill[0]'))},');
    o.writeln('    bottom: ${_colorLiteral(_color(fill[1], '$p.fill[1]'))},');
    o.writeln('    rim: ${_colorLiteral(_color(rm.group(1), '$p.rim'))},');
    o.writeln('    rimWidth: ${_num(rimWidth)},');
    o.writeln('  );');
  }
  o.writeln('}');
  o.writeln();
}

// Motion -------------------------------------------------------------------------------------

final _row = RegExp(
  r'^\|\s*`(spring|fade|delay)\.([A-Za-z0-9]+)`\s*\|(.*)\|\s*$',
);

void _writeMotion(StringBuffer o, String markdown) {
  final springs = <String>[];
  final fades = <String>[];
  final delays = <String>[];
  final curves = <String, List<double>>{};
  final curveNames = <String, String>{};
  final ids = <String, String>{};

  for (final (n, line) in markdown.split('\n').indexed) {
    final trimmed = line.trim();
    final m = _row.firstMatch(trimmed);
    if (m == null) {
      if (RegExp(r'^\|\s*`(spring|fade|delay)\.').hasMatch(trimmed)) {
        throw TokenError(
          '$motionPath:${n + 1}: cannot read the token row "$trimmed"',
        );
      }
      continue;
    }
    final kind = m.group(1)!;
    final name = m.group(2)!;
    final token = '$kind.$name';
    final path = '$motionPath:${n + 1} `$token`';
    final cells = m.group(3)!.split('|').map((c) => c.trim()).toList();
    final id = _camel(name, path);
    _unique(ids, '$kind.$id', token, path);
    switch (kind) {
      case 'spring':
        if (cells.length != 6) {
          throw TokenError(
            '$path: expected | response | ζ | k | c | overshoot | use |',
          );
        }
        final values = [
          for (final (i, c) in cells.take(4).indexed)
            double.tryParse(c) ??
                (throw TokenError(
                  '$path: column ${['response', 'ζ', 'k', 'c'][i]} is not a number: "$c"',
                )),
        ];
        final [response, zeta, k, c] = values;
        if (response <= 0 || zeta <= 0)
          throw TokenError('$path: response and ζ must be positive');
        final kWant = math.pow(2 * math.pi / response, 2).toDouble();
        final cWant = 2 * zeta * math.sqrt(k);
        if ((k - kWant).abs() > 0.1 || (c - cWant).abs() > 0.1) {
          throw TokenError(
            '$path: k ${_num(k)} / c ${_num(c)} do not match response ${_num(response)} and '
            'ζ ${_num(zeta)} (k = (2π / response)² = ${kWant.toStringAsFixed(1)}, '
            'c = 2 ζ √k = ${cWant.toStringAsFixed(1)})',
          );
        }
        final b = StringBuffer();
        _doc(b, '`$token`: overshoot ${cells[4]}. Use: ${cells[5]}.');
        b.writeln('  static const AmalfiSpring $id = AmalfiSpring(');
        b.writeln('    name: ${_dartString(token)},');
        b.writeln('    response: ${_num(response)},');
        b.writeln('    dampingRatio: ${_num(zeta)},');
        b.writeln('    stiffness: ${_num(k)},');
        b.writeln('    damping: ${_num(c)},');
        b.writeln('  );');
        springs.add(b.toString());
      case 'fade':
        if (cells.length != 3)
          throw TokenError('$path: expected | duration | curve | use |');
        final ms = RegExp(r'^(\d+) ms$').firstMatch(cells[0]);
        if (ms == null)
          throw TokenError('$path: duration "${cells[0]}" is not "<n> ms"');
        final cm = RegExp(
          r'^([a-z-]+)(?:\s*\(\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)\s*,\s*([0-9.]+)\s*\))?$',
        ).firstMatch(cells[1]);
        if (cm == null)
          throw TokenError(
            '$path: curve "${cells[1]}" is not "<name> (x1, y1, x2, y2)"',
          );
        final curveId = _camel(cm.group(1)!, path);
        if (cm.group(2) != null) {
          final params = [
            for (var i = 2; i <= 5; i++) double.parse(cm.group(i)!),
          ];
          final known = curves[curveId];
          if (known != null && known.join(',') != params.join(',')) {
            throw TokenError(
              '$path: "${cm.group(1)}" was defined with other control points',
            );
          }
          curves[curveId] = params;
          curveNames[curveId] = cm.group(1)!;
        } else if (!curves.containsKey(curveId)) {
          throw TokenError(
            '$path: curve "${cm.group(1)}" has no control points here or in an earlier row',
          );
        }
        final b = StringBuffer();
        _doc(
          b,
          '`$token`: ${ms.group(1)} ms, ${cm.group(1)}. Use: ${cells[2]}.',
        );
        b.writeln('  static const AmalfiFade $id = AmalfiFade(');
        b.writeln('    name: ${_dartString(token)},');
        b.writeln('    duration: Duration(milliseconds: ${ms.group(1)}),');
        b.writeln('    curve: AmalfiCurves.$curveId,');
        b.writeln('  );');
        fades.add(b.toString());
      case 'delay':
        if (cells.length != 3)
          throw TokenError('$path: expected | duration | — | use |');
        final single = RegExp(r'^(\d+) ms$').firstMatch(cells[0]);
        final moving = RegExp(
          r'^(\d+) ms first, (\d+) ms while moving between items$',
        ).firstMatch(cells[0]);
        final b = StringBuffer();
        if (single != null) {
          _doc(b, '`$token`: ${single.group(1)} ms. Use: ${cells[2]}.');
          b.writeln(
            '  static const Duration $id = Duration(milliseconds: ${single.group(1)});',
          );
        } else if (moving != null) {
          _unique(ids, 'delay.${id}WhileMoving', token, path);
          _doc(b, '`$token`: the first one. Use: ${cells[2]}.');
          b.writeln(
            '  static const Duration $id = Duration(milliseconds: ${moving.group(1)});',
          );
          b.writeln();
          _doc(b, '`$token` while the pointer moves between items.');
          b.writeln(
            '  static const Duration ${id}WhileMoving = '
            'Duration(milliseconds: ${moving.group(2)});',
          );
        } else {
          throw TokenError('$path: cannot read the duration "${cells[0]}"');
        }
        delays.add(b.toString());
    }
  }
  if (springs.isEmpty || fades.isEmpty || delays.isEmpty) {
    throw TokenError(
      '$motionPath: expected spring.*, fade.* and delay.* token rows',
    );
  }

  o.writeln('/// The easing curves of the fade tokens (`motion.md`).');
  o.writeln('abstract final class AmalfiCurves {');
  for (final (i, MapEntry(key: id, value: p)) in curves.entries.indexed) {
    if (i > 0) o.writeln();
    _doc(o, '`${curveNames[id]}` (${p.map(_num).join(', ')}).');
    o.writeln('  static const Cubic $id = Cubic(${p.map(_num).join(', ')});');
  }
  o.writeln('}');
  o.writeln();
  o.writeln(
    '/// The spring tokens (`motion.md`), as [SpringDescription]s of mass 1.',
  );
  o.writeln('///');
  o.writeln(
    '/// Reduced motion: springs become `AmalfiFades.quick` cross-fades, with no',
  );
  o.writeln('/// overshoot and no scale; bounces are off.');
  o.writeln('abstract final class AmalfiSprings {');
  o.write(springs.join('\n'));
  o.writeln('}');
  o.writeln();
  o.writeln('/// The fade tokens (`motion.md`).');
  o.writeln('abstract final class AmalfiFades {');
  o.write(fades.join('\n'));
  o.writeln('}');
  o.writeln();
  o.writeln('/// The delay tokens (`motion.md`).');
  o.writeln('abstract final class AmalfiDelays {');
  o.write(delays.join('\n'));
  o.writeln('}');
}
