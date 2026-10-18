// The Amalfi tokens: the generated file is up to date and deterministic, and every token of
// tool/amalfi/tokens.json and tool/amalfi/motion.md is in it with its value.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

import '../tool/gen_amalfi_tokens.dart' as gen;

final Map<String, Object?> _tokens =
    jsonDecode(File(gen.tokensPath).readAsStringSync()) as Map<String, Object?>;

Map<String, Object?> _obj(Object? v) => v as Map<String, Object?>;

double _n(Object? v) => (v as num).toDouble();

Color _hex(String s) {
  final rgb = int.parse(s.substring(1, 7), radix: 16);
  final a = s.length == 9 ? int.parse(s.substring(7), radix: 16) : 0xFF;
  return Color((a << 24) | rgb);
}

Map<String, Color> _scheme(String scheme) => {
  for (final MapEntry(:key, :value) in _obj(
    _obj(_tokens['colors'])[scheme],
  ).entries)
    key: _hex(value as String),
};

String _generate({String? tokens, String? motion}) => gen.generate(
  tokensJson: tokens ?? File(gen.tokensPath).readAsStringSync(),
  motionMarkdown: motion ?? File(gen.motionPath).readAsStringSync(),
  fontFamilies: gen.fontFamiliesOf(File(gen.pubspecPath).readAsStringSync()),
);

