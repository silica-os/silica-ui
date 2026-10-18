// Generates the Amalfi component checklist `docs/amalfi-checklist/` from the kit index.
//
// Usage, from the package root:
//
//   dart run tool/gen_checklist.dart --design ~/silica/silica-design   regenerate the lists
//   dart run tool/gen_checklist.dart --summary                         only recount README.md
//
// One file per component family (`buttons.md`), one line per kit master
// (`- [ ] Buttons/Push/Primary/Regular/Rest/Light`), grouped by component. Ticked boxes are
// kept when the lists are regenerated. `README.md` gets a summary table (family, masters,
// done) recomputed from the ticks; run with `--summary` after ticking boxes (it needs no
// silica-design checkout), and after a merge conflict in `README.md`.
//
// Masters are assigned to families by the longest matching name prefix in [familySources];
// categories that are not components of this milestone are in [outOfScope]. A category the
// tool does not know stops it with a message, so that a new kit category is never dropped.

import 'dart:io';

import 'kit/kit_index.dart';

const String checklistPath = 'docs/amalfi-checklist';

/// The component families, in the order of the README, with the kit name prefixes that
/// belong to each.
const Map<String, List<String>> familySources = {
  'buttons': ['Buttons'],
  'segmented': ['Segments'],
  'toggles': ['Toggles'],
  'fields': ['Fields'],
  'menus': ['Menus'],
  'popovers': ['Popovers'],
  'tooltips': ['Tooltips'],
  'sliders': ['Sliders'],
  'steppers': ['Steppers'],
  'progress': ['Progress'],
  'scrollbars': ['Scrollbars'],
  'sidebars': ['Sidebars'],
  'lists': [],
  'disclosure': ['Disclosure'],
  'group_boxes': ['Group Boxes'],
  'forms': ['Forms'],
  'titlebars': ['Titlebars'],
  'windows': ['Windows'],
  'alerts': ['Alerts'],
  'dialogs': ['Dialogs'],
  'sheets': ['Windows/Window/Sheet Attached'],
  'wells': ['Wells'],
};

/// Kit categories outside the component milestone, and where they belong.
const Map<String, String> outOfScope = {
  'Apps': 'the app milestones (each `App · <name>` page)',
  'Dock': 'the shell (M4)',
  'Menu Bar': 'the shell (M4)',
  'Control Center': 'the shell (M4)',
  'Notifications': 'the shell (M4)',
  'Pointers': 'the shell (M4) (cursor theme)',
  'Foundations': 'none: a test backdrop for glass, not a component',
};

/// Notes on families with no or partial kit coverage.
const Map<String, String> familyNotes = {
  'lists':
      'no kit masters: lists and tables follow the layout metrics of '
      '`components.md` (rows 28 / 24 / 44, separators inset 16)',
  'sheets':
      'the attached sheet window of the kit (`Windows/Window/Sheet Attached`)',
  'windows': 'without `Windows/Window/Sheet Attached` (in sheets)',
};

final RegExp _line = RegExp(r'^- \[([ xX])\] (.+)$');

void main(List<String> arguments) {
  try {
    _run(arguments.toList());
  } on KitError catch (e) {
    stderr.writeln('gen_checklist: $e');
    exitCode = 65;
  }
}

void _run(List<String> args) {
  final summaryOnly = args.remove('--summary');
  final design = summaryOnly ? null : designDirFrom(args);
  if (args.isNotEmpty) {
    throw KitError(
      'unknown arguments: ${args.join(' ')}\n'
      'usage: dart run tool/gen_checklist.dart [--design <dir> | --summary]',
    );
  }
  if (!summaryOnly && design == null) {
    throw KitError(
      'no silica-design checkout: pass --design <dir>, set SILICA_DESIGN_DIR, '
      'or use --summary to recount the ticks only',
    );
  }
  Directory(checklistPath).createSync(recursive: true);

  final Map<String, int> outOfScopeCounts;
  if (design != null) {
    final index = KitIndex.read(design);
    final commit = commitOf(design);
    final byFamily = {for (final f in familySources.keys) f: <KitEntry>[]};
    final skipped = {for (final c in outOfScope.keys) c: 0};
    for (final e in index.entries) {
      final family = familyOf(e.name);
      if (family != null) {
        byFamily[family]!.add(e);
      } else if (skipped.containsKey(e.category)) {
        skipped[e.category] = skipped[e.category]! + 1;
      } else {
        throw KitError(
          'kit category "${e.category}" (${e.name}) is neither a family nor out '
          'of scope: add it to familySources or outOfScope in tool/gen_checklist.dart',
        );
      }
    }
    for (final MapEntry(key: family, value: entries) in byFamily.entries) {
      final file = File('$checklistPath/$family.md');
      final ticked = _ticked(file);
      file.writeAsStringSync(_familyMarkdown(family, entries, ticked, commit));
      final gone = ticked.difference(entries.map((e) => e.key).toSet());
      if (gone.isNotEmpty) {
        stderr.writeln(
          'gen_checklist: $family: ${gone.length} ticked masters are no longer in '
          'the kit: ${gone.join(', ')}',
        );
      }
    }
    outOfScopeCounts = skipped;
  } else {
    outOfScopeCounts = _outOfScopeCountsFromReadme();
  }

  final rows = <(String, int, int)>[];
  for (final family in familySources.keys) {
    final file = File('$checklistPath/$family.md');
    if (!file.existsSync()) {
      throw KitError('${file.path} is missing: run with --design first');
    }
    var total = 0, done = 0;
    for (final line in file.readAsLinesSync()) {
      final m = _line.firstMatch(line);
      if (m == null) continue;
      total++;
      if (m.group(1) != ' ') done++;
    }
    rows.add((family, total, done));
  }
  File('$checklistPath/README.md')
      .writeAsStringSync(_readme(rows, outOfScopeCounts));
  final total = rows.fold(0, (n, r) => n + r.$2);
  final done = rows.fold(0, (n, r) => n + r.$3);
  stdout.writeln('gen_checklist: $done of $total masters done');
}

