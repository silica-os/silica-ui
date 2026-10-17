// Volumes and badges, with the rules of silica-icons (docs/icon-format.md: "Volumes", "Badges").
// File and folder icons are composed by the daemon (`Thumbnails1.Icon`, see thumbnails.dart).

import 'dart:convert';
import 'dart:io';

import 'mime.dart';
import 'silica_icons.dart';

/// The extension for the label: the last one after the dot, lowercase; empty for names without
/// an extension and for hidden files without another dot.
String fileExtension(String name) {
  final dot = name.lastIndexOf('.');
  if (dot <= 0 || dot == name.length - 1) return '';
  return name.substring(dot + 1).toLowerCase();
}

MimeDatabase? _defaultMime;

/// The system MIME database, read once.
MimeDatabase get systemMime => _defaultMime ??= MimeDatabase.load();

/// The badges (icon-format.md, "Badges").
/// In the order in which one wins when only one remains (below 32 pt).
enum IconBadge { unreadable, alias, locked, cloud }

/// The badge rules of `badges/badges.json` and their files.
class BadgeRules {
  const BadgeRules({
    required this.root,
    required this.files,
    required this.order,
  });

  final String root;

  /// Badge → (light, dark).
  final Map<IconBadge, (String, String?)> files;

  /// The order when only one badge remains (below 32 pt).
  final List<IconBadge> order;

  String? pathFor(IconBadge badge, {required bool dark}) {
    final (light, darkPath) = files[badge] ?? (null, null);
    if (light == null) return null;
    return dark ? (darkPath ?? light) : light;
  }
}

final Map<String, BadgeRules?> _badgeCache = {};

/// The badge rules of the first silica-icons folder that has them.
BadgeRules? findBadgeRules({Map<String, String>? env}) {
  final key = env == null ? '' : jsonEncode(env);
  if (_badgeCache.containsKey(key)) return _badgeCache[key];
  BadgeRules? found;
  for (final dir in silicaIconDirs(env ?? Platform.environment)) {
    final root = '$dir/badges';
    try {
      final json = jsonDecode(File('$root/badges.json').readAsStringSync());
      if (json is! Map || json['format'] != 1) continue;
      final files = <IconBadge, (String, String?)>{};
      final badges = json['badges'];
      if (badges is Map) {
        for (final badge in IconBadge.values) {
          final raw = badges[badge.name];
          if (raw is! Map) continue;
          String? file(Object? name) =>
              name is String &&
                  RegExp(r'^[a-z0-9-]+\.svg$').hasMatch(name) &&
                  File('$root/$name').existsSync()
              ? '$root/$name'
              : null;
          final light = file(raw['file']);
          if (light != null) files[badge] = (light, file(raw['dark']));
        }
      }
      final order = [
        for (final name
            in (json['order'] is List ? json['order'] as List : const []))
          ?IconBadge.values.where((b) => b.name == name).firstOrNull,
      ];
      found = BadgeRules(
        root: root,
        files: files,
        order: order.isEmpty ? IconBadge.values : order,
      );
      break;
    } on Object {
      continue;
    }
  }
  if (env == null) _badgeCache[key] = found;
  return found;
}

/// The badges of a file on disk: alias (symlink), unreadable (also a broken symlink).
/// `locked` and `cloud` are told by whoever lists the files (`locked`: immutable or
/// append-only attribute; `cloud`: content not local).
Set<IconBadge> badgesOf(
  String path, {
  bool locked = false,
  bool cloud = false,
}) {
  final out = <IconBadge>{};
  final type = FileSystemEntity.typeSync(path, followLinks: false);
  if (type == FileSystemEntityType.link) {
    out.add(IconBadge.alias);
    if (FileSystemEntity.typeSync(path) == FileSystemEntityType.notFound) {
      out.add(IconBadge.unreadable);
    }
  }
  if (!out.contains(IconBadge.unreadable) && !_readable(path)) {
    out.add(IconBadge.unreadable);
  }
  if (locked) out.add(IconBadge.locked);
  if (cloud) out.add(IconBadge.cloud);
  return out;
}

/// Readable: a folder must be listable, a file openable.
bool _readable(String path) {
  try {
    switch (FileSystemEntity.typeSync(path)) {
      case FileSystemEntityType.directory:
        Directory(path).listSync().take(1);
      case FileSystemEntityType.notFound:
        return true;
      default:
        File(path).openSync().closeSync();
    }
    return true;
  } on FileSystemException {
    return false;
  }
}

