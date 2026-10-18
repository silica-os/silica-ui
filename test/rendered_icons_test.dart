// The `rendered` PNGs of silica-icons ≥ 0.6: which style draws a PNG, which one composes the
// SVG layers, and that dynamic content stays on top of both.

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';
import 'package:silica_ui/src/icons/silica_icon.dart'
    show RenderedIconImage, monthName;

const String svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">'
    '<rect x="100" y="100" width="824" height="824" fill="#2f8cff"/></svg>';

const String rendered = '''
  "rendered": { "default": "icon.png", "dark": "icon-dark.png",
                "clear": "icon-clear.png", "clear-dark": "icon-clear-dark.png",
                "tinted": "icon-tinted.png", "tinted-dark": "icon-tinted-dark.png" }''';

const List<String> pngs = [
  'icon.png',
  'icon-dark.png',
  'icon-clear.png',
  'icon-clear-dark.png',
  'icon-tinted.png',
  'icon-tinted-dark.png',
];

String manifest(
  String id, {
  String dynamic = 'null',
  bool withRendered = true,
}) =>
    '''
{ "format": 1, "id": "$id", "name": "$id", "kind": "app", "keyline": "square",
  "layers": [ { "role": "background", "file": "background.svg" },
              { "role": "foreground", "file": "foreground.svg", "shadow": "neutral" } ],
  "variants": { "dark": { "background": "background-dark.svg",
                          "foreground": "foreground-dark.svg" } },
  "dynamic": $dynamic${withRendered ? ',$rendered' : ''} }''';

const String clockDynamic = '''
{ "type": "clock", "cap": "cap.svg", "hands": [
    { "unit": "hour", "file": "hand-hour.svg" },
    { "unit": "minute", "file": "hand-minute.svg" },
    { "unit": "second", "file": "hand-second.svg", "min_size": 64 } ] }''';

const String calendarDynamic = '''
{ "type": "calendar",
  "month": { "size": 92, "weight": 900, "color": "#f2382e", "dark_color": "#ff5248",
             "box": [100, 206, 824, 120], "case": "upper", "max_width": 560 },
  "day": { "size": 280, "weight": 700, "color": "#ffffff", "box": [100, 410, 824, 460] } }''';

/// The PNGs are not decoded in these tests (no real image work under the fake clock): only
/// their presence and the choice of the file matter.
Map<String, String> files({bool withPngs = true}) => {
  'background.svg': svg,
  'background-dark.svg': svg,
  'foreground.svg': svg,
  'foreground-dark.svg': svg,
  if (withPngs)
    for (final png in pngs) png: 'not a png',
};

late Directory root;
late Map<String, String> env;

