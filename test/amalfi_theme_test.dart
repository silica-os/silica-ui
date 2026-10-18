// The smooth-corner border and the Amalfi theme.

import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

void _expectRect(Rect actual, Rect expected) {
  expect(actual.left, closeTo(expected.left, 1e-3));
  expect(actual.top, closeTo(expected.top, 1e-3));
  expect(actual.right, closeTo(expected.right, 1e-3));
  expect(actual.bottom, closeTo(expected.bottom, 1e-3));
}

void main() {
  group('AmalfiSmoothBorder', () {
    const rect = Rect.fromLTWH(10, 20, 100, 60);

    test('the path fills the rect exactly', () {
      final path = const AmalfiSmoothBorder(radius: 20).getOuterPath(rect);
      _expectRect(path.getBounds(), rect);
      expect(path.contains(rect.center), isTrue);
    });

    test('corners are rounded outward, smoother than a circular arc', () {
      final smooth = smoothRectPath(rect, 20, 0.6);
      final circular = smoothRectPath(rect, 20, 0);
      final vertex = rect.topLeft;
      // The vertex area is cut away, the inside of the corner is kept.
      expect(smooth.contains(vertex + const Offset(1, 1)), isFalse);
      expect(smooth.contains(vertex + const Offset(12, 12)), isTrue);
      // Straight sides: just inside the top edge, past where the corner starts.
      expect(smooth.contains(vertex + const Offset(50, 0.5)), isTrue);
      // With smoothing the corner starts farther from the vertex ((1 + 0.6) × 20 = 32
      // instead of 20): where the circular arc meets the top edge, the smooth one is
      // still below it.
      expect(circular.contains(vertex + const Offset(20, 0.1)), isTrue);
      expect(smooth.contains(vertex + const Offset(20, 0.1)), isFalse);
      // Smoothing 0 is a circular arc: on the diagonal at r (1 − 1/√2) ≈ 5.86 from each side.
      expect(circular.contains(vertex + const Offset(5.5, 5.5)), isFalse);
      expect(circular.contains(vertex + const Offset(6.3, 6.3)), isTrue);
      // The four corners are the same.
      for (final corner in [rect.topRight, rect.bottomLeft, rect.bottomRight]) {
        final inward = Offset(
          corner.dx == rect.left ? 1 : -1,
          corner.dy == rect.top ? 1 : -1,
        );
        expect(smooth.contains(corner + inward), isFalse);
        expect(smooth.contains(corner + inward * 12), isTrue);
      }
    });

    test('a radius too large gives a capsule, small shapes stay finite', () {
      const pill = Rect.fromLTWH(0, 0, 80, 32);
      final capsule = smoothRectPath(pill, 100, 0.6);
      _expectRect(capsule.getBounds(), pill);
      expect(capsule.contains(const Offset(16, 16)), isTrue);
      expect(capsule.contains(const Offset(2, 2)), isFalse);
      const tiny = Rect.fromLTWH(0, 0, 30, 20);
      _expectRect(smoothRectPath(tiny, 9, 0.6).getBounds(), tiny);
    });

    test('degenerate input never throws', () {
      expect(smoothRectPath(Rect.zero, 10, 0.6).getBounds(), Rect.zero);
      expect(
        smoothRectPath(const Rect.fromLTWH(0, 0, -5, 10), 10, 0.6).getBounds(),
        Rect.zero,
      );
      _expectRect(smoothRectPath(rect, 0, 0.6).getBounds(), rect);
      _expectRect(smoothRectPath(rect, double.nan, 0.6).getBounds(), rect);
      _expectRect(smoothRectPath(rect, 20, double.infinity).getBounds(), rect);
      _expectRect(smoothRectPath(rect, -4, 2).getBounds(), rect);
    });

    test('inner path, paint, scale, lerp', () {
      const border = AmalfiSmoothBorder(
        radius: 12,
        side: BorderSide(width: 2, color: Color(0xFF000000)),
      );
      _expectRect(border.getInnerPath(rect).getBounds(), rect.deflate(2));
      expect(border.dimensions, const EdgeInsets.all(2));
      final recorder = ui.PictureRecorder();
      border.paint(Canvas(recorder), rect);
      recorder.endRecording().dispose();
      expect(border.scale(2).radius, 24);
      expect(border.copyWith(radius: 4).radius, 4);
      final mid = ShapeBorder.lerp(
        const AmalfiSmoothBorder(radius: 0),
        const AmalfiSmoothBorder(radius: 20),
        0.5,
      );
      expect(mid, const AmalfiSmoothBorder(radius: 10));
      expect(const AmalfiSmoothBorder().smoothing, AmalfiRadii.smoothing);
    });

    test('a uniform border is the same as the same radius on each corner', () {
      const uniform = AmalfiSmoothBorder(radius: 14);
      const only = AmalfiSmoothBorder.only(
        topLeft: 14,
        topRight: 14,
        bottomRight: 14,
        bottomLeft: 14,
      );
      expect(only, uniform);
      expect(only.hashCode, uniform.hashCode);
      expect(only.isUniform, isTrue);
      expect(only.radius, 14);
      expect(uniform.radii, [14, 14, 14, 14]);
      expect(uniform.toString(), contains('radius: 14.0'));
      // Same outline: sample rows near the top and bottom edges.
      final a = uniform.getOuterPath(rect);
      final b = only.getOuterPath(rect);
      for (var x = rect.left; x <= rect.right; x += 0.5) {
        for (final y in [rect.top + 0.3, rect.top + 3, rect.bottom - 3]) {
          expect(b.contains(Offset(x, y)), a.contains(Offset(x, y)));
        }
      }
    });

    test('each corner has its own radius, 0 is square', () {
      const border = AmalfiSmoothBorder.only(topLeft: 20, bottomRight: 10);
      expect(border.isUniform, isFalse);
      expect(border.radius, 20);
      expect(border.radii, [20, 0, 10, 0]);
      expect(border.toString(), contains('bottomRight: 10.0'));
      final path = border.getOuterPath(rect);
      _expectRect(path.getBounds(), rect);
      // Square corners keep their vertex.
      expect(path.contains(rect.topRight + const Offset(-0.5, 0.5)), isTrue);
      expect(path.contains(rect.bottomLeft + const Offset(0.5, -0.5)), isTrue);
      // Rounded ones cut it away, each by its own radius.
      expect(path.contains(rect.topLeft + const Offset(1, 1)), isFalse);
      expect(path.contains(rect.topLeft + const Offset(12, 12)), isTrue);
      expect(path.contains(rect.bottomRight + const Offset(-1, -1)), isFalse);
      expect(path.contains(rect.bottomRight + const Offset(-5, -5)), isTrue);
      // Where the 20 corner is still curving (32 from the vertex along the top edge), the
      // 10 one (16) is already straight.
      expect(path.contains(rect.topLeft + const Offset(20, 0.1)), isFalse);
      expect(path.contains(rect.bottomRight + const Offset(-20, -0.1)), isTrue);
      // The smooth corner matches the uniform one at that corner.
      final uniform = smoothRectPath(rect, 20, AmalfiRadii.smoothing);
      for (var i = 0.0; i < 32; i += 0.5) {
        for (final o in [Offset(i, 0.4), Offset(0.4, i), Offset(i, i / 2)]) {
          final p = rect.topLeft + o;
          expect(path.contains(p), uniform.contains(p), reason: '$o');
        }
      }
    });

    test('a capsule keeps the smoothing along its long sides, as the kit', () {
      // The kit's 72 × 28 push button: the top edge is straight up to 1.6 × 14 = 22.4 from
      // each end, the first Bézier ends on the circle at (64.356, 1.526) and the ends meet
      // the short sides as a circle, at mid-height.
      const pill = Rect.fromLTWH(0, 0, 72, 28);
      final path = smoothRectPath(pill, 14, AmalfiRadii.smoothing);
      _expectRect(path.getBounds(), pill);
      expect(path.contains(const Offset(49.4, 0.02)), isTrue);
      expect(path.contains(const Offset(22.6, 0.02)), isTrue);
      expect(path.contains(const Offset(64.356, 1.7)), isTrue);
      expect(path.contains(const Offset(64.356, 1.35)), isFalse);
      expect(path.contains(const Offset(71.95, 14)), isTrue);
      expect(path.contains(const Offset(71.95, 12)), isFalse);
      // A circle with the same radius would already be at the edge at 58.
      expect(
        smoothRectPath(pill, 14, 0).contains(const Offset(58, 0.05)),
        isTrue,
      );
      expect(path.contains(const Offset(58, 0.05)), isFalse);
    });

    test('per-corner radii clamp to a capsule end', () {
      // A segment end: left capsule, right square.
      const pill = Rect.fromLTWH(0, 0, 60, 24);
      final end = smoothRectPathOnly(pill, topLeft: 50, bottomLeft: 50);
      _expectRect(end.getBounds(), pill);
      final capsule = smoothRectPath(pill, 50, AmalfiRadii.smoothing);
      for (var x = 0.0; x <= 12; x += 0.5) {
        for (var y = 0.0; y <= 24; y += 0.5) {
          final p = Offset(x, y);
          expect(end.contains(p), capsule.contains(p), reason: '$p');
        }
      }
      expect(end.contains(const Offset(59.5, 0.5)), isTrue);
      expect(end.contains(const Offset(59.5, 23.5)), isTrue);
      // Degenerate corners never throw.
      _expectRect(
        smoothRectPathOnly(
          rect,
          topLeft: double.nan,
          topRight: -3,
          bottomRight: double.infinity,
          smoothing: double.nan,
        ).getBounds(),
        rect,
      );
      expect(smoothRectPathOnly(Rect.zero, topLeft: 4).getBounds(), Rect.zero);
    });

    test('per-corner scale, copyWith, lerp, inflate, inner path, paint', () {
      const border = AmalfiSmoothBorder.only(
        topLeft: 6,
        bottomLeft: 6,
        side: BorderSide(width: 2, color: Color(0xFF000000)),
      );
      expect(border.scale(2).radii, [12, 0, 0, 12]);
      expect(border.copyWithCorners(topRight: 3).radii, [6, 3, 0, 6]);
      expect(border.copyWith(radius: 4).radii, [4, 4, 4, 4]);
      expect(border.copyWith(radius: 4).copyWithCorners(topLeft: 1).radii, [
        1,
        4,
        4,
        4,
      ]);
      expect(border.inflateRadii(2).radii, [8, 0, 0, 8]);
      expect(border.inflateRadii(-10).radii, [0, 0, 0, 0]);
      final mid = ShapeBorder.lerp(
        const AmalfiSmoothBorder(radius: 10),
        const AmalfiSmoothBorder.only(topLeft: 20),
        0.5,
      );
      expect(
        mid,
        const AmalfiSmoothBorder.only(
          topLeft: 15,
          topRight: 5,
          bottomRight: 5,
          bottomLeft: 5,
        ),
      );
      expect(
        const AmalfiSmoothBorder.only(
          topRight: 8,
        ).lerpTo(const AmalfiSmoothBorder(radius: 8), 1),
        const AmalfiSmoothBorder(radius: 8),
      );
      final inner = border.getInnerPath(rect);
      _expectRect(inner.getBounds(), rect.deflate(2));
      // The inner path keeps square corners square.
      expect(inner.contains(rect.topRight + const Offset(-2.5, 2.5)), isTrue);
      for (final align in [
        BorderSide.strokeAlignInside,
        BorderSide.strokeAlignCenter,
        BorderSide.strokeAlignOutside,
      ]) {
        final recorder = ui.PictureRecorder();
        border
            .copyWith(side: border.side.copyWith(strokeAlign: align))
            .paint(Canvas(recorder), rect);
        recorder.endRecording().dispose();
      }
    });

    testWidgets('draws as a decoration', (tester) async {
      await tester.pumpWidget(
        const Center(
          child: DecoratedBox(
            decoration: ShapeDecoration(
              color: Color(0xFF0E77E6),
              shape: AmalfiSmoothBorder(
                radius: AmalfiRadii.window,
                side: BorderSide(color: Color(0x1A000000)),
              ),
              shadows: [
                BoxShadow(
                  color: Color(0x2E000000),
                  offset: Offset(0, 12),
                  blurRadius: 32,
                ),
              ],
            ),
            child: SizedBox(width: 200, height: 120),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('AmalfiTheme', () {
    Widget host(Brightness system, Widget child) => MediaQuery(
      data: MediaQueryData(platformBrightness: system),
      child: Directionality(textDirection: TextDirection.ltr, child: child),
    );

    testWidgets('without a theme it follows the appearance in effect', (
      tester,
    ) async {
      late AmalfiThemeData data;
      await tester.pumpWidget(
        host(
          Brightness.dark,
          Builder(
            builder: (context) {
              data = AmalfiTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      );
      expect(data.brightness, Brightness.dark);
      expect(data.colors, same(AmalfiColors.dark));
      expect(data.shadows, same(AmalfiShadows.dark));
      expect(data.appColors, isNull);
    });

    testWidgets(
      'forces a brightness and an app palette; nested themes keep the app',
      (tester) async {
        late AmalfiThemeData outer;
        late AmalfiThemeData inner;
        await tester.pumpWidget(
          host(
            Brightness.light,
            AmalfiTheme(
              brightness: Brightness.dark,
              app: 'Mail',
              child: Builder(
                builder: (context) {
                  outer = AmalfiTheme.of(context);
                  return AmalfiTheme(
                    brightness: Brightness.light,
                    child: Builder(
                      builder: (context) {
                        inner = AmalfiTheme.of(context);
                        return const SizedBox();
                      },
                    ),
                  );
                },
              ),
            ),
          ),
        );
        expect(outer.isDark, isTrue);
        expect(outer.appColor('Flag'), AmalfiColors.dark.mail.flag);
        expect(outer.appColors, same(AmalfiColors.dark.mail));
        expect(inner.isDark, isFalse);
        expect(inner.app, 'Mail');
        expect(inner.appColor('Flag'), AmalfiColors.light.mail.flag);
        expect(inner.appColor('Nope'), isNull);
      },
    );

    testWidgets('follows SilicaAppearanceScope', (tester) async {
      late AmalfiThemeData data;
      await tester.pumpWidget(
        host(
          Brightness.light,
          SilicaAppearanceScope(
            appearance: SilicaAppearance.dark,
            child: AmalfiTheme(
              app: 'Clock',
              child: Builder(
                builder: (context) {
                  data = AmalfiTheme.of(context);
                  return const SizedBox();
                },
              ),
            ),
          ),
        ),
      );
      expect(data.brightness, Brightness.dark);
      expect(data.appColors?.app, 'Clock');
      expect(data.appColor('Accent'), AmalfiColors.dark.clock.accent);
    });

    test('an unknown app has no palette', () {
      const data = AmalfiThemeData.light(app: 'Unknown');
      expect(data.appColors, isNull);
      expect(data.appColor('Accent'), isNull);
      expect(
        data,
        const AmalfiThemeData(brightness: Brightness.light, app: 'Unknown'),
      );
    });
  });
}
