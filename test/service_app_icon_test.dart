// Format 2 app icons: parsed from icon.json, composed by the thumbnail service
// (`Thumbnails1.AppIcon`) with the bundled PNG as fallback, dynamic layers drawn live.

import 'dart:convert';
import 'dart:ui' as ui;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';
import 'package:silica_ui/src/icons/silica_icon.dart' show clearGlassGroup;

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">'
    '<rect x="500" y="200" width="24" height="312" fill="#fff"/></svg>';
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

const _manifest = '''
{"format": 2, "id": "clock", "name": "Clock", "kind": "app", "keyline": "full",
 "background": {"light": {"gradient": ["#ffffff", "#dde3ec"]}},
 "layers": [
  {"id": "ticks", "role": "detail"},
  {"id": "hand-hour", "role": "dynamic", "dynamic": {"kind": "clock-hand", "unit": "hour", "pivot": [512, 512]}},
  {"id": "hand-second", "role": "dynamic", "min_size": 64, "tinted": {"mode": "hide"},
   "dynamic": {"kind": "clock-hand", "unit": "second"}},
  {"id": "cap", "role": "dynamic", "dynamic": {"kind": "clock-cap"}}],
 "fallback": {"light": "icon.png", "dark": "icon-dark.png", "time": "10:09:30"}}
''';

Directory _folder() {
  final dir = Directory.systemTemp.createTempSync('format2-');
  addTearDown(() => dir.deleteSync(recursive: true));
  Directory('${dir.path}/layers').createSync();
  File('${dir.path}/icon.json').writeAsStringSync(_manifest);
  File('${dir.path}/icon.png').writeAsBytesSync(_png);
  File('${dir.path}/icon-dark.png').writeAsBytesSync(_png);
  File('${dir.path}/service.png').writeAsBytesSync(_png);
  for (final id in ['ticks', 'hand-hour', 'hand-second', 'cap']) {
    File('${dir.path}/layers/$id.svg').writeAsStringSync(_svg);
  }
  return dir;
}

Future<void> _pump(WidgetTester tester, Widget icon, {double dpr = 2}) async {
  tester.view.devicePixelRatio = dpr;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(child: icon),
    ),
  );
  await tester.pump();
  await tester.pump();
}

Future<List<int>> _transparentPng(WidgetTester tester) async {
  return (await tester.runAsync(() async {
    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder);
    final image = await recorder.endRecording().toImage(4, 4);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  }))!;
}

