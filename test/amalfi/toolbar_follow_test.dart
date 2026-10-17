// The leading toolbar items follow the sidebar edge: x = max(closed x, edge + offset).

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

import 'support/harness.dart';

void main() {
  group('AmalfiToolbarFollow', () {
    test('the toggle is at width - 52 when open and 96 when closed', () {
      expect(AmalfiToolbarFollow.toggleX(240), 188);
      expect(AmalfiToolbarFollow.toggleX(0), 96);
      expect(AmalfiToolbarFollow.toggleX(148), 96);
      expect(AmalfiToolbarFollow.toggleX(149), 97);
    });

    test('a block that starts at the edge keeps a non-negative inset', () {
      // Back/forward + title: 140 when closed, edge + 12 when open.
      double inset(double edge) =>
          AmalfiToolbarFollow.inset(edge: edge, closedX: 140, offset: 12);
      expect(inset(240), 12);
      expect(inset(0), 140);
      expect(inset(100), 40);
      expect(inset(128), 12);
    });

    testWidgets('follows the reveal frame by frame', (tester) async {
      final visible = ValueNotifier<bool>(true);
      Widget scene() => ValueListenableBuilder<bool>(
        valueListenable: visible,
        builder: (context, v, _) => SizedBox(
          width: 600,
          height: 52,
          child: AmalfiSidebarRevealBuilder(
            visible: v,
            builder: (context, progress) => Stack(
              children: [
                AmalfiToolbarFollower(
                  edge: 240 * progress,
                  child: const SizedBox(key: ValueKey('toggle'), width: 44),
                ),
              ],
            ),
          ),
        ),
      );
      double x() => tester.getTopLeft(find.byKey(const ValueKey('toggle'))).dx;
      await pumpKitScene(tester, scene());
      expect(x(), 188);
      visible.value = false;
      await tester.pump();
      var last = x();
      for (var i = 0; i < 24; i++) {
        await tester.pump(const Duration(milliseconds: 10));
        expect(x(), lessThanOrEqualTo(last));
        expect(x(), greaterThanOrEqualTo(96));
        last = x();
      }
      expect(x(), 96);
    });
  });
}
