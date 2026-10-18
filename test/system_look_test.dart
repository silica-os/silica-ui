// The system look: parsed from the daemon's state, followed live, applied by the controls.

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

Widget scoped(Widget child) => Directionality(
  textDirection: TextDirection.ltr,
  child: MediaQuery(
    data: const MediaQueryData(),
    child: SystemLookScope(child: child),
  ),
);

class _Probe extends StatefulWidget {
  const _Probe(this.child);
  final Widget child;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) => widget.child;
}

void main() {
  tearDown(SilicaSystemLook.reset);

  test('a state without look keys is the default look', () {
    expect(SystemLook.fromState(const {}), const SystemLook());
  });

  test('look keys are parsed, odd values fall back', () {
    final look = SystemLook.fromState({
      'look.accent': 'multicolour',
      'look.highlight': 'pink',
      'look.sidebarIconSize': 'large',
      'look.scrollBars': 'always',
      'look.scrollClick': 'spot',
      'look.iconStyle': 'tinted',
      'look.folderColour': 'green',
      'look.glass': 7.0,
      'look.windowTint': true,
    });
    expect(look.accent, SilicaAccent.multicolor);
    expect(look.highlight, SilicaAccent.pink);
    expect(look.sidebarIconSize, SystemSidebarIconSize.large);
    expect(look.scrollBars, SystemScrollBars.always);
    expect(look.scrollClick, SystemScrollClick.spot);
    expect(look.iconStyle, SystemIconStyle.tinted);
    expect(look.folderColour, SilicaAccent.green);
    expect(look.glass, 1);
    expect(look.windowTint, isTrue);
    final odd = SystemLook.fromState({
      'look.accent': 'mauve',
      'look.scrollBars': 3,
      'look.glass': 'x',
    });
    expect(odd.accent, SilicaAccent.multicolor);
    expect(odd.scrollBars, SystemScrollBars.automatic);
    expect(odd.glass, 0.5);
  });

  testWidgets('the Amalfi accent follows the chosen accent', (tester) async {
    late AmalfiThemeData theme;
    await tester.pumpWidget(
      scoped(
        Builder(
          builder: (context) {
            theme = AmalfiTheme.of(context);
            return const SizedBox();
          },
        ),
      ),
    );
    final blue = theme.colors.accentAmalfi;
    SilicaSystemLook.apply(const SystemLook(accent: SilicaAccent.green));
    await tester.pump();
    expect(theme.colors.accentAmalfi, isNot(blue));
    expect(
      theme.colors.accentAmalfi,
      AccentColors.of(SilicaAccent.green, dark: false).plain,
    );
    SilicaSystemLook.apply(const SystemLook());
    await tester.pump();
    expect(theme.colors.accentAmalfi, blue);
  });

  testWidgets('the highlight colour is the selection colour', (tester) async {
    late AmalfiThemeData theme;
    await tester.pumpWidget(
      scoped(
        _Probe(
          Builder(
            builder: (context) {
              theme = AmalfiTheme.of(context);
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    final automatic = theme.selectionColor;
    final state = tester.state(find.byType(_Probe));
    SilicaSystemLook.apply(const SystemLook(highlight: SilicaAccent.red));
    await tester.pump();
    expect(theme.selectionColor, isNot(automatic));
    // The tree below keeps its state when the highlight changes.
    expect(tester.state(find.byType(_Probe)), same(state));
  });

  testWidgets('a daemon without the look leaves the look as it is', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SilicaDBus.channel,
          (call) async => [
            {'wifi.enabled': true},
          ],
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SilicaDBus.channel, null),
    );
    SilicaSystemLook.apply(const SystemLook(accent: SilicaAccent.pink));
    await SilicaSystemLook.refresh();
    expect(SilicaSystemLook.current.accent, SilicaAccent.pink);
  });

  testWidgets('the state is read once, then follows the Changed signal', (
    tester,
  ) async {
    final calls = <String>[];
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SilicaDBus.channel, (call) async {
      final args = call.arguments as Map;
      calls.add('${call.method} ${args['method'] ?? args['member'] ?? ''}');
      return switch (call.method) {
        'subscribe' => calls.where((c) => c.startsWith('subscribe')).length,
        'unsubscribe' => true,
        _ => [
          {'look.accent': 'red', 'look.scrollClick': 'spot'},
        ],
      };
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SilicaDBus.channel, null),
    );
    await tester.pumpWidget(scoped(const SizedBox()));
    await tester.pump();
    expect(calls.where((c) => c == 'call State'), hasLength(1));
    expect(calls, contains('subscribe Changed'));
    expect(SilicaSystemLook.current.accent, SilicaAccent.red);
    expect(SilicaSystemLook.current.scrollClick, SystemScrollClick.spot);
    // The daemon changes the look: the signal carries the state (subscription id 1).
    Future<void> signal(int id, Map<String, Object?> state) =>
        messenger.handlePlatformMessage(
          'silica/dbus',
          const JSONMethodCodec().encodeMethodCall(
            MethodCall('signal', {
              'id': id,
              'sender': ':1.5',
              'path': '/dev/frascella/Silica/System1',
              'interface': 'dev.frascella.Silica.System1',
              'member': 'Changed',
              'args': [state],
            }),
          ),
          (_) {},
        );
    await signal(1, {'look.accent': 'green', 'look.iconStyle': 'dark'});
    await tester.pump();
    expect(SilicaSystemLook.current.accent, SilicaAccent.green);
    expect(SilicaSystemLook.current.iconStyle, SystemIconStyle.dark);
    // A state without the look (an older daemon) changes nothing.
    await signal(1, {'wifi.enabled': true});
    await tester.pump();
    expect(SilicaSystemLook.current.accent, SilicaAccent.green);
    await tester.pumpWidget(const SizedBox());
    expect(calls, contains('unsubscribe '));
  });

  testWidgets('the app and the library both get signals from the one channel', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var next = 0;
    messenger.setMockMethodCallHandler(SilicaDBus.channel, (call) async {
      return switch (call.method) {
        'subscribe' => ++next,
        'unsubscribe' => true,
        _ => const <Object?>[],
      };
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SilicaDBus.channel, null),
    );
    final seen = <String>[];
    final a = SilicaDBus.instance
        .signals(member: 'A')
        .listen((s) => seen.add('a ${s.member}'));
    final b = SilicaDBus.instance
        .signals(member: 'B')
        .listen((s) => seen.add('b ${s.member}'));
    await tester.pump();
    Future<void> signal(int id, String member) =>
        messenger.handlePlatformMessage(
          'silica/dbus',
          const JSONMethodCodec().encodeMethodCall(
            MethodCall('signal', {'id': id, 'member': member, 'args': []}),
          ),
          (_) {},
        );
    await signal(1, 'A');
    await signal(2, 'B');
    await tester.pump();
    expect(seen, ['a A', 'b B']);
    await a.cancel();
    await b.cancel();
  });

  testWidgets('a click in the track jumps to the spot or pages', (
    tester,
  ) async {
    final controller = ScrollController();
    addTearDown(controller.dispose);
    Future<void> pump() async {
      await tester.pumpWidget(
        scoped(
          Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 200,
              height: 200,
              child: AmalfiScrollbar(
                style: AmalfiScrollbarStyle.legacy,
                child: SingleChildScrollView(
                  controller: controller,
                  child: const SizedBox(height: 1000, width: 100),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      controller.jumpTo(1);
      await tester.pump();
      controller.jumpTo(0);
      await tester.pump();
    }

    await pump();
    // Thumb: 40 of 200 at the top. Click at the bottom of the track.
    const click = Offset(194, 180);
    var gesture = await tester.startGesture(
      click,
      kind: PointerDeviceKind.mouse,
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(controller.offset, 200, reason: 'one page');
    controller.jumpTo(0);
    SilicaSystemLook.apply(
      const SystemLook(scrollClick: SystemScrollClick.spot),
    );
    await tester.pump();
    gesture = await tester.startGesture(click, kind: PointerDeviceKind.mouse);
    await gesture.up();
    await tester.pumpAndSettle();
    // The thumb centres on y 180: (180 - 20) / 160 of the range.
    expect(controller.offset, closeTo(800, 1));
  });

  testWidgets('an icon without a style of its own follows the icon style', (
    tester,
  ) async {
    await tester.pumpWidget(
      scoped(const SilicaIcon(FlatSource('/nonexistent.svg'), side: 32)),
    );
    expect(find.byType(SilicaIcon), findsOneWidget);
    SilicaSystemLook.apply(
      const SystemLook(
        iconStyle: SystemIconStyle.tinted,
        accent: SilicaAccent.green,
      ),
    );
    await tester.pump();
    final icons = tester.widgetList<SilicaIcon>(find.byType(SilicaIcon));
    expect(icons.length, 2);
    expect(icons.last.appearance, IconAppearance.tinted);
    expect(icons.last.tint, isNotNull);
    // An icon with its own style keeps it.
    await tester.pumpWidget(
      scoped(
        const SilicaIcon(
          FlatSource('/nonexistent.svg'),
          side: 32,
          appearance: IconAppearance.light,
        ),
      ),
    );
    expect(find.byType(SilicaIcon), findsOneWidget);
  });

  testWidgets('Tab reaches the controls only with keyboard navigation', (
    tester,
  ) async {
    var pressed = 0;
    await tester.pumpWidget(
      scoped(
        Shortcuts(
          shortcuts: WidgetsApp.defaultShortcuts,
          child: Actions(
            actions: WidgetsApp.defaultActions,
            child: Focus(
              autofocus: true,
              child: Align(
                alignment: Alignment.topLeft,
                child: AmalfiPushButton(
                  label: 'One',
                  onPressed: () => pressed++,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(pressed, 0, reason: 'skipped by Tab');
    SilicaSystemLook.apply(const SystemLook(keyboardNavigation: true));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    expect(pressed, 1);
    expect(
      SystemLook.fromState(const {
        'look.keyboardNavigation': true,
      }).keyboardNavigation,
      isTrue,
    );
  });

  testWidgets('the double click time is the one chosen in Settings', (
    tester,
  ) async {
    var doubles = 0;
    await tester.pumpWidget(
      scoped(
        Align(
          alignment: Alignment.topLeft,
          child: SilicaDoubleTap(
            onDoubleTap: () => doubles++,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(width: 100, height: 100),
          ),
        ),
      ),
    );
    var clock = Duration.zero;
    var pointer = 0;
    Future<void> click(Duration after) async {
      clock += after;
      pointer++;
      await tester.sendEventToBinding(
        PointerDownEvent(
          pointer: pointer,
          position: const Offset(50, 50),
          timeStamp: clock,
        ),
      );
      await tester.sendEventToBinding(
        PointerUpEvent(
          pointer: pointer,
          position: const Offset(50, 50),
          timeStamp: clock + const Duration(milliseconds: 40),
        ),
      );
    }

    await click(Duration.zero);
    await click(const Duration(milliseconds: 200));
    expect(doubles, 1, reason: '200 ms is within the default 300');
    await click(const Duration(seconds: 2));
    await click(const Duration(milliseconds: 450));
    expect(doubles, 1, reason: '450 ms is too slow for 300');
    await click(const Duration(seconds: 2));
    SilicaSystemLook.apply(const SystemLook(doubleClickMs: 600));
    await click(const Duration(milliseconds: 450));
    expect(doubles, 2, reason: '450 ms is fine for 600');
    expect(
      SystemLook.fromState(const {'look.doubleClickMs': 5000}).doubleClickMs,
      1000,
    );
  });

  testWidgets('Larger Text scales the text of an app, not of a bare scope', (
    tester,
  ) async {
    late TextScaler app;
    late TextScaler bare;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: Column(
            children: [
              SilicaAppearanceScope(
                child: Builder(
                  builder: (context) {
                    app = MediaQuery.textScalerOf(context);
                    return const SizedBox();
                  },
                ),
              ),
              SystemLookScope(
                child: Builder(
                  builder: (context) {
                    bare = MediaQuery.textScalerOf(context);
                    return const SizedBox();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
    expect(app.scale(10), 10);
    SilicaSystemLook.apply(const SystemLook(textScale: 1.3));
    await tester.pump();
    expect(app.scale(10), closeTo(13, 1e-9));
    expect(bare.scale(10), 10);
    expect(SystemLook.fromState(const {'look.textScale': 9.0}).textScale, 1.5);
    expect(SystemLook.fromState(const {}).textScale, 1.0);
  });

  testWidgets('Reduce Motion turns animations off for the widgets below', (
    tester,
  ) async {
    late bool disabled;
    await tester.pumpWidget(
      scoped(
        Builder(
          builder: (context) {
            disabled = MediaQuery.disableAnimationsOf(context);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(disabled, isFalse);
    SilicaSystemLook.apply(const SystemLook(reduceMotion: true));
    await tester.pump();
    expect(disabled, isTrue);
    expect(
      SystemLook.fromState(const {
        'look.reduceTransparency': true,
      }).reduceTransparency,
      isTrue,
    );
  });

  testWidgets('Reduce Transparency draws the Flutter glass opaque', (
    tester,
  ) async {
    Future<void> pump() => tester.pumpWidget(
      scoped(
        const SizedBox(
          width: 100,
          height: 100,
          child: AmalfiGlass(radius: 12, child: SizedBox.expand()),
        ),
      ),
    );
    await pump();
    final blurred = find.byType(BackdropFilter);
    expect(blurred, findsWidgets);
    SilicaSystemLook.apply(const SystemLook(reduceTransparency: true));
    await tester.pump();
    expect(blurred, findsNothing);
  });
}
