import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

import 'harness.dart';

const sections = [
  Segment(label: 'World'),
  Segment(label: 'Alarms'),
  Segment(label: 'Stopwatch'),
  Segment(label: 'Timer'),
];

const lensKey = ValueKey('glass lens');
const pillKey = ValueKey('chosen pill');
const trackKey = ValueKey('segmented track');

/// Clock's section switch: large, four segments of 94 pt content on a 384 pt track (96 pt each,
/// tiling the track), with the app's selection.
Widget clock({
  required int selected,
  required ValueChanged<int> onChanged,
  bool dark = true,
  bool reduceMotion = false,
  ControlSize size = ControlSize.large,
  bool? lens,
}) => harness(
  Builder(
    builder: (context) => MediaQuery(
      data: MediaQuery.of(context).copyWith(disableAnimations: reduceMotion),
      child: SegmentedControl(
        segments: sections,
        selected: {selected},
        size: size,
        segmentWidth: 94,
        lens: lens,
        onChanged: onChanged,
      ),
    ),
  ),
  dark: dark,
);

/// The control with its selection kept in a `StatefulBuilder`; `log` receives every change.
Future<void> pumpClock(
  WidgetTester tester,
  List<int> log, {
  int initial = 0,
  bool dark = true,
  bool reduceMotion = false,
}) async {
  var selected = initial;
  await tester.pumpWidget(
    StatefulBuilder(
      builder: (context, setState) => clock(
        selected: selected,
        dark: dark,
        reduceMotion: reduceMotion,
        onChanged: (i) {
          log.add(i);
          setState(() => selected = i);
        },
      ),
    ),
  );
}

/// The large control's segments share the track: (2 x 4 + 4 x 94) / 4.
const double slot = 96;

/// The centre of segment `i` along the track.
double centre(num i) => slot / 2 + slot * i;

Offset segmentCenter(WidgetTester tester, int i) {
  final track = tester.getTopLeft(find.byKey(trackKey));
  return track + Offset(centre(i), 18);
}

/// The pill's centre along the track.
double pillCentre(WidgetTester tester) =>
    tester.getCenter(find.byKey(pillKey)).dx -
    tester.getTopLeft(find.byKey(trackKey)).dx;

