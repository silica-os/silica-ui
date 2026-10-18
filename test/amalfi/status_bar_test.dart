// The Status Bar against the kit (`Status Bar/*`): the items (glyph at rest and active, battery,
// input source, clock) and the bars of both contexts (menu bar, lock screen) in every legibility
// treatment. Spec: silica-desktop docs/design/amalfi/status-bar.md.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

import 'support/harness.dart';

/// The box of a label: the whole-points box around the text, which decides the layout.
Finder label(String text) => find
    .ancestor(of: find.text(text), matching: find.byType(AmalfiWholePoints))
    .first;

/// The visible box of the item keyed [name].
Finder box(String name) => find.byKey(ValueKey('box $name'));

const Key itemKey = ValueKey('box item');

/// The clock's label hugs its text (status-bar.md › Items: "in code, labels hug their text");
/// Inter measures `Fri 16 Oct  09:41` a little narrower here than in Sketch, so its box on the
/// 4 pt grid is 100 instead of the kit's 104, and the item 116 instead of 120.
const String clockReason =
    'the clock label hugs its text: 100 pt here, 104 in the kit';

/// The plate's two round ends: the kit draws them with corner style 0 (circular) instead of the
/// smooth capsule of radius 14 that status-bar.md asks for (concentric with the Active capsule);
/// see docs/amalfi-checklist/kit-issues.md.
List<Rect> plateEnds(KitMaster master, AmalfiStatusBarLegibility legibility) =>
    legibility == AmalfiStatusBarLegibility.standard
    ? const []
    : [
        const Rect.fromLTWH(0, 2, 14, 28),
        Rect.fromLTWH(master.size.width - 14, 2, 14, 28),
      ];

const Map<String, String> clockDeviations = {
  '#frame': clockReason,
  'Label': clockReason,
};

/// The plate's style, in the kit's terms: the variant's fill, its rim inside and its rim light.
RenderedStyle? _plate(Widget widget, BuildContext context) {
  if (widget is! AmalfiStatusBarPlate) return null;
  final v = widget.variant;
  return RenderedStyle(
    fills: [v.fill],
    borders: [RenderedBorder(v.rimInside, 1, BorderSide.strokeAlignInside)],
    innerShadows: [
      if (v.rimLight case final light?)
        BoxShadow(color: light, offset: const Offset(0, 1), blurRadius: 1),
    ],
    radii: const [14, 14, 14, 14],
    smoothing: AmalfiRadii.smoothing,
    source: 'AmalfiStatusBarPlate',
  );
}

/// The menu bar's cluster of the kit, in its default order.
List<Widget> menuBarItems() => const [
  AmalfiStatusGlyphItem(
    boxKey: ValueKey('box Bluetooth'),
    symbol: 'bluetooth',
    label: 'Bluetooth',
  ),
  AmalfiStatusGlyphItem(
    boxKey: ValueKey('box Wi-Fi'),
    symbol: 'wifi',
    label: 'Wi-Fi',
  ),
  AmalfiStatusGlyphItem(
    boxKey: ValueKey('box Sound'),
    symbol: 'volume-2',
    label: 'Sound',
  ),
  AmalfiStatusBatteryItem(
    boxKey: ValueKey('box Battery'),
    level: 0.84,
    percentage: '84%',
    label: 'Battery',
  ),
  AmalfiStatusGlyphItem(
    boxKey: ValueKey('box Search'),
    symbol: 'search',
    label: 'Search',
  ),
  AmalfiStatusClockItem(
    boxKey: ValueKey('box Clock'),
    text: 'Fri 16 Oct  09:41',
    label: 'Clock',
  ),
  AmalfiStatusGlyphItem(
    boxKey: ValueKey('box Control Center'),
    symbol: 'control-center',
    label: 'Control Center',
  ),
];

/// The lock screen's cluster of the kit.
List<Widget> lockScreenItems() => const [
  AmalfiStatusInputSourceItem(
    boxKey: ValueKey('box Input Source'),
    source: 'Italian',
    label: 'Input source',
  ),
  AmalfiStatusGlyphItem(
    boxKey: ValueKey('box Wi-Fi'),
    symbol: 'wifi',
    label: 'Wi-Fi',
  ),
  AmalfiStatusBatteryItem(
    boxKey: ValueKey('box Battery'),
    level: 0.84,
    percentage: '84%',
    label: 'Battery',
  ),
];

