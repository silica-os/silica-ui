// Format 2 app icons: parsed from icon.json, composed by the thumbnail service
// (`Thumbnails1.AppIcon`) with the bundled PNG as fallback, dynamic layers drawn live.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

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
    expect(args, [dir.path, (64 * 1024 / 824 * 2).round(), 2.0, 1, 0]);
    expect(find.byType(BackdropFilter), findsOneWidget);
    // Hour and second hands (the canvas is above 64 pt): the cap does not rotate.
    expect(_live(tester), greaterThanOrEqualTo(2));
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
