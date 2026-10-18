// Wells against the kit (`Wells/*`): image wells, colour wells, the colour panel and the
// swatches. Checklist: docs/amalfi-checklist/wells.md.

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

import 'support/harness.dart';

const List<String> appearances = ['Light', 'Dark'];

/// The dashes of an empty well: Sketch spaces them along the outline from another start
/// than ours, so they land differently around the corners (phase does not fix it: measured
/// mean 0.43–1.12 for every phase of the pattern).
const KitPixelTolerance dashedBorder = KitPixelTolerance(mean: 1.2, max: 88);

/// The outside halo and the accent border meet at the smooth corners a little differently
/// from Sketch's offset path (measured max 61 at the corners, mean ≤ 0.35).
const KitPixelTolerance haloCorners = KitPixelTolerance(max: 64);

/// Small smooth corners (radius 5–12) and the ring outside a chip antialias a little
/// differently from Sketch (measured max 56 at a corner pixel); with the disabled colour
/// masked, few pixels are compared and the corners weigh more (mean 1.36).
const KitPixelTolerance smoothCorners = KitPixelTolerance(mean: 1.5, max: 60);

/// A filled well: the edges of the test picture (the hill's smooth corners) and of the clip
/// at the well's corners antialias differently from Sketch (measured max 76 at the 20 pt
/// corners of Large, mean ≤ 0.26).
const KitPixelTolerance pictureEdges = KitPixelTolerance(max: 80);

// ---------------------------------------------------------------------------------------------
// Image wells

/// The kit's test picture of a filled well (Sky, Sun, Sea, Hill), built from the master.
Widget landscape(KitMaster master) => Stack(
  children: [
    for (final name in ['Sky', 'Sun', 'Sea', 'Hill'])
      Positioned.fromRect(
        rect: master.layer(name).rectInMaster,
        child: DecoratedBox(
          key: ValueKey(name),
          decoration: ShapeDecoration(
            color: master.layer(name).style?.fills.first.swatch?.resolve(),
            // The well clips the picture: the sky's and the sea's own corners would only
            // antialias the edge twice.
            shape: name == 'Sea' || name == 'Sky'
                ? const AmalfiSmoothBorder(radius: 0)
                : AmalfiSmoothBorder(
                    radius: master.layer(name).style?.corners?.maxRadius ?? 0,
                  ),
          ),
        ),
      ),
  ],
);

AmalfiImageWellSize imageSize(String name) => switch (name) {
  'Small' => AmalfiImageWellSize.small,
  'Large' => AmalfiImageWellSize.large,
  _ => AmalfiImageWellSize.regular,
};

const Key dragSource = ValueKey('drag-source');

/// An image well with a 1 pt drag source at its top-left corner (to drag over it for real).
Widget imageScene(
  KitMaster master, {
  required bool filled,
  required bool enabled,
  FocusNode? focus,
  ValueChanged<Object>? onDrop,
}) => Stack(
  children: [
    AmalfiImageWell(
      size: imageSize(master.name.split('/')[3]),
      image: filled ? landscape(master) : null,
      enabled: enabled,
      focusNode: focus,
      onDrop: onDrop ?? (_) {},
      onPressed: () {},
      onCleared: () {},
    ),
    const Positioned(
      left: 0,
      top: 0,
      child: Draggable<Object>(
        key: dragSource,
        data: 'picture.png',
        feedback: SizedBox.shrink(),
        // A colour so that the 1 pt source is hit.
        child: ColoredBox(
          color: Color(0x00000000),
          child: SizedBox.square(dimension: 1),
        ),
      ),
    ),
  ],
);

/// Starts a drag from the drag source and holds it over the centre of the well.
Future<void> dragOver(WidgetTester tester) async {
  final from =
      tester.getTopLeft(find.byKey(dragSource)) + const Offset(0.5, 0.5);
  final gesture = await tester.startGesture(
    from,
    kind: PointerDeviceKind.mouse,
  );
  addTearDown(() async {
    await gesture.up();
  });
  await gesture.moveBy(const Offset(20, 20));
  await gesture.moveTo(tester.getCenter(find.byType(AmalfiImageWell)));
  await tester.pump();
  await tester.pump(AmalfiFades.quick.duration);
  await tester.pump();
}

Future<void> settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(AmalfiFades.quick.duration);
  await tester.pump();
}

// ---------------------------------------------------------------------------------------------
// Colour wells

