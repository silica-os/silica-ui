// Gatekeeper and disk images: the clients of silica-daemon's `dev.frascella.Silica.Trust1`
// (silica-desktop docs/spec/trust.md) and `dev.frascella.Silica.Volumes1` (docs/spec/volumes.md).

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'dbus.dart';

const String _silica = 'dev.frascella.Silica';

Future<List<Object?>> _call(
  String path,
  String interface,
  String method,
  String signature,
  List<Object?> args,
) => SilicaDBus.instance.call(
  destination: _silica,
  path: path,
  interface: interface,
  method: method,
  signature: signature,
  args: args,
);

/// An app blocked by Gatekeeper in the last hour: Open Anyway is offered for it.
@immutable
class SilicaBlockedApp {
  const SilicaBlockedApp({
    required this.path,
    required this.name,
    required this.time,
  });

  final String path;
  final String name;

  /// When it was blocked (unix seconds).
  final int time;
}

/// The verdict on an app and what it is made of.
@immutable
class SilicaTrustAssessment {
  const SilicaTrustAssessment(this.verdict, this.info);

  /// `allow`, `confirm`, `block` or `malware`.
  final String verdict;
  final Map<String, Object?> info;

  String get developer =>
      info['developer'] is String ? info['developer'] as String : '';

  /// `verified`, `self-signed`, `unsigned` or `revoked`.
  String get developerStatus => info['developer_status'] is String
      ? info['developer_status'] as String
      : '';
}

/// Gatekeeper (`Trust1`). Without the daemon: nothing blocked, nothing assessed.
abstract final class SilicaTrust {
  static const String path = '/dev/frascella/Silica/Trust1';
  static const String interface = 'dev.frascella.Silica.Trust1';

