import 'dart:io';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:silica_ui/silica_ui.dart';
import 'package:silica_ui/src/icons/silica_icon.dart'
    show monthName, withoutFilters;

const String svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">'
    '<rect x="100" y="100" width="824" height="824" fill="#2f8cff"/></svg>';

const String mailManifest = '''
{
  "format": 1, "id": "mail", "name": "Mail", "kind": "app", "keyline": "landscape",
  "layers": [
    { "role": "background", "file": "background.svg" },
    { "role": "foreground", "file": "foreground.svg", "shadow": "neutral" }
  ],
  "variants": { "dark": { "background": "background-dark.svg" } },
  "dynamic": null
}
''';

const String symbolSvg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24">'
    '<path d="M4 4 L20 20" stroke="currentColor" stroke-width="1.5"/></svg>';

const String folderManifest = '''
{
  "format": 1, "id": "folder-generic", "name": "Folder Generic", "kind": "file",
  "layers": [
    { "role": "back", "file": "back.svg" },
    { "role": "middle", "file": "middle.svg", "when": "not-empty" },
    { "role": "front", "file": "front.svg" } ],
  "variants": null
}
''';

/// The fake repo for the generic folder: back, middle and front.
Directory folderTree() => iconTree({
  'files/folder-generic': {
    'icon.json': folderManifest,
    'back.svg': svg,
    'middle.svg': svg,
    'front.svg': svg,
  },
});

/// A fake icons folder: `apps/<id>/` with the given files.
Directory iconTree(Map<String, Map<String, String>> icons) {
  final root = Directory.systemTemp.createTempSync('silica-icons-');
  for (final MapEntry(key: path, value: files) in icons.entries) {
    final dir = Directory('${root.path}/$path')..createSync(recursive: true);
    for (final MapEntry(key: name, value: text) in files.entries) {
      File('${dir.path}/$name').writeAsStringSync(text);
    }
  }
  return root;
}

