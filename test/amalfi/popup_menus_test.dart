// Menus, popovers and pop-up buttons as popups of their own (silica-desktop#4): the calls they
// make on `silica/window`, what they draw in the popup's view, and the fallback to the
// window's overlay when the system offers no popups.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

import 'support/harness.dart';

/// A second view of the test engine, which has only one: it has its own id.
class _PopupView extends TestFlutterView {
  _PopupView(TestFlutterView base, this.id)
    : super(
        view: base,
        platformDispatcher: base.platformDispatcher,
        display: base.display,
      );

  final int id;

  @override
  int get viewId => id;
}

const simpleEntries = <AmalfiMenuEntry>[
  AmalfiMenuAction('Orange'),
  AmalfiMenuAction('Lemon', checked: true),
  AmalfiMenuAction('Olive'),
  AmalfiMenuAction('Fig'),
];

void main() {
  late List<MethodCall> calls;
  late int nextView;

  /// What the embedder answers `openPopup`: the next view id and where it put the popup.
  Object? Function(MethodCall call)? place;

  setUp(() {
    calls = [];
    nextView = 7;
    place = null;
    SilicaWindows.reset();
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      GlassRegistry.channel,
      (_) async => true,
    );
  });

  tearDown(() {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SilicaWindow.channel, null);
    messenger.setMockMethodCallHandler(GlassRegistry.channel, null);
    SilicaWindows.reset();
  });

  /// The embedder offers popups (or not): `openPopup` opens view 7, 8… and says where.
  Future<void> offerPopups(WidgetTester tester, {bool offered = true}) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SilicaWindow.channel, (call) async {
          calls.add(call);
          switch (call.method) {
            case 'popupsAvailable':
              return offered;
            case 'openPopup':
              if (place != null) return place!(call);
              final args = call.arguments as Map;
              final anchor = args['anchorRect'] as List;
              return {
                'viewId': nextView++,
                'x': anchor[0],
                'y': (anchor[1] as num) + (anchor[3] as num),
                'width': args['width'],
                'height': args['height'],
              };
          }
          return null;
        });
    SilicaPopups.debugViewResolver = (id) => _PopupView(tester.view, id);
    await SilicaPopups.probe();
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }
  }

  List<MethodCall> opened() =>
      calls.where((call) => call.method == 'openPopup').toList();

  testWidgets(
    'a popup goes into the overlay it is given, anchored by its edges',
    (tester) async {
      // A shell layer has no root overlay of its own (silica-desktop#222): the caller gives one.
      final overlayKey = GlobalKey<OverlayState>();
      late BuildContext context;
      await pumpKitScene(
        tester,
        Stack(
          children: [
            Builder(
              builder: (c) {
                context = c;
                return const SizedBox(width: 400, height: 300);
              },
            ),
            IgnorePointer(child: Overlay(key: overlayKey)),
          ],
        ),
      );
      await offerPopups(tester);
      showAmalfiAsPopup(
        context: context,
        anchor: const Offset(380, 44) & const Size(1, 1),
        anchorEdge: SilicaPopupEdge.topRight,
        gravity: SilicaPopupEdge.bottomLeft,
        overlay: overlayKey.currentState,
        builder: (context, dismiss, placement) =>
            AmalfiMenu(entries: simpleEntries, onDismiss: dismiss),
      );
      await settle(tester);
      final args = opened().single.arguments as Map;
      expect(args['anchor'], 'top-right');
      expect(args['gravity'], 'bottom-left');
      expect(
        find.descendant(
          of: find.byWidget(overlayKey.currentWidget!),
          matching: find.byType(ViewAnchor),
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets('without popups the menu is drawn in the window, as before', (
    tester,
  ) async {
    late BuildContext context;
    await pumpKitScene(
      tester,
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox(width: 400, height: 300);
        },
      ),
    );
    await offerPopups(tester, offered: false);
    showAmalfiMenu(
      context: context,
      position: const Offset(100, 100),
      entries: simpleEntries,
    );
    await tester.pump();
    await tester.pump(AmalfiFades.instant.duration);
    expect(opened(), isEmpty);
    expect(View.of(tester.element(find.byType(AmalfiMenu))).viewId, 0);
  });

  testWidgets('a popover is a popup, its arrow follows where Ossido put it', (
    tester,
  ) async {
    late BuildContext context;
    await pumpKitScene(
      tester,
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox(width: 400, height: 300);
        },
      ),
    );
    await offerPopups(tester);
    // Ossido flipped it above its anchor and slid it 20 pt to the left.
    place = (call) {
      final args = call.arguments as Map;
      return {
        'viewId': 7,
        'x': 280.0,
        'y': 40.0,
        'width': args['width'],
        'height': args['height'],
      };
    };
    const anchor = Rect.fromLTWH(300, 300, 40, 20);
    showAmalfiPopover(
      context: context,
      anchor: anchor,
      builder: (context, dismiss) => const SizedBox(width: 120, height: 60),
    );
    await settle(tester);

    final args = opened().single.arguments as Map;
    expect(args['parent'], 0);
    expect(args['anchorRect'], [300.0, 300.0, 40.0, 20.0]);
    // Under the anchor, centred, its arrow on the anchor's edge; either side, along the edge.
    expect(args['anchor'], 'bottom');
    expect(args['gravity'], 'bottom');
    expect(args['adjust'], unorderedEquals(['flipX', 'flipY', 'slideX']));
    final popover = tester.widget<AmalfiPopover>(find.byType(AmalfiPopover));
    expect(View.of(tester.element(find.byType(AmalfiPopover))).viewId, 7);
    // The popup is as big as the popover drawn in it, with the compositor's glass (taller than
    // with the in-window glass): nothing of it is cut (silica-desktop#238).
    expect(
      Size(
        (args['width'] as num).toDouble(),
        (args['height'] as num).toDouble(),
      ),
      tester.getSize(find.byType(AmalfiPopover)),
    );
    // It went above: the arrow is on its bottom edge, at the anchor's centre (320 − 280).
    expect(popover.arrowEdge, AmalfiPopoverArrowEdge.bottom);
    expect(popover.arrowOffset, 40);

    // Esc closes it.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await settle(tester);
    expect(
      calls.where((call) => call.method == 'closeWindow').single.arguments,
      {'viewId': 7},
    );
  });

  testWidgets('SilicaPopups.show: the call and what it returns', (
    tester,
  ) async {
    await pumpKitScene(tester, const SizedBox());
    await offerPopups(tester);
    place = (call) => 7;
    final popup = await SilicaPopups.show(
      parent: 0,
      size: const Size(100, 50),
      anchorRect: const Rect.fromLTWH(10, 20, 30, 40),
      anchor: SilicaPopupEdge.topRight,
      gravity: SilicaPopupEdge.left,
      adjust: {SilicaPopupAdjust.flipX},
      grab: false,
    );
    expect(opened().single.arguments, {
      'parent': 0,
      'width': 100.0,
      'height': 50.0,
      'anchorRect': [10.0, 20.0, 30.0, 40.0],
      'anchor': 'top-right',
      'gravity': 'left',
      'adjust': ['flipX'],
      'grab': false,
    });
    // An embedder that answers with the id only (no placement).
    expect(popup, isNotNull);
    expect(popup!.viewId, 7);
    expect(popup.placement, isNull);
    expect(popup.isOpen, isTrue);
    await SilicaWindows.handle('windowClosed', {'viewId': 7});
    expect(popup.isOpen, isFalse);
    await popup.closed;
  });

  testWidgets('a popup whose view the engine does not know is closed again', (
    tester,
  ) async {
    await pumpKitScene(tester, const SizedBox());
    await offerPopups(tester);
    place = (call) => {'viewId': 99};
    final popup = await SilicaPopups.show(
      parent: 0,
      size: const Size(10, 10),
      anchorRect: Rect.zero,
    );
    // The resolver of these tests knows every id: forget this one.
    SilicaPopups.debugViewResolver = null;
    expect(popup, isNotNull);
    final unknown = await SilicaPopups.show(
      parent: 0,
      size: const Size(10, 10),
      anchorRect: Rect.zero,
    );
    expect(unknown, isNull);
    expect(
      calls.where((call) => call.method == 'closeWindow').single.arguments,
      {'viewId': 99},
    );
  });
}