void main() {
  setUp(() {
    root = Directory.systemTemp.createTempSync('silica-icons-');
    env = {'SILICA_ICONS_DIR': root.path};
    void icon(String id, String json, Map<String, String> extra) {
      final dir = Directory('${root.path}/apps/$id')
        ..createSync(recursive: true);
      for (final MapEntry(:key, :value) in {
        'icon.json': json,
        ...extra,
      }.entries) {
        File('${dir.path}/$key').writeAsStringSync(value);
      }
    }

    icon('mail', manifest('mail'), files());
    icon('old', manifest('old', withRendered: false), files(withPngs: false));
    icon('clock', manifest('clock', dynamic: clockDynamic), {
      ...files(),
      'cap.svg': svg,
      'hand-hour.svg': svg,
      'hand-minute.svg': svg,
      'hand-second.svg': svg,
    });
    icon('calendar', manifest('calendar', dynamic: calendarDynamic), files());
  });
  tearDown(() => root.deleteSync(recursive: true));

  Future<void> show(
    WidgetTester tester,
    String id, {
    IconAppearance? appearance,
    bool? dark,
    Color? tint,
    double side = 48,
  }) => tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: SilicaIcon(
          LayeredSource(findSilicaIcon(id, env: env)!),
          side: side,
          dark: dark,
          appearance: appearance,
          tint: tint,
        ),
      ),
    ),
  );

  String? drawnPng(WidgetTester tester) {
    final found = find.byType(RenderedIconImage);
    if (found.evaluate().isEmpty) return null;
    return tester.widget<RenderedIconImage>(found).path.split('/').last;
  }

  test(
    'the manifest lists one PNG per style; bad or missing entries are skipped',
    () {
      final mail = findSilicaIcon('mail', env: env)!;
      expect(mail.rendered.length, 6);
      expect(mail.renderedFor(IconAppearance.light), endsWith('/icon.png'));
      expect(
        mail.renderedFor(IconAppearance.tintedDark),
        endsWith('/icon-tinted-dark.png'),
      );
      expect(findSilicaIcon('old', env: env)!.rendered, isEmpty);

      final dir = Directory('${root.path}/apps/mail').path;
      final partial = parseManifest(
        dir,
        manifest('mail')
            .replaceAll('"icon-clear.png"', '"../../../etc/passwd.png"')
            .replaceAll('"icon-tinted.png"', '"missing.png"'),
      )!;
      expect(partial.renderedFor(IconAppearance.clear), isNull);
      expect(partial.renderedFor(IconAppearance.tinted), isNull);
      expect(partial.renderedFor(IconAppearance.dark), isNotNull);
    },
  );

  testWidgets('Default and Dark draw the rendered PNG, not the layers', (
    tester,
  ) async {
    await show(tester, 'mail');
    expect(drawnPng(tester), 'icon.png');
    expect(find.byType(SvgPicture), findsNothing);

    await show(tester, 'mail', dark: true);
    expect(drawnPng(tester), 'icon-dark.png');

    await show(tester, 'mail', appearance: IconAppearance.dark);
    expect(drawnPng(tester), 'icon-dark.png');
  });

  testWidgets('Clear draws its PNG over a backdrop blur; Tinted its PNG', (
    tester,
  ) async {
    await show(tester, 'mail', appearance: IconAppearance.clear);
    expect(drawnPng(tester), 'icon-clear.png');
    expect(find.byType(BackdropFilter), findsOneWidget);

    await show(tester, 'mail', appearance: IconAppearance.clearDark);
    expect(drawnPng(tester), 'icon-clear-dark.png');

    await show(tester, 'mail', appearance: IconAppearance.tinted);
    expect(drawnPng(tester), 'icon-tinted.png');
    expect(find.byType(BackdropFilter), findsNothing);

    await show(
      tester,
      'mail',
      appearance: IconAppearance.tintedDark,
      tint: defaultIconTint,
    );
    expect(drawnPng(tester), 'icon-tinted-dark.png');
  });

  testWidgets('a custom tint composes the layers, recoloured', (tester) async {
    await show(
      tester,
      'mail',
      appearance: IconAppearance.tinted,
      tint: const Color(0xFF2FB350),
    );
    expect(drawnPng(tester), isNull);
    // The background is generated: only the foreground is an SVG, through the tint filter.
    expect(find.byType(SvgPicture), findsNWidgets(2)); // shadow pass and art
    expect(find.byType(ColorFiltered), findsWidgets);
  });

  testWidgets(
    'without `rendered` (older packs) every style composes the layers',
    (tester) async {
      await show(tester, 'old');
      expect(drawnPng(tester), isNull);
      expect(find.byType(SvgPicture), findsNWidgets(3));

      await show(tester, 'old', dark: true);
      expect(drawnPng(tester), isNull);
      final paths = tester
          .widgetList<SvgPicture>(find.byType(SvgPicture))
          .length;
      expect(paths, 3);

      await show(tester, 'old', appearance: IconAppearance.clear);
      expect(drawnPng(tester), isNull);
      expect(find.byType(BackdropFilter), findsOneWidget);
    },
  );

  testWidgets('the clock draws its hands and cap on top of the PNG', (
    tester,
  ) async {
    await show(tester, 'clock', side: 64);
    expect(drawnPng(tester), 'icon.png');
    // hour, minute, second (from 64 pt) and the cap.
    expect(find.byType(SvgPicture), findsNWidgets(4));

    await show(tester, 'clock', side: 32);
    expect(find.byType(SvgPicture), findsNWidgets(3));

    // Clear: the hands follow the grey foreground.
    await show(tester, 'clock', side: 64, appearance: IconAppearance.clear);
    expect(drawnPng(tester), 'icon-clear.png');
    expect(
      find.ancestor(
        of: find.byType(SvgPicture).first,
        matching: find.byType(ColorFiltered),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the calendar writes month and day on top of the PNG', (
    tester,
  ) async {
    await show(tester, 'calendar');
    expect(drawnPng(tester), 'icon.png');
    final now = DateTime.now();
    expect(find.text('${now.day}'), findsOneWidget);
    expect(find.text(monthName(now.month, 'en').toUpperCase()), findsOneWidget);

    await show(tester, 'calendar', dark: true);
    expect(drawnPng(tester), 'icon-dark.png');
    expect(find.text('${now.day}'), findsOneWidget);
  });

  testWidgets('an unreadable PNG falls back to the layers', (tester) async {
    // Real I/O: the file is read and the codec fails on the fake PNG.
    await tester.runAsync(() async {
      await show(tester, 'mail');
      expect(find.byType(SvgPicture), findsNothing);
      final image = tester.widget<Image>(find.byType(Image));
      final failed = Completer<void>();
      image.image
          .resolve(ImageConfiguration.empty)
          .addListener(
            ImageStreamListener(
              (_, _) {},
              onError: (_, _) {
                if (!failed.isCompleted) failed.complete();
              },
            ),
          );
      await failed.future.timeout(const Duration(seconds: 5));
    });
    await tester.pump();
    expect(find.byType(SvgPicture), findsNWidgets(3));
  });

  test('the decoded side follows the drawn pixels in powers of two', () {
    expect(RenderedIconImage.decodeSide(20), 64);
    expect(RenderedIconImage.decodeSide(116), 128);
    expect(RenderedIconImage.decodeSide(130), 256);
    expect(RenderedIconImage.decodeSide(5000), 1024);
  });
}
