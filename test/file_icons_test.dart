import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

const String svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">'
    '<rect x="100" y="100" width="824" height="824" fill="#ffffff"/></svg>';

String manifest(String id, {Object? dynamic}) => jsonEncode({
  'format': 1,
  'id': id,
  'name': id,
  'kind': 'file',
  'layers': [
    {'role': 'artwork', 'file': 'icon.svg'},
  ],
  'dynamic': dynamic,
});

const Map<String, Object> labelRules = {
  'type': 'file-label',
  'label': {
    'size': 160,
    'box': [245, 376, 534, 194],
    'max_chars': 4,
    'max_width': 534,
  },
  'colors': {
    'document': {'color': '#2f7cf6', 'dark_color': '#5aa0ff'},
    'data': {'color': '#1f9d55'},
    'code': {'color': '#ff6a00'},
    'other': {'color': '#636366'},
  },
  'overrides': {
    'json': 'data',
    'skt': {'color': '#f7b500'},
  },
  'icons': {
    'mime': {
      'application/pdf': 'file-pdf',
      'text/plain': 'file-text',
      'image/*': 'file-image',
      'application/x-shellscript': 'file-executable',
      'application/json': 'file-generic',
    },
    'extensions': {'pdf': 'file-pdf', 'xlsx': 'file-spreadsheet'},
  },
  'fallback': 'file-unknown',
};

/// A fake repo: the generic file with the rules, some type icons and the badges.
Directory iconTree() {
  final root = Directory.systemTemp.createTempSync('silica-file-icons-');
  for (final id in [
    'file-pdf',
    'file-text',
    'file-image',
    'file-executable',
    'file-spreadsheet',
    'file-unknown',
  ]) {
    Directory('${root.path}/files/$id').createSync(recursive: true);
    File('${root.path}/files/$id/icon.json').writeAsStringSync(manifest(id));
    File('${root.path}/files/$id/icon.svg').writeAsStringSync(svg);
  }
  Directory('${root.path}/files/file-generic').createSync(recursive: true);
  File('${root.path}/files/file-generic/icon.json')
      .writeAsStringSync(manifest('file-generic', dynamic: labelRules));
  File('${root.path}/files/file-generic/icon.svg').writeAsStringSync(svg);
  Directory('${root.path}/badges').createSync();
  for (final name in ['alias', 'unreadable', 'locked', 'cloud']) {
    File('${root.path}/badges/$name.svg').writeAsStringSync(svg);
  }
  File('${root.path}/badges/badges.json').writeAsStringSync(
    jsonEncode({
      'format': 1,
      'order': ['unreadable', 'alias', 'locked', 'cloud'],
      'badges': {
        for (final name in ['alias', 'unreadable', 'locked', 'cloud'])
          name: {'file': '$name.svg'},
      },
    }),
  );
  return root;
}

final MimeDatabase mime = MimeDatabase.fromText(
  globs2: '''
50:application/pdf:*.pdf
50:text/plain:*.txt
50:image/png:*.png
50:application/json:*.json
50:application/x-shellscript:*.sh
50:text/x-csrc:*.c
50:application/gzip:*.gz
50:application/x-compressed-tar:*.tar.gz
50:text/x-makefile:Makefile
10:text/x-readme:README*
50:application/vnd.ms-excel:*.xls
''',
  subclasses: '''
application/x-shellscript text/plain
text/x-csrc text/plain
application/json application/javascript
''',
  aliases: 'application/x-pdf application/pdf',
);