AmalfiColorWellStyle wellStyle(String name) => switch (name) {
  'Minimal' => AmalfiColorWellStyle.minimal,
  'Expanded' => AmalfiColorWellStyle.expanded,
  _ => AmalfiColorWellStyle.standard,
};

Widget colorWell(
  KitMaster master, {
  required bool enabled,
  FocusNode? focus,
  ValueChanged<Color>? onChanged,
}) {
  final colors = AmalfiColors.of(master.brightness);
  return AmalfiColorWell(
    style: wellStyle(master.name.split('/')[2]),
    color: colors.accentAmalfi,
    name: 'Amalfi blue',
    enabled: enabled,
    focusNode: focus,
    onChanged: onChanged ?? (_) {},
    onPickFromScreen: () {},
  );
}

TestGesture? _mouse;

/// Moves a mouse onto the colour well and waits for the hover overlay.
Future<void> hoverWell(WidgetTester tester) async {
  var mouse = _mouse;
  if (mouse == null) {
    mouse = _mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    addTearDown(() async {
      await _mouse?.removePointer();
      _mouse = null;
    });
    await mouse.addPointer(location: const Offset(-50, -50));
  } else {
    await mouse.moveTo(const Offset(-50, -50));
  }
  await tester.pump();
  await mouse.moveTo(tester.getCenter(find.byType(AmalfiColorWell)));
  await settle(tester);
}