  /// The verdict on an app bundle or an AppImage; null without the service.
  static Future<SilicaTrustAssessment?> assess(String appPath) async {
    try {
      final reply = await _call(path, interface, 'Assess', 's', [appPath]);
      if (reply.length < 2 || reply[0] is! String || reply[1] is! Map) {
        return null;
      }
      return SilicaTrustAssessment(
        reply[0] as String,
        (reply[1] as Map).cast<String, Object?>(),
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// The apps blocked in the last hour.
  static Future<List<SilicaBlockedApp>> blocked() async {
    try {
      final reply = await _call(path, interface, 'Blocked', '', const []);
      return parseBlocked(reply.isEmpty ? null : reply.first);
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  /// The blocked apps of a `Blocked` reply, `a(sst)`; malformed items skipped.
  static List<SilicaBlockedApp> parseBlocked(Object? reply) => [
    if (reply is List)
      for (final item in reply)
        if (item is List &&
            item.length >= 3 &&
            item[0] is String &&
            item[1] is String &&
            item[2] is int)
          SilicaBlockedApp(
            path: item[0] as String,
            name: item[1] as String,
            time: item[2] as int,
          ),
  ];

  /// Open Anyway: asks for an administrator, approves the app and opens it. False when the
  /// password was not given; an error message when refused for another reason.
  static Future<(bool, String?)> openAnyway(String appPath) async {
    try {
      final reply = await _call(path, interface, 'OpenAnyway', 's', [appPath]);
      return (reply.isNotEmpty && reply.first == true, null);
    } on PlatformException catch (e) {
      return (false, e.message ?? e.code);
    } on MissingPluginException {
      return (false, null);
    }
  }
}

/// An attached disk image.
@immutable
class SilicaVolume {
  const SilicaVolume({
    required this.mountpoint,
    required this.image,
    required this.name,
    this.signature = '',
    this.developerStatus = '',
    this.window = const SilicaVolumeWindow(),
  });

  final String mountpoint;
  final String image;
  final String name;

  /// `valid`, `invalid` or `unsigned`.
  final String signature;
  final String developerStatus;
  final SilicaVolumeWindow window;

  static SilicaVolume? fromTuple(Object? tuple) {
    if (tuple is! List || tuple.length < 3) return null;
    final [mount, image, info, ...] = tuple;
    if (mount is! String || image is! String || info is! Map) return null;
    String s(String k) => info[k] is String ? info[k] as String : '';
    return SilicaVolume(
      mountpoint: mount,
      image: image,
      name: s('name').isEmpty ? mount.split('/').last : s('name'),
      signature: s('signature'),
      developerStatus: s('developer_status'),
      window: SilicaVolumeWindow.fromMap(info['window']),
    );
  }
}

/// An item of a volume window: a name at a centre point.
@immutable
class SilicaVolumeItem {
  const SilicaVolumeItem(this.name, this.x, this.y);

  final String name;
  final double x;
  final double y;
}

/// The window layout of a volume (`.silica-window.toml`, read by the daemon).
@immutable
class SilicaVolumeWindow {
  const SilicaVolumeWindow({
    this.width = 540,
    this.height = 380,
    this.background = '',
    this.view = 'icons',
    this.iconSize = 128,
    this.textSize = 13,
    this.items = const [],
  });

  final double width;
  final double height;

  /// An absolute path inside the volume, or empty.
  final String background;
  final String view;
  final double iconSize;
  final double textSize;
  final List<SilicaVolumeItem> items;

  static SilicaVolumeWindow fromMap(Object? map) {
    if (map is! Map) return const SilicaVolumeWindow();
    double d(String k, double fallback) =>
        map[k] is num ? (map[k] as num).toDouble() : fallback;
    return SilicaVolumeWindow(
      width: d('width', 540),
      height: d('height', 380),
      background: map['background'] is String
          ? map['background'] as String
          : '',
      view: map['view'] is String ? map['view'] as String : 'icons',
      iconSize: d('icon_size', 128),
      textSize: d('text_size', 13),
      items: [
        if (map['items'] case final List items)
          for (final i in items)
            if (i is List &&
                i.length >= 3 &&
                i[0] is String &&
                i[1] is num &&
                i[2] is num)
              SilicaVolumeItem(
                i[0] as String,
                (i[1] as num).toDouble(),
                (i[2] as num).toDouble(),
              ),
      ],
    );
  }
}

/// What `Inspect` says about an image before it is attached.
@immutable
class SilicaVolumeInfo {
  const SilicaVolumeInfo({
    required this.name,
    required this.signature,
    required this.developerStatus,
    required this.license,
  });

  final String name;
  final String signature;
  final String developerStatus;

  /// The license to accept before mounting; empty when none.
  final String license;
}

/// Why an image did not attach.
enum SilicaVolumeError {
  licenseRequired,
  badSignature,
  unsigned,
  revoked,
  invalid,
  failed,
}

/// Disk images (`Volumes1`).
abstract final class SilicaVolumes {
  static const String path = '/dev/frascella/Silica/Volumes1';
  static const String interface = 'dev.frascella.Silica.Volumes1';

  /// Reads and verifies an image; null without the service or when it is not an image.
  static Future<SilicaVolumeInfo?> inspect(String image) async {
    try {
      final reply = await _call(path, interface, 'Inspect', 's', [image]);
      final map = reply.isEmpty ? null : reply.first;
      if (map is! Map) return null;
      String s(String k) => map[k] is String ? map[k] as String : '';
      return SilicaVolumeInfo(
        name: s('name'),
        signature: s('signature'),
        developerStatus: s('developer_status'),
        license: s('license'),
      );
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// The error of a D-Bus failure of `Attach`.
  static SilicaVolumeError errorOf(String message) {
    for (final (name, error) in [
      ('LicenseRequired', SilicaVolumeError.licenseRequired),
      ('BadSignature', SilicaVolumeError.badSignature),
      ('Unsigned', SilicaVolumeError.unsigned),
      ('Revoked', SilicaVolumeError.revoked),
      ('Invalid', SilicaVolumeError.invalid),
    ]) {
      if (message.contains('Volumes1.Error.$name')) return error;
    }
    return SilicaVolumeError.failed;
  }

  /// Attaches an image: its mount point, or the error.
  static Future<(String?, SilicaVolumeError?)> attach(
    String image, {
    bool acceptLicense = false,
  }) async {
    try {
      final reply = await _call(path, interface, 'Attach', 'sa{sv}', [
        image,
        {if (acceptLicense) 'accept_license': true},
      ]);
      final mount = reply.isEmpty ? null : reply.first;
      return mount is String ? (mount, null) : (null, SilicaVolumeError.failed);
    } on PlatformException catch (e) {
      return (null, errorOf('${e.code} ${e.message ?? ''}'));
    } on MissingPluginException {
      return (null, SilicaVolumeError.failed);
    }
  }

  /// Ejects a volume. False when busy or unknown.
  static Future<bool> detach(String mountpoint) async {
    try {
      await _call(path, interface, 'Detach', 's', [mountpoint]);
      return true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// The attached volumes; empty without the service.
  static Future<List<SilicaVolume>> list() async {
    try {
      final reply = await _call(path, interface, 'List', '', const []);
      final list = reply.isEmpty ? null : reply.first;
      return [
        if (list is List)
          for (final item in list) ?SilicaVolume.fromTuple(item),
      ];
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  /// A volume was attached or detached (its mount point).
  static Stream<String> changes() => SilicaDBus.instance
      .signals(interface: interface, path: path)
      .where((s) => s.member == 'Attached' || s.member == 'Detached')
      .map(
        (s) => s.args.isNotEmpty && s.args.first is String
            ? s.args.first as String
            : '',
      )
      .handleError((Object _) {});
}

/// An update found by `Updates1.Check`.
@immutable
class SilicaUpdate {
  const SilicaUpdate({
    required this.id,
    required this.kind,
    required this.name,
    required this.current,
    required this.available,
    this.notes = '',
    this.size = 0,
  });

  final String id;

  /// `bundle`, `appimage`, `flatpak` or `system`.
  final String kind;
  final String name;
  final String current;
  final String available;
  final String notes;
  final int size;

  static SilicaUpdate? fromTuple(Object? tuple) {
    if (tuple is! List || tuple.length < 6) return null;
    final [id, kind, name, current, available, details, ...] = tuple;
    if (id is! String || kind is! String || details is! Map) return null;
    return SilicaUpdate(
      id: id,
      kind: kind,
      name: '$name',
      current: '$current',
      available: '$available',
      notes: details['notes'] is String ? details['notes'] as String : '',
      size: details['size'] is int ? details['size'] as int : 0,
    );
  }
}

/// Software update (`Updates1`).
abstract final class SilicaUpdates {
  static const String path = '/dev/frascella/Silica/Updates1';
  static const String interface = 'dev.frascella.Silica.Updates1';

  /// Looks for updates; null without the service.
  static Future<List<SilicaUpdate>?> check() async {
    try {
      final reply = await _call(path, interface, 'Check', '', const []);
      final list = reply.isEmpty ? null : reply.first;
      return [
        if (list is List)
          for (final item in list) ?SilicaUpdate.fromTuple(item),
      ];
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Installs one update: `installed`, `pending_restart`, `staged`, or `failed: …`.
  static Future<String> update(String id) async {
    try {
      final reply = await _call(path, interface, 'Update', 's', [id]);
      return reply.isNotEmpty && reply.first is String
          ? reply.first as String
          : 'failed';
    } on PlatformException catch (e) {
      return 'failed: ${e.message ?? e.code}';
    } on MissingPluginException {
      return 'failed';
    }
  }
}
