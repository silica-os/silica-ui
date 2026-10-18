// Tooltips against the kit (`Tooltips/*`): the worked example of the harness
// (test/amalfi/README.md). Checklist: docs/amalfi-checklist/tooltips.md.

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

import 'support/harness.dart';

/// The box of a label: the whole-points box around the text, which decides the layout.
Finder label(String text) => find
    .ancestor(of: find.text(text), matching: find.byType(AmalfiWholePoints))
    .first;

const Key targetKey = ValueKey('target');

/// The scene of `Tooltips/Placement/*`: a target at [target] in an area of [size], with a
/// tooltip region on it. The target stands in for `Buttons/Icon/Round` (the buttons family),
/// which the pixel tests mask out.
Widget placementScene(
  Size size,
  Rect target,
  AmalfiTooltipPlacement placement,
) => SizedBox.fromSize(
  size: size,
  child: Stack(
    children: [
      Positioned.fromRect(
        rect: target,
        child: AmalfiTooltipRegion(
          message: 'Add to favourites',
          placement: placement,
          child: const SizedBox.expand(key: targetKey),
        ),
      ),
    ],
  ),
);

TestGesture? _mouse;

/// Hovers the target and waits until the tooltip is fully shown. The mouse stays for the
/// rest of the test (a pixel test pumps the scene again and hovers it again).
Future<void> hoverTarget(WidgetTester tester) async {
  var mouse = _mouse;
  if (mouse == null) {
    mouse = _mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(() async {
      await _mouse?.removePointer();
      _mouse = null;
    });
    await mouse.addPointer(location: Offset.zero);
  } else {
    await mouse.moveTo(Offset.zero);
  }
  await mouse.moveTo(tester.getCenter(find.byKey(targetKey)));
  await tester.pump(AmalfiDelays.tooltip);
  await tester.pump(AmalfiFades.quick.duration);
  await tester.pump();
}

