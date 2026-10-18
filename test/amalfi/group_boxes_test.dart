// Group boxes against the kit (`Group Boxes/Box/*`). Checklist:
// docs/amalfi-checklist/group_boxes.md.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

import 'support/harness.dart';
import 'toggles_support.dart';

const appearances = ['Light', 'Dark'];

/// `Fields/Text Field/Regular/Filled`.
Widget field() => AmalfiTextField(
  key: const ValueKey('field'),
  placeholder: 'Name',
  controller: TextEditingController(text: 'Amalfi coast'),
);

Widget checkbox(String label, {bool value = true}) => AmalfiCheckbox(
  key: ValueKey(label),
  value: value,
  label: label,
  onChanged: (_) {},
);

/// The untitled box of `Group Boxes/Box/Untitled`.
Widget untitled() => AmalfiGroupBox(
  key: const ValueKey('untitled'),
  children: [field(), checkbox('Remember this name')],
);

/// The labels of the kit's checkbox rows in [name] ([rows]), to the box's right edge: the
/// kit's text overflows its (stale) frames, which the text mask would leave out.
List<Rect> labels(String name, List<String> rows) {
  final master = KitMaster.load(name);
  final surface = master.layer('Box/Surface').rectInMaster;
  return [
    for (final row in rows)
      () {
        final r = master.layer(row).rectInMaster;
        return Rect.fromLTRB(r.left + 28, r.top, surface.right, r.bottom);
      }(),
  ];
}

Finder box(Finder root) => layerOf(root, AmalfiLayerKeys.body).first;

void main() {
  setUpAll(loadAmalfiFonts);

  for (final appearance in appearances) {
    for (final state in ['Rest', 'Disabled']) {
      final name = 'Group Boxes/Box/Titled/$state/$appearance';
      testWidgets(name, (tester) async {
        // Kit defect: "Show banners" and "Play sound" keep the width of the longest label
        // (168, "Show on lock screen"); the code sizes each row to its label.
        const rows = 'kit rows keep a stale width (168)';
        // Disabled, the whole group dims (its rows are Rest instances in the kit).
        await checkKit(
          tester,
          name,
          SizedBox(
            width: 192,
            child: AmalfiGroupBox(
              title: 'Notifications',
              enabled: state == 'Rest',
              children: [
                checkbox('Show banners'),
                checkbox('Play sound'),
                checkbox('Show on lock screen', value: false),
              ],
            ),
          ),
          layers: (root) => {
            'Title': find.byKey(AmalfiLayerKeys.label).first,
            'Box': box(root),
            'Box/Surface': box(root),
            'Box/Show banners': find.byKey(const ValueKey('Show banners')),
            'Box/Play sound': find.byKey(const ValueKey('Play sound')),
            'Box/Lock screen': find.byKey(
              const ValueKey('Show on lock screen'),
            ),
          },
          deviations: {
            'Title': 'kit fixed-width title frame 88 for "Notifications" (84 on the grid)',
            'Box/Show banners': rows,
            'Box/Play sound': rows,
          },
          mask: labels(name, [
            'Box/Show banners',
            'Box/Play sound',
            'Box/Lock screen',
          ]),
        );
      });
    }

    testWidgets('Group Boxes/Box/Untitled/Rest/$appearance', (tester) async {
      await checkKit(
        tester,
        'Group Boxes/Box/Untitled/Rest/$appearance',
        SizedBox(width: 224, child: untitled()),
        layers: (root) => {
          'Box': box(root),
          'Box/Surface': box(root),
          'Box/Name': find.byKey(const ValueKey('field')),
          'Box/Remember': find.byKey(const ValueKey('Remember this name')),
        },
        deviations: {
          'Box/Remember':
              'kit row keeps a stale width (168), the code fits the label',
        },
        mask: labels('Group Boxes/Box/Untitled/Rest/$appearance', [
          'Box/Remember',
        ]),
      );
    });

    testWidgets('Group Boxes/Box/Nested/Rest/$appearance', (tester) async {
      await checkKit(
        tester,
        'Group Boxes/Box/Nested/Rest/$appearance',
        SizedBox(
          width: 280,
          child: AmalfiGroupBox(
            title: 'Recipe sharing',
            children: [
              AmalfiSwitch(
                key: const ValueKey('sync'),
                value: true,
                label: 'Enable sync',
                onChanged: (_) {},
              ),
              untitled(),
            ],
          ),
        ),
        layers: (root) => {
          'Title': find.byKey(AmalfiLayerKeys.label).first,
          'Box': box(root),
          'Box/Surface': box(root),
          'Box/Enable': find.byKey(const ValueKey('sync')),
          'Box/Inner box': find.byKey(const ValueKey('untitled')),
        },
        // The inner box's checkbox label (see Untitled).
        mask: const [Rect.fromLTWH(24 + 28, 24 + 52 + 48, 268 - 52, 20)],
      );
    });
  }

  testWidgets('a disabled box blocks its controls', (tester) async {
    final changes = <bool>[];
    await pumpKitScene(
      tester,
      SizedBox(
        width: 192,
        child: AmalfiGroupBox(
          title: 'Notifications',
          enabled: false,
          children: [
            AmalfiCheckbox(
              value: false,
              label: 'Play sound',
              onChanged: changes.add,
            ),
          ],
        ),
      ),
    );
    await tester.tap(find.text('Play sound'), warnIfMissed: false);
    await tester.pump();
    expect(changes, isEmpty);
    expect(
      tester.widget<Opacity>(find.byType(Opacity).first).opacity,
      AmalfiStates.disabledOpacity,
    );
  });

  testWidgets('an unbounded box hugs its widest child', (tester) async {
    await pumpKitScene(
      tester,
      UnconstrainedBox(
        child: AmalfiGroupBox(
          children: [
            const SizedBox(width: 100, height: 20),
            const SizedBox(width: 60, height: 20),
          ],
        ),
      ),
    );
    expect(
      tester.getSize(find.byKey(AmalfiLayerKeys.body)),
      const Size(124, 72),
    );
  });
}