void main() {
  test('MIME: longest glob, case, literals, parents, aliases', () {
    expect(mime.typeForName('a.pdf'), 'application/pdf');
    expect(mime.typeForName('A.PDF'), 'application/pdf');
    expect(mime.typeForName('x.tar.gz'), 'application/x-compressed-tar');
    expect(mime.typeForName('Makefile'), 'text/x-makefile');
    expect(mime.typeForName('README.it'), 'text/x-readme');
    expect(mime.typeForName('senza'), isNull);
    expect(mime.parentsOf('text/x-csrc'), ['text/plain']);
    expect(mime.parentsOf('text/x-readme'), ['text/plain']);
    expect(mime.canonical('application/x-pdf'), 'application/pdf');
    final ambiguous = MimeDatabase.fromText(
      globs2:
          '50:text/vnd.trolltech.linguist:*.ts\n50:video/mp2t:*.ts\n'
          '50:application/pdf:*.pdf\n',
    );
    expect(ambiguous.isAmbiguousName('main.ts'), isTrue);
    expect(ambiguous.isAmbiguousName('a.pdf'), isFalse);
  });

  test('MIME from the content: ELF, script, text, binary, empty', () {
    final dir = Directory.systemTemp.createTempSync('mime-');
    addTearDown(() => dir.deleteSync(recursive: true));
    File(
      '${dir.path}/prog',
    ).writeAsBytesSync([0x7f, 0x45, 0x4c, 0x46, ...List.filled(12, 0), 2, 0]);
    File(
      '${dir.path}/lib',
    ).writeAsBytesSync([0x7f, 0x45, 0x4c, 0x46, ...List.filled(12, 0), 3, 0]);
    File('${dir.path}/avvia').writeAsStringSync('#!/bin/bash\necho ciao\n');
    File('${dir.path}/note').writeAsStringSync('solo testo\n');
    File('${dir.path}/dati').writeAsBytesSync([1, 2, 0, 3]);
    File('${dir.path}/vuoto').writeAsBytesSync([]);
    expect(mime.typeOf('${dir.path}/prog'), 'application/x-executable');
    expect(mime.typeOf('${dir.path}/lib'), 'application/x-sharedlib');
    expect(mime.typeOf('${dir.path}/avvia'), 'application/x-shellscript');
    expect(mime.typeOf('${dir.path}/note'), 'text/plain');
    expect(mime.typeOf('${dir.path}/dati'), octetStream);
    expect(mime.typeOf('${dir.path}/vuoto'), 'application/x-zerosize');
    expect(mime.typeOf('${dir.path}/sparito'), octetStream);
  });

  test('badges from disk: symlink, broken, unreadable', () {
    final dir = Directory.systemTemp.createTempSync('badge-');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/vero').writeAsStringSync('x');
    Link('${dir.path}/link').createSync('vero');
    Link('${dir.path}/broken').createSync('missing');
    expect(badgesOf('${dir.path}/vero'), isEmpty);
    expect(badgesOf('${dir.path}/link'), {IconBadge.alias});
    expect(badgesOf('${dir.path}/broken'), {
      IconBadge.alias,
      IconBadge.unreadable,
    });
    expect(badgesOf('${dir.path}/vero', cloud: true), {IconBadge.cloud});
  });

  test('volumes: network, image, optical, external, internal', () {
    expect(volumeIconId(const VolumeInfo(fsType: 'cifs')), 'volume-network');
    expect(volumeIconId(const VolumeInfo(scheme: 'sftp')), 'volume-network');
    expect(
      volumeIconId(
        const VolumeInfo(device: '/dev/loop3', backingFile: '/a.iso'),
      ),
      'volume-disk-image',
    );
    expect(
      volumeIconId(const VolumeInfo(device: '/dev/sr0')),
      'volume-optical',
    );
    expect(
      volumeIconId(const VolumeInfo(device: '/dev/sdb1', connectionBus: 'usb')),
      'volume-external',
    );
    expect(
      volumeIconId(const VolumeInfo(device: '/dev/nvme0n1p2')),
      'volume-internal',
    );
    final mounts = parseMountinfo(
      '29 1 259:2 / / rw,relatime shared:1 - ext4 /dev/nvme0n1p2 rw\n'
      '80 29 8:17 / /media/io/Chiave\\040USB rw - vfat /dev/sdb1 rw\n',
    );
    expect(mounts.map((m) => m.path), ['/', '/media/io/Chiave USB']);
    expect(mounts.last.fsType, 'vfat');
    expect(mounts.last.device, '/dev/sdb1');
  });

  test('ground shadow: the IC-01 measurements and in between', () {
    for (final (side, opacity, sigma, offset) in [
      (32.0, 0.35, 1.2, 0.55),
      (64.0, 0.20, 1.45, 0.8),
      (128.0, 0.28, 2.7, 1.2),
      (512.0, 0.25, 7.5, 3.1),
    ]) {
      final s = IconShadow.forSide(side);
      expect(s.opacity, closeTo(opacity, 1e-9));
      expect(s.sigma, closeTo(sigma, 1e-9));
      expect(s.offset, closeTo(offset, 1e-9));
    }
    final mid = IconShadow.forSide(90);
    expect(mid.sigma, inExclusiveRange(1.45, 2.7));
    expect(IconShadow.forSide(16).sigma, closeTo(0.6, 1e-9));
  });
}
