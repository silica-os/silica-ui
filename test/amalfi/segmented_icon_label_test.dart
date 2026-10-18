// The Segmented Control, Icon + Label against the kit (`Segments/Icon + Label Item/*`,
// `Segments/Control/One <N> Icon + Label/*`): geometry and pixels of every master, plus
// behaviour.

import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

import 'support/harness.dart';

List<String> masters() {
  final dir = Directory('test/amalfi/kit/Segments');
  return [
    for (final f in dir.listSync(recursive: true))
      if (f is File &&
          f.path.endsWith('.json') &&
          f.path.contains('Icon + Label'))
        f.path
            .substring('test/amalfi/kit/'.length)
            .replaceFirst(RegExp(r'\.json$'), ''),
  ]..sort();
}

const tolerance = KitPixelTolerance(mean: 2.5, max: 96);

/// A 52 pt track has a body beyond the glass edge band that the tests mask: Dark/Glass/Regular
/// stacks the glass fill and the tint (alpha 214), the test fallback draws one (153); the
/// shader draws the real glass (kit-issues.md, glass pixel tests).
const darkBarTolerance = KitPixelTolerance(mean: 5, max: 96);

/// The bar and item widgets of a master: the kit's panes are 96 wide ("General" and friends
/// at 96 = master default), so the labels are those of the master's instances.
Widget barOf(KitMaster master, int n, {int selected = 0}) {
  // The overrides of a pane: its glyph name, then its label.
  List<String> overrides(int i) => [
    for (final o in master.layer('Pane $i').overrides)
      if (o.property == 'stringValue') o.value as String? ?? '',
  ];
  final panes = [for (var i = 1; i <= n; i++) overrides(i)];
  return AmalfiIconLabelSegmentedControl(
    tabs: [
      for (final p in panes)
        AmalfiIconLabelSegment(
          label: p.length > 1 ? p[1] : 'Label',
          symbol: p.isNotEmpty ? p[0] : 'gear',
        ),
    ],
    selected: selected,
    paneWidth: 96,
    onChanged: (_) {},
  );
}

void main() {
  setUpAll(loadAmalfiFonts);

  group('metrics', () {
    testWidgets('pane width: longest label + 24 up to 8, at least 72', (
      tester,
    ) async {
      late BuildContext context;
      await tester.pumpWidget(
        AmalfiTheme(
          brightness: Brightness.light,
          child: Builder(
            builder: (c) {
              context = c;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(AmalfiIconLabelMetrics.paneWidth(context, ['A', 'B']), 72);
      expect(AmalfiIconLabelMetrics.barWidth(4, 112), 456);
    });
  });

  group('behaviour', () {
    testWidgets('a click chooses a pane; disabled panes do not', (
      tester,
    ) async {
      var chosen = 0;
      await tester.pumpWidget(
        AmalfiTheme(
          brightness: Brightness.light,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Center(
              child: AmalfiIconLabelSegmentedControl(
                tabs: const [
                  AmalfiIconLabelSegment(label: 'General', symbol: 'gear'),
                  AmalfiIconLabelSegment(label: 'Tags', symbol: 'tag'),
                  AmalfiIconLabelSegment(
                    label: 'Off',
                    symbol: 'gear',
                    enabled: false,
                  ),
                ],
                selected: chosen,
                onChanged: (i) => chosen = i,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('amalfi-icon-label-label-1')));
      expect(chosen, 1);
      await tester.tap(find.byKey(const ValueKey('amalfi-icon-label-label-2')));
      expect(chosen, 1);
    });
  });

  group('kit', () {
    for (final key in masters()) {
      testWidgets(key, (tester) async {
        final master = KitMaster.load(key);
        final parts = key.split('/');
        final bar = parts[1] == 'Control';
        final Widget widget;
        final Map<String, Finder> layers;
        if (bar) {
          final n = int.parse(parts[2].split(' ')[1]);
          widget = barOf(master, n);
          layers = {
            'Track': find.byKey(const ValueKey('amalfi-icon-label-track')),
          };
        } else {
          final state = parts[2];
          widget = _Item(
            label: master.layer('Label').text ?? 'General',
            symbol: master.layer('Glyph').text ?? 'gear',
            state: state,
            width: master.root.frame.width,
          );
          layers = {
            'Label': find.byKey(const ValueKey('amalfi-icon-label-label-0')),
            'Glyph': find.byKey(const ValueKey('amalfi-icon-label-glyph-0')),
          };
        }
        final root = await pumpKitScene(tester, widget, master: master);
        expectKitGeometry(tester, master, root: root, layers: layers);
        // The glyphs are Icon Kit symbols (silica-icons): their boxes are masked.
        final glyphs = <Rect>[
          if (bar)
            for (final pane in master.root.descendants.where(
              (l) => l.name.startsWith('Pane '),
            ))
              Rect.fromLTWH(
                pane.rectInMaster.left + (pane.rectInMaster.width - 20) / 2,
                pane.rectInMaster.top + 4,
                20,
                21,
              )
          else
            master.layer('Glyph').rectInMaster,
        ];
        await expectKitPixels(
          tester,
          master,
          widget,
          maskText: true,
          mask: glyphs,
          tolerance: bar && key.endsWith('/Dark')
              ? darkBarTolerance
              : tolerance,
        );
      });
    }
  });
}

/// A single pane in a given state, drawn by a one-pane bar's pane.
class _Item extends StatelessWidget {
  const _Item({
    required this.label,
    required this.symbol,
    required this.state,
    required this.width,
  });

  final String label, symbol, state;
  final double width;

  @override
  Widget build(BuildContext context) => AmalfiIconLabelItem(
    tab: AmalfiIconLabelSegment(
      label: label,
      symbol: symbol,
      enabled: state != 'Disabled',
    ),
    width: width,
    selected: state == 'Selected',
    hovered: state == 'Hover',
    pressed: state == 'Pressed',
  );
}