void main() {
  setUpAll(() async {
    await loadAmalfiFonts();
    RenderedStyle.register(_plate);
  });

  for (final appearance in ['Light', 'Dark']) {
    group('kit $appearance', () {
      testWidgets('Item/Glyph/Rest', (tester) async {
        final master = KitMaster.load('Status Bar/Item/Glyph/Rest/$appearance');
        await pumpKitScene(
          tester,
          const AmalfiStatusGlyphItem(
            boxKey: itemKey,
            symbol: 'wifi',
            label: 'Wi-Fi',
          ),
          master: master,
        );
        expectKitGeometry(
          tester,
          master,
          root: find.byKey(itemKey),
          layers: {'Glyph Status': find.byType(AmalfiSymbol)},
        );
        await expectKitPixels(
          tester,
          master,
          const AmalfiStatusGlyphItem(symbol: 'wifi', label: 'Wi-Fi'),
          origin: const Offset(0, -AmalfiStatusBarMetrics.itemTop),
          maskText: true,
        );
      });

      testWidgets('Item/Glyph/Active', (tester) async {
        final master = KitMaster.load(
          'Status Bar/Item/Glyph/Active/$appearance',
        );
        const item = AmalfiStatusGlyphItem(
          boxKey: itemKey,
          symbol: 'wifi',
          label: 'Wi-Fi',
          active: true,
        );
        await pumpKitScene(tester, item, master: master);
        expectKitGeometry(
          tester,
          master,
          root: find.byKey(itemKey),
          layers: {
            'Active fill': find.descendant(
              of: find.byKey(itemKey),
              matching: find.byType(DecoratedBox),
            ),
            'Glyph Status': find.byType(AmalfiSymbol),
          },
        );
        // The item is 32 tall (the hit area), its box 28 at y 2: the kit's master is the box.
        await expectKitPixels(
          tester,
          master,
          item,
          origin: const Offset(0, -AmalfiStatusBarMetrics.itemTop),
          maskText: true,
        );
      });

      testWidgets('Item/Battery/Rest', (tester) async {
        final master = KitMaster.load(
          'Status Bar/Item/Battery/Rest/$appearance',
        );
        await pumpKitScene(
          tester,
          const AmalfiStatusBatteryItem(
            boxKey: itemKey,
            level: 0.84,
            percentage: '84%',
            label: 'Battery',
          ),
          master: master,
        );
        expectKitGeometry(
          tester,
          master,
          root: find.byKey(itemKey),
          layers: {
            'Percentage': label('84%'),
            'Glyph Status': find.byType(AmalfiSymbol),
          },
        );
        await expectKitPixels(
          tester,
          master,
          const AmalfiStatusBatteryItem(
            level: 0.84,
            percentage: '84%',
            label: 'Battery',
          ),
          origin: const Offset(0, -AmalfiStatusBarMetrics.itemTop),
          maskText: true,
        );
      });

      testWidgets('Item/Input Source/Rest', (tester) async {
        final master = KitMaster.load(
          'Status Bar/Item/Input Source/Rest/$appearance',
        );
        await pumpKitScene(
          tester,
          const AmalfiStatusInputSourceItem(
            boxKey: itemKey,
            source: 'Italian',
            label: 'Input source',
          ),
          master: master,
        );
        expectKitGeometry(
          tester,
          master,
          root: find.byKey(itemKey),
          layers: {
            'Label': label('Italian'),
            'Glyph Status': find.byType(AmalfiSymbol),
          },
        );
        await expectKitPixels(
          tester,
          master,
          const AmalfiStatusInputSourceItem(
            source: 'Italian',
            label: 'Input source',
          ),
          origin: const Offset(0, -AmalfiStatusBarMetrics.itemTop),
          maskText: true,
        );
      });

      testWidgets('Item/Clock/Rest', (tester) async {
        final master = KitMaster.load('Status Bar/Item/Clock/Rest/$appearance');
        await pumpKitScene(
          tester,
          const AmalfiStatusClockItem(
            boxKey: itemKey,
            text: 'Fri 16 Oct  09:41',
            label: 'Clock',
          ),
          master: master,
        );
        expectKitGeometry(
          tester,
          master,
          root: find.byKey(itemKey),
          layers: {'Label': label('Fri 16 Oct  09:41')},
          deviations: clockDeviations,
        );
        // The label is 4 pt narrower (clockReason): compare the item's box without the text.
        await expectKitPixels(
          tester,
          master,
          const AmalfiStatusClockItem(
            text: 'Fri 16 Oct  09:41',
            label: 'Clock',
          ),
          origin: const Offset(0, -AmalfiStatusBarMetrics.itemTop),
          maskText: true,
        );
      });

      for (final (kit, legibility) in const [
        ('Default', AmalfiStatusBarLegibility.standard),
        ('Increase Contrast', AmalfiStatusBarLegibility.increaseContrast),
        ('Reduce Transparency', AmalfiStatusBarLegibility.reduceTransparency),
      ]) {
        testWidgets('Bar/Menu Bar/$kit', (tester) async {
          final master = KitMaster.load(
            'Status Bar/Bar/Menu Bar/$kit/$appearance',
          );
          final bar = AmalfiStatusBar(
            placement: AmalfiStatusBarPlacement.menuBar,
            legibility: legibility,
            items: menuBarItems(),
          );
          final root = await pumpKitScene(tester, bar, master: master);
          expectKitGeometry(
            tester,
            master,
            root: root,
            layers: {
              for (final name in const [
                'Bluetooth',
                'Wi-Fi',
                'Sound',
                'Battery',
                'Search',
                'Clock',
                'Control Center',
              ])
                name: box(name),
              if (legibility != AmalfiStatusBarLegibility.standard)
                'Plate': find.byType(AmalfiStatusBarPlate),
            },
            deviations: {
              '#frame': clockReason,
              'Clock': clockReason,
              'Control Center': clockReason,
              if (legibility != AmalfiStatusBarLegibility.standard)
                'Plate': clockReason,
              if (legibility == AmalfiStatusBarLegibility.increaseContrast)
                'Plate#blurs':
                    'the plate is 95 % opaque: its background blur shows only at the '
                    'antialiased edge and is not drawn (status-bar.md, provisional)',
            },
          );
          // Every item takes the ink of the context: Text/Primary of the appearance.
          final ink = AmalfiColors.of(master.brightness).textPrimary;
          for (final symbol in tester.widgetList<AmalfiSymbol>(
            find.byType(AmalfiSymbol),
          )) {
            expect(symbol.color, ink);
          }
          // The clock is 4 pt narrower than the kit's (clockReason): compare the cluster up
          // to the clock, the items after it are shifted.
          await expectKitPixels(
            tester,
            master,
            bar,
            maskText: true,
            mask: [
              ...plateEnds(master, legibility),
              const Rect.fromLTWH(212, 0, 160, 32),
            ],
          );
        });

        testWidgets('Bar/Lock Screen/$kit', (tester) async {
          final master = KitMaster.load(
            'Status Bar/Bar/Lock Screen/$kit/$appearance',
          );
          final bar = AmalfiStatusBar(
            placement: AmalfiStatusBarPlacement.lockScreen,
            legibility: legibility,
            items: lockScreenItems(),
          );
          final root = await pumpKitScene(tester, bar, master: master);
          expectKitGeometry(
            tester,
            master,
            root: root,
            layers: {
              for (final name in const ['Input Source', 'Wi-Fi', 'Battery'])
                name: box(name),
              if (legibility != AmalfiStatusBarLegibility.standard)
                'Plate': find.byType(AmalfiStatusBarPlate),
            },
            deviations: {
              if (legibility == AmalfiStatusBarLegibility.increaseContrast)
                'Plate#blurs':
                    'the plate is 95 % opaque: its background blur shows only at the '
                    'antialiased edge and is not drawn (status-bar.md, provisional)',
            },
          );
          // On the photo the ink is on-photo white in both appearances, with the on-photo
          // shadow in Light; on a plate it is Text/Primary of the appearance.
          final onPhoto = legibility == AmalfiStatusBarLegibility.standard;
          final ink = onPhoto
              ? AmalfiColors.dark.textPrimary
              : AmalfiColors.of(master.brightness).textPrimary;
          final style = AmalfiStatusBarStyle.of(
            tester.element(find.byType(AmalfiStatusGlyph).first),
          );
          expect(style.ink, ink);
          expect(
            style.shadows,
            onPhoto && master.brightness == Brightness.light
                ? AmalfiShadows.onPhoto
                : isEmpty,
          );
          final percentage = tester.widget<Text>(find.text('84%'));
          expect(percentage.style?.color, ink);
          await expectKitPixels(
            tester,
            master,
            bar,
            maskText: true,
            mask: plateEnds(master, legibility),
          );
        });
      }
    });
  }

  group('behaviour', () {
    testWidgets('the hit area is the whole item over the full bar height', (
      tester,
    ) async {
      var pressed = 0;
      await tester.pumpWidget(
        AmalfiTheme(
          brightness: Brightness.light,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: AmalfiStatusBar(
                placement: AmalfiStatusBarPlacement.menuBar,
                legibility: AmalfiStatusBarLegibility.standard,
                items: [
                  AmalfiStatusGlyphItem(
                    boxKey: itemKey,
                    symbol: 'wifi',
                    label: 'Wi-Fi',
                    onPressed: () => pressed++,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(tester.getSize(find.byType(AmalfiStatusBar)), const Size(36, 32));
      expect(
        tester.getRect(find.byKey(itemKey)),
        const Rect.fromLTWH(0, 2, 36, 28),
      );
      // The screen's top edge (y 0) and the bar's bottom row (y 31) still hit the item.
      await tester.tapAt(const Offset(2, 0));
      await tester.tapAt(const Offset(34, 31));
      expect(pressed, 2);
    });

    testWidgets('Return and Space activate a focused item', (tester) async {
      var pressed = 0;
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(
        AmalfiTheme(
          brightness: Brightness.dark,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: AmalfiStatusBar(
                placement: AmalfiStatusBarPlacement.lockScreen,
                legibility: AmalfiStatusBarLegibility.standard,
                items: [
                  Focus(
                    focusNode: focus,
                    skipTraversal: true,
                    child: AmalfiStatusInputSourceItem(
                      source: 'Italian',
                      label: 'Input source',
                      onPressed: () => pressed++,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      Focus.of(tester.element(find.byType(AmalfiStatusGlyph))).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(pressed, 2);
    });

    testWidgets('an item reads its name, its value and whether it is open', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        AmalfiTheme(
          brightness: Brightness.light,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Align(
              alignment: Alignment.topLeft,
              child: AmalfiStatusBar(
                placement: AmalfiStatusBarPlacement.menuBar,
                legibility: AmalfiStatusBarLegibility.standard,
                items: [
                  AmalfiStatusBatteryItem(
                    level: 0.84,
                    percentage: '84%',
                    label: 'Battery',
                    value: '84 percent',
                    active: true,
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(AmalfiStatusBatteryItem)),
        matchesSemantics(
          label: 'Battery',
          value: '84 percent',
          isButton: true,
          hasExpandedState: true,
          isExpanded: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    test('the battery glyph follows the level', () {
      expect(AmalfiStatusBatteryItem.symbolFor(1), 'battery');
      expect(AmalfiStatusBatteryItem.symbolFor(0.84), 'battery');
      expect(AmalfiStatusBatteryItem.symbolFor(0.5), 'battery-50');
      expect(AmalfiStatusBatteryItem.symbolFor(0.2), 'battery-10');
      expect(AmalfiStatusBatteryItem.symbolFor(0.02), 'battery-0');
      expect(
        AmalfiStatusBatteryItem.symbolFor(0.2, charging: true),
        'battery-charging',
      );
    });

    testWidgets('a wider percentage widens the item to the left', (
      tester,
    ) async {
      Future<Rect> glyphAt(String percentage) async {
        await tester.pumpWidget(
          AmalfiTheme(
            brightness: Brightness.light,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Align(
                alignment: Alignment.topRight,
                child: AmalfiStatusBar(
                  placement: AmalfiStatusBarPlacement.menuBar,
                  legibility: AmalfiStatusBarLegibility.standard,
                  items: [
                    AmalfiStatusBatteryItem(
                      level: 1,
                      percentage: percentage,
                      label: 'Battery',
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        return tester.getRect(find.byType(AmalfiSymbol));
      }

      await ensureAmalfiFonts(tester);
      final narrow = await glyphAt('84%');
      final wide = await glyphAt('100%');
      expect(wide, narrow);
    });

    test('Reduce transparency makes the Active capsule opaque', () {
      for (final b in Brightness.values) {
        final style = AmalfiStatusBarStyle.resolve(
          placement: AmalfiStatusBarPlacement.menuBar,
          legibility: AmalfiStatusBarLegibility.reduceTransparency,
          brightness: b,
        );
        final colors = AmalfiColors.of(b);
        expect(
          style.active,
          b == Brightness.dark
              ? colors.surfaceControl
              : colors.surfaceControlPressed,
        );
        expect(style.active.a, 1);
      }
    });
  });
}
