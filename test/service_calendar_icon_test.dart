// Calendar in format 2: the month and day are text layers drawn live (font, size, weight,
// colours, box, case, format, refresh) over the icon the thumbnail service composes.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';
import 'package:silica_ui/src/icons/silica_icon.dart' show monthLabel;

const _svg =
    '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">'
    '<rect x="300" y="160" width="424" height="190" fill="#f5222f"/></svg>';
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

const _manifest = '''
{"format": 2, "id": "calendar", "name": "Calendar", "kind": "app", "keyline": "full",
 "background": {"light": {"gradient": ["#ffffff", "#dde3ec"]}},
 "layers": [
  {"id": "date-disc", "role": "body", "tinted": {"mode": "accent"}},
  {"id": "month", "role": "dynamic", "tinted": {"mode": "accent"},
   "dynamic": {"kind": "calendar-month", "font": "Inter", "size": 190, "weight": 900,
               "tracking": 0, "color": "#f5222f", "dark_color": "#ff5a62",
               "box": [212, 144, 600, 230], "case": "upper", "format": "short",
               "refresh": "midnight"}},
  {"id": "day", "role": "dynamic",
   "dynamic": {"kind": "calendar-day", "font": "Inter", "size": 308, "weight": 700,
               "tracking": 0, "color": "#ffffff", "dark_color": "#f2f4f8",
               "box": [212, 426, 600, 372], "refresh": "midnight"}}],
 "fallback": {"light": "icon.png", "dark": "icon-dark.png"}}
''';

Directory _folder([String manifest = _manifest]) {
  final dir = Directory.systemTemp.createTempSync('calendar2-');
  addTearDown(() => dir.deleteSync(recursive: true));
  Directory('${dir.path}/layers').createSync();
  File('${dir.path}/icon.json').writeAsStringSync(manifest);
  for (final name in ['icon.png', 'icon-dark.png', 'service.png']) {
    File('${dir.path}/$name').writeAsBytesSync(_png);
  }
  for (final id in ['date-disc', 'month', 'day']) {
    File('${dir.path}/layers/$id.svg').writeAsStringSync(_svg);
  }
  return dir;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(
    () => messenger.setMockMethodCallHandler(SilicaThumbnails.channel, null),
  );

  test('the text fields of the calendar layers parse', () {
    final icon = parseManifest(_folder().path, _manifest)!;
    final live = icon.dynamicLayers;
    expect(live.map((l) => l.kind), [
      DynamicKind.calendarMonth,
      DynamicKind.calendarDay,
    ]);
    final month = live[0].text!;
    expect(month.font, 'Inter');
    expect((month.size, month.weight, month.tracking), (190, 900, 0));
    expect(month.color, const Color(0xFFF5222F));
    expect(month.darkColor, const Color(0xFFFF5A62));
    expect(month.box, const Rect.fromLTWH(212, 144, 600, 230));
    expect(
      (month.upper, month.format, month.refresh),
      (true, 'short', 'midnight'),
    );
    expect(live[0].tintedMode, 'accent');
    final day = live[1].text!;
    expect(
      (day.upper, day.format, day.size, day.weight),
      (false, '', 308, 700),
    );
    expect(day.box, const Rect.fromLTWH(212, 426, 600, 372));
  });

  test('a calendar layer without its box is invalid', () {
    final broken = _manifest.replaceFirst('"box": [212, 144, 600, 230],', '');
    expect(parseManifest(_folder(broken).path, broken), isNull);
  });

  test('month labels: three letters, one letter or the full name', () {
    expect(monthLabel(10, 'en', 'short').toUpperCase(), 'OCT');
    expect(monthLabel(10, 'it', 'short').toUpperCase(), 'OTT');
    expect(monthLabel(5, 'it', 'short').toUpperCase(), 'MAG');
    expect(monthLabel(3, 'fr', 'short').toUpperCase(), 'MAR');
    expect(monthLabel(10, 'en', 'narrow'), 'O');
    expect(monthLabel(10, 'en', 'long'), 'October');
    expect(monthLabel(10, 'it', ''), 'ottobre');
  });

  Future<void> pump(
    WidgetTester tester,
    LayeredIcon icon, {
    Locale locale = const Locale('en'),
    bool dark = false,
    IconAppearance? appearance,
  }) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Localizations(
          locale: locale,
          delegates: const [DefaultWidgetsLocalizations.delegate],
          child: Center(
            child: SilicaIcon(
              LayeredSource(icon),
              side: 200,
              dark: dark,
              appearance: appearance,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('today is drawn live in its boxes, centred, upper case', (
    tester,
  ) async {
    final dir = _folder();
    messenger.setMockMethodCallHandler(
      SilicaThumbnails.channel,
      (call) async => ['${dir.path}/service.png'],
    );
    final icon = parseManifest(dir.path, _manifest)!;
    await pump(tester, icon);
    final now = DateTime.now();
    final month = monthLabel(now.month, 'en', 'short').toUpperCase();
    expect(find.text(month), findsOneWidget);
    expect(find.text('${now.day}'), findsOneWidget);
    // Canvas: a 200 pt body is 200 * 1024 / 824 pt; boxes scale with it.
    final canvas = 200 * 1024 / 824;
    final k = canvas / 1024;
    // The canvas is centred on the icon (the body, 200 pt, is inset by 100/1024).
    final origin =
        tester.getCenter(find.byType(SilicaIcon)) - Offset(canvas, canvas) / 2;
    for (final (text, box) in [
      (month, const Rect.fromLTWH(212, 144, 600, 230)),
      ('${now.day}', const Rect.fromLTWH(212, 426, 600, 372)),
    ]) {
      final rect = tester.getRect(find.text(text));
      final want = Rect.fromLTWH(
        origin.dx + box.left * k,
        origin.dy + box.top * k,
        box.width * k,
        box.height * k,
      );
      expect(want.inflate(1).contains(rect.center), isTrue, reason: text);
      expect((rect.center.dx - want.center.dx).abs(), lessThan(1.5));
      expect(
        (rect.center.dy - want.center.dy).abs(),
        lessThan(want.height / 2),
      );
      expect(rect.width, lessThanOrEqualTo(want.width + 1));
    }
    final style = tester.widget<Text>(find.text(month)).style!;
    expect(style.fontWeight, FontWeight.w900);
    expect(style.color, const Color(0xFFF5222F));
    expect(style.fontSize, closeTo(190 * k, 0.01));
  });

  testWidgets('Italian month, dark colours', (tester) async {
    final dir = _folder();
    messenger.setMockMethodCallHandler(
      SilicaThumbnails.channel,
      (call) async => ['${dir.path}/service.png'],
    );
    final icon = parseManifest(dir.path, _manifest)!;
    await pump(tester, icon, locale: const Locale('it'), dark: true);
    final month = monthLabel(DateTime.now().month, 'it', 'short').toUpperCase();
    expect(
      tester.widget<Text>(find.text(month)).style!.color,
      const Color(0xFFFF5A62),
    );
  });

  testWidgets('no text without the service image (the flat PNG has it)', (
    tester,
  ) async {
    final dir = _folder();
    final icon = parseManifest(dir.path, _manifest)!;
    await pump(tester, icon);
    expect(find.text('${DateTime.now().day}'), findsNothing);
  });
}
