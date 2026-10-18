// The standard About panel of every Silica app (silica-ui#99): App › About <App> opens it,
// built from the app's metadata ([SilicaAppInfo]). Nothing of it was measured on the reference:
// the layout uses the Amalfi tokens (spacing, type, colours) and the app's own icon.

import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'amalfi/foundation/app_icon.dart';
import 'amalfi/theme.dart';
import 'amalfi/tokens.g.dart';
import 'app.dart';
import 'windows.dart';

/// What the About panel and the app menu say about the app.
@immutable
class SilicaAppInfo {
  const SilicaAppInfo({
    required this.name,
    this.version = '',
    this.copyright = defaultCopyright,
    this.icon,
  });

  /// The copyright line of Silica's own apps (their LICENSE files).
  static const String defaultCopyright = '© 2026 The Silica authors';

  /// The app's name, as its menu shows it (in the user's language).
  final String name;

  /// The app's version (its pubspec's), shown as "Version <version>"; empty: no line.
  final String version;

  /// The copyright line; empty: no line.
  final String copyright;

  /// The app's icon: a silica-icons name or the absolute path of its `icon/` folder (the
  /// `X-Silica-Icon` of its desktop entry). Null: the folder next to the app's bundle, as
  /// installed (the embedder says where the bundle is).
  final String? icon;

  SilicaAppInfo copyWith({String? icon}) => SilicaAppInfo(
    name: name,
    version: version,
    copyright: copyright,
    icon: icon ?? this.icon,
  );
}

/// The About panel's measures (Amalfi tokens: nothing was measured on the reference).
abstract final class SilicaAboutMetrics {
  /// The panel's width.
  static const double width = 280;

  /// The side of the app icon's canvas.
  static const double iconSide = 96;

  /// The margin around the content.
  static const double padding = AmalfiSpacing.xxl;

  /// From the icon to the name.
  static const double iconGap = AmalfiSpacing.m;

  /// From the name to the version and between the lines below it.
  static const double lineGap = AmalfiSpacing.xs;

  /// From the version to the copyright.
  static const double copyrightGap = AmalfiSpacing.m;

  /// The panel's height for [info]: the content's, which never scrolls.
  static double heightFor(SilicaAppInfo info) {
    final name = AmalfiType.headlineToken.lineHeight ?? 18;
    final line = AmalfiType.captionToken.lineHeight ?? 14;
    var height = padding + iconSide + iconGap + name;
    if (info.version.isNotEmpty) height += lineGap + line;
    if (info.copyright.isNotEmpty) height += copyrightGap + line;
    return height + padding;
  }
}

/// The content of the About panel: the app's icon, name, version and copyright, centred.
class SilicaAboutPanel extends StatelessWidget {
  const SilicaAboutPanel({
    super.key,
    required this.info,
    this.versionLabel = defaultVersionLabel,
    this.env,
  });

  /// "Version 1.2" in English; the app gives its own words for other languages.
  static String defaultVersionLabel(String version) => 'Version $version';

  final SilicaAppInfo info;

  /// The version line for a version.
  final String Function(String version) versionLabel;

  /// The environment for finding the icon (tests); null: the process one.
  final Map<String, String>? env;

  @override
  Widget build(BuildContext context) {
    final colors = AmalfiTheme.of(context).colors;
    final icon = info.icon;
    return ColoredBox(
      color: colors.surfaceWindow,
      child: Padding(
        padding: const EdgeInsets.all(SilicaAboutMetrics.padding),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox.square(
              key: const ValueKey('about icon'),
              dimension: SilicaAboutMetrics.iconSide,
              child: icon == null || icon.isEmpty
                  ? null
                  : AmalfiAppIcon(
                      icon,
                      size: SilicaAboutMetrics.iconSide,
                      env: env,
                    ),
            ),
            const SizedBox(height: SilicaAboutMetrics.iconGap),
            Text(
              info.name,
              key: const ValueKey('about name'),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AmalfiType.headline(color: colors.textPrimary),
            ),
            if (info.version.isNotEmpty) ...[
              const SizedBox(height: SilicaAboutMetrics.lineGap),
              Text(
                versionLabel(info.version),
                key: const ValueKey('about version'),
                textAlign: TextAlign.center,
                // One line each: the panel is as tall as [SilicaAboutMetrics.heightFor] says.
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AmalfiType.caption(color: colors.textSecondary),
              ),
            ],
            if (info.copyright.isNotEmpty) ...[
              const SizedBox(height: SilicaAboutMetrics.copyrightGap),
              Text(
                info.copyright,
                key: const ValueKey('about copyright'),
                textAlign: TextAlign.center,
                // One line each: the panel is as tall as [SilicaAboutMetrics.heightFor] says.
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AmalfiType.caption(color: colors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Opens the About panel of the app, once: while it is open a second About opens no other. Null when the system cannot open windows (an app not started with
/// `--multi-window`, tests without the embedder).
Future<SilicaWindowController?> showSilicaAbout({
  SilicaAppInfo? info,
  String Function(String version)? versionLabel,
}) async {
  final open = _aboutWindow;
  if (open != null && open.isOpen) return open;
  var about = info ?? SilicaApp.info;
  if (about.icon == null) {
    final folder = await SilicaApp.iconFolder();
    if (folder != null) about = about.copyWith(icon: folder);
  }
  final window = await SilicaWindows.openWindow(
    // The panel has no title: the name is in it.
    title: '',
    size: Size(SilicaAboutMetrics.width, SilicaAboutMetrics.heightFor(about)),
    minSize: Size(
      SilicaAboutMetrics.width,
      SilicaAboutMetrics.heightFor(about),
    ),
    maxSize: Size(
      SilicaAboutMetrics.width,
      SilicaAboutMetrics.heightFor(about),
    ),
    kind: SilicaWindowKind.utility,
    builder: (context) => SilicaAboutPanel(
      info: about,
      versionLabel: versionLabel ?? SilicaAboutPanel.defaultVersionLabel,
    ),
  );
  _aboutWindow = window;
  return window;
}

SilicaWindowController? _aboutWindow;

/// The `icon/` folder next to the app's bundle (`<bundle>/../icon`, as installed), if it has the
/// compiled icon.
String? iconFolderNextTo(String bundle) {
  var path = bundle;
  while (path.length > 1 && path.endsWith('/')) {
    path = path.substring(0, path.length - 1);
  }
  final dir = '${File(path).parent.path}/icon';
  return File('$dir/icon.assets').existsSync() ? dir : null;
}

/// The bundle's path from the embedder's `appInfo` answer.
@visibleForTesting
String? bundleOf(Object? answer) {
  if (answer is! Map) return null;
  final bundle = answer['bundle'];
  return bundle is String && bundle.isNotEmpty ? bundle : null;
}

/// Asks the embedder on [channel] for the app's bundle (null outside Silica or on an older one).
Future<String?> askBundle(MethodChannel channel) async {
  try {
    return bundleOf(await channel.invokeMethod<Object?>('appInfo'));
  } on MissingPluginException {
    return null;
  } on PlatformException {
    return null;
  }
}
