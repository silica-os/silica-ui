// The imperative Amalfi sheet: shown over the window, modal, closed with a value or Esc.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  late BuildContext host;
  var taps = 0;

  Future<void> pumpWindow(WidgetTester tester) async {
    taps = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(size: Size(600, 400)),
          child: Overlay(
            initialEntries: [
              OverlayEntry(
                builder: (context) {
                  host = context;
                  return GestureDetector(
                    key: const ValueKey('window'),
                    behavior: HitTestBehavior.opaque,
                    onTap: () => taps++,
                    child: const SizedBox.expand(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget sheetBody(BuildContext context, AmalfiSheetRoute<int> sheet) =>
      GestureDetector(
        key: const ValueKey('sheet'),
        behavior: HitTestBehavior.opaque,
        onTap: () => sheet.close(7),
        child: const SizedBox(width: 300, height: 120),
      );

  testWidgets(
    'it slides in from the title bar, dims the window and takes its clicks',
    (tester) async {
      await pumpWindow(tester);
      final result = showAmalfiSheet<int>(host, builder: sheetBody);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byKey(const ValueKey('sheet')), findsOneWidget);
      expect(find.byType(AmalfiSheetScrim), findsOneWidget);
      // Hangs centred from the title bar.
      final rect = tester.getRect(find.byKey(const ValueKey('sheet')));
      expect(
        rect.center.dx,
        closeTo(
          tester.view.physicalSize.width / tester.view.devicePixelRatio / 2,
          0.5,
        ),
      );
      expect(
        rect.top,
        closeTo(toolbarHeight - AmalfiSheetMetrics.titleBarOverlap, 1),
      );
      // The window behind takes no clicks.
      await tester.tapAt(const Offset(20, 380));
      expect(taps, 0);
      await tester.tap(find.byKey(const ValueKey('sheet')));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 600));
      expect(await result, 7);
      expect(find.byKey(const ValueKey('sheet')), findsNothing);
      await tester.tapAt(const Offset(20, 380));
      expect(taps, 1);
    },
  );

  testWidgets('Esc cancels with null, unless the sheet cannot be cancelled', (
    tester,
  ) async {
    await pumpWindow(tester);
    final result = showAmalfiSheet<int>(host, builder: sheetBody);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 600));
    expect(await result, isNull);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const ValueKey('sheet')), findsNothing);

    final kept = showAmalfiSheet<int>(
      host,
      builder: sheetBody,
      cancelOnEscape: false,
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byKey(const ValueKey('sheet')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sheet')));
    await tester.pump(const Duration(milliseconds: 600));
    expect(await kept, 7);
  });
}