/// The family of the master named [name]: the longest matching prefix; null when none.
String? familyOf(String name) {
  String? best;
  var bestLength = -1;
  for (final MapEntry(key: family, value: prefixes) in familySources.entries) {
    for (final p in prefixes) {
      if ((name == p || name.startsWith('$p/')) && p.length > bestLength) {
        best = family;
        bestLength = p.length;
      }
    }
  }
  return best;
}

Set<String> _ticked(File file) {
  if (!file.existsSync()) return {};
  return {
    for (final line in file.readAsLinesSync())
      if (_line.firstMatch(line) case final m? when m.group(1) != ' ')
        m.group(2)!,
  };
}

String _title(String family) => family
    .split('_')
    .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

String _familyMarkdown(
  String family,
  List<KitEntry> entries,
  Set<String> ticked,
  String commit,
) {
  final sources = familySources[family]!;
  final b = StringBuffer()
    ..writeln('# ${_title(family)}')
    ..writeln()
    ..writeln(
      'Kit: ${sources.isEmpty ? 'none' : sources.map((s) => '`$s`').join(', ')} '
      '(${entries.length} masters). Generated by `tool/gen_checklist.dart` from '
      'silica-design `${commit.substring(0, 7)}`.',
    );
  if (familyNotes[family] case final note?) {
    b
      ..writeln()
      ..writeln('Note: $note.');
  }
  b
    ..writeln()
    ..writeln(
      'Tick a master when the component reproduces it with a geometry test and a pixel '
      'test against the kit (`test/amalfi/README.md`) and it is on the gallery page.',
    );
  String? component;
  for (final e in entries) {
    final segments = e.name.split('/');
    final group = segments.take(segments.length > 2 ? 2 : 1).join('/');
    if (group != component) {
      component = group;
      b
        ..writeln()
        ..writeln('## $group')
        ..writeln();
    }
    b.writeln('- [${ticked.contains(e.key) ? 'x' : ' '}] ${e.key}');
  }
  return b.toString();
}

String _readme(List<(String, int, int)> rows, Map<String, int> counts) {
  final total = rows.fold(0, (n, r) => n + r.$2);
  final done = rows.fold(0, (n, r) => n + r.$3);
  final b = StringBuffer()
    ..writeln('# Amalfi component checklist')
    ..writeln()
    ..writeln(
      'One line per master of the Silica 1.0 "Amalfi" UI kit '
      '([silica-design](https://github.com/silica-os/silica-design)), per component '
      'family. Generated by `tool/gen_checklist.dart`: tick boxes in the family files, '
      'then run `dart run tool/gen_checklist.dart --summary` to recount this table (also '
      'the way to resolve a merge conflict here).',
    )
    ..writeln()
    ..writeln('| Family | Kit | Masters | Done |')
    ..writeln('| --- | --- | ---: | ---: |');
  for (final (family, masters, ticked) in rows) {
    final sources = familySources[family]!;
    b.writeln(
      '| [${_title(family)}]($family.md) | '
      '${sources.isEmpty ? '—' : sources.map((s) => '`$s`').join(', ')} | '
      '$masters | $ticked |',
    );
  }
  b
    ..writeln('| **Total** | | **$total** | **$done** |')
    ..writeln()
    ..writeln('## Out of scope of the component milestone (M3)')
    ..writeln()
    ..writeln('| Kit category | Masters | Belongs to |')
    ..writeln('| --- | ---: | --- |');
  for (final MapEntry(key: category, value: where) in outOfScope.entries) {
    b.writeln('| `$category` | ${counts[category] ?? 0} | $where |');
  }
  return b.toString();
}

// Out-of-scope counts as written in README.md, for --summary runs without the kit.
Map<String, int> _outOfScopeCountsFromReadme() {
  final file = File('$checklistPath/README.md');
  final counts = <String, int>{};
  if (file.existsSync()) {
    final row = RegExp(r'^\| `(.+)` \| (\d+) \|');
    for (final line in file.readAsLinesSync()) {
      if (row.firstMatch(line) case final m?) {
        counts[m.group(1)!] = int.parse(m.group(2)!);
      }
    }
  }
  return counts;
}
