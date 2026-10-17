// The Amalfi theme: which appearance (and which app palette) the widgets below draw with.

import 'package:flutter/widgets.dart';

import '../appearance.dart' show SilicaAppearance;
import '../system_look.dart';
import 'token_types.dart';
import 'tokens.g.dart';

/// The Amalfi tokens in effect: the colours and shadows of one appearance, and optionally the
/// palette of one app.
@immutable
class AmalfiThemeData {
  const AmalfiThemeData({
    required this.brightness,
    this.app,
    this.accent,
    this.highlight,
  });

  /// The light appearance, with the palette of [app] if given.
  const AmalfiThemeData.light({this.app, this.accent, this.highlight})
    : brightness = Brightness.light;

  /// The dark appearance, with the palette of [app] if given.
  const AmalfiThemeData.dark({this.app, this.accent, this.highlight})
    : brightness = Brightness.dark;

  /// The appearance.
  final Brightness brightness;

  /// The app whose palette [appColors] gives (`Mail`, `Mission Control`); null: none.
  final String? app;

  /// The accent chosen in the system settings, in place of `Accent/Amalfi`; null: the token's.
  final Color? accent;

  /// The text highlight colour chosen in the system settings; null: the accent's soft tone.
  final Color? highlight;

  /// Whether this is the dark appearance.
  bool get isDark => brightness == Brightness.dark;

  /// The colours of [brightness], with [accent] in place of `Accent/Amalfi` when set (its
  /// pressed tone is 20 % darker, its soft tone a translucent wash of it).
  AmalfiColors get colors {
    final base = AmalfiColors.of(brightness);
    final accent = this.accent;
    if (accent == null) return base;
    return base.withAccent(
      accent,
      Color.lerp(accent, const Color(0xFF000000), 0.2)!,
      accent.withAlpha(isDark ? 0x38 : 0x24),
    );
  }

  /// The background of selected text: the highlight colour, otherwise the accent's soft tone.
  Color get selectionColor {
    final highlight = this.highlight;
    return highlight == null
        ? colors.accentAmalfiSoft
        : highlight.withAlpha(isDark ? 0x66 : 0x55);
  }

  /// The drop shadows of [brightness].
  AmalfiShadows get shadows => AmalfiShadows.of(brightness);

  /// The palette of [app] in [brightness]; null when there is no app or it has no palette.
  AmalfiAppColors? get appColors {
    final name = app;
    return name == null ? null : colors.palette(name);
  }

  /// The colour [token] of the app palette (`Flag`); null when there is none.
  Color? appColor(String token) => appColors?[token];

  /// A copy with the given fields replaced.
  AmalfiThemeData copyWith({
    Brightness? brightness,
    String? app,
    Color? accent,
    Color? highlight,
  }) => AmalfiThemeData(
    brightness: brightness ?? this.brightness,
    app: app ?? this.app,
    accent: accent ?? this.accent,
    highlight: highlight ?? this.highlight,
  );

  @override
  bool operator ==(Object other) =>
      other is AmalfiThemeData &&
      other.brightness == brightness &&
      other.app == app &&
      other.accent == accent &&
      other.highlight == highlight;

  @override
  int get hashCode => Object.hash(brightness, app, accent, highlight);

  @override
  String toString() => 'AmalfiThemeData($brightness, app: $app)';
}

/// Gives the widgets below it an [AmalfiThemeData], read with [AmalfiTheme.of].
///
/// [brightness] null follows the appearance in effect ([SilicaAppearance.brightnessOf]: the
/// window's or the app's override, otherwise the system's); [app] null keeps the app of an
/// enclosing [AmalfiTheme]. Without any [AmalfiTheme] above, [AmalfiTheme.of] still answers,
/// with the appearance in effect and no app palette.
///
/// An app with a single appearance (the dark-only Calculator and Clock) should force it with
/// [SilicaAppearance] rather than here, so that the window and Ossido agree.
class AmalfiTheme extends StatelessWidget {
  const AmalfiTheme({
    super.key,
    this.brightness,
    this.app,
    required this.child,
  });

  /// The appearance to force; null: the one in effect.
  final Brightness? brightness;

  /// The app palette to use; null: the enclosing theme's.
  final String? app;

  final Widget child;

  /// The theme in effect under [context].
  static AmalfiThemeData of(BuildContext context) =>
      maybeOf(context) ?? _withLook(context, null, null);

  /// The theme of the closest [AmalfiTheme] above [context]; null when there is none.
  static AmalfiThemeData? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_AmalfiScope>()?.data;

  /// The theme of the appearance in effect with the system look (accent, highlight) under
  /// [context]; [brightness] and [app] override the appearance and the palette.
  static AmalfiThemeData _withLook(
    BuildContext context,
    Brightness? brightness,
    String? app,
  ) {
    final dark =
        (brightness ?? SilicaAppearance.brightnessOf(context)) ==
        Brightness.dark;
    final look = SystemLookScope.of(context);
    return AmalfiThemeData(
      brightness: dark ? Brightness.dark : Brightness.light,
      app: app,
      accent: SystemLook.amalfiColor(look.accent, dark: dark),
      highlight: look.highlight == null
          ? null
          : SystemLook.amalfiColor(look.highlight!, dark: dark),
    );
  }

  @override
  Widget build(BuildContext context) => _AmalfiScope(
    data: _withLook(context, brightness, app ?? maybeOf(context)?.app),
    child: child,
  );
}

class _AmalfiScope extends InheritedWidget {
  const _AmalfiScope({required this.data, required super.child});

  final AmalfiThemeData data;

  @override
  bool updateShouldNotify(_AmalfiScope old) => old.data != data;
}
