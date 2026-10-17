// The Share menu: the system share service (silica-daemon, `dev.frascella.Silica.Share1`).

import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'amalfi/components/menus/menu.dart';
import 'icons/silica_icon.dart';
import 'icons/silica_icons.dart';

/// A place the Share menu can send files to.
@immutable
class SilicaShareTarget {
  const SilicaShareTarget({
    required this.id,
    required this.name,
    this.icon = '',
  });

  /// `copy`, or the desktop entry id of an application.
  final String id;

  /// The application's name (the menu translates `copy`).
  final String name;

  /// The application's icon id, empty for `copy`.
  final String icon;

  /// Whether this is the clipboard target.
  bool get isCopy => id == SilicaShare.copy;

  @override
  bool operator ==(Object other) =>
      other is SilicaShareTarget &&
      other.id == id &&
      other.name == name &&
      other.icon == icon;

  @override
  int get hashCode => Object.hash(id, name, icon);
}

/// The system share service over the embedder's `silica/dbus` channel. Outside Silica (no
/// channel, no daemon) there are no targets, so a Share button stays hidden.
abstract final class SilicaShare {
  static const MethodChannel channel = MethodChannel(
    'silica/dbus',
    JSONMethodCodec(),
  );

  static const String copy = 'copy';
  static const String _name = 'dev.frascella.Silica';
  static const String _path = '/dev/frascella/Silica/Share1';
  static const String _interface = 'dev.frascella.Silica.Share1';

  static Future<List<Object?>> _call(String method, List<Object?> args) async {
    final reply = await channel.invokeMethod<List<Object?>>('call', {
      'bus': 'session',
      'destination': _name,
      'path': _path,
      'interface': _interface,
      'method': method,
      'signature': method == 'Targets' ? 'as' : 'sas',
      'args': args,
    });
    return reply ?? const [];
  }

  /// The targets for [files] (`file://` URIs), `copy` first; empty when the service is not
  /// there.
  static Future<List<SilicaShareTarget>> targets(List<Uri> files) async {
    if (files.isEmpty) return const [];
    try {
      final reply = await _call('Targets', [
        [for (final f in files) f.toString()],
      ]);
      return reply.isEmpty ? const [] : parseTargets(reply.first);
    } on PlatformException {
      return const [];
    } on MissingPluginException {
      return const [];
    }
  }

  /// Sends [files] to [target]. False when the service is not there or refused.
  static Future<bool> share(SilicaShareTarget target, List<Uri> files) async {
    if (files.isEmpty) return false;
    try {
      final reply = await _call('Share', [
        target.id,
        [for (final f in files) f.toString()],
      ]);
      return reply.isNotEmpty && reply.first == true;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// The targets in the service's typed reply, `a(sss)` (id, name, icon), which the channel
  /// delivers as a list of lists; malformed entries are skipped.
  static List<SilicaShareTarget> parseTargets(Object? reply) {
    if (reply is! List) return const [];
    return [
      for (final item in reply)
        if (item is List &&
            item.length >= 2 &&
            item[0] is String &&
            item[1] is String)
          SilicaShareTarget(
            id: item[0] as String,
            name: item[1] as String,
            icon: item.length > 2 && item[2] is String ? item[2] as String : '',
          ),
    ];
  }
}

/// The menu entries for [targets]: the applications, a divider, then Copy (labelled
/// [copyLabel]). Choosing one calls [onShare].
List<AmalfiMenuEntry> silicaShareEntries(
  List<SilicaShareTarget> targets, {
  required String copyLabel,
  required void Function(SilicaShareTarget target) onShare,
}) {
  final apps = [
    for (final t in targets)
      if (!t.isCopy) t,
  ];
  final copy = [
    for (final t in targets)
      if (t.isCopy) t,
  ];
  Widget? iconOf(SilicaShareTarget t) {
    final icon = t.icon.isEmpty ? null : findSilicaIcon(t.icon);
    return icon == null ? null : SilicaIcon(LayeredSource(icon), side: 16);
  }

  return [
    for (final t in apps)
      AmalfiMenuAction(t.name, icon: iconOf(t), onSelected: () => onShare(t)),
    if (apps.isNotEmpty && copy.isNotEmpty) const AmalfiMenuDivider(),
    for (final t in copy)
      AmalfiMenuAction(copyLabel, onSelected: () => onShare(t)),
  ];
}

/// Asks the service for the targets of [files] and shows the Share menu at the global
/// [position]. Completes with the chosen target once it was sent, or null when the menu
/// closed without a choice or there was nothing to show.
Future<SilicaShareTarget?> showSilicaShareMenu({
  required BuildContext context,
  required Offset position,
  required List<Uri> files,
  String copyLabel = 'Copy',
}) async {
  final targets = await SilicaShare.targets(files);
  if (targets.isEmpty || !context.mounted) return null;
  SilicaShareTarget? chosen;
  await showAmalfiMenu(
    context: context,
    position: position,
    entries: silicaShareEntries(
      targets,
      copyLabel: copyLabel,
      onShare: (t) => chosen = t,
    ),
  );
  final target = chosen;
  if (target == null) return null;
  return await SilicaShare.share(target, files) ? target : null;
}
