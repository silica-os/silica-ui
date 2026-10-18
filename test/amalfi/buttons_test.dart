// Buttons against the kit (`Buttons/*`): every master's geometry, the pixels of every master
// (text masked), and the behaviour. Checklist: docs/amalfi-checklist/buttons.md.

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';
import 'package:silica_ui/src/amalfi/components/buttons/button_base.dart';

import 'support/harness.dart';

const states = ['Rest', 'Hover', 'Pressed', 'Disabled', 'Focused'];
const appearances = ['Light', 'Dark'];
const sizes = {
  'Mini': AmalfiControlSize.mini,
  'Small': AmalfiControlSize.small,
  'Regular': AmalfiControlSize.regular,
  'Large': AmalfiControlSize.large,
};

void _noop() {}

// ---------------------------------------------------------------------------------------------
// Pointer and focus.

TestGesture? _mouse;
bool _down = false;

Future<TestGesture> _pointer(WidgetTester tester) async {
  final existing = _mouse;
  if (existing != null) return existing;
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  _mouse = mouse;
  addTearDown(() async {
    if (_down) await _mouse?.up();
    _down = false;
    await _mouse?.removePointer();
    _mouse = null;
  });
  await mouse.addPointer(location: const Offset(-100, -100));
  return mouse;
}

/// Releases the mouse and moves it away from everything.
Future<void> releasePointer(WidgetTester tester) async {
  final mouse = _mouse;
  if (mouse == null) return;
  if (_down) {
    await mouse.up();
    _down = false;
  }
  await mouse.moveTo(const Offset(-100, -100));
  await tester.pump(const Duration(milliseconds: 200));
}

/// Brings the widget at [target] into the kit [state] with real input.
Future<void> enterState(
  WidgetTester tester,
  String state,
  Finder target,
) async {
  switch (state) {
    case 'Hover':
      final mouse = await _pointer(tester);
      await mouse.moveTo(tester.getCenter(target));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    case 'Pressed':
      final mouse = await _pointer(tester);
      await mouse.moveTo(tester.getCenter(target));
      await tester.pump();
      await mouse.down(tester.getCenter(target));
      _down = true;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    case 'Focused':
      final detector = find
          .descendant(
            of: find.descendant(
              of: target,
              matching: find.byType(AmalfiInteraction),
            ),
            matching: find.byType(Listener),
          )
          .first;
      Focus.of(tester.element(detector)).requestFocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
  }
}

// ---------------------------------------------------------------------------------------------
// Finders.

Finder byKey(Key key, [Finder? within]) => within == null
    ? find.byKey(key)
    : find.descendant(of: within, matching: find.byKey(key));

/// The label box: the grid-width box around [text], or the text itself.
Finder labelOf(String text, [Finder? within]) {
  final t = within == null
      ? find.text(text)
      : find.descendant(of: within, matching: find.text(text));
  final box = find.ancestor(of: t, matching: find.byType(AmalfiWholePoints));
  return box.evaluate().isEmpty ? t : box.first;
}

/// Maps the layers of a simple button master to finders of the widget.
Map<String, Finder> layersOf(KitMaster master, String state, Finder within) {
  final map = <String, Finder>{};
  for (final layer in master.root.children) {
    final finder = switch (layer.name) {
      'Background' => byKey(AmalfiButtonLayers.background, within),
      'State' || 'Highlight' => byKey(
        state == 'Hover' ? AmalfiButtonLayers.hover : AmalfiButtonLayers.press,
        within,
      ),
      'Focus Halo' => byKey(AmalfiButtonLayers.halo, within),
      'Label' || 'Help' => labelOf(layer.text ?? '', within),
      _ when layer.type == KitLayerType.symbolInstance => find.descendant(
        of: within,
        matching: find.byType(AmalfiGlyph),
      ),
      _ => null,
    };
    if (finder != null) map[layer.name] = finder;
  }
  return map;
}

/// Turns on the traditional (keyboard) focus highlight for the test.
void keyboardHighlight() {
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  addTearDown(
    () => FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.automatic,
  );
}