/// The badges to draw for an icon side: from 32 pt one per corner (on the right the first of
/// unreadable, locked, cloud), between 16 and 31 just one (the first in the order), below none.
List<IconBadge> visibleBadges(
  Set<IconBadge> badges,
  double side, {
  List<IconBadge> order = IconBadge.values,
}) {
  if (side < 16 || badges.isEmpty) return const [];
  if (side < 32) {
    final first = order.where(badges.contains).firstOrNull;
    return first == null ? const [] : [first];
  }
  final right = const [
    IconBadge.unreadable,
    IconBadge.locked,
    IconBadge.cloud,
  ].where(badges.contains).firstOrNull;
  return [if (badges.contains(IconBadge.alias)) IconBadge.alias, ?right];
}

/// What is known about a mounted volume to choose its icon.
class VolumeInfo {
  const VolumeInfo({
    this.fsType = '',
    this.device = '',
    this.scheme,
    this.backingFile,
    this.optical = false,
    this.removable = false,
    this.connectionBus = '',
  });

  /// File system type (mountinfo) and device (`/dev/sda1`, `/dev/loop0`…).
  final String fsType;
  final String device;

  /// GVfs scheme (`smb`, `sftp`…) for GVfs mounts.
  final String? scheme;

  /// The file behind a loop device (UDisks2 `Loop.BackingFile`).
  final String? backingFile;
  final bool optical;
  final bool removable;

  /// UDisks2 `Drive.ConnectionBus` (`usb`, `sdio`, `ieee1394`, empty for internal disks).
  final String connectionBus;
}

const Set<String> _networkFs = {
  'nfs',
  'nfs4',
  'cifs',
  'smb3',
  '9p',
  'fuse.sshfs',
  'fuse.rclone',
  'davfs',
};
const Set<String> _networkSchemes = {
  'smb',
  'sftp',
  'ftp',
  'ftps',
  'dav',
  'davs',
  'nfs',
  'afp',
};

/// The icon of a volume: the first case that applies (icon-format.md, "Volumes").
String volumeIconId(VolumeInfo v) {
  if (_networkFs.contains(v.fsType) || _networkSchemes.contains(v.scheme)) {
    return 'volume-network';
  }
  if (v.device.startsWith('/dev/loop') && (v.backingFile?.isNotEmpty ?? true)) {
    return 'volume-disk-image';
  }
  if (v.optical || v.device.startsWith('/dev/sr')) return 'volume-optical';
  if (v.removable ||
      const {'usb', 'sdio', 'ieee1394'}.contains(v.connectionBus)) {
    return 'volume-external';
  }
  return 'volume-internal';
}

/// A mount point from `/proc/self/mountinfo`.
class MountPoint {
  const MountPoint(this.path, this.fsType, this.device);
  final String path;
  final String fsType;
  final String device;
}

/// The mounts of `/proc/self/mountinfo` (text, for tests): path, type, device.
List<MountPoint> parseMountinfo(String text) {
  final out = <MountPoint>[];
  for (final line in text.split('\n')) {
    final fields = line.split(' ');
    final dash = fields.indexOf('-');
    if (dash < 0 || fields.length < dash + 3 || fields.length < 5) continue;
    // Spaces in paths are written as \040.
    String unescape(String s) => s.replaceAllMapped(
      RegExp(r'\\([0-7]{3})'),
      (m) => String.fromCharCode(int.parse(m.group(1)!, radix: 8)),
    );
    out.add(
      MountPoint(unescape(fields[4]), fields[dash + 1], fields[dash + 2]),
    );
  }
  return out;
}

/// Is the disk removable (`/sys/block/<disk>/removable`)? For a partition the disk is checked.
bool blockRemovable(String device, {String sys = '/sys/block'}) {
  final name = device.split('/').last;
  if (name.isEmpty) return false;
  try {
    for (final entry in Directory(sys).listSync()) {
      final disk = entry.path.split('/').last;
      if (name == disk ||
          (name.startsWith(disk) && name.length > disk.length)) {
        return File('${entry.path}/removable').readAsStringSync().trim() == '1';
      }
    }
  } on FileSystemException {
    // Without /sys: not removable.
  }
  return false;
}