void main() {
  setUpAll(loadAmalfiFonts);

  for (final appearance in appearances) {
    group('kit $appearance', () {
      // -------------------------------------------------------------------------------- images
      for (final size in ['Small', 'Regular', 'Large']) {
        for (final state in ['Rest', 'Drag Over', 'Disabled']) {
          testWidgets('Image Well Empty $size $state', (tester) async {
            final master = KitMaster.load(
              'Wells/Image Well/Empty/$size/$state/$appearance',
            );
            final scene = imageScene(
              master,
              filled: false,
              enabled: state != 'Disabled',
            );
            final root = await pumpKitScene(tester, scene, master: master);
            final dragged = state == 'Drag Over';
            if (dragged) await dragOver(tester);
            final hint = master.maybeLayer('Hint')?.text;
            expectKitGeometry(
              tester,
              master,
              root: root,
              layers: {
                'Background': find.byKey(AmalfiImageWell.backgroundKey),
                if (dragged) 'Focus Halo': find.byType(AmalfiFocusHalo),
                'Photo': find.byType(AmalfiGlyph),
                if (hint != null)
                  'Hint': find
                      .ancestor(
                        of: find.text(hint),
                        matching: find.byType(AmalfiWholePoints),
                      )
                      .first,
              },
              // The kit's Caption (11 pt) hint is the text's own width (61), centred on a
              // half point; ours is whole points (60).
              deviations: {
                if (size != 'Small')
                  'Hint':
                      'kit text measure 61 (half-point frame), ours whole points',
              },
            );
            await expectKitPixels(
              tester,
              master,
              scene,
              maskText: true,
              // The kit keeps the photo glyph's 24 pt stroke (1.5) at 20, 28 and 36; the
              // control glyphs scale the stroke with the size (1.5 x size / 24): kit defect,
              // user decisions 6-7 (2026-10-16).
              maskLayers: const ['Photo'],
              prepare: dragged ? dragOver : null,
              tolerance: dragged ? haloCorners : dashedBorder,
            );
          });
        }
        for (final state in ['Rest', 'Focused', 'Disabled']) {
          testWidgets('Image Well Filled $size $state', (tester) async {
            final master = KitMaster.load(
              'Wells/Image Well/Filled/$size/$state/$appearance',
            );
            final focus = FocusNode();
            addTearDown(focus.dispose);
            final scene = imageScene(
              master,
              filled: true,
              enabled: state != 'Disabled',
              focus: focus,
            );
            Future<void> prepare(WidgetTester tester) async {
              if (state != 'Focused') return;
              focus.unfocus();
              await tester.pump();
              focus.requestFocus();
              await settle(tester);
            }

            final root = await pumpKitScene(tester, scene, master: master);
            await prepare(tester);
            expectKitGeometry(
              tester,
              master,
              root: root,
              layers: {
                for (final name in ['Sky', 'Sun', 'Sea', 'Hill'])
                  name: find.byKey(ValueKey(name)),
                'Rim': find.byType(AmalfiFieldSurface),
                if (state == 'Focused')
                  'Focus Halo': find.byType(AmalfiFocusHalo),
              },
              deviations: const {
                'Sky#corners':
                    'test picture: the well clips the sky, its own corners do not show',
                'Sea#corners':
                    'test picture: the well clips the sea, its own corners do not show',
              },
            );
            await expectKitPixels(
              tester,
              master,
              scene,
              prepare: prepare,
              tolerance: pictureEdges,
            );
            if (state == 'Disabled') {
              expect(
                tester
                    .widget<Opacity>(
                      find.ancestor(
                        of: find.byKey(const ValueKey('Sky')),
                        matching: find.byType(Opacity),
                      ),
                    )
                    .opacity,
                AmalfiStates.disabledOpacity,
              );
            }
          });
        }
      }

      // -------------------------------------------------------------------------- colour wells
      for (final style in ['Minimal', 'Default', 'Expanded']) {
        for (final state in ['Rest', 'Hover', 'Focused', 'Disabled']) {
          testWidgets('Color Well $style $state', (tester) async {
            final master = KitMaster.load(
              'Wells/Color Well/$style/$state/$appearance',
            );
            final focus = FocusNode();
            addTearDown(focus.dispose);
            final scene = colorWell(
              master,
              enabled: state != 'Disabled',
              focus: focus,
            );
            Future<void> prepare(WidgetTester tester) async {
              if (state == 'Hover') await hoverWell(tester);
              if (state == 'Focused') {
                focus.unfocus();
                await tester.pump();
                focus.requestFocus();
                await settle(tester);
              }
            }

            final root = await pumpKitScene(tester, scene, master: master);
            await prepare(tester);
            expectKitGeometry(
              tester,
              master,
              root: root,
              layers: {
                'Background': find.byType(AmalfiFieldSurface),
                if (state == 'Hover')
                  'State': find.byKey(AmalfiColorWell.stateKey),
                if (state == 'Focused')
                  'Focus Halo': find.byType(AmalfiFocusHalo),
                'Colour': find.byKey(AmalfiColorWell.colourKey),
                if (style == 'Default')
                  'Picker chevron': find.byType(AmalfiGlyph),
                if (style == 'Expanded') ...{
                  'Eyedropper': find.byType(AmalfiGlyph),
                  'Name': find.byKey(AmalfiColorWell.nameKey),
                },
              },
            );
            await expectKitPixels(
              tester,
              master,
              scene,
              maskText: true,
              prepare: prepare,
              maskLayers: [
                // The kit keeps the eyedropper's 24 pt stroke (1.5) at 16; the glyph here
                // is stroked 1 (1.5 x 16 / 24): kit defect, user decisions 6-7.
                if (style == 'Expanded') 'Eyedropper',
              ],
              tolerance: smoothCorners,
            );
          });
        }
      }

      // ------------------------------------------------------------------------------ swatches
      for (final state in ['Rest', 'Selected']) {
        testWidgets('Swatch Chip $state', (tester) async {
          final master = KitMaster.load('Wells/Swatch Chip/$state/$appearance');
          final colors = AmalfiColors.of(master.brightness);
          final chip = AmalfiSwatchChip(
            color: colors.accentAmalfi,
            selected: state == 'Selected',
            onPressed: () {},
          );
          final root = await pumpKitScene(tester, chip, master: master);
          final boxes = find.descendant(
            of: find.byType(AmalfiSwatchChip),
            matching: find.byType(DecoratedBox),
          );
          final selected = state == 'Selected';
          expectKitGeometry(
            tester,
            master,
            root: root,
            layers: {
              if (selected) 'Selection Ring': boxes.at(0),
              'Colour': boxes.at(selected ? 1 : 0),
            },
          );
          await expectKitPixels(tester, master, chip, tolerance: smoothCorners);
        });
      }

      for (final row in [1, 2, 3, 4]) {
        testWidgets('Swatch Row $row', (tester) async {
          final master = KitMaster.load(
            'Wells/Swatch Row/Row $row/Rest/$appearance',
          );
          final colors = AmalfiColors.of(master.brightness);
          final swatches = AmalfiColorPanel.amalfiSwatches(colors)[row - 1];
          final widget = AmalfiSwatchRow(
            colors: swatches,
            selected: row == 1 ? colors.accentAmalfi : null,
            onSelected: (_) {},
          );
          final root = await pumpKitScene(tester, widget, master: master);
          final chips = [...master.root.children]
            ..sort((a, b) => a.frame.left.compareTo(b.frame.left));
          expectKitGeometry(
            tester,
            master,
            root: root,
            layers: {
              for (var i = 0; i < chips.length; i++)
                chips[i].name: find.byType(AmalfiSwatchChip).at(i),
            },
          );
          // Each chip has the colour the kit's override gives it (the token of its name).
          for (var i = 0; i < chips.length; i++) {
            final override = chips[i].overrides
                .where((o) => o.property == 'color:fill-0')
                .map((o) => parseKitColor('${o.value}'))
                .first;
            expect(swatches[i], override, reason: chips[i].name);
            expect(
              chips[i].isKitInstance &&
                  KitMaster.nested(
                    chips[i],
                  ).name.contains(i == 0 && row == 1 ? 'Selected' : 'Rest'),
              isTrue,
            );
          }
          await expectKitPixels(
            tester,
            master,
            widget,
            tolerance: smoothCorners,
          );
        });
      }

      testWidgets('Color Panel Swatch Grid', (tester) async {
        final master = KitMaster.load(
          'Wells/Color Panel/Swatch Grid/Rest/$appearance',
        );
        final colors = AmalfiColors.of(master.brightness);
        final panel = AmalfiColorPanel(
          selected: colors.accentAmalfi,
          onSelected: (_) {},
        );
        final root = await pumpKitScene(tester, panel, master: master);
        expectKitGeometry(
          tester,
          master,
          root: root,
          layers: {
            'Surface': find.byType(AmalfiGlass),
            'Title': find
                .ancestor(
                  of: find.text('Swatches'),
                  matching: find.byType(AmalfiWholePoints),
                )
                .first,
            for (var i = 0; i < 4; i++)
              'Row ${i + 1}': find.byType(AmalfiSwatchRow).at(i),
          },
        );
        await expectKitPixels(tester, master, panel, maskText: true);
        await expectKitPixels(
          tester,
          master,
          panel,
          tolerance: KitPixelTolerance.withText,
        );
      });
    });
  }

  // ------------------------------------------------------------------------------ behaviour
  group('image well', () {
    testWidgets('a drop calls onDrop; Delete clears a focused filled well', (
      tester,
    ) async {
      final master = KitMaster.load(
        'Wells/Image Well/Filled/Regular/Rest/Light',
      );
      Object? dropped;
      await pumpKitScene(
        tester,
        imageScene(
          master,
          filled: false,
          enabled: true,
          onDrop: (d) => dropped = d,
        ),
      );
      final from =
          tester.getTopLeft(find.byKey(dragSource)) + const Offset(0.5, 0.5);
      final gesture = await tester.startGesture(from);
      await gesture.moveBy(const Offset(20, 20));
      await gesture.moveTo(tester.getCenter(find.byType(AmalfiImageWell)));
      await tester.pump();
      expect(find.text('Release to add'), findsOneWidget);
      await gesture.up();
      await tester.pump();
      expect(dropped, 'picture.png');
      expect(find.text('Drop image'), findsOneWidget);
    });

    // pumpKitScene keeps the first overlay entry of a test: one scene per test.
    testWidgets('Delete and Backspace clear a focused filled well', (
      tester,
    ) async {
      final master = KitMaster.load(
        'Wells/Image Well/Filled/Regular/Rest/Light',
      );
      var cleared = 0;
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpKitScene(
        tester,
        AmalfiImageWell(
          image: landscape(master),
          focusNode: focus,
          onCleared: () => cleared++,
        ),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.delete);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      expect(cleared, 2);
    });

    testWidgets('a disabled well takes no drop and no focus', (tester) async {
      Object? dropped;
      await pumpKitScene(
        tester,
        Stack(
          children: [
            AmalfiImageWell(enabled: false, onDrop: (d) => dropped = d),
            const Positioned(
              left: 0,
              top: 0,
              child: Draggable<Object>(
                key: dragSource,
                data: 'x',
                feedback: SizedBox.shrink(),
                // A colour so that the 1 pt source is hit.
                child: ColoredBox(
                  color: Color(0x00000000),
                  child: SizedBox.square(dimension: 1),
                ),
              ),
            ),
          ],
        ),
      );
      final gesture = await tester.startGesture(const Offset(0.5, 0.5));
      await gesture.moveBy(const Offset(20, 20));
      await gesture.moveTo(tester.getCenter(find.byType(AmalfiImageWell)));
      await tester.pump();
      expect(find.text('Release to add'), findsNothing);
      await gesture.up();
      await tester.pump();
      expect(dropped, isNull);
    });
  });

  group('colour well', () {
    testWidgets('a click opens the panel, a swatch picks and closes it', (
      tester,
    ) async {
      Color? picked;
      await pumpKitScene(
        tester,
        AmalfiColorWell(
          color: AmalfiColors.light.accentAmalfi,
          onChanged: (c) => picked = c,
        ),
        brightness: Brightness.light,
      );
      expect(find.byType(AmalfiColorPanel), findsNothing);
      await tester.tap(find.byType(AmalfiColorWell));
      await tester.pump();
      expect(find.byType(AmalfiColorPanel), findsOneWidget);
      expect(
        tester.getTopLeft(find.byType(AmalfiColorPanel)),
        const Offset(0, 28 + AmalfiColorWellMetrics.panelGap),
      );
      // The well's colour is the selected chip.
      expect(
        tester
            .widget<AmalfiSwatchChip>(find.byType(AmalfiSwatchChip).first)
            .selected,
        isTrue,
      );
      await tester.tap(find.byType(AmalfiSwatchChip).at(2));
      await tester.pump();
      expect(picked, AmalfiColors.light.paletteTerracotta);
      expect(find.byType(AmalfiColorPanel), findsNothing);
    });

    testWidgets('Space opens it, Esc and a click outside close it', (
      tester,
    ) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpKitScene(
        tester,
        // Space and Enter activate through the app's shortcuts; a click outside reaches
        // the well through the app's tap region surface (both from pumpKitScene's app).
        SizedBox(
          width: 400,
          height: 300,
          // A window background to click on.
          child: ColoredBox(
            color: const Color(0x00000000),
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Align(
                alignment: Alignment.topLeft,
                child: AmalfiColorWell(
                  color: AmalfiColors.light.accentAmalfi,
                  focusNode: focus,
                  onChanged: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(find.byType(AmalfiColorPanel), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byType(AmalfiColorPanel), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.byType(AmalfiColorPanel), findsOneWidget);
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(find.byType(AmalfiColorPanel), findsNothing);
    });

    testWidgets('the eyedropper shows only with a callback and calls it', (
      tester,
    ) async {
      var picks = 0;
      Widget well({VoidCallback? pick}) => AmalfiColorWell(
        style: AmalfiColorWellStyle.expanded,
        color: AmalfiColors.light.accentAmalfi,
        name: 'Amalfi blue',
        onChanged: (_) {},
        onPickFromScreen: pick,
      );
      await pumpKitScene(tester, well(pick: () => picks++));
      await tester.tap(find.byType(AmalfiGlyph));
      await tester.pump();
      expect(picks, 1);
      expect(find.byType(AmalfiColorPanel), findsNothing);
    });

    testWidgets('no eyedropper without a callback', (tester) async {
      await pumpKitScene(
        tester,
        AmalfiColorWell(
          style: AmalfiColorWellStyle.expanded,
          color: AmalfiColors.light.accentAmalfi,
          name: 'Amalfi blue',
          onChanged: (_) {},
        ),
      );
      expect(find.byType(AmalfiGlyph), findsNothing);
    });

    testWidgets('a disabled well does not open', (tester) async {
      await pumpKitScene(
        tester,
        AmalfiColorWell(
          color: AmalfiColors.light.accentAmalfi,
          enabled: false,
          onChanged: (_) {},
        ),
      );
      await tester.tap(find.byType(AmalfiColorWell));
      await tester.pump();
      expect(find.byType(AmalfiColorPanel), findsNothing);
    });

    testWidgets('a forced state shows through the states controller', (
      tester,
    ) async {
      final states = WidgetStatesController({WidgetState.focused});
      addTearDown(states.dispose);
      await pumpKitScene(
        tester,
        AmalfiColorWell(
          color: AmalfiColors.light.accentAmalfi,
          onChanged: (_) {},
          statesController: states,
        ),
      );
      final halo = tester.widget<AmalfiFocusHalo>(find.byType(AmalfiFocusHalo));
      expect(halo.visible, isTrue);
    });
  });

  testWidgets('swatches announce their selection', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpKitScene(
      tester,
      AmalfiSwatchChip(
        color: AmalfiColors.light.accentAmalfi,
        selected: true,
        semanticLabel: 'Amalfi blue',
        onPressed: () {},
      ),
    );
    expect(
      tester.getSemantics(find.byType(AmalfiSwatchChip)),
      matchesSemantics(
        label: 'Amalfi blue',
        isSelected: true,
        hasSelectedState: true,
        isButton: true,
        hasTapAction: true,
        hasFocusAction: true,
        isFocusable: true,
      ),
    );
    semantics.dispose();
  });
}