/// Geometry and pixels of [master] for [widget] in [state].
Future<void> checkMaster(
  WidgetTester tester,
  String key,
  String state,
  Widget widget, {
  Map<String, String> deviations = const {},
  List<String> maskLayers = const [],
  List<Rect> mask = const [],
  bool pixels = true,
}) async {
  final master = KitMaster.load(key);
  keyboardHighlight();
  final root = await pumpKitScene(tester, widget, master: master);
  await enterState(tester, state, root);
  expectKitGeometry(
    tester,
    master,
    root: root,
    layers: layersOf(master, state, root),
    deviations: deviations,
  );
  await releasePointer(tester);
  if (!pixels) return;
  await kitPixels(
    tester,
    master,
    widget,
    maskText: true,
    maskLayers: maskLayers,
    mask: mask,
    prepare: (tester) => enterState(
      tester,
      state,
      find.byKey(const ValueKey('button-under-test')),
    ),
  );
  await releasePointer(tester);
}

/// The pixel tolerance of the buttons (text masked). Sketch antialiases the edges of the
/// small controls about a quarter point wider than Skia: on the 20 pt capsules, where the edge
/// is a large share of the pixels, single edge pixels reach 83 (Push Mini, measured with kit
/// 747ea80); the mean reaches 1.40 (Gradient Pressed Light). The shapes match exactly: the
/// outlines are the kit's (see `smooth_border.dart`).
const KitPixelTolerance buttonsTolerance = KitPixelTolerance(
  mean: 1.5,
  max: 84,
);

/// The tolerance of the masters that draw a symbol (icon buttons, toolbar buttons, Gradient
/// add/remove, Glass push buttons with a glyph). The kit draws the symbol from the Silica
/// Symbols font in Sketch, which sets its glyphs and strokes slightly differently from Skia:
/// a 16 or 20 pt symbol sits up to a point higher in the kit than centred in its box, and
/// the strokes antialias differently. The frame (box, size, colour, text) is checked exactly.
const KitPixelTolerance buttonsSymbolTolerance = KitPixelTolerance(
  mean: 9,
  max: 255,
);

bool _hasSymbol(String name) =>
    name.startsWith('Buttons/Icon/') ||
    name.startsWith('Buttons/Toolbar/') ||
    name.startsWith('Buttons/Gradient/') ||
    name.startsWith('Buttons/Push/Glass/');

/// [expectKitPixels] with real shadows: flutter_test draws BoxShadows solid
/// (`debugDisableShadows`), the kit blurs them.
Future<KitPixelResult> kitPixels(
  WidgetTester tester,
  KitMaster master,
  Widget widget, {
  bool maskText = false,
  List<String> maskLayers = const [],
  List<Rect> mask = const [],
  Offset? origin,
  Future<void> Function(WidgetTester tester)? prepare,
}) async {
  debugDisableShadows = false;
  try {
    return await expectKitPixels(
      tester,
      master,
      widget,
      tolerance: _hasSymbol(master.name)
          ? buttonsSymbolTolerance
          : buttonsTolerance,
      maskText: maskText,
      maskLayers: maskLayers,
      mask: mask,
      origin: origin,
      prepare: prepare,
    );
  } finally {
    debugDisableShadows = true;
  }
}

/// [child] keyed so that [checkMaster] finds it in the pixel scene.
Widget keyed(Widget child) =>
    KeyedSubtree(key: const ValueKey('button-under-test'), child: child);

// ---------------------------------------------------------------------------------------------