void main() {
  group('geometry: the pill is centred on its segment', () {
    testWidgets('large: segments tile the track, the pill is centred on each, '
        'the first and last too', (tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.pumpWidget(clock(selected: i, onChanged: (_) {}));
        await tester.pumpAndSettle();
        final track = tester.getRect(find.byKey(trackKey));
        final pill = tester.getRect(find.byKey(pillKey));
        expect(track.width, 4 * slot);
        expect(pill.center.dx - track.left, closeTo(centre(i), 1e-9));
        // ~89 pt on a ~95 pt segment (measured on the mid row), 4 pt from the top and bottom.
        expect(pill.width, slot - 6);
        expect(pill.top - track.top, 4, reason: 'top of $i');
        expect(track.bottom - pill.bottom, 4, reason: 'bottom of $i');
        // The label is centred on the same point.
        final label = tester.getCenter(find.text(sections[i].label!));
        expect(label.dx - track.left, closeTo(centre(i), 0.5));
        // At the ends the pill sits 3 pt from the round end, not 4.
        if (i == 0) expect(pill.left - track.left, 3);
        if (i == 3) expect(track.right - pill.right, 3);
      }
    });

    testWidgets('regular (the window control): the pill fills its segment, '
        'inset 2 pt on every side', (tester) async {
      for (var i = 0; i < 4; i++) {
        await tester.pumpWidget(
          clock(selected: i, size: ControlSize.regular, onChanged: (_) {}),
        );
        await tester.pumpAndSettle();
        final track = tester.getRect(find.byKey(trackKey));
        final pill = tester.getRect(find.byKey(pillKey));
        expect(pill.top - track.top, 2);
        expect(track.bottom - pill.bottom, 2);
        expect(pill.left - track.left, 2 + 94 * i);
        expect(pill.width, 94);
        final label = tester.getCenter(find.text(sections[i].label!));
        expect(label.dx, closeTo(pill.center.dx, 0.5));
      }
    });

    testWidgets('the lens is centred on each segment, the first and last too', (
      tester,
    ) async {
      for (var i = 0; i < 4; i++) {
        await tester.pumpWidget(clock(selected: i, onChanged: (_) {}));
        await tester.pumpAndSettle();
        final press = await tester.startGesture(segmentCenter(tester, i));
        await tester.pumpAndSettle();
        final track = tester.getRect(find.byKey(trackKey));
        final lens = tester.getRect(find.byKey(lensKey));
        expect(lens.center.dx - track.left, closeTo(centre(i), 1e-9));
        expect(lens.center.dy, closeTo(track.center.dy, 1e-9));
        expect(lens.size, const Size(91, 48));
        await press.up();
        await tester.pumpAndSettle();
      }
    });

    testWidgets('the lens passes the control: 6 pt above and below, past the '
        'ends on narrow segments, painted in the overlay', (tester) async {
      await tester.pumpWidget(
        harness(
          // A clip as tight as the control (a toolbar): the lens is not cut by it.
          ClipRect(
            key: const ValueKey('toolbar'),
            child: SegmentedControl(
              segments: sections,
              selected: const {0},
              size: ControlSize.large,
              segmentWidth: 60,
              onChanged: (_) {},
            ),
          ),
          dark: true,
        ),
      );
      final track = tester.getRect(find.byKey(trackKey));
      final press = await tester.startGesture(
        track.centerLeft + const Offset(10, 0),
      );
      await tester.pumpAndSettle();
      var lens = tester.getRect(find.byKey(lensKey));
      // 62 pt segments: the 91 pt lens on the first one passes the left end.
      expect(lens.center.dx - track.left, closeTo(31, 1e-9));
      expect(lens.left, lessThan(track.left));
      expect(track.top - lens.top, closeTo(6, 1e-9));
      expect(lens.bottom - track.bottom, closeTo(6, 1e-9));
      // It is not painted under the control's clip: it lives in the overlay.
      final clip = tester.renderObject(find.byKey(const ValueKey('toolbar')));
      final theater = tester.renderObject(find.byType(Overlay));
      final ancestors = <RenderObject>[];
      for (
        RenderObject? o = tester.renderObject(find.byKey(lensKey));
        o != null;
        o = o.parent
      ) {
        ancestors.add(o);
      }
      expect(ancestors, isNot(contains(clip)));
      expect(ancestors, contains(theater));
      await press.moveTo(track.centerRight + const Offset(40, 0));
      await tester.pump();
      lens = tester.getRect(find.byKey(lensKey));
      expect(lens.center.dx - track.left, closeTo(62 * 3.5, 1e-9));
      expect(lens.right, greaterThan(track.right));
      await press.up();
      await tester.pumpAndSettle();
    });

    testWidgets('without an overlay the lens paints in place, unclipped', (
      tester,
    ) async {
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SegmentedControl(
              segments: sections,
              selected: const {1},
              size: ControlSize.large,
              segmentWidth: 94,
              onChanged: (_) {},
            ),
          ),
        ),
      );
      final press = await tester.startGesture(segmentCenter(tester, 1));
      await tester.pumpAndSettle();
      final track = tester.getRect(find.byKey(trackKey));
      final lens = tester.getRect(find.byKey(lensKey));
      expect(lens.center.dx - track.left, closeTo(centre(1), 1e-9));
      expect(lens.height, 48);
      await press.up();
      await tester.pumpAndSettle();
    });
  });

  group('lens (LENS, silica-reference #92)', () {
    Rect lensRect(WidgetTester tester) => tester.getRect(find.byKey(lensKey));
    Rect trackRect(WidgetTester tester) => tester.getRect(find.byKey(trackKey));
    Future<void> ms(WidgetTester tester, int t) =>
        tester.pump(Duration(milliseconds: t));

    testWidgets('a 91 x 48 capsule, 6 pt past the track at top and bottom', (
      tester,
    ) async {
      await pumpClock(tester, [], initial: 1);
      expect(find.byKey(lensKey), findsNothing);
      final press = await tester.startGesture(segmentCenter(tester, 1));
      await tester.pump();
      await ms(tester, 400);
      final lens = lensRect(tester);
      final track = trackRect(tester);
      expect(lens.width, closeTo(91, 0.01));
      expect(lens.height, closeTo(48, 0.01));
      expect(track.top - lens.top, closeTo(6, 0.01));
      expect(lens.bottom - track.bottom, closeTo(6, 0.01));
      expect(
        lens.center.dx,
        closeTo(tester.getRect(find.byKey(pillKey)).center.dx, 0.01),
      );
      // The labels under the lens are magnified 1.11 x.
      final magnified = find.descendant(
        of: find.byKey(lensKey),
        matching: find.byType(Transform),
      );
      final scale = tester.widget<Transform>(magnified.first).transform;
      expect(GlassLensMetrics.magnification, 1.11);
      expect(scale.getMaxScaleOnAxis(), closeTo(1.11, 0.001));
      await press.up();
      await tester.pumpAndSettle();
    });

    testWidgets('look: clear body, dark rim, light lines, fringes, no region', (
      tester,
    ) async {
      for (final dark in [false, true]) {
        await pumpClock(tester, [], dark: dark);
        final press = await tester.startGesture(segmentCenter(tester, 0));
        await tester.pumpAndSettle();
        final painter =
            tester
                    .widget<CustomPaint>(
                      find
                          .descendant(
                            of: find.byKey(lensKey),
                            matching: find.byType(CustomPaint),
                          )
                          .first,
                    )
                    .painter!
                as GlassLensPainter;
        expect(painter.style, GlassLensStyle.clear, reason: 'same in $dark');
        expect(painter.style.fill.a, 0);
        expect(painter.style.edge.a, greaterThan(0));
        expect(painter.style.highlight.a, greaterThan(0));
        expect(painter.style.fringeWarm.a, greaterThan(0));
        expect(painter.style.fringeCool.a, greaterThan(0));
        // No glass region: the lens refracts the window's own content.
        expect(find.byType(Glass), findsNothing);
        await press.up();
        await tester.pumpAndSettle();
        expect(find.byType(Glass), findsNothing);
      }
    });

    testWidgets('while pressed, the original labels are cut out under the lens', (
      tester,
    ) async {
      await pumpClock(tester, [], initial: 1);
      const labelsKey = ValueKey('segmented labels');
      // At rest nothing is clipped.
      expect(tester.widget<ClipPath>(find.byKey(labelsKey)).clipper, isNull);
      final press = await tester.startGesture(segmentCenter(tester, 1));
      await tester.pump();
      await ms(tester, 400);
      final lens = lensRect(tester);
      final track = trackRect(tester);
      final clip = tester.widget<ClipPath>(find.byKey(labelsKey));
      final size = tester.getSize(find.byKey(labelsKey));
      final path = clip.clipper!.getClip(size);
      // Local to the control: the lens centre and its ends are cut out, the rest is kept.
      final local = lens.shift(-track.topLeft);
      expect(path.contains(local.center), isFalse);
      expect(path.contains(local.center + const Offset(0, 10)), isFalse);
      expect(path.contains(local.centerLeft + const Offset(8, 0)), isFalse);
      expect(path.contains(local.centerLeft - const Offset(2, 0)), isTrue);
      expect(path.contains(local.centerRight + const Offset(2, 0)), isTrue);
      // The "Alarms" label sits under the lens centre: it is clipped there, so only the
      // magnified copy is seen.
      expect(clip.clipBehavior, Clip.antiAlias);
      expect(
        find.descendant(of: find.byKey(lensKey), matching: find.text('Alarms')),
        findsOneWidget,
      );
      // Neighbouring labels outside the lens are still painted.
      expect(path.contains(Offset(centre(0), 18)), isTrue);
      await press.up();
      await tester.pumpAndSettle();
      expect(tester.widget<ClipPath>(find.byKey(labelsKey)).clipper, isNull);
    });

    testWidgets('paint order: track, pill, labels, lens', (tester) async {
      await pumpClock(tester, [], initial: 1);
      final press = await tester.startGesture(segmentCenter(tester, 1));
      await tester.pump();
      await ms(tester, 100);
      final all = tester.allWidgets.toList();
      int at(Key key) =>
          all.indexOf(tester.widget(find.byKey(key as ValueKey<String>)));
      final track = at(trackKey);
      final pill = at(pillKey);
      final labels = at(const ValueKey('segmented labels'));
      final lens = at(lensKey);
      expect(track, lessThan(pill));
      expect(pill, lessThan(labels));
      expect(labels, lessThan(lens));
      // The rim is part of the track, under the pill; the pill sits inside the rim.
      final trackRect = tester.getRect(find.byKey(trackKey));
      final pillRect = tester.getRect(find.byKey(pillKey));
      expect(trackRect.contains(pillRect.topLeft), isTrue);
      expect(pillRect.top - trackRect.top, greaterThanOrEqualTo(2));
      await press.up();
      await tester.pumpAndSettle();
    });

    testWidgets('the pill is not drawn under the full lens', (tester) async {
      await pumpClock(tester, []);
      final press = await tester.startGesture(segmentCenter(tester, 0));
      await tester.pump();
      await ms(tester, 60);
      double pillAlpha() =>
          (tester
                      .widget<DecoratedBox>(
                        find.descendant(
                          of: find.byKey(pillKey),
                          matching: find.byType(DecoratedBox),
                        ),
                      )
                      .decoration
                  as BoxDecoration)
              .color!
              .a;
      expect(pillAlpha(), greaterThan(0.1));
      await ms(tester, 400);
      expect(pillAlpha(), closeTo(0, 0.01));
      await press.up();
      await tester.pumpAndSettle();
      expect(pillAlpha(), greaterThan(0.1));
    });

    testWidgets('press on the selected segment: +120 ms out, +240 ms full', (
      tester,
    ) async {
      await pumpClock(tester, [], initial: 1);
      final press = await tester.startGesture(segmentCenter(tester, 1));
      await tester.pump();
      await ms(tester, 100);
      // Not yet past the 36 pt track.
      expect(lensRect(tester).height, lessThan(36));
      await ms(tester, 20); // +120 ms
      expect(lensRect(tester).height, greaterThan(36));
      var tallest = 0.0;
      for (var t = 0; t < 7; t++) {
        await ms(tester, 17);
        tallest = tallest < lensRect(tester).height
            ? lensRect(tester).height
            : tallest;
      }
      // A small overshoot on the way to 48 pt.
      expect(tallest, greaterThan(48.2));
      expect(tallest, lessThan(50.5));
      await tester.pump(const Duration(milliseconds: 240));
      expect(lensRect(tester).height, closeTo(48, 0.01));
      // No slide: the lens stays on its segment.
      expect(pillCentre(tester), centre(1));
      await press.up();
      await tester.pumpAndSettle();
    });

    testWidgets('press on another segment: slide at +28 ms, lens on the way, '
        'settled by +400-500 ms', (tester) async {
      final log = <int>[];
      await pumpClock(tester, log);
      final press = await tester.startGesture(segmentCenter(tester, 2));
      await tester.pump();
      await ms(tester, 24);
      expect(
        pillCentre(tester),
        centre(0),
        reason: 'no movement before +28 ms',
      );
      await ms(tester, 30); // +54
      final early = pillCentre(tester);
      expect(early, greaterThan(centre(0)));
      await ms(tester, 66); // +120: already a lens, still travelling
      expect(lensRect(tester).height, greaterThan(36));
      expect(pillCentre(tester), greaterThan(early));
      expect(pillCentre(tester), lessThan(centre(2) - 20));
      await ms(tester, 130); // +250: full size, still not there
      expect(lensRect(tester).height, closeTo(48, 0.01));
      expect(pillCentre(tester), lessThan(centre(2) - 3));
      await ms(tester, 150); // +400
      expect(pillCentre(tester), closeTo(centre(2), 5));
      await ms(tester, 110); // +510
      expect(pillCentre(tester), closeTo(centre(2), 0.05));
      // The content changes only after the release.
      expect(log, isEmpty);
      await press.up();
      await tester.pumpAndSettle();
      expect(log, [2]);
    });

    testWidgets('dragging: the lens follows the pointer continuously', (
      tester,
    ) async {
      final log = <int>[];
      await pumpClock(tester, log);
      final start = segmentCenter(tester, 0);
      final press = await tester.startGesture(start);
      await tester.pump();
      await ms(tester, 600);
      for (final dx in [7.0, 31.0, 50.0, 93.0, 140.0]) {
        await press.moveTo(start + Offset(dx, 0));
        await tester.pump();
        expect(
          pillCentre(tester),
          closeTo(centre(0) + dx, 0.01),
          reason: 'at $dx',
        );
        expect(find.byKey(lensKey), findsOneWidget);
      }
      expect(log, isEmpty);
      // The lens centre is the pointer: it sits between segments.
      expect((pillCentre(tester) - centre(0)) % slot, isNot(closeTo(0, 1)));
      await press.up();
      await tester.pumpAndSettle();
      expect(log, [1]);
    });

    testWidgets('dragging is clamped between the first and last centres', (
      tester,
    ) async {
      await pumpClock(tester, []);
      final press = await tester.startGesture(segmentCenter(tester, 1));
      await tester.pump();
      await ms(tester, 600);
      await press.moveTo(segmentCenter(tester, 3) + const Offset(60, 0));
      await tester.pump();
      expect(pillCentre(tester), closeTo(centre(3), 0.01));
      // The lens ends line up with the track ends (measured).
      expect(lensRect(tester).right, closeTo(trackRect(tester).right, 3));
      await press.moveTo(segmentCenter(tester, 0) - const Offset(80, 0));
      await tester.pump();
      expect(pillCentre(tester), closeTo(centre(0), 0.01));
      // 60 pt below the control the lens stays big, at its last x.
      await press.moveTo(segmentCenter(tester, 2) + const Offset(0, 60));
      await tester.pump();
      expect(lensRect(tester).height, closeTo(48, 0.01));
      await press.cancel();
      await tester.pumpAndSettle();
    });

    testWidgets('release inside: the lens retracts in ~130 ms, then it is '
        'chosen', (tester) async {
      final log = <int>[];
      await pumpClock(tester, log, initial: 1);
      final press = await tester.startGesture(segmentCenter(tester, 1));
      await tester.pump();
      await ms(tester, 400);
      await press.up();
      await tester.pump();
      await ms(tester, 60);
      expect(find.byKey(lensKey), findsOneWidget);
      expect(lensRect(tester).height, lessThan(48));
      await ms(tester, 50); // +110
      expect(find.byKey(lensKey), findsOneWidget);
      await ms(tester, 25); // +135
      expect(find.byKey(lensKey), findsNothing);
      expect(find.byType(Glass), findsNothing);
      await tester.pumpAndSettle();
      expect(log, [1]);
    });

    testWidgets('release outside cancels: lens ~100 ms, pill back in ~200 ms', (
      tester,
    ) async {
      final log = <int>[];
      await pumpClock(tester, log);
      final press = await tester.startGesture(segmentCenter(tester, 0));
      await tester.pump();
      await press.moveTo(segmentCenter(tester, 3));
      await ms(tester, 600);
      expect(pillCentre(tester), closeTo(centre(3), 0.5));
      await press.moveTo(segmentCenter(tester, 3) + const Offset(0, 80));
      await tester.pump();
      await press.up();
      await tester.pump();
      await ms(tester, 50);
      expect(find.byKey(lensKey), findsOneWidget);
      await ms(tester, 55); // +105
      expect(find.byKey(lensKey), findsNothing);
      expect(
        pillCentre(tester),
        inExclusiveRange(centre(0) + 0.5, centre(3) - 5),
      );
      await ms(tester, 100); // +205
      expect(pillCentre(tester), closeTo(centre(0), 0.05));
      await tester.pumpAndSettle();
      expect(log, isEmpty);
    });

    testWidgets('the app may refuse the choice: the pill returns', (
      tester,
    ) async {
      final log = <int>[];
      await tester.pumpWidget(clock(selected: 0, onChanged: log.add));
      final press = await tester.startGesture(segmentCenter(tester, 2));
      await tester.pumpAndSettle();
      await press.up();
      await tester.pumpAndSettle();
      expect(log, [2]);
      expect(pillCentre(tester), closeTo(centre(0), 0.05));
    });

    testWidgets('hover is instant: no fade in or out', (tester) async {
      await pumpClock(tester, [], initial: 0);
      final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await mouse.addPointer(location: const Offset(1, 1));
      await mouse.moveTo(segmentCenter(tester, 2));
      await tester.pump();
      final hover = find.byKey(const ValueKey('hover 2'));
      expect(hover, findsOneWidget);
      final decoration =
          tester
                  .widget<DecoratedBox>(
                    find.descendant(
                      of: hover,
                      matching: find.byType(DecoratedBox),
                    ),
                  )
                  .decoration
              as BoxDecoration;
      expect(decoration.color!.a, greaterThan(0.5));
      expect(tester.hasRunningAnimations, isFalse);
      await mouse.moveTo(const Offset(1, 1));
      await tester.pump();
      expect(hover, findsNothing);
    });

    testWidgets('over a disabled segment the lens passes; release keeps the '
        'last enabled one', (tester) async {
      final log = <int>[];
      await tester.pumpWidget(
        harness(
          SegmentedControl(
            segments: const [
              Segment(label: 'A'),
              Segment(label: 'B', enabled: false),
              Segment(label: 'C'),
            ],
            selected: const {0},
            size: ControlSize.large,
            // 96 pt slots, as in the four-segment control.
            segmentWidth: 280 / 3,
            onChanged: log.add,
          ),
          dark: true,
        ),
      );
      final press = await tester.startGesture(segmentCenter(tester, 0));
      await tester.pump();
      await ms(tester, 600);
      await press.moveTo(segmentCenter(tester, 1));
      await tester.pump();
      expect(pillCentre(tester), closeTo(centre(1), 0.01));
      await press.up();
      await tester.pumpAndSettle();
      expect(log, [0]);
      final again = await tester.startGesture(segmentCenter(tester, 0));
      await tester.pump();
      await ms(tester, 600);
      await again.moveTo(segmentCenter(tester, 2));
      await tester.pump();
      await again.up();
      await tester.pumpAndSettle();
      expect(log, [0, 2]);
    });

    testWidgets('reduced motion: the lens appears, follows and goes at once', (
      tester,
    ) async {
      final log = <int>[];
      await pumpClock(tester, log, reduceMotion: true);
      final press = await tester.startGesture(segmentCenter(tester, 0));
      await tester.pump();
      expect(lensRect(tester).height, closeTo(48, 0.01));
      await press.moveTo(segmentCenter(tester, 3));
      await tester.pump();
      expect(pillCentre(tester), closeTo(centre(3), 0.01));
      // Nothing moves on its own (the overlay re-checks the lens's place each frame, without
      // asking for frames).
      expect(tester.binding.hasScheduledFrame, isFalse);
      await press.up();
      await tester.pump();
      await tester.pump();
      expect(log, [3]);
      expect(find.byKey(lensKey), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('off by default below large; on when asked', (tester) async {
      final log = <int>[];
      await tester.pumpWidget(
        clock(selected: 0, size: ControlSize.regular, onChanged: log.add),
      );
      final track = tester.getTopLeft(find.byKey(trackKey));
      final press = await tester.startGesture(track + const Offset(50, 12));
      await tester.pump();
      expect(find.byKey(lensKey), findsNothing);
      await press.up();
      await tester.pumpWidget(
        clock(
          selected: 0,
          size: ControlSize.regular,
          lens: true,
          onChanged: log.add,
        ),
      );
      final again = await tester.startGesture(track + const Offset(50, 12));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(lensKey), findsOneWidget);
      await again.up();
      await tester.pumpAndSettle();
      expect(find.byKey(lensKey), findsNothing);
    });

    testWidgets('no lens in select any and momentary', (tester) async {
      await tester.pumpWidget(
        harness(
          SegmentedControl(
            segments: sections,
            mode: SegmentedMode.selectAny,
            size: ControlSize.large,
            segmentWidth: 94,
            selected: const {0},
            lens: true,
            onChanged: (_) {},
          ),
        ),
      );
      final press = await tester.startGesture(segmentCenter(tester, 1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(lensKey), findsNothing);
      await press.up();
    });
  });

  group('GlassLens', () {
    testWidgets('nothing at presence 0; ignores the pointer and semantics', (
      tester,
    ) async {
      Widget lens(double presence) => Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: SizedBox(
            width: 200,
            height: 40,
            child: GlassLens(
              rect: const Rect.fromLTWH(50, 6, 60, 28),
              presence: presence,
              style: GlassLensStyle.light,
              content: const Text('label'),
            ),
          ),
        ),
      );
      await tester.pumpWidget(lens(0));
      expect(find.byKey(lensKey), findsNothing);
      await tester.pumpWidget(lens(1));
      expect(find.byKey(lensKey), findsOneWidget);
      expect(tester.getSize(find.byKey(lensKey)), const Size(60, 28));
      expect(find.bySemanticsLabel('label'), findsNothing);
      // Without Impeller (the test engine) there is no refraction filter.
      expect(GlassLens.refractionSupported, isFalse);
      expect(find.byKey(const ValueKey('glass lens refraction')), findsNothing);
    });

    testWidgets('the lens shader is bundled and has the expected uniforms', (
      tester,
    ) async {
      await tester.runAsync(() async {
        // A root asset here; `GlassLens.shaderAsset` in the apps that depend on silica_ui.
        final program = await ui.FragmentProgram.fromAsset(
          'shaders/glass_lens.frag',
        );
        final shader = program.fragmentShader();
        // The backdrop size, then 11 floats and two colours.
        for (var i = 0; i < 2 + 11 + 8; i++) {
          shader.setFloat(i, 1);
        }
        expect(() => shader.setFloat(21, 0), throwsA(anything));
        shader.dispose();
      });
    });

    test('glassLensRect grows around the pill to 91 x 48', () {
      const pill = Rect.fromLTWH(10, 4, 94, 28);
      expect(glassLensRect(pill, 0), pill);
      final full = glassLensRect(pill, 1);
      expect((full.center - pill.center).distance, lessThan(1e-9));
      expect(full.width, closeTo(91, 1e-9));
      expect(full.height, closeTo(48, 1e-9));
      final half = glassLensRect(pill, 0.5);
      expect(half.height, closeTo(38, 1e-9));
    });

    test('the measured timing curves', () {
      expect(GlassLensMetrics.appearCurve.transform(0), 0);
      expect(GlassLensMetrics.appearCurve.transform(1), 1);
      expect(GlassLensMetrics.appearCurve.transform(0.67), greaterThan(1));
      expect(GlassLensMetrics.travelDelay.inMilliseconds, 28);
      expect(GlassLensMetrics.retractDuration.inMilliseconds, 130);
      expect(GlassLensMetrics.cancelReturnDuration.inMilliseconds, 200);
    });
  });

  group('backdrop refraction (Impeller)', () {
    tearDown(() {
      GlassLens.debugRefractionSupportedOverride = null;
      GlassLens.debugShaderFilter = null;
      GlassLens.debugReset();
    });

    /// Pretends the engine supports shader filters; the filter itself is a stand-in, since
    /// `ImageFilter.shader` throws without Impeller.
    Future<void> impeller(WidgetTester tester) async {
      GlassLens.debugRefractionSupportedOverride = true;
      GlassLens.debugShaderFilter = (_) =>
          ui.ImageFilter.blur(sigmaX: 1, sigmaY: 1);
      final program = await tester.runAsync(GlassLens.loadProgram);
      expect(program, isNotNull);
      expect(GlassLens.usesBackdrop, isTrue);
    }

    testWidgets('the lens refracts the backdrop: no copy of the labels, the '
        'labels are not cut out', (tester) async {
      await impeller(tester);
      await pumpClock(tester, [], initial: 1);
      final press = await tester.startGesture(segmentCenter(tester, 1));
      await tester.pumpAndSettle();
      const refraction = ValueKey('glass lens refraction');
      expect(find.byKey(refraction), findsOneWidget);
      expect(
        find.descendant(of: find.byKey(lensKey), matching: find.byType(Text)),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byKey(lensKey),
          matching: find.byType(Transform),
        ),
        findsNothing,
      );
      final labels = tester.widget<ClipPath>(
        find.byKey(const ValueKey('segmented labels')),
      );
      expect(labels.clipper, isNull);
      // A backdrop filter clipped to the capsule.
      final box = tester.renderObject<RenderGlassLensBackdrop>(
        find.byKey(refraction),
      );
      expect(box.debugFilter, isNotNull);
      expect(box.debugLayer, isA<ClipRRectLayer>());
      final clip = box.debugLayer! as ClipRRectLayer;
      expect(clip.clipRRect!.tlRadiusX, 24);
      expect(clip.firstChild, isA<BackdropFilterLayer>());
      // The lens geometry in the backdrop's physical pixels.
      final dpr = tester.view.devicePixelRatio;
      final lens = tester.getRect(find.byKey(lensKey));
      final u = box.debugUniforms;
      expect(u[0], closeTo(lens.center.dx * dpr, 1e-6));
      expect(u[1], closeTo(lens.center.dy * dpr, 1e-6));
      expect(u[2], closeTo(91 / 2 * dpr, 1e-6));
      expect(u[3], closeTo(48 / 2 * dpr, 1e-6));
      expect(u[4], closeTo(dpr, 1e-9));
      expect(u[5], closeTo(1.11, 1e-9));
      expect(u[6], GlassLensMetrics.refractionDepth);
      expect(u[7], GlassLensMetrics.rimBlur);
      expect(u[8], GlassLensMetrics.chromaticOffset);
      expect(u[9], 1);
      expect(u.length, 11 + 8);
      // No glass region declared to the compositor.
      expect(find.byType(Glass), findsNothing);
      await press.up();
      await tester.pumpAndSettle();
      expect(find.byKey(refraction), findsNothing);
    });

    testWidgets('the refraction grows with the presence', (tester) async {
      await impeller(tester);
      await pumpClock(tester, [], initial: 1);
      final press = await tester.startGesture(segmentCenter(tester, 1));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 110));
      final box = tester.renderObject<RenderGlassLensBackdrop>(
        find.byKey(const ValueKey('glass lens refraction')),
      );
      final u = box.debugUniforms;
      expect(u[9], inExclusiveRange(0, 1));
      expect(u[5], inExclusiveRange(1, 1.11));
      expect(u[6], lessThan(GlassLensMetrics.refractionDepth));
      await press.up();
      await tester.pumpAndSettle();
    });

    testWidgets('without shader filters: the magnified copy, labels cut out', (
      tester,
    ) async {
      GlassLens.debugRefractionSupportedOverride = false;
      expect(GlassLens.usesBackdrop, isFalse);
      await pumpClock(tester, [], initial: 1);
      final press = await tester.startGesture(segmentCenter(tester, 1));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('glass lens refraction')), findsNothing);
      expect(
        find.descendant(of: find.byKey(lensKey), matching: find.text('Alarms')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ClipPath>(find.byKey(const ValueKey('segmented labels')))
            .clipper,
        isNotNull,
      );
      await press.up();
      await tester.pumpAndSettle();
    });
  });
}
