import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

/// A control in a window: light or dark, active or inactive, with an overlay for menus.
Widget harness(
  Widget child, {
  bool dark = false,
  bool active = true,
}) => MediaQuery(
  data: MediaQueryData(
    platformBrightness: dark ? Brightness.dark : Brightness.light,
  ),
  child: Directionality(
    textDirection: TextDirection.ltr,
    child: ToolbarScope(
      active: active,
      child: _Slot(
        control: child,
        // The overlay keeps its first entries: the entry reads the control from the slot.
        overlay: Overlay(
          initialEntries: [
            OverlayEntry(
              builder: (context) => Center(child: _Slot.of(context)),
            ),
          ],
        ),
      ),
    ),
  ),
);

/// The glass talks to the compositor: here nobody answers.
void muteGlass() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(GlassRegistry.channel, (call) async => true);
}

/// The fill of the first decorated container with `key`.
Color? fillOf(WidgetTester tester, Key key) {
  final decoration = tester.widget<Container>(find.byKey(key).first).decoration;
  return decoration is BoxDecoration ? decoration.color : null;
}

/// The color of the first text under `of`.
Color? textColor(WidgetTester tester, Finder of) => tester
    .widget<Text>(find.descendant(of: of, matching: find.byType(Text)).first)
    .style
    ?.color;

/// A mouse hovering `finder`.
Future<TestGesture> hover(WidgetTester tester, Finder finder) async {
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: Offset.zero);
  await mouse.moveTo(tester.getCenter(finder));
  await tester.pump();
  return mouse;
}

/// Gives `node` the keyboard focus, as with full keyboard access (the ring shows).
Future<void> keyboardFocus(WidgetTester tester, FocusNode node) async {
  FocusManager.instance.highlightStrategy =
      FocusHighlightStrategy.alwaysTraditional;
  node.requestFocus();
  await tester.pump();
  await tester.pump();
}

/// Back to the automatic highlight strategy.
void resetHighlight() =>
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic;

class _Slot extends InheritedWidget {
  const _Slot({required this.control, required Widget overlay})
    : super(child: overlay);

  final Widget control;

  static Widget of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_Slot>()!.control;

  @override
  bool updateShouldNotify(_Slot old) => old.control != control;
}
