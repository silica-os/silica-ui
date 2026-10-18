import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';
import 'package:silica_ui_example/amalfi/gallery.dart';
import 'package:silica_ui_example/amalfi/pages.dart';

Future<void> pumpGallery(
  WidgetTester tester, {
  String family = 'tooltips',
  Brightness brightness = Brightness.light,
}) async {
  tester.view.physicalSize = const Size(1600, 1200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    WidgetsApp(
      color: const Color(0xFF0E77E6),
      builder: (context, _) => Overlay(
        key: ValueKey((family, brightness)),
        initialEntries: [
          OverlayEntry(
            builder: (_) => AmalfiGallery(
              initialFamily: family,
              initialBrightness: brightness,
            ),
          ),
        ],
      ),
    ),
  );
  await tester.pump();
}

void main() {
  test('one page per family, in the order of the checklist', () {
    expect(amalfiGalleryPages.map((p) => p.family), [
      'buttons', 'segmented', 'toggles', 'fields', 'menus', 'popovers', //
      'tooltips', 'sliders', 'steppers', 'progress', 'scrollbars', 'sidebars',
      'lists', 'disclosure', 'group_boxes', 'forms', 'titlebars', 'windows',
      'alerts', 'dialogs', 'sheets', 'wells', 'status_bar',
    ]);
  });

  for (final brightness in Brightness.values) {
    testWidgets('every page builds ($brightness)', (tester) async {
      for (final page in amalfiGalleryPages) {
        await pumpGallery(tester, family: page.family, brightness: brightness);
        expect(tester.takeException(), isNull, reason: page.family);
        expect(find.text('Amalfi · ${page.title}'), findsOneWidget);
      }
    });
  }

  testWidgets('the tooltips page shows every variant and a live tooltip', (
    tester,
  ) async {
    await pumpGallery(tester);
    expect(find.byType(AmalfiTooltip), findsNWidgets(3));
    expect(find.byType(AmalfiTooltipRegion), findsNWidgets(4));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(mouse.removePointer);
    await mouse.addPointer(location: Offset.zero);
    await mouse.moveTo(
      tester.getCenter(find.byType(AmalfiTooltipRegion).first),
    );
    await tester.pump(AmalfiDelays.tooltip);
    await tester.pump(AmalfiFades.quick.duration * 2);
    expect(find.byType(AmalfiTooltip), findsNWidgets(4));
  });

  testWidgets('the appearance switch turns the page dark', (tester) async {
    await pumpGallery(tester);
    Brightness current() => AmalfiTheme.of(
      tester.element(find.byType(AmalfiTooltip).first),
    ).brightness;
    expect(current(), Brightness.light);
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();
    expect(current(), Brightness.dark);
  });
}
