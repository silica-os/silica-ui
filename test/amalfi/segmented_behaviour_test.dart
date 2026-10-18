// Segmented controls: behaviour (pointer, lens, keyboard, semantics, layout edge cases).
// The kit comparisons are in segmented_test.dart.

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

import 'support/harness.dart';

Finder byKey(String key) => find.byKey(ValueKey(key));

/// Reads the colour an icon segment receives.
class ProbeGlyph extends StatelessWidget {
  const ProbeGlyph(this.name, {super.key});

  final String name;

  static final Map<String, Color?> colors = {};

  @override
  Widget build(BuildContext context) {
    colors[name] = IconTheme.of(context).color;
    return const SizedBox.expand();
  }
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// A select-one control kept in a [StatefulBuilder], with the changes recorded.
Widget selectOne(
  List<Set<int>> changes, {
  Set<int> initial = const {0},
  int count = 3,
  AmalfiSegmentedSelection selection = AmalfiSegmentedSelection.one,
  bool enabledLast = true,
  TextDirection direction = TextDirection.ltr,
  FocusNode? focusNode,
}) {
  var selected = initial;
  return Directionality(
    textDirection: direction,
    child: StatefulBuilder(
      builder: (context, setState) => AmalfiSegmentedControl(
        segments: [
          for (var i = 0; i < count; i++)
            AmalfiSegment.text(
              'Item $i',
              enabled: enabledLast || i < count - 1,
            ),
        ],
        selected: selected,
        selection: selection,
        focusNode: focusNode,
        onChanged: (s) {
          changes.add(s);
          setState(() => selected = s);
        },
      ),
    ),
  );
}

void main() {
  setUpAll(loadAmalfiFonts);

  group('action segments', () {
    Widget capsule(
      List<int> pressed, {
      Set<int> selected = const {},
      bool active = true,
      bool enabledLast = true,
    }) => AmalfiActionSegments(
      size: AmalfiControlSize.regular,
      selected: selected,
      active: active,
      segments: [
        for (var i = 0; i < 3; i++)
          AmalfiSegment.icon(
            ProbeGlyph('g$i'),
            semanticLabel: 'Action $i',
            enabled: enabledLast || i < 2,
          ),
      ],
      onPressed: pressed.add,
    );

    testWidgets('fires on release over the pressed segment only', (
      tester,
    ) async {
      final pressed = <int>[];
      await pumpKitScene(tester, capsule(pressed));
      final first = tester.getCenter(byKey('amalfi-segment-glyph-0'));
      final second = tester.getCenter(byKey('amalfi-segment-glyph-1'));
      await tester.tapAt(first);
      expect(pressed, [0]);

      // Pressed, then released on another segment: nothing.
      final gesture = await tester.startGesture(first);
      await tester.pump();
      await gesture.moveTo(second);
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(pressed, [0]);
    });

    testWidgets('a disabled segment does not fire and is dimmed to 35 %', (
      tester,
    ) async {
      final pressed = <int>[];
      await pumpKitScene(tester, capsule(pressed, enabledLast: false));
      await tester.tapAt(tester.getCenter(byKey('amalfi-segment-glyph-2')));
      expect(pressed, isEmpty);
      final colors = AmalfiColors.light;
      expect(ProbeGlyph.colors['g0'], colors.textPrimary);
      expect(ProbeGlyph.colors['g2'], colors.textPrimary);
      double opacityOf(String key) => tester
          .widgetList<Opacity>(
            find.ancestor(of: byKey(key), matching: find.byType(Opacity)),
          )
          .fold(1.0, (o, w) => o * w.opacity);
      expect(opacityOf('amalfi-segment-glyph-0'), 1);
      expect(opacityOf('amalfi-segment-glyph-2'), AmalfiStates.disabledOpacity);
    });

    testWidgets('a disabled capsule dims as a whole and does not fire', (
      tester,
    ) async {
      await pumpKitScene(
        tester,
        const AmalfiActionSegments(
          segments: [
            AmalfiSegment.text('Back'),
            AmalfiSegment.text('Next', enabled: false),
          ],
        ),
      );
      final opacities = tester
          .widgetList<Opacity>(
            find.ancestor(
              of: byKey('amalfi-segment-label-1'),
              matching: find.byType(Opacity),
            ),
          )
          .map((o) => o.opacity);
      // Once, not again for the disabled segment.
      expect(opacities, [AmalfiStates.disabledOpacity]);
    });

    testWidgets('selected glyphs are accent, inactive windows tertiary', (
      tester,
    ) async {
      await pumpKitScene(tester, capsule([], selected: {1}));
      expect(ProbeGlyph.colors['g1'], AmalfiColors.light.accentAmalfi);
    });

    testWidgets('an inactive window draws every segment tertiary', (
      tester,
    ) async {
      await pumpKitScene(tester, capsule([], active: false));
      expect(ProbeGlyph.colors['g0'], AmalfiColors.light.textTertiary);
    });

    testWidgets('the arrows move the focus, Space presses', (tester) async {
      final pressed = <int>[];
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpKitScene(
        tester,
        AmalfiActionSegments(
          focusNode: focus,
          segments: const [
            AmalfiSegment.text('Back'),
            AmalfiSegment.text('Next'),
          ],
          onPressed: pressed.add,
        ),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(pressed, [0, 1, 1]);
    });

    testWidgets('segments are buttons for screen readers', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpKitScene(tester, capsule([], selected: {0}));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Action 0')),
        matchesSemantics(
          label: 'Action 0',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
          isSelected: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });

    testWidgets('text segments grow to a long label, on the grid', (
      tester,
    ) async {
      await pumpKitScene(
        tester,
        const AmalfiActionSegments(
          size: AmalfiControlSize.regular,
          segments: [
            AmalfiSegment.text('Back'),
            AmalfiSegment.text('A much longer label'),
          ],
        ),
      );
      final size = tester.getSize(find.byType(AmalfiActionSegments));
      expect(size.height, 28);
      expect(size.width % 8, 0);
      expect(size.width, greaterThan(104));
    });
  });

  group('segmented control', () {
    testWidgets('a click chooses the item; the thumb slides there', (
      tester,
    ) async {
      final changes = <Set<int>>[];
      await pumpKitScene(tester, selectOne(changes));
      await tester.tapAt(tester.getCenter(byKey('amalfi-segmented-item-2')));
      await settle(tester);
      expect(changes, [
        {2},
      ]);
      expect(
        tester.getRect(byKey('amalfi-segmented-thumb')),
        tester.getRect(byKey('amalfi-segmented-item-2')),
      );
      expect(find.byType(AmalfiSegmentLens), findsNothing);
    });

    testWidgets(
      'the lens grows over the pressed item and follows the pointer',
      (tester) async {
        final changes = <Set<int>>[];
        await pumpKitScene(tester, selectOne(changes));
        final item1 = tester.getRect(byKey('amalfi-segmented-item-1'));
        final gesture = await tester.startGesture(item1.center);
        await settle(tester);
        // 8 beyond the item sideways and beyond the track above and below.
        expect(
          tester.getRect(find.byType(AmalfiSegmentLens)),
          Rect.fromLTRB(item1.left - 8, -8, item1.right + 8, 28 + 8.0),
        );
        // The selection stays until the release.
        expect(
          tester.getRect(byKey('amalfi-segmented-thumb')),
          tester.getRect(byKey('amalfi-segmented-item-0')),
        );
        // 1:1 while dragging.
        await gesture.moveBy(const Offset(30, 0));
        await tester.pump();
        expect(
          tester.getRect(find.byType(AmalfiSegmentLens)).center.dx,
          item1.center.dx + 30,
        );
        // Released over the third item: chosen; the lens settles and fades.
        final item2 = tester.getRect(byKey('amalfi-segmented-item-2'));
        await gesture.moveTo(item2.center);
        await gesture.up();
        await tester.pump();
        expect(changes, [
          {2},
        ]);
        await settle(tester);
        expect(find.byType(AmalfiSegmentLens), findsNothing);
      },
    );

    testWidgets('the lens stays on the track and the content is magnified', (
      tester,
    ) async {
      await pumpKitScene(tester, selectOne([]));
      final item0 = tester.getRect(byKey('amalfi-segmented-item-0'));
      final item2 = tester.getRect(byKey('amalfi-segmented-item-2'));
      final gesture = await tester.startGesture(item0.center);
      await settle(tester);
      await gesture.moveBy(const Offset(1000, 0));
      await tester.pump();
      expect(
        tester.getRect(find.byType(AmalfiSegmentLens)).center.dx,
        item2.center.dx,
      );
      final scales = tester
          .widgetList<AmalfiSegmentItem>(find.byType(AmalfiSegmentItem))
          .map((i) => i.magnification)
          .toList();
      expect(scales.last, closeTo(1.1, 1e-9));
      expect(scales.first, 1);
      await gesture.cancel();
      await settle(tester);
    });

    testWidgets('releasing outside cancels', (tester) async {
      final changes = <Set<int>>[];
      await pumpKitScene(tester, selectOne(changes));
      final gesture = await tester.startGesture(
        tester.getCenter(byKey('amalfi-segmented-item-1')),
      );
      await tester.pump();
      await gesture.moveTo(const Offset(600, 400));
      await gesture.up();
      await settle(tester);
      expect(changes, isEmpty);
      expect(find.byType(AmalfiSegmentLens), findsNothing);
    });

    testWidgets('select any toggles items', (tester) async {
      final changes = <Set<int>>[];
      await pumpKitScene(
        tester,
        selectOne(changes, selection: AmalfiSegmentedSelection.any),
      );
      await tester.tapAt(tester.getCenter(byKey('amalfi-segmented-item-1')));
      await settle(tester);
      await tester.tapAt(tester.getCenter(byKey('amalfi-segmented-item-0')));
      await settle(tester);
      expect(changes, [
        {0, 1},
        {1},
      ]);
      expect(
        find.byKey(const ValueKey('amalfi-segmented-thumb')),
        findsNothing,
      );
    });

    testWidgets('keyboard: the arrows choose (select one)', (tester) async {
      final changes = <Set<int>>[];
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpKitScene(
        tester,
        selectOne(changes, enabledLast: false, focusNode: focus),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      // The last item is disabled: the choice stops at 1.
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(changes, [
        {1},
        {0},
      ]);
    });

    testWidgets('keyboard: Space toggles the focused item (select any)', (
      tester,
    ) async {
      final any = <Set<int>>[];
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpKitScene(
        tester,
        selectOne(
          any,
          selection: AmalfiSegmentedSelection.any,
          focusNode: focus,
        ),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      expect(any, [
        {0, 1},
      ]);
    });

    testWidgets('the arrows follow the reading direction', (tester) async {
      final changes = <Set<int>>[];
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await pumpKitScene(
        tester,
        selectOne(changes, direction: TextDirection.rtl, focusNode: focus),
      );
      expect(
        tester.getRect(byKey('amalfi-segmented-item-0')).left,
        greaterThan(tester.getRect(byKey('amalfi-segmented-item-1')).left),
      );
      focus.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      expect(changes, [
        {1},
      ]);
    });

    testWidgets('select any: no lens, a flat pressed item toggled on release', (
      tester,
    ) async {
      final changes = <Set<int>>[];
      await pumpKitScene(
        tester,
        selectOne(changes, selection: AmalfiSegmentedSelection.any),
      );
      final item1 = tester.getCenter(byKey('amalfi-segmented-item-1'));
      final gesture = await tester.startGesture(item1);
      await settle(tester);
      expect(find.byType(AmalfiSegmentLens), findsNothing);
      AmalfiSegmentItem item(int i) =>
          tester.widget<AmalfiSegmentItem>(byKey('amalfi-segmented-item-$i'));
      expect(item(1).pressed, isTrue);
      // Off the item: not pressed; released there, nothing changes.
      await gesture.moveTo(tester.getCenter(byKey('amalfi-segmented-item-2')));
      await tester.pump();
      expect(item(1).pressed, isFalse);
      await gesture.up();
      await tester.pump();
      expect(changes, isEmpty);
      await tester.tapAt(item1);
      await tester.pump();
      expect(changes, [
        {0, 1},
      ]);
      expect(item(1).pressed, isFalse);
    });

    testWidgets('disabled: the selection stays, the control at 35 %', (
      tester,
    ) async {
      await pumpKitScene(
        tester,
        const AmalfiSegmentedControl(
          segments: [
            AmalfiSegment.text('One'),
            AmalfiSegment.text('Two', enabled: false),
          ],
          selected: {0},
        ),
      );
      expect(find.byKey(const ValueKey('amalfi-segmented-thumb')), findsOne);
      final opacities = tester
          .widgetList<Opacity>(
            find.ancestor(
              of: byKey('amalfi-segmented-item-1'),
              matching: find.byType(Opacity),
            ),
          )
          .map((o) => o.opacity);
      expect(opacities, [AmalfiStates.disabledOpacity]);
      expect(
        tester
            .widgetList<Opacity>(
              find.descendant(
                of: byKey('amalfi-segmented-item-1'),
                matching: find.byType(Opacity),
              ),
            )
            .isEmpty,
        isTrue,
      );
    });

    testWidgets('disabled: no change, no lens', (tester) async {
      await pumpKitScene(
        tester,
        const AmalfiSegmentedControl(
          segments: [AmalfiSegment.text('One'), AmalfiSegment.text('Two')],
          selected: {0},
        ),
      );
      await tester.startGesture(
        tester.getCenter(byKey('amalfi-segmented-item-1')),
      );
      await settle(tester);
      expect(find.byType(AmalfiSegmentLens), findsNothing);
    });

    testWidgets('hovering an item draws the kit hover item', (tester) async {
      final master = KitMaster.load('Segments/Text Item/Regular/Hover/Light');
      await pumpKitScene(
        tester,
        const AmalfiSegmentedControl(
          segments: [AmalfiSegment.text('One'), AmalfiSegment.text('Item')],
          selected: {0},
          onChanged: _ignore,
        ),
      );
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      addTearDown(mouse.removePointer);
      await mouse.addPointer(location: const Offset(400, 400));
      await mouse.moveTo(tester.getCenter(byKey('amalfi-segmented-item-1')));
      await tester.pump();
      final item = byKey('amalfi-segmented-item-1');
      expectKitGeometry(
        tester,
        master,
        root: item,
        layers: {
          'Background': find.descendant(
            of: item,
            matching: byKey('amalfi-segment-item-background'),
          ),
          'Label': find.descendant(
            of: item,
            matching: byKey('amalfi-segment-item-label'),
          ),
        },
      );
    });

    testWidgets('items are selectable buttons for screen readers', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpKitScene(tester, selectOne([]));
      expect(
        tester.getSemantics(find.bySemanticsLabel('Item 0')),
        matchesSemantics(
          label: 'Item 0',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasSelectedState: true,
          isSelected: true,
          isInMutuallyExclusiveGroup: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });
  });

  group('edge cases', () {
    testWidgets('no segments and tight constraints do not crash', (
      tester,
    ) async {
      await pumpKitScene(
        tester,
        const Column(
          children: [
            AmalfiActionSegments(segments: []),
            AmalfiSegmentedControl(segments: [], selected: {}),
            SizedBox(
              width: 10,
              height: 10,
              child: AmalfiSegmentedControl(
                segments: [AmalfiSegment.text('One')],
                selected: {3},
              ),
            ),
          ],
        ),
      );
      expect(tester.takeException(), isNull);
    });

    test('the kit capsule keeps the smoothing on the long side', () {
      // Segments/Action/Icon 2/Regular: 56 × 28, the corner starts 22.4 from the end.
      final path = const AmalfiSmoothBorder(radius: 14)
          .getOuterPath(const Rect.fromLTWH(0, 0, 56, 28));
      expect(path.contains(const Offset(22.5, 0.3)), isTrue);
      expect(path.contains(const Offset(1, 3)), isFalse);
      final bounds = path.getBounds();
      expect(bounds.left, moreOrLessEquals(0, epsilon: 1e-4));
      expect(bounds.top, moreOrLessEquals(0, epsilon: 1e-4));
      expect(bounds.width, moreOrLessEquals(56, epsilon: 1e-4));
      expect(bounds.height, moreOrLessEquals(28, epsilon: 1e-4));
    });
  });
}

void _ignore(Set<int> _) {}
