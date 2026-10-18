import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SilicaWindow.channel, (call) async {
          calls.add(call);
          return call.method == 'setFullSizeContent' ? true : null;
        });
  });

  test('size and size limits go to the embedder', () async {
    expect(await SilicaWindow.setFixedSize(const Size(230, 408)), isFalse);
    final methods = calls.map((c) => c.method).toList();
    expect(methods, ['setSizeLimits']);
    expect(calls.single.arguments, {
      'minWidth': 230.0,
      'minHeight': 408.0,
      'maxWidth': 230.0,
      'maxHeight': 408.0,
    });
  });

  test('the window is exported for the dialogs of other apps', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SilicaWindow.channel, (call) async {
          calls.add(call);
          return 'wayland:h4ndle';
        });
    expect(await SilicaWindow.exportHandle(), 'wayland:h4ndle');
    expect(calls.single.method, 'exportHandle');
    expect(calls.single.arguments, isNull);
    expect(await SilicaWindow.exportHandle(viewId: 3), 'wayland:h4ndle');
    expect(calls.last.arguments, {'viewId': 3});
  });

  test('without the embedder or the protocol there is no handle', () async {
    // The mock answers null: an embedder or a compositor without xdg-foreign.
    expect(await SilicaWindow.exportHandle(), isNull);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SilicaWindow.channel, null);
    expect(await SilicaWindow.exportHandle(), isNull);
  });

  test('full-size content', () async {
    expect(await SilicaWindow.setFullSizeContent(52), isTrue);
    expect(calls.single.method, 'setFullSizeContent');
    expect((calls.single.arguments as Map)['toolbarHeight'], 52);
  });

  testWidgets(
    'dragging the empty part moves the window; controls receive the click',
    (tester) async {
      var tapped = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: WindowDragArea(
            child: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 400,
                height: toolbarHeight,
                child: Align(
                  alignment: Alignment.centerRight,
                  child: ToolbarCapsule(
                    separators: true,
                    children: [
                      ToolbarSegment(
                        key: const ValueKey('a'),
                        icon: (c) => SizedBox(
                          width: 8,
                          height: 14,
                          child: ColoredBox(color: c),
                        ),
                        onTap: () => tapped++,
                      ),
                      ToolbarSegment(
                        icon: (c) => const SizedBox(width: 8, height: 14),
                        chosen: true,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.getSize(find.byType(ToolbarCapsule)).height,
        toolbarCapsuleHeight,
      );
      await tester.tap(find.byKey(const ValueKey('a')));
      expect(tapped, 1);
      // Dragging from a control does not move the window.
      final fromControl = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('a'))),
        kind: PointerDeviceKind.mouse,
      );
      await fromControl.moveBy(const Offset(-40, 0));
      await fromControl.up();
      await tester.pump();
      expect(calls, isEmpty);
      final gesture = await tester.startGesture(
        const Offset(20, 26),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(30, 0));
      await gesture.up();
      await tester.pump();
      expect(calls.map((c) => c.method), contains('startMove'));
      // The double tap recognizer's timeout.
      await tester.pump(const Duration(milliseconds: 400));
    },
  );

  testWidgets('a double click on the empty bar zooms or minimizes as chosen', (
    tester,
  ) async {
    // The Settings service's key (silica-desktop#240), here in memory.
    final backend = MemorySettingsBackend({});
    SilicaSettings.useBackend(backend);
    addTearDown(() => SilicaSettings.useBackend(MemorySettingsBackend({})));
    Future<void> doubleTap() async {
      await tester.tapAt(const Offset(20, 26));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tapAt(const Offset(20, 26));
      await tester.pump(const Duration(milliseconds: 500));
    }

    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: WindowDragArea(
          child: SizedBox(width: 400, height: toolbarHeight),
        ),
      ),
    );
    await doubleTap();
    expect(calls.map((c) => c.method), ['zoom']);
    calls.clear();
    backend.emit(SilicaWindow.titleBarDoubleClickKey, 'minimize');
    await doubleTap();
    expect(calls.map((c) => c.method), ['minimize']);
    calls.clear();
    backend.emit(SilicaWindow.titleBarDoubleClickKey, 'none');
    await doubleTap();
    expect(calls, isEmpty);
  });

  testWidgets('a drag on a SegmentedControl in the toolbar does not move the '
      'window; a drag on the empty toolbar does', (tester) async {
    var selected = 0;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 600,
            height: toolbarHeight,
            child: WindowDragArea(
              child: Center(
                child: SegmentedControl(
                  segments: const [
                    Segment(label: 'World'),
                    Segment(label: 'Alarms'),
                    Segment(label: 'Stopwatch'),
                    Segment(label: 'Timers'),
                  ],
                  selected: {selected},
                  onChanged: (i) => selected = i,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    final center = tester.getCenter(find.byType(SegmentedControl));
    for (final delta in const [Offset(40, 0), Offset(0, 30), Offset(30, 20)]) {
      final g = await tester.startGesture(
        center,
        kind: PointerDeviceKind.mouse,
      );
      await g.moveBy(delta);
      await g.moveBy(delta);
      await g.up();
      await tester.pump();
    }
    expect(calls.map((c) => c.method), isNot(contains('startMove')));
    final empty = await tester.startGesture(
      const Offset(10, 26),
      kind: PointerDeviceKind.mouse,
    );
    await empty.moveBy(const Offset(30, 0));
    await empty.up();
    await tester.pump();
    expect(calls.map((c) => c.method), contains('startMove'));
    await tester.pump(const Duration(milliseconds: 400));
  });

  testWidgets('capsules follow the system appearance', (tester) async {
    Color? drawn;
    Future<void> pump(Brightness b) => tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(platformBrightness: b),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: ToolbarCapsule(
              children: [
                ToolbarSegment(
                  icon: (color) {
                    drawn = color;
                    return const SizedBox(width: 10, height: 10);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await pump(Brightness.light);
    expect(drawn, ToolbarColors.light.icon);
    await pump(Brightness.dark);
    expect(drawn, ToolbarColors.dark.icon);
  });

  testWidgets(
    'a drag area limited to a band moves the window only from the band',
    (tester) async {
      // A whole window with full-size content, as SilicaWindowHost wraps it (silica-ui#101):
      // the app draws no drag area of its own.
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: WindowDragArea(
            band: toolbarHeight,
            child: ColoredBox(color: Color(0xFF202020)),
          ),
        ),
      );
      Future<void> drag(Offset from) async {
        final gesture = await tester.startGesture(
          from,
          kind: PointerDeviceKind.mouse,
        );
        await gesture.moveBy(const Offset(40, 0));
        await gesture.up();
        await tester.pump(const Duration(milliseconds: 600));
      }

      // Below the band: the content, not a move.
      await drag(const Offset(200, 120));
      expect(calls.map((c) => c.method), isNot(contains('startMove')));
      // In the band: the window moves.
      await drag(const Offset(200, 26));
      expect(calls.map((c) => c.method), contains('startMove'));
    },
  );

  testWidgets('a drag area inside the band takes the press first', (
    tester,
  ) async {
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: WindowDragArea(
          band: toolbarHeight,
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: toolbarHeight,
              child: WindowDragArea(child: SizedBox.expand()),
            ),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      const Offset(200, 26),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(40, 0));
    await gesture.up();
    await tester.pump(const Duration(milliseconds: 600));
    // One move, from the inner area.
    expect(calls.where((c) => c.method == 'startMove'), hasLength(1));
  });
}