void main() {
  setUpAll(loadAmalfiFonts);

  for (final appearance in ['Light', 'Dark']) {
    group('kit $appearance', () {
      testWidgets('One Line', (tester) async {
        final master = KitMaster.load(
          'Tooltips/Tooltip/One Line/Rest/$appearance',
        );
        const tooltip = AmalfiTooltip(message: 'Add to favourites');
        final root = await pumpKitScene(tester, tooltip, master: master);
        expectKitGeometry(
          tester,
          master,
          root: root,
          layers: {
            'Surface': find.byType(AmalfiGlass),
            'Label': label('Add to favourites'),
          },
        );
        await expectKitPixels(tester, master, tooltip, maskText: true);
        await expectKitPixels(
          tester,
          master,
          tooltip,
          tolerance: KitPixelTolerance.withText,
        );
      });

      testWidgets('Two Lines', (tester) async {
        final master = KitMaster.load(
          'Tooltips/Tooltip/Two Lines/Rest/$appearance',
        );
        const text =
            'Shows the recipe in a new window so you can keep this one open.';
        const tooltip = AmalfiTooltip(message: text);
        final root = await pumpKitScene(tester, tooltip, master: master);
        expectKitGeometry(
          tester,
          master,
          root: root,
          layers: {'Surface': find.byType(AmalfiGlass), 'Label': label(text)},
        );
        await expectKitPixels(tester, master, tooltip, maskText: true);
        await expectKitPixels(
          tester,
          master,
          tooltip,
          tolerance: KitPixelTolerance.withText,
        );
      });

      testWidgets('Shortcut', (tester) async {
        final master = KitMaster.load(
          'Tooltips/Tooltip/Shortcut/Rest/$appearance',
        );
        const tooltip = AmalfiTooltip(message: 'Duplicate', shortcut: '⌘D');
        final root = await pumpKitScene(tester, tooltip, master: master);
        expectKitGeometry(
          tester,
          master,
          root: root,
          layers: {
            'Surface': find.byType(AmalfiGlass),
            'Label': label('Duplicate'),
            'Shortcut': label('⌘D'),
          },
        );
        expect(tester.getSize(root), const Size(104, 24));
        expect(
          tester.getTopLeft(label('⌘D')) -
              tester.getTopRight(label('Duplicate')),
          const Offset(AmalfiTooltipMetrics.shortcutGap, 0),
        );
        await expectKitPixels(tester, master, tooltip, maskText: true);
        await expectKitPixels(
          tester,
          master,
          tooltip,
          tolerance: KitPixelTolerance.withText,
        );
      });

      for (final (placement, side) in [
        (AmalfiTooltipPlacement.below, 'Below'),
        (AmalfiTooltipPlacement.above, 'Above'),
        (AmalfiTooltipPlacement.leading, 'Leading'),
        (AmalfiTooltipPlacement.trailing, 'Trailing'),
      ]) {
        testWidgets('Placement $side', (tester) async {
          final master = KitMaster.load(
            'Tooltips/Placement/$side/Rest/$appearance',
          );
          final target = master.layer('Target').rectInMaster;
          final scene = placementScene(master.size, target, placement);
          final root = await pumpKitScene(tester, scene, master: master);
          await hoverTarget(tester);
          expectKitGeometry(
            tester,
            master,
            root: root,
            layers: {
              'Target': find.byKey(targetKey),
              'Tooltip': find.byType(AmalfiTooltip),
            },
          );
          await expectKitPixels(
            tester,
            master,
            scene,
            maskText: true,
            maskLayers: ['Target'],
            prepare: hoverTarget,
          );
        });
      }
    });
  }

  group('placement', () {
    const size = Size(116, 24);
    const bounds = Size(400, 300);
    Offset place(
      Rect target,
      AmalfiTooltipPlacement placement, {
      TextDirection direction = TextDirection.ltr,
    }) => amalfiTooltipOffset(
      target: target,
      size: size,
      bounds: bounds,
      placement: placement,
      textDirection: direction,
    );

    test('8 from the target, centred across and floored to the grid', () {
      const target = Rect.fromLTWH(146, 100, 28, 28);
      expect(
        place(target, AmalfiTooltipPlacement.below),
        const Offset(100, 136),
      );
      expect(
        place(target, AmalfiTooltipPlacement.above),
        const Offset(100, 68),
      );
      expect(
        place(target, AmalfiTooltipPlacement.leading),
        const Offset(22, 100),
      );
      expect(
        place(target, AmalfiTooltipPlacement.trailing),
        const Offset(182, 100),
      );
    });

    test('leading and trailing follow the reading direction', () {
      const target = Rect.fromLTWH(146, 100, 28, 28);
      expect(
        place(
          target,
          AmalfiTooltipPlacement.leading,
          direction: TextDirection.rtl,
        ),
        place(target, AmalfiTooltipPlacement.trailing),
      );
    });

    test('flips when there is no room, then stays inside the bounds', () {
      expect(
        place(
          const Rect.fromLTWH(0, 280, 28, 20),
          AmalfiTooltipPlacement.below,
        ),
        const Offset(0, 248),
      );
      expect(
        place(
          const Rect.fromLTWH(380, 0, 20, 28),
          AmalfiTooltipPlacement.above,
        ),
        const Offset(284, 36),
      );
    });
  });

  group('region', () {
    Future<void> pumpTwo(WidgetTester tester) => pumpKitScene(
      tester,
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final name in ['a', 'b'])
            AmalfiTooltipRegion(
              message: 'Tip $name',
              shortcut: name == 'b' ? '⌘B' : null,
              child: SizedBox(key: ValueKey(name), width: 40, height: 28),
            ),
        ],
      ),
    );

    testWidgets('shows after the delay, moves at once, hides on leave and press', (
      tester,
    ) async {
      // Lets a fade run to its end (its ticker starts on the frame after it is started).
      Future<void> fade() async {
        await tester.pump();
        await tester.pump(AmalfiFades.quick.duration * 2);
        await tester.pump();
      }

      Offset centre(String key) => tester.getCenter(find.byKey(ValueKey(key)));

      await pumpTwo(tester);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(300, 300));
      await mouse.moveTo(centre('a'));
      await tester.pump(AmalfiDelays.tooltip - const Duration(milliseconds: 1));
      expect(find.text('Tip a'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      await fade();
      expect(find.text('Tip a'), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(AmalfiTooltip)).dy,
        28 + AmalfiTooltipMetrics.distance,
      );

      // Moving to the neighbour: its tooltip replaces the first one without the delay.
      await mouse.moveTo(centre('b'));
      await fade();
      expect(find.text('Tip a'), findsNothing);
      expect(find.text('Tip b'), findsOneWidget);
      expect(find.text('⌘B'), findsOneWidget);

      // Leaving fades it out.
      await mouse.moveTo(const Offset(300, 300));
      await fade();
      expect(find.text('Tip b'), findsNothing);

      // A press hides it.
      await mouse.moveTo(centre('a'));
      await tester.pump(AmalfiDelays.tooltip);
      await fade();
      expect(find.text('Tip a'), findsOneWidget);
      await mouse.down(centre('a'));
      await fade();
      expect(find.text('Tip a'), findsNothing);
      await mouse.up();
    });

    testWidgets('the message is the hint for screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpTwo(tester);
      expect(
        tester.getSemantics(find.byKey(const ValueKey('a'))),
        matchesSemantics(tooltip: 'Tip a'),
      );
      semantics.dispose();
    });
  });
}
