// Where the menu of a pop-up button or a pull-down goes, and how long it takes
// (docs/spec/menus.md "Pop-up button", measured): the pure rules and the in-window fallback.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

import 'support/scene.dart';

const _bounds = Rect.fromLTWH(0, 0, 1000, 800);

/// Five rows of 24 and 5 of padding on both ends: 130.
const _height = 130.0;

double _rowTop(int i) => 5 + 24.0 * i;

AmalfiMenuPlacement _popUp(
  Rect control,
  int selected, {
  double width = 150,
  double height = _height,
  Rect bounds = _bounds,
}) => AmalfiMenuPlacement.popUp(
  control: control,
  bounds: bounds,
  width: width,
  height: height,
  selectedTop: _rowTop(selected),
  first: selected == 0,
);

void main() {
  const control = Rect.fromLTWH(300, 300, 120, 24);

  group('pop-up placement', () {
    test(
      'the selected row\'s top is the control\'s top: first, middle, last',
      () {
        for (final i in [0, 2, 4]) {
          final p = _popUp(control, i);
          expect(p.top + _rowTop(i), 300, reason: 'row $i');
          expect(p.left, 288);
          expect(p.height, _height);
          expect(p.scroll, 0);
          expect(p.arrowTop || p.arrowBottom, isFalse);
          expect(p.flipped, isFalse);
        }
      },
    );

    test(
      'the left edge is 12 left of the control; the text lands 5 right of its label',
      () {
        final p = _popUp(control, 1);
        expect(p.left, control.left - 12);
        // Row text 30 into the menu, the label 12 + 1 into the control.
        expect(p.left + 30 - (control.left + 13), 5);
      },
    );

    test('small and mini controls', () {
      final small = _popUp(const Rect.fromLTWH(300, 300, 100, 20), 1);
      expect(small.left, 289);
      expect(small.top + _rowTop(1), 300);
      final mini = _popUp(const Rect.fromLTWH(300, 300, 100, 16), 1);
      expect(mini.left, 288);
      expect(mini.top + _rowTop(1), 303);
      expect(AmalfiPopUpMenuMetrics.rowHeight(AmalfiPopUpControl.regular), 24);
      expect(AmalfiPopUpMenuMetrics.rowHeight(AmalfiPopUpControl.small), 22);
      expect(AmalfiPopUpMenuMetrics.rowHeight(AmalfiPopUpControl.mini), 19);
    });

    test('first item with no room below: the menu opens above the control', () {
      final p = _popUp(const Rect.fromLTWH(300, 770, 120, 24), 0);
      expect(p.flipped, isTrue);
      expect(p.top + p.height, 770);
      expect(p.arrowTop || p.arrowBottom, isFalse);
    });

    test('a middle item near the bottom keeps the alignment and scrolls', () {
      final p = _popUp(const Rect.fromLTWH(300, 760, 120, 24), 2);
      expect(p.flipped, isFalse);
      expect(p.top, 760 - _rowTop(2));
      // Cut at 6 from the bottom: 794.
      expect(p.top + p.height, 794);
      expect(p.scroll, 0);
      expect(p.arrowBottom, isTrue);
      expect(p.arrowTop, isFalse);
    });

    test('the last item near the top does not flip: it scrolls', () {
      final p = _popUp(const Rect.fromLTWH(300, 20, 120, 24), 4);
      expect(p.flipped, isFalse);
      expect(p.top, 6);
      expect(p.scroll, 6 - (20 - _rowTop(4)));
      expect(p.arrowTop, isTrue);
      expect(p.arrowBottom, isFalse);
      // The selected row stays on the control.
      expect(p.top - p.scroll + _rowTop(4), 20);
    });

    test('the first item near the top may cover the bar: 6 from the edge', () {
      final p = _popUp(const Rect.fromLTWH(300, 8, 120, 24), 2);
      expect(p.top, 6);
      expect(p.arrowTop, isTrue);
    });

    test('a menu taller than the output scrolls at both ends', () {
      final p = _popUp(
        const Rect.fromLTWH(300, 400, 120, 24),
        20,
        height: 1000,
      );
      expect(p.top, 6);
      expect(p.height, 788);
      expect(p.arrowTop, isTrue);
      expect(p.arrowBottom, isTrue);
    });

    test(
      'past the right edge the menu slides left; the vertical alignment stays',
      () {
        final p = _popUp(const Rect.fromLTWH(940, 300, 120, 24), 2, width: 200);
        expect(p.left, 1000 - 6 - 200);
        expect(p.top + _rowTop(2), 300);
      },
    );

    test('the menu stays 6 from the usable area\'s bottom (the Dock)', () {
      final p = _popUp(
        const Rect.fromLTWH(300, 700, 120, 24),
        2,
        bounds: const Rect.fromLTWH(0, 0, 1000, 760),
      );
      expect(p.top + p.height, 754);
    });
  });

  group('pull-down placement', () {
    test('3 below the control, 5 left of it', () {
      final p = AmalfiMenuPlacement.pullDown(
        control: control,
        bounds: _bounds,
        width: 116,
        height: 106,
      );
      expect(p.top, 327);
      expect(p.left, 295);
      expect(p.flipped, isFalse);
    });

    test(
      'without room below it opens above, its bottom on the control\'s top',
      () {
        final p = AmalfiMenuPlacement.pullDown(
          control: const Rect.fromLTWH(300, 740, 120, 24),
          bounds: _bounds,
          width: 116,
          height: 106,
        );
        expect(p.flipped, isTrue);
        expect(p.top + p.height, 740);
      },
    );

    test('past the right edge it slides left', () {
      final p = AmalfiMenuPlacement.pullDown(
        control: const Rect.fromLTWH(950, 300, 120, 24),
        bounds: _bounds,
        width: 180,
        height: 106,
      );
      expect(p.left, 1000 - 6 - 180);
    });
  });

  group('timings', () {
    test('the measured durations', () {
      expect(AmalfiPopUpMenuMetrics.open, Duration.zero);
      expect(AmalfiPopUpMenuMetrics.fadeOut, const Duration(milliseconds: 190));
      expect(
        AmalfiPopUpMenuMetrics.chooseFadeDelay + AmalfiPopUpMenuMetrics.fadeOut,
        const Duration(milliseconds: 340),
      );
    });

    test('the fade is ease-out in the amount that goes', () {
      const c = AmalfiPopUpMenuMetrics.fadeCurve;
      expect(c.transform(1), 1);
      expect(c.transform(0), 0);
      // Half the contrast is gone by 80 ms (0.42 of the time) or earlier: ease-out is
      // faster than linear.
      expect(c.transform(1 - 80 / 190), lessThan(0.5));
      expect(c.transform(1 - 145 / 190), lessThan(0.15));
    });
  });

  group('in-window fallback', () {
    const items = [
      AmalfiPopUpItem(value: 1, label: 'Orange'),
      AmalfiPopUpItem(value: 2, label: 'Lemon'),
      AmalfiPopUpItem(value: 3, label: 'Olive'),
      AmalfiPopUpItem(value: 4, label: 'Fig'),
    ];

    Widget at(Widget button, {double left = 300, double top = 300}) => Stack(
      children: [Positioned(left: left, top: top, child: button)],
    );

    Future<void> openPopUp(
      WidgetTester tester, {
      int value = 3,
      double left = 300,
      double top = 300,
      ValueChanged<int>? onChanged,
      AmalfiControlSize size = AmalfiControlSize.small,
    }) async {
      await pumpKitScene(
        tester,
        at(
          AmalfiPopUpButton<int>(
            items: items,
            value: value,
            size: size,
            onChanged: onChanged ?? (_) {},
          ),
          left: left,
          top: top,
        ),
      );
      await tester.tap(find.byType(AmalfiPopUpButton<int>));
      await tester.pump();
    }

    testWidgets('pop-up: the chosen row is over the control', (tester) async {
      await openPopUp(tester);
      final button = tester.getRect(find.byType(AmalfiPopUpButton<int>));
      final menu = tester.getRect(find.byType(AmalfiMenu));
      expect(button.height, 24);
      expect(menu.left, button.left - 12);
      // Third row: 5 + 2 * 24 into the menu.
      expect(menu.top + 5 + 2 * 24, button.top);
      expect(menu.width, button.width);
    });

    testWidgets('pop-up: wider rows widen the menu to the right', (
      tester,
    ) async {
      await pumpKitScene(
        tester,
        at(
          AmalfiPopUpButton<int>(
            items: const [
              AmalfiPopUpItem(
                value: 1,
                label:
                    'A very long item that needs much more room than the button',
              ),
              AmalfiPopUpItem(value: 2, label: 'Short'),
            ],
            value: 2,
            onChanged: (_) {},
          ),
        ),
      );
      await tester.tap(find.byType(AmalfiPopUpButton<int>));
      await tester.pump();
      final button = tester.getRect(find.byType(AmalfiPopUpButton<int>));
      final menu = tester.getRect(find.byType(AmalfiMenu));
      expect(menu.left, button.left - 12);
      expect(menu.width, greaterThan(button.width));
    });

    testWidgets('pop-up: the first item with no room below flips above', (
      tester,
    ) async {
      await openPopUp(tester, value: 1, top: 1180);
      final button = tester.getRect(find.byType(AmalfiPopUpButton<int>));
      final menu = tester.getRect(find.byType(AmalfiMenu));
      expect(menu.bottom, button.top);
    });

    testWidgets('pop-up: near the bottom the rows scroll and an arrow shows', (
      tester,
    ) async {
      await openPopUp(tester, value: 3, top: 1170);
      final menu = tester.getRect(find.byType(AmalfiMenu));
      expect(menu.bottom, 1200 - 6);
      expect(
        find.descendant(
          of: find.byType(AmalfiMenu),
          matching: find.byType(AmalfiGlyph),
        ),
        findsWidgets,
      );
    });

    testWidgets('pop-up: near the right edge it slides left', (tester) async {
      await openPopUp(tester, left: 1480);
      final menu = tester.getRect(find.byType(AmalfiMenu));
      expect(menu.right, lessThanOrEqualTo(1600 - 6));
    });

    testWidgets('pull-down: 3 below, 5 left, 4 narrower', (tester) async {
      await pumpKitScene(
        tester,
        at(
          AmalfiPullDownButton(
            label: 'Actions',
            items: [
              AmalfiPullDownItem(label: 'Duplicate', onSelected: () {}),
              AmalfiPullDownItem(label: 'Delete', onSelected: () {}),
            ],
          ),
        ),
      );
      await tester.tap(find.byType(AmalfiPullDownButton));
      await tester.pump();
      final button = tester.getRect(find.byType(AmalfiPullDownButton));
      final menu = tester.getRect(find.byType(AmalfiMenu));
      expect(menu.top, button.bottom + 3);
      expect(menu.left, button.left - 5);
      expect(menu.width, button.width - 4);
    });

    testWidgets('it opens in one frame; Esc fades it over 190 ms, ease-out', (
      tester,
    ) async {
      await openPopUp(tester);
      FadeTransition fade() => tester.widget<FadeTransition>(
        find
            .ancestor(
              of: find.byType(AmalfiMenu),
              matching: find.byType(FadeTransition),
            )
            .first,
      );
      expect(fade().opacity.value, 1);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 80));
      expect(fade().opacity.value, inInclusiveRange(0.25, 0.5));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byType(AmalfiMenu), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pumpAndSettle();
      expect(find.byType(AmalfiMenu), findsNothing);
    });

    testWidgets(
      'a choice blinks once and the fade starts 150 ms after the click',
      (tester) async {
        int? chosen;
        await openPopUp(tester, onChanged: (v) => chosen = v);
        await tester.tap(find.text('Fig'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 140));
        expect(chosen, isNull);
        await tester.pump(const Duration(milliseconds: 15));
        expect(chosen, 4);
        // Fading: still there ~335 ms after the click, gone after ~345.
        await tester.pump(const Duration(milliseconds: 170));
        expect(find.byType(AmalfiMenu), findsOneWidget);
        await tester.pump(const Duration(milliseconds: 30));
        await tester.pumpAndSettle();
        expect(find.byType(AmalfiMenu), findsNothing);
      },
    );
  });
}