int _live(WidgetTester tester) => find.byType(Transform).evaluate().length;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(
    () => messenger.setMockMethodCallHandler(SilicaThumbnails.channel, null),
  );

  test('a format 2 manifest parses: fallback PNGs, dynamic layers', () {
    final dir = _folder();
    final icon = parseManifest(dir.path, _manifest)!;
    expect(icon.format, 2);
    expect(icon.dir, dir.path);
    expect(icon.layers, hasLength(4));
    expect(icon.renderedFor(IconAppearance.light), endsWith('icon.png'));
    expect(icon.renderedFor(IconAppearance.dark), endsWith('icon-dark.png'));
    final live = icon.dynamicLayers;
    expect(live.map((l) => l.kind), [
      DynamicKind.clockHand,
      DynamicKind.clockHand,
      DynamicKind.clockCap,
    ]);
    expect(live[1].unit, ClockUnit.second);
    expect(live[1].minSize, 64);
    expect(live[1].tintedMode, 'hide');
    expect(live[0].pivot, const Offset(512, 512));
  });

  test(
    'a format 2 manifest without its fallback or layer files is invalid',
    () {
      final dir = _folder();
      File('${dir.path}/layers/cap.svg').deleteSync();
      expect(parseManifest(dir.path, _manifest), isNull);
      File('${dir.path}/layers/cap.svg').writeAsStringSync(_svg);
      File('${dir.path}/icon.png').deleteSync();
      expect(parseManifest(dir.path, _manifest), isNull);
    },
  );

  test(
    'the AppIcon request carries folder, pixels, scale, look and accent',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(SilicaThumbnails.channel, (
        call,
      ) async {
        calls.add(call);
        return ['/cache/x.png'];
      });
      expect(
        await SilicaThumbnails.appIcon(
          '/apps/clock/icon',
          256,
          scale: 2,
          look: IconAppearance.tintedDark,
          accent: const Color(0xFF123456),
        ),
        '/cache/x.png',
      );
      final args = calls.single.arguments as Map;
      expect(args['interface'], 'dev.frascella.Silica.Thumbnails1');
      expect(args['method'], 'AppIcon');
      expect(args['signature'], 'suduu');
      expect(args['args'], ['/apps/clock/icon', 256, 2.0, 6, 0x123456]);
      // The accent only goes with the tinted looks; a relative folder is refused.
      await SilicaThumbnails.appIcon(
        '/apps/clock/icon',
        64,
        look: IconAppearance.clear,
        accent: const Color(0xFF123456),
      );
      expect((calls.last.arguments as Map)['args'], [
        '/apps/clock/icon',
        64,
        1.0,
        1,
        0,
      ]);
      expect(await SilicaThumbnails.appIcon('relative', 64), isNull);
      expect(await SilicaThumbnails.appIcon('/a', 0), isNull);
    },
  );

  testWidgets('the service image shows with the live layers on top', (
    tester,
  ) async {
    final dir = _folder();
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(SilicaThumbnails.channel, (call) async {
      calls.add(call);
      return ['${dir.path}/service.png'];
    });
    final icon = parseManifest(dir.path, _manifest)!;
    await _pump(
      tester,
      SilicaIcon(
        LayeredSource(icon),
        side: 64,
        appearance: IconAppearance.clear,
      ),
    );
    final args = (calls.single.arguments as Map)['args'] as List;
    // 64 pt body -> 64 * 1024 / 824 pt canvas at 2x.
    // Clear asks for the bare composition (1 + 8): the body is the compositor's glass.
    expect(args, [dir.path, (64 * 1024 / 824 * 2).round(), 2.0, 9, 0]);
    expect(find.byType(BackdropFilter), findsNothing);
    final glass = tester.widget<Glass>(find.byType(Glass));
    expect(glass.profile, GlassProfile.control);
    expect(glass.profileShadow, isFalse);
    expect(glass.group, clearGlassGroup);
    expect(glass.radius, closeTo(64 * 0.30, 1e-9));
    // The region is the body's rectangle.
    expect(tester.getSize(find.byType(Glass)), const Size(64, 64));
    // Hour and second hands (the canvas is above 64 pt): the cap does not rotate.
    expect(_live(tester), greaterThanOrEqualTo(2));
  });

  testWidgets('a Clear icon has no shadow inside its body, only around it', (
    tester,
  ) async {
    final dir = _folder();
    // The service answers with a fully transparent foreground.
    final blank = await _transparentPng(tester);
    File('${dir.path}/service.png').writeAsBytesSync(blank);
    messenger.setMockMethodCallHandler(
      SilicaThumbnails.channel,
      (call) async => ['${dir.path}/service.png'],
    );
    final icon = parseManifest(dir.path, _manifest)!;
    Future<ui.Image> render(IconAppearance look) async {
      final key = GlobalKey();
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: RepaintBoundary(
              key: key,
              child: SizedBox.square(
                dimension: 200,
                child: Center(
                  child: SilicaIcon(
                    LayeredSource(icon),
                    side: 100,
                    appearance: look,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      // Real time for the service's answer and the image decode.
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
      return (await tester.runAsync(() async {
        final boundary =
            key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        return boundary.toImage();
      }))!;
    }

    Future<int> alpha(ui.Image image, int x, int y) async {
      final data = (await tester.runAsync(
        () => image.toByteData(format: ui.ImageByteFormat.rawRgba),
      ))!;
      return data.getUint8((y * image.width + x) * 4 + 3);
    }

    final clear = await render(IconAppearance.clear);
    // The body is 100 pt in the middle of 200 (x and y 50..150): untouched at its centre and
    // just inside its bottom edge, where a drop shadow would show...
    // (the live clock hands are drawn on the middle, so sample beside them)
    expect(await alpha(clear, 70, 130), 0);
    expect(await alpha(clear, 100, 140), 0);
    // ... and drawn just below it.
    expect(await alpha(clear, 100, 154), greaterThan(0));

    // Any other style keeps the shadow under the body (it is hidden by the opaque body there,
    // here the body is transparent too, so the shadow shows through).
    final light = await render(IconAppearance.light);
    expect(await alpha(light, 100, 140), greaterThan(0));
  });

  testWidgets('a hidden or too small layer is not drawn', (tester) async {
    final dir = _folder();
    messenger.setMockMethodCallHandler(
      SilicaThumbnails.channel,
      (call) async => ['${dir.path}/service.png'],
    );
    final icon = parseManifest(dir.path, _manifest)!;
    await _pump(
      tester,
      SilicaIcon(LayeredSource(icon), side: 40, dark: true),
      dpr: 1,
    );
    final small = _live(tester);
    await _pump(tester, SilicaIcon(LayeredSource(icon), side: 100), dpr: 1);
    expect(_live(tester), small + 1, reason: 'the second hand needs 64 pt');
  });

  testWidgets(
    'without the service or a compiled icon only the flat PNG shows',
    (tester) async {
      final dir = _folder();
      final icon = parseManifest(dir.path, _manifest)!;
      // No handler: MissingPluginException.
      await _pump(tester, SilicaIcon(LayeredSource(icon), side: 100));
      final missing = _live(tester);
      // The service answers "": no compiled icon.
      messenger.setMockMethodCallHandler(
        SilicaThumbnails.channel,
        (call) async => [''],
      );
      await _pump(tester, SilicaIcon(LayeredSource(icon), side: 96));
      expect(_live(tester), missing, reason: 'no hands over the flat icon');
      expect(find.byType(BackdropFilter), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
