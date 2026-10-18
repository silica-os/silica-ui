// Pumping a widget for a geometry test against a kit master.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

import 'fonts.dart';
import 'kit.dart';

/// The key of the widget pumped by [pumpKitScene]: `find.byKey(kitSceneRoot)` is the root.
const Key kitSceneRoot = ValueKey('kit-scene-root');

/// Pumps [widget] at device pixel ratio 1 at the top left of a 1600 × 1200 view, with loose
/// constraints, in the appearance of [master] (or [brightness]), with the package fonts
/// loaded, inside a [WidgetsApp] (its default shortcuts and actions, so Enter and Space
/// activate as in an app, and its tap region surface, so clicks outside close menus and
/// popovers), with [Directionality], [MediaQuery] and an [Overlay] above the widget. Returns
/// the finder of the widget, to pass as `root` to `expectKitGeometry`.
///
/// Pumping again in the same test replaces the widget as [WidgetTester.pumpWidget] does: the
/// same kind of widget at the same place keeps its state, a different one starts afresh.
Future<Finder> pumpKitScene(
  WidgetTester tester,
  Widget widget, {
  KitMaster? master,
  Brightness? brightness,
  Size view = const Size(1600, 1200),
}) async {
  await ensureAmalfiFonts(tester);
  final appearance = brightness ?? master?.brightness ?? Brightness.light;
  tester.view
    ..devicePixelRatio = 1
    ..physicalSize = view;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    WidgetsApp(
      color: const Color(0xFF0E77E6),
      debugShowCheckedModeBanner: false,
      builder: (context, _) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(size: view, platformBrightness: appearance),
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: AmalfiTheme(
            brightness: appearance,
            child: _KitScene(
              child: KeyedSubtree(key: kitSceneRoot, child: widget),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  return find.byKey(kitSceneRoot);
}

/// An [Overlay] whose single entry shows [child] at the top left of an empty (but hit-testable) background, rebuilt when [child]
/// changes (an overlay keeps its initial entries otherwise).
class _KitScene extends StatefulWidget {
  const _KitScene({required this.child});

  final Widget child;

  @override
  State<_KitScene> createState() => _KitSceneState();
}

class _KitSceneState extends State<_KitScene> {
  late final OverlayEntry _entry = OverlayEntry(
    // An empty window background: a click beside the widget lands on something, as in
    // an app, so that tap regions see it as a click outside.
    // (A MetaData, not a ColoredBox, which a test could take for a layer of the widget.)
    builder: (_) => MetaData(
      behavior: HitTestBehavior.opaque,
      child: Align(alignment: Alignment.topLeft, child: widget.child),
    ),
  );

  @override
  void didUpdateWidget(_KitScene old) {
    super.didUpdateWidget(old);
    if (old.child != widget.child) _entry.markNeedsBuild();
  }

  @override
  void dispose() {
    _entry
      ..remove()
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}
