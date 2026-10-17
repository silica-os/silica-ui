// The system look: parsed from the daemon's state, followed live, applied by the controls.

import 'package:flutter/gestures.dart';
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
          SilicaSystemLook.channel,
          (call) async => [
            {'wifi.enabled': true},
          ],
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SilicaSystemLook.channel, null),
    );
    SilicaSystemLook.apply(const SystemLook(accent: SilicaAccent.pink));
    await SilicaSystemLook.refresh();
    expect(SilicaSystemLook.current.accent, SilicaAccent.pink);
  });

  testWidgets('the daemon state is read from System1', (tester) async {
    final calls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SilicaSystemLook.channel, (call) async {
          calls.add('${(call.arguments as Map)['method']}');
          return [
            {'look.accent': 'red', 'look.scrollClick': 'spot'},
          ];
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SilicaSystemLook.channel, null),
    );
    await tester.pumpWidget(scoped(const SizedBox()));
    await tester.pump();
    expect(calls, ['State']);
    expect(SilicaSystemLook.current.accent, SilicaAccent.red);
    expect(SilicaSystemLook.current.scrollClick, SystemScrollClick.spot);
    await tester.pumpWidget(const SizedBox());
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
}