void main() {
  group('generator', () {
    test('is deterministic', () {
      expect(_generate(), _generate());
    });

    test('the committed file is what it generates (no diff)', () async {
      final formatted = await gen.formatDart(_generate());
      expect(
        formatted == File(gen.outputPath).readAsStringSync(),
        isTrue,
        reason:
            '${gen.outputPath} is stale: run `dart run tool/gen_amalfi_tokens.dart`',
      );
    });

    test('carries the generated header', () {
      expect(
        File(gen.outputPath).readAsStringSync(),
        startsWith('// GENERATED CODE - DO NOT EDIT BY HAND.'),
      );
    });

    test('fails with a message on bad input, never crashes', () {
      String withColor(String value) => File(
        gen.tokensPath,
      ).readAsStringSync().replaceFirst('"#0E77E6FF"', value);
      Matcher fails(String fragment) => throwsA(
        isA<gen.TokenError>().having(
          (e) => e.message,
          'message',
          contains(fragment),
        ),
      );
      expect(
        () => _generate(tokens: withColor('"#0E77E6F"')),
        fails('colors.light["Accent/Amalfi"]'),
      );
      expect(
        () => _generate(tokens: withColor('12')),
        fails('expected a string'),
      );
      expect(() => _generate(tokens: '{'), fails('not valid JSON'));
      expect(() => _generate(tokens: '[]'), fails('expected an object'));
      final unknown = File(
        gen.tokensPath,
      ).readAsStringSync().replaceFirst('"grid": {', '"grid": {"extra": 1, ');
      expect(() => _generate(tokens: unknown), fails('unknown key "extra"'));
      final missingDark = File(
        gen.tokensPath,
      ).readAsStringSync().replaceFirst('"Accent/Amalfi": "#3D95FFFF",', '');
      expect(
        () => _generate(tokens: missingDark),
        fails('light and dark differ'),
      );
      final badFont = File(
        gen.tokensPath,
      ).readAsStringSync().replaceFirst('"JetBrains Mono"', '"Unknown Mono"');
      expect(() => _generate(tokens: badFont), fails('not a font family'));
      final motion = File(gen.motionPath).readAsStringSync();
      expect(
        () => _generate(motion: motion.replaceFirst('631.7', '600.0')),
        fails('do not match'),
      );
      expect(
        () => _generate(motion: motion.replaceFirst('| 100 ms |', '| soon |')),
        fails('is not "<n> ms"'),
      );
      expect(() => _generate(motion: ''), fails('expected spring.*'));
    });
  });

  group('colours', () {
    final light = _scheme('light');
    final dark = _scheme('dark');

    test('every colour token is generated with its value', () {
      for (final (scheme, values, colors) in [
        ('light', light, AmalfiColors.light),
        ('dark', dark, AmalfiColors.dark),
      ]) {
        for (final MapEntry(:key, :value) in values.entries) {
          expect(colors.byName(key), value, reason: '$scheme $key');
          expect(AmalfiColors.tokenNames, contains(key));
          final parts = key.split('/');
          if (parts.first == 'App') {
            expect(
              colors.app(parts[1], parts[2]),
              value,
              reason: '$scheme $key',
            );
            expect(colors.palette(parts[1])?.brightness.name, scheme);
          }
        }
      }
      expect(AmalfiColors.tokenNames.toSet(), {
        ...light.keys,
        ...dark.keys,
      }, reason: 'no generated token without a source');
    });

    test('typed fields', () {
      expect(AmalfiColors.light.accentAmalfi, const Color(0xFF0E77E6));
      expect(AmalfiColors.dark.accentAmalfi, const Color(0xFF3D95FF));
      expect(AmalfiColors.light.textOnAccent, const Color(0xFFFFFFFF));
      expect(AmalfiColors.light.shadow1, const Color(0x1A000000));
      expect(AmalfiColors.dark.mail.flag, const Color(0xFFFF9C3D));
      expect(AmalfiColors.light.terminal.ansiRed, const Color(0xFF990100));
      expect(AmalfiColors.light.missionControl.ring, const Color(0xFF3B99FD));
      expect(AmalfiColors.of(Brightness.dark), same(AmalfiColors.dark));
    });

    test('light and dark have the same keys', () {
      final system = light.keys.where((k) => !k.startsWith('App/')).toSet();
      expect(dark.keys.where((k) => !k.startsWith('App/')).toSet(), system);
      for (final name in AmalfiColors.tokenNames) {
        expect(AmalfiColors.light.byName(name), isNotNull, reason: name);
        expect(AmalfiColors.dark.byName(name), isNotNull, reason: name);
      }
      for (final app in AmalfiColors.appNames) {
        final l = AmalfiColors.light.palette(app);
        final d = AmalfiColors.dark.palette(app);
        expect(l?.tokenNames, d?.tokenNames, reason: app);
      }
    });

    test('a single-appearance app has its palette in both', () {
      for (final app in AmalfiColors.appNames) {
        final inLight = light.keys.any((k) => k.startsWith('App/$app/'));
        final inDark = dark.keys.any((k) => k.startsWith('App/$app/'));
        final palette = AmalfiColors.light.palette(app);
        expect(palette, isNotNull);
        expect(palette?.appearances, {
          if (inLight) Brightness.light,
          if (inDark) Brightness.dark,
        });
        if (!inLight) {
          expect(palette, same(AmalfiColors.dark.palette(app)), reason: app);
        }
      }
      expect(AmalfiColors.light.calculator.brightness, Brightness.dark);
    });

    test('unknown names give null', () {
      expect(AmalfiColors.light.byName('Text/Missing'), isNull);
      expect(AmalfiColors.light.app('Nope', 'Flag'), isNull);
      expect(AmalfiColors.light.app('Mail', 'Nope'), isNull);
      expect(AmalfiColors.light.palette(''), isNull);
    });
  });

  test('every text style', () {
    final typography = _obj(_tokens['typography']);
    expect(AmalfiType.tokens.map((t) => t.name), typography.keys);
    for (final MapEntry(key: name, value: raw) in typography.entries) {
      final s = _obj(raw);
      final token = AmalfiType.tokenNamed(name);
      expect(token, isNotNull, reason: name);
      if (token == null) continue;
      expect(token.family, s['family']);
      expect(token.size, _n(s['size']));
      final lineHeight = s['lineHeight'] == null ? null : _n(s['lineHeight']);
      expect(token.lineHeight, lineHeight);
      expect(token.weight.value, _n(s['weight']));
      expect(token.colorTokens, s['colors']);
      final style = AmalfiType.byName(name, color: const Color(0xFF123456));
      expect(style?.fontSize, _n(s['size']));
      expect(
        style?.height,
        lineHeight == null ? null : lineHeight / _n(s['size']),
      );
      expect(style?.color, const Color(0xFF123456));
      expect(style?.fontFamily, 'packages/silica_ui/${s['family']}');
      expect(token.tracking, s['tracking'] == null ? 0 : _n(s['tracking']));
      expect(token.features, s['features'] ?? const <String>[]);
      expect(
        style?.letterSpacing,
        s['tracking'] == null ? null : _n(s['tracking']),
      );
    }
    // The lock screen's clock: Inter 200 Semibold, tracking -6, tabular figures.
    expect(AmalfiType.lockClock().letterSpacing, -6);
    expect(AmalfiType.lockClock().fontFeatures, const [FontFeature('tnum')]);
    expect(AmalfiType.lockClock().fontWeight, FontWeight.w600);
    expect(AmalfiType.lockDate().fontSize, 32);
    expect(AmalfiType.lockDate().height, 40 / 32);
    expect(AmalfiType.lockDateToken.colorTokens, ['On Photo']);
    expect(AmalfiType.body().letterSpacing, isNull);
    expect(AmalfiType.body().fontFeatures, isNull);
    expect(AmalfiType.mono().fontFamily, 'packages/silica_ui/JetBrains Mono');
    expect(AmalfiType.body().fontWeight, FontWeight.w400);
    expect(AmalfiType.title1().fontSize, 26);
    expect(AmalfiType.tokenNamed('Nope'), isNull);
  });

  test('text styles with a natural line height and a "use" note', () {
    for (final style in [
      AmalfiType.numeral40,
      AmalfiType.numeral64,
      AmalfiType.numeral72,
      AmalfiType.numeral104,
      AmalfiType.wordmark,
    ]) {
      expect(style().height, isNull);
    }
    expect(AmalfiType.numeral104Token.lineHeight, isNull);
    expect(AmalfiType.numeral104Token.size, 104);
    expect(AmalfiType.wordmarkToken.size, 110);
    expect(AmalfiType.wordmarkToken.weight, FontWeight.w700);
    expect(AmalfiType.field().height, 32 / 26);
    expect(AmalfiType.fieldToken.lineHeight, 32);
    final generated = File('lib/src/amalfi/tokens.g.dart').readAsStringSync();
    expect(generated, contains('Use: Faro and Launcher search field.'));
    expect(generated, contains('Use: kit cover only, not UI.'));
  });

  test('grid, spacing, controls, radii', () {
    expect(AmalfiGrid.base, _n(_obj(_tokens['grid'])['base']));
    expect(AmalfiGrid.snap(13), 12);
    final spacing = _obj(_tokens['spacing']);
    expect(
      [
        AmalfiSpacing.xs,
        AmalfiSpacing.s,
        AmalfiSpacing.m,
        AmalfiSpacing.l,
        AmalfiSpacing.xl,
        AmalfiSpacing.xxl,
      ],
      [
        for (final k in ['xs', 's', 'm', 'l', 'xl', 'xxl']) _n(spacing[k]),
      ],
    );
    final padding = _obj(spacing['padding']);
    expect(AmalfiSpacing.paddingRegularWindow, _n(padding['regularWindow']));
    expect(
      AmalfiSpacing.paddingCompactWindowAndPanel,
      _n(padding['compactWindowAndPanel']),
    );
    expect(
      AmalfiSpacing.paddingDocumentAndSettings,
      _n(padding['documentAndSettings']),
    );

    final heights = _obj(_tokens['controlHeights']);
    final icons = _obj(_tokens['controlIcons']);
    expect(AmalfiControlSize.values.map((s) => s.height), [20, 24, 28, 32]);
    for (final size in AmalfiControlSize.values) {
      expect(size.height, _n(heights[size.name]));
      expect(size.iconSize, _n(icons[size.name]));
    }
    expect(AmalfiControlIcons.toolbar, _n(icons['toolbar']));

    final radii = _obj(_tokens['radii']);
    expect(AmalfiRadii.smallControl, _n(radii['smallControl']));
    expect(AmalfiRadii.regularControl, _n(radii['regularControl']));
    expect(AmalfiRadii.field, _n(radii['field']));
    expect(AmalfiRadii.menu, _n(radii['menu']));
    expect(AmalfiRadii.popover, _n(radii['popover']));
    expect(AmalfiRadii.sheetAlert, _n(radii['sheetAlert']));
    expect(AmalfiRadii.window, _n(radii['window']));
    expect(AmalfiRadii.sidebarInsetPanel, _n(radii['sidebarInsetPanel']));
    expect(AmalfiRadii.faroAndLauncher, _n(radii['faroAndLauncher']));
    expect(AmalfiRadii.capsule(32), 16);
    expect(AmalfiRadii.smoothing, 0.6);
  });

  test('shadows, focus, states', () {
    final shadows = _obj(_tokens['shadows']);
    for (final (scheme, generated) in [
      ('light', AmalfiShadows.light),
      ('dark', AmalfiShadows.dark),
    ]) {
      for (final MapEntry(:key, :value) in _obj(shadows[scheme]).entries) {
        final s = _obj(value);
        final list = generated.level(int.parse(key));
        expect(list, hasLength(1), reason: '$scheme $key');
        final shadow = list?.single;
        expect(shadow?.color, _hex(s['color'] as String));
        expect(shadow?.offset, Offset(0, _n(s['y'])));
        expect(shadow?.blurRadius, _n(s['blur']));
      }
    }
    expect(AmalfiShadows.light.level(4), isNull);

    expect(AmalfiFocus.halo, 3);
    expect(AmalfiFocus.color(AmalfiColors.dark), AmalfiColors.dark.lineFocus);

    final states = _obj(_tokens['states']);
    for (final b in Brightness.values) {
      expect(
        AmalfiStates.hoverOverlay(b),
        _hex(_obj(states['hoverOverlay'])[b.name] as String),
      );
      expect(
        AmalfiStates.pressOverlay(b),
        _hex(_obj(states['pressOverlay'])[b.name] as String),
      );
    }
    expect(AmalfiStates.disabledOpacity, 0.35);
  });

  test('materials', () {
    final materials = _obj(_tokens['materials']);
    // The glass clipped to glyphs (`Glass/Clock`, it has a fill) is a material of its own.
    expect(
      AmalfiMaterials.all.map((m) => m.name),
      materials.keys.where(
        (k) =>
            k.startsWith('Glass/') && !_obj(materials[k]).containsKey('fill'),
      ),
    );
    // Glass/Lock: no refraction, no shadow, and opaque accessibility variants (the Status Bar
    // plates).
    final lock = AmalfiMaterials.lock;
    expect(lock.refraction, isNull);
    expect(lock.shadowLevel, isNull);
    expect(lock.backgroundBlur, 20);
    expect(lock.tint(Brightness.dark), const Color(0x47FFFFFF));
    expect(lock.tint(Brightness.light), const Color(0x99FFFFFF));
    expect(lock.rimInside(Brightness.dark), const Color(0x3DFFFFFF));
    expect(
      lock.increaseContrast(Brightness.dark)!.fill,
      const Color(0xF22A2B30),
    );
    expect(
      lock.increaseContrast(Brightness.light)!.rimInside,
      const Color(0x991D1E21),
    );
    expect(
      lock.reduceTransparency(Brightness.dark)!.fill,
      const Color(0xFF5B5C5E),
    );
    expect(
      lock.reduceTransparency(Brightness.light)!.rimLight,
      const Color(0xB3FFFFFF),
    );
    expect(AmalfiMaterials.regular.increaseContrast(Brightness.dark), isNull);
    // Glass/Clock: the lock screen's digits.
    final clock = AmalfiGlyphMaterials.clock;
    expect(clock.backgroundBlur, 8);
    expect(clock.saturation, 1.3);
    expect(clock.brightness, 1.3);
    expect(clock.refraction.distortion, 0.5);
    expect(clock.fill, const Color(0xC2FFFFFF));
    expect(clock.lineInside, const Color(0xCCFFFFFF));
    expect(clock.rimOutside(Brightness.dark), const Color(0x52000000));
    expect(clock.reduceTransparencyFill, const Color(0xEBFFFFFF));
    expect(clock.increaseContrastRimWidth, 2);
    expect(clock.increaseContrastRim, const Color(0x66000000));
    // Scrim/Lock Light: black 20 % at the top to 0 at 30 %, 0 to 60 %, black 35 % at the bottom.
    expect(AmalfiScrims.lockLight.stops, [0, 0.3, 0.6, 1]);
    expect(AmalfiScrims.lockLight.colors.first, const Color(0x33000000));
    expect(AmalfiScrims.lockLight.colors.last, const Color(0x59000000));
    // shadows.onPhoto: black 40 %, y 1, blur 6.
    expect(AmalfiShadows.onPhoto, const [
      BoxShadow(color: Color(0x66000000), offset: Offset(0, 1), blurRadius: 6),
    ]);
    // The blur strip over a sidebar: no glass, just blur and a tint.
    final strip = _obj(materials['Blur/Sidebar Title Bar']);
    expect(AmalfiBlurs.sidebarTitleBar.backgroundBlur, strip['backgroundBlur']);
    expect(AmalfiBlurs.sidebarTitleBar.saturation, strip['saturation']);
    expect(AmalfiBlurs.sidebarTitleBar.tintLight, const Color(0xCCF5F6F8));
    expect(AmalfiBlurs.sidebarTitleBar.tintDark, const Color(0xCC232428));
    final regular = _obj(materials['Glass/Regular']);
    expect(
      AmalfiMaterials.regular.backgroundBlur,
      _n(regular['backgroundBlur']),
    );
    expect(AmalfiMaterials.regular.saturation, _n(regular['saturation']));
    expect(
      AmalfiMaterials.regular.tint(Brightness.dark),
      _hex(_obj(regular['tint'])['dark'] as String),
    );
    expect(AmalfiMaterials.regular.shadowLevel, 2);
    expect(AmalfiMaterials.thick.backgroundBlur, 10);
    // Regular and Thick are real glass: edge refraction, specular rim, brightness.
    final regularRefraction = AmalfiMaterials.regular.refraction!;
    expect(regularRefraction.distortion, 0.3);
    expect(regularRefraction.depth, 0.35);
    expect(regularRefraction.chromaticAberration, 0.03);
    expect(regularRefraction.magnification, 1);
    expect(AmalfiMaterials.regular.lens, isFalse);
    expect(AmalfiMaterials.regular.specularHighlights, isTrue);
    expect(AmalfiMaterials.regular.brightnessLight, 1.25);
    expect(AmalfiMaterials.regular.brightnessDark, 1.1);
    final thickRefraction = AmalfiMaterials.thick.refraction!;
    expect(thickRefraction.distortion, 0.22);
    expect(thickRefraction.depth, 0.28);
    expect(thickRefraction.chromaticAberration, 0.015);
    expect(AmalfiMaterials.thick.specularHighlights, isTrue);
    expect(AmalfiMaterials.thick.brightnessLight, 1.12);
    expect(AmalfiMaterials.thick.brightnessDark, 1.05);
    expect(AmalfiMaterials.thick.saturation, 1.1);
    expect(AmalfiMaterials.thick.shadowLevel, 3);
    expect(
      AmalfiMaterials.thick.tint(Brightness.light),
      AmalfiColors.light.glassTintThick,
    );
    final clear = AmalfiMaterials.clear;
    expect(clear.lens, isTrue);
    expect(clear.tint(Brightness.light), isNull);
    expect(clear.shadowLevel, isNull);
    expect(clear.backgroundBlur, 2);
    expect(clear.refraction?.magnification, 1.1);
    expect(clear.refraction?.chromaticAberration, 0.08);
    expect(clear.brightnessLight, 1.04);
    expect(clear.brightnessDark, 0.98);
    for (final m in AmalfiMaterials.all) {
      expect(m.rimInside(Brightness.light), AmalfiColors.light.glassRimDark);
      expect(m.rimLight(Brightness.dark), AmalfiColors.dark.glassRimLight);
      expect(m.rimLightOffset, const Offset(0, 1));
      expect(AmalfiMaterials.byName(m.name), same(m));
    }
  });

  test('window controls', () {
    final wc = _obj(_tokens['windowControls']);
    expect(AmalfiWindowControls.dot, _n(wc['dot']));
    expect(AmalfiWindowControls.firstCentreX, _n(wc['firstCentreX']));
    expect(AmalfiWindowControls.pitch, _n(wc['pitch']));
    for (final (key, control) in [
      ('close', AmalfiWindowControls.close),
      ('minimise', AmalfiWindowControls.minimise),
      ('zoom', AmalfiWindowControls.zoom),
    ]) {
      final c = _obj(wc[key]);
      final fill = c['fill'] as List<Object?>;
      expect(control.top, _hex(fill[0] as String), reason: key);
      expect(control.bottom, _hex(fill[1] as String), reason: key);
      final rim = (c['rim'] as String).split(' ');
      expect(control.rim, _hex(rim[0]), reason: key);
      expect(control.rimWidth, double.parse(rim[1]), reason: key);
    }
  });

  group('motion', () {
    test('springs match motion.md', () {
      const table = {
        'snappy': (0.25, 0.90, 631.7, 45.2),
        'panel': (0.35, 0.82, 322.3, 29.4),
        'window': (0.40, 0.88, 246.7, 27.6),
        'morph': (0.50, 0.70, 157.9, 17.6),
        'bouncy': (0.60, 0.50, 109.7, 10.5),
      };
      final springs = {
        'snappy': AmalfiSprings.snappy,
        'panel': AmalfiSprings.panel,
        'window': AmalfiSprings.window,
        'morph': AmalfiSprings.morph,
        'bouncy': AmalfiSprings.bouncy,
      };
      for (final MapEntry(key: name, value: (response, zeta, k, c))
          in table.entries) {
        final s = springs[name];
        expect(s?.name, 'spring.$name');
        expect(s?.mass, 1);
        expect(s?.response, response);
        expect(s?.dampingRatio, zeta);
        expect(s?.stiffness, k);
        expect(s?.damping, c);
        expect(k, closeTo(math.pow(2 * math.pi / response, 2), 0.1));
        expect(c, closeTo(2 * zeta * math.sqrt(k), 0.1));
      }
      // Every spring row of motion.md is generated.
      final rows = RegExp(
        r'^\| `spring\.',
        multiLine: true,
      ).allMatches(File(gen.motionPath).readAsStringSync());
      expect(rows.length, table.length);
    });

    test('fades and delays', () {
      expect(AmalfiFades.instant.duration, const Duration(milliseconds: 100));
      expect(AmalfiFades.quick.duration, const Duration(milliseconds: 150));
      expect(AmalfiFades.standard.duration, const Duration(milliseconds: 250));
      expect(AmalfiFades.slow.duration, const Duration(milliseconds: 400));
      expect(AmalfiFades.instant.curve, AmalfiCurves.easeOut);
      expect(AmalfiFades.quick.curve, AmalfiCurves.easeOut);
      expect(AmalfiFades.standard.curve, AmalfiCurves.easeInOut);
      expect(AmalfiCurves.easeOut, const Cubic(0.2, 0, 0, 1));
      expect(AmalfiCurves.easeInOut, const Cubic(0.4, 0, 0.2, 1));
      expect(AmalfiDelays.hoverIntent, const Duration(milliseconds: 60));
      expect(AmalfiDelays.tooltip, const Duration(milliseconds: 700));
      expect(AmalfiDelays.tooltipWhileMoving, Duration.zero);
    });
  });
}
