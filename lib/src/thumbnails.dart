// File thumbnails: the system thumbnail service (silica-daemon,
// `dev.frascella.Silica.Thumbnails1`), cached per the freedesktop thumbnail specification.

import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'icons/silica_icon.dart';
import 'icons/silica_icons.dart';

/// The system thumbnail service over the embedder's `silica/dbus` channel. Outside Silica (no
/// channel, no daemon) there are no thumbnails and callers keep their fallback.
abstract final class SilicaThumbnails {
  static const MethodChannel channel = MethodChannel(
    'silica/dbus',
    JSONMethodCodec(),
  );

  static const String _name = 'dev.frascella.Silica';
  static const String _path = '/dev/frascella/Silica/Thumbnails1';
  static const String _interface = 'dev.frascella.Silica.Thumbnails1';

  static final Map<String, Future<String?>> _pending = {};

  static Future<List<Object?>> _call(
    String method,
    String signature,
    List<Object?> args,
  ) async {
    final reply = await channel.invokeMethod<List<Object?>>('call', {
      'bus': 'session',
      'destination': _name,
      'path': _path,
      'interface': _interface,
      'method': method,
      'signature': signature,
      'args': args,
    });
    return reply ?? const [];
  }

  /// The path of the cached PNG of [file] for [sizePx] device pixels, or null when the file has
  /// no thumbnail or the service is not there. Equal requests in flight share one call. The
  /// image is at least [sizePx] on its longest edge unless the source is smaller.
  static Future<String?> thumbnail(Uri file, int sizePx) {
    if (sizePx <= 0) return Future.value();
    final key = '$sizePx $file';
    return _pending[key] ??= _request(file, sizePx).whenComplete(() {
      _pending.remove(key);
    });
  }