void main() {
  setUpAll(loadAmalfiFonts);

  group('kit Push', () {
    const variants = {
      'Primary': AmalfiPushButtonVariant.primary,
      'Secondary': AmalfiPushButtonVariant.secondary,
      'Destructive': AmalfiPushButtonVariant.destructive,
      'Borderless': AmalfiPushButtonVariant.borderless,
      'Glass': AmalfiPushButtonVariant.glass,
    };
    for (final MapEntry(key: v, value: variant) in variants.entries) {
      for (final MapEntry(key: s, value: size) in sizes.entries) {
        for (final state in states) {
          for (final a in appearances) {
            testWidgets('$v $s $state $a', (tester) async {
              await checkMaster(
                tester,
                'Buttons/Push/$v/$s/$state/$a',
                state,
                keyed(
                  AmalfiPushButton(
                    label: 'Button',
                    variant: variant,
                    size: size,
                    onPressed: state == 'Disabled' ? null : _noop,
                  ),
                ),
              );
            });
          }
        }
      }
    }
  });

  group('kit Icon', () {
    const shapes = {
      'Round': AmalfiIconButtonShape.round,
      'Square': AmalfiIconButtonShape.square,
    };
    for (final MapEntry(key: sh, value: shape) in shapes.entries) {
      for (final MapEntry(key: s, value: size) in sizes.entries) {
        for (final state in states) {
          for (final a in appearances) {
            testWidgets('$sh $s $state $a', (tester) async {
              await checkMaster(
                tester,
                'Buttons/Icon/$sh/$s/$state/$a',
                state,
                keyed(
                  AmalfiIconButton(
                    icon: const AmalfiGlyph(AmalfiGlyphs.plus),
                    semanticLabel: 'Add',
                    shape: shape,
                    size: size,
                    onPressed: state == 'Disabled' ? null : _noop,
                  ),
                ),
              );
            });
          }
        }
      }
    }
  });

  group('kit Help and Link', () {
    for (final state in states) {
      for (final a in appearances) {
        testWidgets('Help $state $a', (tester) async {
          await checkMaster(
            tester,
            'Buttons/Help/$state/$a',
            state,
            keyed(
              AmalfiHelpButton(onPressed: state == 'Disabled' ? null : _noop),
            ),
          );
        });
        testWidgets('Link $state $a', (tester) async {
          await checkMaster(
            tester,
            'Buttons/Link/Link/$state/$a',
            state,
            keyed(
              AmalfiLinkButton(
                label: 'Learn more',
                onPressed: state == 'Disabled' ? null : _noop,
              ),
            ),
          );
        });
      }
    }
  });

  group('kit Toolbar', () {
    for (final state in states) {
      for (final a in appearances) {
        for (final (name, label) in [
          ('Icon', null),
          ('Icon + Label', 'Label'),
          ('Icon Small', null),
        ]) {
          // `Icon Small` (the compact bars' 24 pt button) has Rest and Disabled only.
          if (name == 'Icon Small' && state != 'Rest' && state != 'Disabled') {
            continue;
          }
          testWidgets('$name $state $a', (tester) async {
            await checkMaster(
              tester,
              'Buttons/Toolbar/$name/$state/$a',
              state,
              keyed(
                AmalfiToolbarButton(
                  small: name == 'Icon Small',
                  icon: const AmalfiGlyph(AmalfiGlyphs.gear),
                  label: label,
                  semanticLabel: 'Settings',
                  onPressed: state == 'Disabled' ? null : _noop,
                ),
              ),
            );
          });
        }
      }
    }
  });

  group('kit Gradient', () {
    for (final state in states) {
      for (final a in appearances) {
        testWidgets('Add Remove $state $a', (tester) async {
          final master = KitMaster.load(
            'Buttons/Gradient/Add Remove/$state/$a',
          );
          keyboardHighlight();
          final enabled = state != 'Disabled';
          final widget = keyed(
            AmalfiGradientButtons(
              onAdd: enabled ? _noop : null,
              onRemove: enabled ? _noop : null,
            ),
          );
          final root = await pumpKitScene(tester, widget, master: master);
          final add = find.byKey(AmalfiGradientButtons.addKey);
          final remove = find.byKey(AmalfiGradientButtons.removeKey);
          await enterState(tester, state, add);
          // Each half is a button of its own: the hover overlay, the pressed fill and the
          // focus halo cover the "+" half (28 × 24, outer corners rounded), where the kit
          // draws them over the whole control.
          const half = 'per-half state (each half is its own button)';
          expectKitGeometry(
            tester,
            master,
            root: root,
            layers: {
              'Background': find.byKey(AmalfiButtonLayers.background).first,
              'Divider': find.byKey(AmalfiGradientButtons.dividerKey),
              'Glyph Plus': find.descendant(
                of: add,
                matching: find.byType(AmalfiGlyph),
              ),
              'Glyph Minus': find.descendant(
                of: remove,
                matching: find.byType(AmalfiGlyph),
              ),
              if (state == 'Hover')
                'State': byKey(AmalfiButtonLayers.hover, add),
              if (state == 'Focused')
                'Focus Halo': byKey(AmalfiButtonLayers.halo, add),
            },
            deviations: switch (state) {
              'Hover' => {'State': half, 'State#corners': half},
              'Pressed' => {'Background#fills': half},
              'Focused' => {'Focus Halo': half, 'Focus Halo#corners': half},
              _ => const {},
            },
          );
          if (state == 'Pressed') {
            expect(
              tester.getRect(byKey(AmalfiButtonLayers.press, add)),
              const Rect.fromLTWH(1, 1, 26, 22),
            );
          }
          await releasePointer(tester);
          // Pixels: the "+" half matches the kit; the "−" half shows the rest look.
          await kitPixels(
            tester,
            master,
            widget,
            mask: [
              if (state != 'Rest' && state != 'Disabled')
                const Rect.fromLTWH(28, -4, 32, 32),
            ],
            prepare: (tester) => enterState(
              tester,
              state,
              find.byKey(AmalfiGradientButtons.addKey),
            ),
          );
          await releasePointer(tester);
        });
      }
    }
  });

  group('kit Pop-up and Pull-down', () {
    for (final (kind, label) in [
      ('Pop-up', 'Lemon'),
      ('Pull-down', 'Actions'),
    ]) {
      for (final MapEntry(key: s, value: size) in sizes.entries) {
        for (final state in states) {
          for (final a in appearances) {
            testWidgets('$kind $s $state $a', (tester) async {
              final enabled = state != 'Disabled';
              final Widget button = kind == 'Pop-up'
                  ? AmalfiPopUpButton<String>(
                      items: const [
                        AmalfiPopUpItem(value: 'Lemon', label: 'Lemon'),
                        AmalfiPopUpItem(value: 'Orange', label: 'Orange'),
                      ],
                      value: 'Lemon',
                      size: size,
                      onChanged: enabled ? (_) {} : null,
                    )
                  : AmalfiPullDownButton(
                      label: label,
                      size: size,
                      items: [
                        AmalfiPullDownItem(
                          label: 'New window',
                          onSelected: enabled ? _noop : null,
                        ),
                      ],
                    );
              // Pressing opens the menu; the kit's Pressed master is the button alone.
              // Kit defect (user decision 7, 2026-10-16): the pop-up chevron keeps the
              // 24 pt stroke (1.5) at every size; the glyph rule scales it (1 at 16).
              final maskChevron = kind == 'Pop-up';
              await checkMaster(
                tester,
                'Buttons/$kind/$s/$state/$a',
                state,
                keyed(button),
                maskLayers: maskChevron ? const ['Chevron'] : const [],
              );
            });
          }
        }
      }
      for (final a in appearances) {
        // The Open masters place the menu by the measured rules (menu_placement_test.dart):
        // pop-up 136 x 104, button (12, 26), menu (0, 0) with "Lemon" over the button;
        // pull-down 129 x 135, button (5, 0), menu (31 below the top) 120 wide.
        testWidgets('$kind Open $a', (tester) async {
          final master = KitMaster.load('Buttons/$kind/Open/Rest/$a');
          final popUp = kind == 'Pop-up';
          final button = popUp
              ? AmalfiPopUpButton<String>(
                  items: const [
                    AmalfiPopUpItem(value: 'Orange', label: 'Orange'),
                    AmalfiPopUpItem(value: 'Lemon', label: 'Lemon'),
                    AmalfiPopUpItem(value: 'Olive', label: 'Olive'),
                    AmalfiPopUpItem(value: 'Fig', label: 'Fig'),
                  ],
                  value: 'Lemon',
                  onChanged: (_) {},
                )
              : AmalfiPullDownButton(
                  label: 'Actions',
                  items: [
                    for (final l in [
                      'New window',
                      'Duplicate',
                      'Rename',
                      'Delete',
                    ])
                      AmalfiPullDownItem(label: l, onSelected: _noop),
                  ],
                );
          final widget = keyed(
            SizedBox(
              width: popUp ? 136 : 129,
              height: popUp ? 104 : 135,
              child: Stack(
                children: [
                  Positioned(
                    left: popUp ? 12 : 5,
                    top: popUp ? 26 : 0,
                    width: 124,
                    child: button,
                  ),
                ],
              ),
            ),
          );
          // The geometry scene is 20 pt from the view's edge, so that the 6 pt screen margin
          // does not move the menu (the pixel scene has the master's own margin).
          final inView = Padding(
            padding: const EdgeInsets.all(20),
            child: widget,
          );
          Future<void> open(WidgetTester tester) async {
            final mouse = await _pointer(tester);
            final target = find.byType(
              popUp ? AmalfiPopUpButton<String> : AmalfiPullDownButton,
            );
            await mouse.moveTo(tester.getCenter(target));
            await mouse.down(tester.getCenter(target));
            await mouse.up();
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 200));
            if (popUp) {
              // The kit highlights "Olive", under the pointer (the menu opens on the
              // checked "Lemon").
              await mouse.moveTo(
                tester.getTopLeft(find.byType(AmalfiMenu)) +
                    const Offset(100, 4 + 2 * 24 + 12),
              );
              await tester.pump();
            } else {
              // Nothing highlighted, as in the kit: the pointer leaves the button sideways.
              await mouse.moveTo(const Offset(180, 14));
              await tester.pump();
            }
          }

          await pumpKitScene(tester, inView, master: master);
          final root = find.byKey(const ValueKey('button-under-test'));
          await open(tester);
          expectKitGeometry(
            tester,
            master,
            root: root,
            layers: {
              'Button': find.byType(
                popUp ? AmalfiPopUpButton<String> : AmalfiPullDownButton,
              ),
              'Menu': find.byType(AmalfiMenu),
            },
          );
          await kitPixels(
            tester,
            master,
            widget,
            maskText: true,
            // The renderBounds estimate scales the menu's shadow with the menu's resize
            // (120 of 200 wide); the PNG has the full 32 pt blur left of the menu.
            origin: popUp ? null : const Offset(32, 1),
            mask: [
              // Kit defect (user decision 7): the pop-up chevron keeps the 24 pt stroke.
              if (popUp) const Rect.fromLTWH(100, 6, 16, 16),
              // Kit defect: the pull-down's second row keeps the nested menu's checkmark
              // (its override names "Lemon", checked, instead of "Duplicate").
              if (!popUp) const Rect.fromLTWH(8, 60, 16, 16),
            ],
            prepare: open,
          );
          await releasePointer(tester);
        });
      }
    }
  });

  group('behaviour', () {
    testWidgets('a click and Space / Return activate; disabled does nothing', (
      tester,
    ) async {
      var presses = 0;
      final node = FocusNode();
      addTearDown(node.dispose);
      await pumpKitScene(
        tester,
        AmalfiPushButton(
          label: 'OK',
          variant: AmalfiPushButtonVariant.primary,
          focusNode: node,
          onPressed: () => presses++,
        ),
      );
      await tester.tap(find.byType(AmalfiPushButton));
      expect(presses, 1);
      // A click does not take the keyboard focus.
      expect(node.hasFocus, isFalse);
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      expect(presses, 3);

      await pumpKitScene(
        tester,
        const AmalfiPushButton(label: 'OK', onPressed: null),
      );
      await tester.tap(find.byType(AmalfiPushButton), warnIfMissed: false);
      expect(presses, 3);
    });

    testWidgets('a stretched push button keeps its label (and icon) centred', (
      tester,
    ) async {
      await pumpKitScene(
        tester,
        const SizedBox(
          width: 300,
          child: AmalfiPushButton(label: 'Button', onPressed: _noop),
        ),
      );
      expect(tester.getSize(find.byType(AmalfiPushButton)).width, 300);
      final label = tester.getRect(find.text('Button'));
      final button = tester.getRect(find.byType(AmalfiPushButton));
      // The text frame is the label rounded up to the 8 pt grid, centred in the button.
      expect(label.center.dx, closeTo(button.center.dx, 0.5));
      expect(label.center.dy, closeTo(button.center.dy, 0.5));
    });

    testWidgets('the halo shows for keyboard focus only', (tester) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await pumpKitScene(
        tester,
        AmalfiIconButton(
          icon: const AmalfiGlyph(AmalfiGlyphs.plus),
          semanticLabel: 'Add',
          focusNode: node,
          onPressed: _noop,
        ),
      );
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTouch;
      node.requestFocus();
      await tester.pump();
      expect(find.byKey(AmalfiButtonLayers.halo), findsNothing);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.alwaysTraditional;
      await tester.pump();
      expect(find.byKey(AmalfiButtonLayers.halo), findsOneWidget);
      FocusManager.instance.highlightStrategy =
          FocusHighlightStrategy.automatic;
    });

    testWidgets('hover fades in with fade.quick and out in 60 ms', (
      tester,
    ) async {
      await pumpKitScene(
        tester,
        const AmalfiPushButton(label: 'Button', onPressed: _noop),
      );
      final mouse = await _pointer(tester);
      await mouse.moveTo(tester.getCenter(find.byType(AmalfiPushButton)));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 75));
      final half = tester.widget<Opacity>(
        find.ancestor(
          of: find.byKey(AmalfiButtonLayers.hover),
          matching: find.byType(Opacity),
        ),
      );
      expect(half.opacity, inExclusiveRange(0, 1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(
        find.ancestor(
          of: find.byKey(AmalfiButtonLayers.hover),
          matching: find.byType(Opacity),
        ),
        findsNothing,
      );
      await mouse.moveTo(const Offset(-100, -100));
      await tester.pump();
      await tester.pump(amalfiButtonFadeOut);
      await tester.pump();
      expect(find.byKey(AmalfiButtonLayers.hover), findsNothing);
    });

    testWidgets('semantics: a button with its label, enabled or not', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await pumpKitScene(
        tester,
        const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AmalfiPushButton(label: 'Save', onPressed: _noop),
            AmalfiLinkButton(label: 'Learn more', onPressed: null),
            AmalfiIconButton(
              icon: AmalfiGlyph(AmalfiGlyphs.plus),
              semanticLabel: 'Add',
              onPressed: _noop,
            ),
          ],
        ),
      );
      expect(
        tester.getSemantics(find.byType(AmalfiPushButton)),
        isSemantics(
          label: 'Save',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      expect(
        tester.getSemantics(find.byType(AmalfiLinkButton)),
        isSemantics(label: 'Learn more', isButton: true, hasEnabledState: true),
      );
      expect(
        tester.getSemantics(find.byType(AmalfiIconButton)),
        isSemantics(
          label: 'Add',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          isFocusable: true,
          hasTapAction: true,
          hasFocusAction: true,
        ),
      );
      handle.dispose();
    });

    testWidgets('gradient halves act on their own', (tester) async {
      var added = 0, removed = 0;
      await pumpKitScene(
        tester,
        AmalfiGradientButtons(onAdd: () => added++, onRemove: () => removed++),
      );
      await tester.tap(find.byKey(AmalfiGradientButtons.addKey));
      await tester.tap(find.byKey(AmalfiGradientButtons.removeKey));
      await tester.tap(find.byKey(AmalfiGradientButtons.removeKey));
      expect((added, removed), (1, 2));
      await pumpKitScene(
        tester,
        AmalfiGradientButtons(onAdd: () => added++, onRemove: null),
      );
      await tester.tap(
        find.byKey(AmalfiGradientButtons.removeKey),
        warnIfMissed: false,
      );
      expect(removed, 2);
    });

    testWidgets('pop-up: click opens, click on an item chooses and closes', (
      tester,
    ) async {
      String? chosen;
      await pumpKitScene(
        tester,
        Padding(
          padding: const EdgeInsets.all(100),
          child: AmalfiPopUpButton<int>(
            items: const [
              AmalfiPopUpItem(value: 1, label: 'One'),
              AmalfiPopUpItem(value: 2, label: 'Two'),
              AmalfiPopUpItem(value: 3, label: 'Three', enabled: false),
            ],
            value: 1,
            onChanged: (v) => chosen = '$v',
          ),
        ),
      );
      expect(find.text('One'), findsOneWidget);
      await tester.tap(find.byType(AmalfiPopUpButton<int>));
      await tester.pumpAndSettle();
      expect(find.byType(AmalfiMenu), findsOneWidget);
      // The current value is checked.
      expect(find.byType(AmalfiGlyph), findsNWidgets(2));
      await tester.tap(find.text('Three'));
      await tester.pump(AmalfiMenuMetrics.chooseClose);
      await tester.pumpAndSettle();
      expect(chosen, isNull);
      expect(find.byType(AmalfiMenu), findsOneWidget);
      await tester.tap(find.text('Two'));
      // The menu blinks the item, chooses it at +150 ms, then fades out.
      await tester.pump(const Duration(milliseconds: 136));
      expect(chosen, isNull);
      await tester.pump(const Duration(milliseconds: 14));
      expect(chosen, '2');
      await tester.pumpAndSettle();
      expect(find.byType(AmalfiMenu), findsNothing);
    });

    testWidgets(
      'pop-up: keyboard opens, arrows move, Return chooses, Escape closes',
      (tester) async {
        int? chosen;
        final node = FocusNode();
        addTearDown(node.dispose);
        await pumpKitScene(
          tester,
          AmalfiPopUpButton<int>(
            items: const [
              AmalfiPopUpItem(value: 1, label: 'One'),
              AmalfiPopUpItem(value: 2, label: 'Two'),
            ],
            value: 1,
            focusNode: node,
            onChanged: (v) => chosen = v,
          ),
        );
        node.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.space);
        await tester.pumpAndSettle();
        expect(find.byType(AmalfiMenu), findsOneWidget);
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        await tester.pump();
        expect(find.byType(AmalfiMenu), findsNothing);
        expect(chosen, isNull);
        node.requestFocus();
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump(AmalfiMenuMetrics.chooseClose);
        await tester.pumpAndSettle();
        expect(chosen, 2);
        expect(find.byType(AmalfiMenu), findsNothing);
      },
    );

    testWidgets('pull-down: an item runs its command; a click outside closes', (
      tester,
    ) async {
      var duplicated = 0;
      // pumpKitScene's app reports clicks outside the menu (its tap region surface).
      await pumpKitScene(
        tester,
        Padding(
          padding: const EdgeInsets.all(40),
          child: AmalfiPullDownButton(
            label: 'Actions',
            items: [
              AmalfiPullDownItem(
                label: 'Duplicate',
                onSelected: () => duplicated++,
              ),
              const AmalfiPullDownItem(label: 'Delete'),
            ],
          ),
        ),
      );
      await tester.tap(find.byType(AmalfiPullDownButton));
      await tester.pumpAndSettle();
      await tester.tapAt(const Offset(700, 500));
      await tester.pumpAndSettle();
      expect(find.byType(AmalfiMenu), findsNothing);
      await tester.tap(find.byType(AmalfiPullDownButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Delete'));
      await tester.pump(AmalfiMenuMetrics.chooseClose);
      await tester.pumpAndSettle();
      // A disabled item does nothing; the menu stays.
      expect(find.byType(AmalfiMenu), findsOneWidget);
      await tester.tap(find.text('Duplicate'));
      await tester.pump(AmalfiMenuMetrics.chooseClose);
      await tester.pumpAndSettle();
      expect(duplicated, 1);
      expect(find.byType(AmalfiMenu), findsNothing);
    });

    testWidgets('AmalfiButtonPreview forces a look without input', (
      tester,
    ) async {
      for (final (state, key) in [
        (AmalfiButtonPreviewState.hover, AmalfiButtonLayers.hover),
        (AmalfiButtonPreviewState.pressed, AmalfiButtonLayers.press),
        (AmalfiButtonPreviewState.focused, AmalfiButtonLayers.halo),
      ]) {
        await pumpKitScene(
          tester,
          AmalfiButtonPreview(
            state: state,
            child: const AmalfiPushButton(
              label: 'Button',
              variant: AmalfiPushButtonVariant.destructive,
              onPressed: _noop,
            ),
          ),
        );
        expect(find.byKey(key), findsOneWidget, reason: '$state');
      }
      // A disabled button keeps its disabled look.
      await pumpKitScene(
        tester,
        const AmalfiButtonPreview(
          state: AmalfiButtonPreviewState.focused,
          child: AmalfiPushButton(label: 'Button', onPressed: null),
        ),
      );
      expect(find.byKey(AmalfiButtonLayers.halo), findsNothing);
    });

    testWidgets('odd constraints do not throw', (tester) async {
      for (final w in <Widget>[
        const AmalfiPushButton(
          label: 'A very long label indeed',
          onPressed: _noop,
        ),
        AmalfiPopUpButton<int>(
          items: const [AmalfiPopUpItem(value: 1, label: 'A long, long label')],
          value: 1,
          onChanged: (_) {},
        ),
        const AmalfiToolbarButton(
          icon: AmalfiGlyph(AmalfiGlyphs.plus),
          label: 'A long label',
          onPressed: _noop,
        ),
      ]) {
        await pumpKitScene(tester, SizedBox(width: 30, height: 10, child: w));
        expect(tester.takeException(), isNull);
        await pumpKitScene(tester, SizedBox.shrink(child: w));
        expect(tester.takeException(), isNull);
      }
    });

    testWidgets('pull-down entries: sections, dividers and checked items', (
      tester,
    ) async {
      var chosen = '';
      await pumpKitScene(
        tester,
        Padding(
          padding: const EdgeInsets.all(40),
          child: AmalfiPullDownButton.entries(
            label: 'Options',
            entries: [
              const AmalfiMenuSection('Save to'),
              AmalfiMenuAction(
                'Desktop',
                checked: true,
                onSelected: () => chosen = 'Desktop',
              ),
              const AmalfiMenuDivider(),
              AmalfiMenuAction('Clipboard', onSelected: () => chosen = 'Clip'),
            ],
          ),
        ),
      );
      await tester.tap(find.byType(AmalfiPullDownButton));
      await tester.pumpAndSettle();
      expect(find.text('Save to'), findsOneWidget);
      final menu = tester.widget<AmalfiMenu>(find.byType(AmalfiMenu));
      expect(menu.entries.whereType<AmalfiMenuDivider>(), hasLength(1));
      expect(menu.entries.whereType<AmalfiMenuAction>().first.checked, isTrue);
      await tester.tap(find.text('Clipboard'));
      await tester.pump(AmalfiMenuMetrics.chooseClose);
      await tester.pumpAndSettle();
      expect(chosen, 'Clip');
      expect(find.byType(AmalfiMenu), findsNothing);
    });

    testWidgets('pull-down entries without a selectable action is disabled', (
      tester,
    ) async {
      await pumpKitScene(
        tester,
        const AmalfiPullDownButton.entries(
          label: 'Options',
          entries: [AmalfiMenuSection('Only a header')],
        ),
      );
      await tester.tap(find.byType(AmalfiPullDownButton));
      await tester.pumpAndSettle();
      expect(find.byType(AmalfiMenu), findsNothing);
    });

    for (final popUp in [true, false]) {
      testWidgets(
        '${popUp ? 'pop-up' : 'pull-down'} menu follows the compositor backend',
        (tester) async {
          GlassRegistry.instance.regions; // touched to fail early if unexported
          await pumpKitScene(
            tester,
            AmalfiGlassBackendScope(
              backend: AmalfiGlassBackend.compositor,
              child: Padding(
                padding: const EdgeInsets.all(40),
                child: popUp
                    ? AmalfiPopUpButton<int>(
                        items: const [AmalfiPopUpItem(value: 1, label: 'One')],
                        value: 1,
                        onChanged: (_) {},
                      )
                    : AmalfiPullDownButton(
                        label: 'Go',
                        items: [
                          AmalfiPullDownItem(label: 'One', onSelected: () {}),
                        ],
                      ),
              ),
            ),
          );
          await tester.tap(
            find.byType(AmalfiPopUpButton<int>).evaluate().isEmpty
                ? find.byType(AmalfiPullDownButton)
                : find.byType(AmalfiPopUpButton<int>),
          );
          await tester.pumpAndSettle();
          expect(
            GlassRegistry.instance.regions.map((r) => r['profile']),
            contains('menu'),
          );
        },
      );
    }
  });
}