void main() {
  test('valid manifest: layers in order, dark variant, foreground shadow', () {
    final root = iconTree({
      'apps/mail': {
        'icon.json': mailManifest,
        'background.svg': svg,
        'background-dark.svg': svg,
        'foreground.svg': svg,
      },
    });
    addTearDown(() => root.deleteSync(recursive: true));
    final icon = findSilicaIcon('mail', env: {'SILICA_ICONS_DIR': root.path})!;
    expect(icon.kind, IconKind.app);
    expect(icon.layers, hasLength(2));
    expect(icon.layers[0].pathFor(dark: true), endsWith('background-dark.svg'));
    expect(icon.layers[1].pathFor(dark: true), endsWith('foreground.svg'));
    expect(icon.layers[1].shadow, isTrue);
  });

  test('hostile manifest: broken JSON, missing files or files outside the folder are rejected', () {
    final dir = Directory.systemTemp.createTempSync('silica-icon-');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/background.svg').writeAsStringSync(svg);
    expect(parseManifest(dir.path, '{'), isNull);
    expect(parseManifest(dir.path, '[]'), isNull);
    expect(parseManifest(dir.path, mailManifest), isNull);
    expect(
      parseManifest(
        dir.path,
        mailManifest.replaceAll('foreground.svg', '../../etc/passwd.svg'),
      ),
      isNull,
    );
    expect(
      parseManifest(
        dir.path,
        mailManifest.replaceAll('"format": 1', '"format": 2'),
      ),
      isNull,
    );
    expect(
      findSilicaIcon('../mail', env: {'SILICA_ICONS_DIR': dir.path}),
      isNull,
    );
  });

  test('dynamic clock and calendar', () {
    final root = iconTree({
      'apps/clock': {
        'icon.json': '''
{ "format": 1, "id": "clock", "name": "Clock", "kind": "app",
  "layers": [ { "role": "background", "file": "background.svg" } ],
  "dynamic": { "type": "clock", "cap": "cap.svg", "hands": [
    { "unit": "hour", "file": "hand-hour.svg" },
    { "unit": "minute", "file": "hand-minute.svg" },
    { "unit": "second", "file": "hand-second.svg", "min_size": 64 } ] } }''',
        'background.svg': svg,
        'cap.svg': svg,
        'hand-hour.svg': svg,
        'hand-hour-dark.svg': svg,
        'hand-minute.svg': svg,
        'hand-second.svg': svg,
      },
      'apps/calendar': {
        'icon.json': '''
{ "format": 1, "id": "calendar", "name": "Calendar", "kind": "app",
  "layers": [ { "role": "background", "file": "background.svg" } ],
  "dynamic": { "type": "calendar",
    "month": { "size": 92, "weight": 900, "color": "#f2382e", "dark_color": "#ff5248",
               "box": [100, 206, 824, 120], "case": "upper", "max_width": 560 },
    "day": { "size": 280, "weight": 700, "color": "#ffffff", "box": [100, 410, 824, 460] } } }''',
        'background.svg': svg,
      },
    });
    addTearDown(() => root.deleteSync(recursive: true));
    final env = {'SILICA_ICONS_DIR': root.path};
    final clock = findSilicaIcon('clock', env: env)!.dynamic! as ClockHands;
    expect(clock.hour.pathFor(dark: true), endsWith('hand-hour-dark.svg'));
    expect(clock.second, isNotNull);
    final calendar =
        findSilicaIcon('calendar', env: env)!.dynamic! as CalendarText;
    expect(calendar.month.upper, isTrue);
    expect(calendar.month.darkColor, const Color(0xFFFF5248));
    expect(calendar.day.box, const Rect.fromLTWH(100, 410, 824, 460));
  });

  test('special folders: xdg-user-dirs, home, apps, library', () {
    final home = Directory.systemTemp.createTempSync('silica-home-');
    addTearDown(() => home.deleteSync(recursive: true));
    Directory('${home.path}/.config').createSync();
    File('${home.path}/.config/user-dirs.dirs').writeAsStringSync(
      '# commento\n'
      'XDG_DESKTOP_DIR="\$HOME/Scrivania"\n'
      'XDG_DOCUMENTS_DIR="\$HOME/Documenti/"\n'
      'XDG_DOWNLOAD_DIR="/srv/downloads"\n'
      'XDG_MUSIC_DIR="\$HOME/"\n'
      'XDG_PICTURES_DIR="relativo/Immagini"\n'
      'XDG_VIDEOS_DIR=senza-virgolette\n',
    );
    final env = {'HOME': home.path, 'XDG_DATA_DIRS': '/usr/share'};
    final dirs = xdgUserDirs(env);
    expect(dirs, {
      'DESKTOP': '${home.path}/Scrivania',
      'DOCUMENTS': '${home.path}/Documenti',
      'DOWNLOAD': '/srv/downloads',
    });
    expect(specialFolderKey('${home.path}/Documenti/', env: env), 'DOCUMENTS');
    expect(specialFolderKey('/srv/downloads', env: env), 'DOWNLOAD');
    expect(specialFolderKey(home.path, env: env), 'HOME');
    expect(
      specialFolderKey('/usr/share/applications', env: env),
      'APPLICATIONS',
    );
    expect(
      specialFolderKey('${home.path}/Applications', env: env),
      'APPLICATIONS',
    );
    expect(specialFolderKey('${home.path}/.local/share', env: env), 'LIBRARY');
    expect(specialFolderKey('${home.path}/Progetti', env: env), isNull);
    expect(specialFolderKey('', env: env), isNull);
    expect(xdgUserDirs(const {}), isEmpty);
  });

  testWidgets(
    'a plain folder draws back and front, not the sheet of the folder with items',
    (tester) async {
      final root = folderTree();
      addTearDown(() => root.deleteSync(recursive: true));
      final folder = findSilicaIcon(
        'folder-generic',
        env: {'SILICA_ICONS_DIR': root.path},
      )!;
      expect(folder.layers.length, 3);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(child: SilicaIcon(LayeredSource(folder), side: 64)),
        ),
      );
      expect(find.byType(SvgPicture), findsNWidgets(2));
    },
  );

  test('the body mask fits the rectangle and is not a rounded rectangle', () {
    const body = Rect.fromLTWH(0, 0, 100, 100);
    final path = iconBodyPath(body);
    expect(path.getBounds().left, closeTo(0, 0.01));
    expect(path.getBounds().right, closeTo(100, 0.01));
    expect(path.contains(const Offset(50, 0.5)), isTrue);
    expect(path.contains(const Offset(1, 1)), isFalse);
    // Radius 214 on 824 (26 %), smoothing 0.6: the diagonal point (10, 10) is inside.
    expect(path.contains(const Offset(10, 10)), isTrue);
    // The Sketch outline: the straight edge ends at 41.55 % of the side, the corner curve at 14.2 %.
    expect(path.contains(const Offset(41.6, 0.5)), isTrue);
    expect(path.contains(const Offset(3, 3)), isFalse);
  });

  testWidgets('a layered icon composes without errors, even with the clock', (
    tester,
  ) async {
    final root = iconTree({
      'apps/mail': {
        'icon.json': mailManifest,
        'background.svg': svg,
        'background-dark.svg': svg,
        'foreground.svg': svg,
      },
      'apps/clock': {
        'icon.json': '''
{ "format": 1, "id": "clock", "name": "Clock", "kind": "app",
  "layers": [ { "role": "background", "file": "background.svg" } ],
  "dynamic": { "type": "clock", "cap": "cap.svg", "hands": [
    { "unit": "hour", "file": "hand.svg" }, { "unit": "minute", "file": "hand.svg" } ] } }''',
        'background.svg': svg,
        'cap.svg': svg,
        'hand.svg': svg,
      },
    });
    addTearDown(() => root.deleteSync(recursive: true));
    final env = {'SILICA_ICONS_DIR': root.path};
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            SilicaIcon(
              LayeredSource(findSilicaIcon('mail', env: env)!),
              side: 48,
            ),
            SilicaIcon(
              LayeredSource(findSilicaIcon('clock', env: env)!),
              side: 96,
              dark: true,
            ),
          ],
        ),
      ),
    );
    await tester.pump(const Duration(seconds: 2));
    expect(tester.takeException(), isNull);
    expect(find.byType(SilicaIcon), findsNWidgets(2));
  });

  testWidgets('the system dark appearance does not change the icon', (
    tester,
  ) async {
    const red =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">'
        '<rect width="1024" height="1024" fill="#ff0000"/></svg>';
    const blue =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">'
        '<rect width="1024" height="1024" fill="#0000ff"/></svg>';
    final root = iconTree({
      'files/file-text': {
        'icon.json': '''
{ "format": 1, "id": "file-text", "name": "Text", "kind": "file",
  "layers": [ { "role": "artwork", "file": "icon.svg" } ],
  "variants": { "dark": { "artwork": "icon-dark.svg" } } }''',
        'icon.svg': red,
        'icon-dark.svg': blue,
      },
    });
    addTearDown(() => root.deleteSync(recursive: true));
    final icon = findSilicaIcon(
      'file-text',
      env: {'SILICA_ICONS_DIR': root.path},
    )!;
    Future<Color> center(bool? dark) async {
      final key = GlobalKey();
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(platformBrightness: Brightness.dark),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: RepaintBoundary(
                key: key,
                child: SilicaIcon(LayeredSource(icon), side: 64, dark: dark),
              ),
            ),
          ),
        ),
      );
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      await tester.pump();
      final boundary =
          key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
      final pixel = await tester.runAsync(() async {
        final image = await boundary.toImage();
        final data = await image.toByteData();
        final w = image.width, h = image.height;
        final i = ((h ~/ 2) * w + w ~/ 2) * 4;
        return Color.fromARGB(
          255,
          data!.getUint8(i),
          data.getUint8(i + 1),
          data.getUint8(i + 2),
        );
      });
      return pixel!;
    }

    expect(await center(null), const Color(0xFFFF0000));
    expect(await center(true), const Color(0xFF0000FF));
  });

  test(
    'the canvas: whole for files, with the app border for apps and in the Dock',
    () {
      final root = iconTree({
        'files/trash-empty': {
          'icon.json':
              '{ "format": 1, "id": "trash-empty", "name": "Trash", "kind": "file", '
              '"layers": [ { "role": "artwork", "file": "icon.svg" } ] }',
          'icon.svg': svg,
        },
        'apps/mail': {
          'icon.json': mailManifest,
          'background.svg': svg,
          'background-dark.svg': svg,
          'foreground.svg': svg,
        },
      });
      addTearDown(() => root.deleteSync(recursive: true));
      final env = {'SILICA_ICONS_DIR': root.path};
      final trash = LayeredSource(findSilicaIcon('trash-empty', env: env)!);
      final mail = LayeredSource(findSilicaIcon('mail', env: env)!);
      expect(SilicaIcon(trash, side: 64).canvasExtent, 64);
      expect(
        SilicaIcon(trash, side: 48, besideApps: true).canvasExtent,
        48 * 1024 / 824,
      );
      expect(SilicaIcon(mail, side: 48).canvasExtent, 48 * 1024 / 824);
    },
  );

  test('calendar month names follow the language, English by default', () {
    expect(monthName(10, 'it'), 'ottobre');
    expect(monthName(10, 'en'), 'October');
    expect(monthName(10, 'de'), 'October');
    expect(monthName(10, null), 'October');
  });

  group('withoutFilters', () {
    String blurred(String attr) =>
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><defs>'
        '<filter id="b"><feGaussianBlur stdDeviation="2"/></filter>'
        '<mask id="m"><rect width="5" height="5" fill="#fff"/></mask>'
        '<clipPath id="c"><rect width="5" height="5"/></clipPath></defs>'
        '<circle cx="5" cy="5" r="3" fill="#ff0000" filter="url(#b)" $attr/>'
        '</svg>';

    test('keeps mask and its definition', () {
      final out = withoutFilters(blurred('mask="url(#m)"'));
      expect(out, contains('<g mask="url(#m)">'));
      expect(out, contains('<mask id="m">'));
      expect(out, isNot(contains('filter=')));
      expect(out, contains('radialGradient'));
    });

    test('keeps clip-path and its definition', () {
      final out = withoutFilters(blurred('clip-path="url(#c)"'));
      expect(out, contains('<g clip-path="url(#c)">'));
      expect(out, contains('<clipPath id="c">'));
    });

    test('keeps transform, and adds no group without attributes', () {
      expect(
        withoutFilters(blurred('transform="translate(1 2)"')),
        contains('<g transform="translate(1 2)">'),
      );
      expect(withoutFilters(blurred('')), isNot(contains('<g')));
    });
  });

  group('real silica-icons checkout', () {
    final dirEnv = Platform.environment['SILICA_ICONS_DIR'];
    final dir = [
      if (dirEnv != null && dirEnv.isNotEmpty) dirEnv,
      '../silica-icons',
    ].where((d) => Directory('$d/files').existsSync()).firstOrNull;
    final skip = dir == null ? 'no silica-icons checkout' : null;
    final env = {'SILICA_ICONS_DIR': dir ?? '', 'HOME': '/nessuna'};

    List<String> ids(String kind) => [
      for (final e in Directory('$dir/$kind').listSync())
        if (File('${e.path}/icon.json').existsSync()) e.path.split('/').last,
    ];

    test('every file and app icon parses with its layers', () {
      for (final id in [...ids('files'), ...ids('apps')]) {
        final icon = findSilicaIcon(id, env: env);
        expect(icon, isNotNull, reason: id);
        expect(icon!.layers, isNotEmpty, reason: id);
        for (final layer in icon.layers) {
          expect(File(layer.path).existsSync(), isTrue, reason: id);
        }
      }
    }, skip: skip);

    test('the generic file and folder are layers only', () {
      final file = findSilicaIcon('file-generic', env: env)!;
      expect([for (final l in file.layers) l.role], ['back', 'front']);
      expect(file.dynamic, isNull);
      final folder = findSilicaIcon('folder-generic', env: env)!;
      expect(
        [for (final l in folder.layers) l.role],
        ['back', 'middle', 'front'],
      );
      expect(
        [for (final l in folder.layers) l.when],
        [null, 'not-empty', null],
      );
      expect(folder.dynamic, isNull);
      expect(silicaSymbolsDir(env: env), isNotNull);
    }, skip: skip);
  });
}