  static Future<String?> _request(Uri file, int sizePx) async {
    try {
      final reply = await _call('Thumbnail', 'su', [file.toString(), sizePx]);
      final path = reply.isEmpty ? null : reply.first;
      return path is String && path.isNotEmpty ? path : null;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// The icon of [file] (a file or a folder) at exactly [sizePx] device pixels, composed by the
  /// service (`Thumbnails1.Icon`): the preview when there is one (unless [noPreview]), else the
  /// composed file or folder icon. [scale] is the device pixel ratio, which sets the symbol
  /// weight and the label. Null when the service is not there or has nothing. Equal requests in
  /// flight share one call.
  static Future<ComposedIcon?> icon(
    Uri file,
    int sizePx, {
    double scale = 1,
    bool noPreview = false,
    IconAppearance look = IconAppearance.light,
    Color? accent,
  }) {
    if (sizePx <= 0 || !scale.isFinite || scale <= 0) return Future.value();
    final flags = iconFlags(noPreview: noPreview, look: look, accent: accent);
    final key = '$sizePx $scale $flags $file';
    return _pendingIcons[key] ??= _requestIcon(file, sizePx, scale, flags)
        .whenComplete(() {
          _pendingIcons.remove(key);
        });
  }

  /// The `flags` of `Icon`: bit 0 no preview; bits 1 to 3 the icon style as the `AppIcon`
  /// appearance word (folders are drawn in it: dark, clear, tinted); bits 8 to 31 the accent of
  /// the tinted styles (0: the service's default).
  @visibleForTesting
  static int iconFlags({
    bool noPreview = false,
    IconAppearance look = IconAppearance.light,
    Color? accent,
  }) {
    final rgb = look.isTinted && accent != null
        ? accent.toARGB32() & 0xFFFFFF
        : 0;
    return (noPreview ? iconNoPreview : 0) |
        (look.serviceWord << 1) |
        (rgb << 8);
  }

  static final Map<String, Future<ComposedIcon?>> _pendingIcons = {};

  /// `Icon` flag: no preview, only the composed icon.
  static const int iconNoPreview = 1;

  static Future<ComposedIcon?> _requestIcon(
    Uri file,
    int sizePx,
    double scale,
    int flags,
  ) async {
    try {
      final reply = await _call('Icon', 'sudu', [
        file.toString(),
        sizePx,
        scale,
        flags,
      ]);
      if (reply.length < 2) return null;
      final path = reply[0];
      final preview = reply[1];
      if (path is! String || path.isEmpty) return null;
      return ComposedIcon(path, preview == true);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// The icon of an app composed by the service (`Thumbnails1.AppIcon`) from the
  /// `icon/icon.assets` in [iconDir] (the absolute `X-Silica-Icon` folder), at exactly [sizePx]
  /// device pixels, in [look] and (Tinted) with [accent]. The layers that move (Clock hands) are
  /// not in the PNG: the caller draws them. Null when the service is not there or the app has no
  /// compiled icon (the caller keeps the bundled `icon.png`). Equal requests in flight share one
  /// call.
  static Future<String?> appIcon(
    String iconDir,
    int sizePx, {
    double scale = 1,
    IconAppearance look = IconAppearance.light,
    Color? accent,
    bool bare = false,
  }) {
    if (sizePx <= 0 ||
        !scale.isFinite ||
        scale <= 0 ||
        !iconDir.startsWith('/')) {
      return Future.value();
    }
    // 0: the service's default accent. Only the tinted looks use it.
    final rgb = look.isTinted && accent != null
        ? accent.toARGB32() & 0xFFFFFF
        : 0;
    final word = look.serviceWord + (bare ? bareAppearance : 0);
    final key = '$iconDir $sizePx $scale $word $rgb';
    return _pendingApps[key] ??= _requestApp(iconDir, sizePx, scale, word, rgb)
        .whenComplete(() {
          _pendingApps.remove(key);
        });
  }

  static final Map<String, Future<String?>> _pendingApps = {};

  /// Added to the `AppIcon` appearance word: only the foreground layers, no generated
  /// background (the Clear icons, over the compositor's glass).
  static const int bareAppearance = 8;

  static Future<String?> _requestApp(
    String iconDir,
    int sizePx,
    double scale,
    int appearance,
    int accent,
  ) async {
    try {
      final reply = await _call('AppIcon', 'suduu', [
        iconDir,
        sizePx,
        scale,
        appearance,
        accent,
      ]);
      final path = reply.isEmpty ? null : reply.first;
      return path is String && path.isNotEmpty ? path : null;
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Tells the service that [files] changed, so it forgets their thumbnails.
  static Future<void> invalidate(List<Uri> files) async {
    if (files.isEmpty) return;
    try {
      await _call('Invalidate', 'as', [
        [for (final f in files) f.toString()],
      ]);
    } on PlatformException {
      return;
    } on MissingPluginException {
      return;
    }
  }
}

/// The thumbnail of [file], [size] logical pixels square at most. It asks the service for
/// `size * devicePixelRatio` pixels and shows [fallback] (the file-type icon, say) until the
/// image is there, and for good when the file has no thumbnail or the service is missing.
class SilicaThumbnail extends StatefulWidget {
  const SilicaThumbnail({
    super.key,
    required this.file,
    required this.size,
    required this.fallback,
    this.fit = BoxFit.contain,
  });

  /// The file, as a `file://` URI.
  final Uri file;

  /// The edge of the box, in logical pixels.
  final double size;

  /// Shown until the thumbnail is ready, or when there is none. Sized by the caller.
  final Widget fallback;

  final BoxFit fit;

  @override
  State<SilicaThumbnail> createState() => _SilicaThumbnailState();
}

class _SilicaThumbnailState extends State<SilicaThumbnail> {
  String? _path;
  int _requested = 0;
  int _generation = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(SilicaThumbnail old) {
    super.didUpdateWidget(old);
    if (old.file != widget.file || old.size != widget.size) _load();
  }

  void _load() {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final px = (widget.size * dpr).ceil();
    if (px <= 0 || !px.isFinite) return;
    // A bigger request than the last one for the same file asks again; a smaller one keeps the
    // image it has.
    final sameFile = _path != null && _file == widget.file;
    if (sameFile && px <= _requested) return;
    if (!sameFile) _path = null;
    _file = widget.file;
    _requested = px;
    final generation = ++_generation;
    SilicaThumbnails.thumbnail(widget.file, px).then((path) {
      if (!mounted || generation != _generation || path == null) return;
      setState(() => _path = path);
    });
  }

  Uri? _file;

  @override
  Widget build(BuildContext context) {
    final path = _path;
    if (path == null) return widget.fallback;
    return Image.file(
      File(path),
      width: widget.size,
      height: widget.size,
      fit: widget.fit,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => widget.fallback,
    );
  }
}

/// The reply of `Thumbnails1.Icon`: the PNG and whether it is a preview of the content (an image
/// or a PDF) rather than the composed icon.
class ComposedIcon {
  const ComposedIcon(this.path, this.preview);

  final String path;
  final bool preview;
}

/// The icon of a file or a folder as the system draws it everywhere: the preview of the content
/// or the composed icon of the daemon (kind, handling app, folder colour and symbol), at exactly
/// `size * devicePixelRatio` pixels. Until the PNG is there, and for good without the service,
/// it shows [fallback]; by default the plain generic layers of silica-icons (the sheet, or the
/// folder) at the exact size, or an empty box when the pack is not installed. silica_ui composes
/// nothing itself.
class SilicaFileIcon extends StatefulWidget {
  const SilicaFileIcon({
    super.key,
    required this.file,
    required this.size,
    this.isFolder = false,
    this.preview = true,
    this.fallback,
    this.revision,
    this.fit = BoxFit.contain,
    this.env,
    this.look,
    this.tint,
    this.onComposed,
  });

  /// Called once, per delivered image, when the composed icon's first frame is decoded and
  /// drawn in place of the fallback.
  final VoidCallback? onComposed;

  /// The icon style folders are drawn in (Default, Dark, Clear, Tinted). Null: the system's
  /// (Settings > Appearance > icon style), which is what the file manager and the shell want.
  final IconAppearance? look;

  /// The accent of the Tinted styles; null: the system's.
  final Color? tint;

  /// The file or folder, as a `file://` URI.
  final Uri file;

  /// The edge of the box, in logical pixels.
  final double size;

  /// Chooses the plain layers of the default fallback: the folder instead of the sheet.
  final bool isFolder;

  /// Allow the preview of the content (images, PDF); false: always the composed icon.
  final bool preview;

  /// Replaces the default fallback; sized by the caller.
  final Widget? fallback;

  /// Changes when the icon may have changed without the path or size changing (content of a
  /// folder, a new colour); a different value asks the service again.
  final Object? revision;

  final BoxFit fit;

  /// The environment for finding silica-icons (tests).
  final Map<String, String>? env;

  @override
  State<SilicaFileIcon> createState() => _SilicaFileIconState();
}

class _SilicaFileIconState extends State<SilicaFileIcon> {
  String? _path;
  int _generation = 0;
  String? _reported;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(SilicaFileIcon old) {
    super.didUpdateWidget(old);
    if (old.file != widget.file ||
        old.size != widget.size ||
        old.preview != widget.preview ||
        old.look != widget.look ||
        old.tint != widget.tint ||
        old.revision != widget.revision) {
      if (old.file != widget.file) _path = null;
      _load();
    }
  }

  void _load() {
    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final px = (widget.size * dpr).round();
    if (px <= 0 || !widget.size.isFinite) return;
    final generation = ++_generation;
    final (look, accent) = widget.look != null
        ? (widget.look!, widget.tint)
        : systemIconLook(context);
    SilicaThumbnails.icon(
      widget.file,
      px,
      scale: dpr,
      noPreview: !widget.preview,
      look: look,
      accent: widget.tint ?? accent,
    ).then((icon) {
      if (!mounted || generation != _generation || icon == null) return;
      setState(() => _path = icon.path);
    });
  }

  Widget _plain() {
    final icon = findSilicaIcon(
      widget.isFolder ? 'folder-generic' : 'file-generic',
      env: widget.env,
    );
    final size = widget.size.isFinite ? widget.size : 0.0;
    if (icon == null) return SizedBox.square(dimension: size);
    return SilicaIcon(LayeredSource(icon), side: size, env: widget.env);
  }

  @override
  Widget build(BuildContext context) {
    final path = _path;
    final fallback = widget.fallback ?? _plain();
    if (path == null) return fallback;
    return Image.file(
      File(path),
      width: widget.size,
      height: widget.size,
      fit: widget.fit,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      frameBuilder: (context, child, frame, sync) {
        if ((sync || frame != null) && _reported != path) {
          _reported = path;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _reported == path) widget.onComposed?.call();
          });
        }
        return child;
      },
      errorBuilder: (_, _, _) => fallback,
    );
  }
}
