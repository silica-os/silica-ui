// Windows against the kit (`Windows/*`, without `Window/Sheet Attached`). Checklist:
// docs/amalfi-checklist/windows.md.
//
// The masters are whole windows with sample content: the frame, the regions, the separators
// and the bars are ours; nested controls of other families (buttons, group boxes, pop-ups,
// segmented controls, checkboxes, search fields, the menu bar) are masked in the pixel tests,
// and so are bars already compared on their own (`titlebars_test.dart`).

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

import 'sidebars_test.dart' show panelRows;
import 'support/harness.dart';
import 'titlebars_kit_support.dart';

const String body =
    'Whisk the eggs with sugar until pale, fold in the flour, then the lemon zest and juice. '
    'Bake for forty minutes and let it cool before slicing.';

/// The sample content of a window: a Title 1 heading and a paragraph.
Widget sampleContent({
  required EdgeInsets padding,
  double gap = 16,
  bool active = true,
}) => Builder(
  builder: (context) {
    final colors = AmalfiTheme.of(context).colors;
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Lemon cake',
            key: const ValueKey('Content title'),
            style: AmalfiType.title1(
              color: active ? colors.textPrimary : colors.textTertiary,
            ),
          ),
          SizedBox(height: gap),
          Text(
            body,
            key: const ValueKey('Content body'),
            style: AmalfiType.body(
              color: active ? colors.textSecondary : colors.textTertiary,
            ),
          ),
        ],
      ),
    );
  },
);

/// The frame layers of every window master.
Map<String, Finder> frameLayers() {
  final decorated = find.descendant(
    of: find.byType(AmalfiWindow),
    matching: find.byType(DecoratedBox),
  );
  return {
    'Window shadow': decorated.first,
    'Window surface': find
        .descendant(
          of: find.byType(AmalfiWindow),
          matching: find.byType(ColoredBox),
        )
        .first,
    'Window rim': decorated.last,
    'Content title': find.byKey(const ValueKey('Content title')),
    'Content body': find.byKey(const ValueKey('Content body')),
  };
}

/// A sidebar under a bar or a split toolbar (kit `Windows/Sidebar Body/Below Bar|Full`).
Widget sidebarBody({required bool full}) => AmalfiSidebarPanel(
  padding: EdgeInsets.fromLTRB(12, full ? 60 : 8, 12, 0),
  children: [
    for (final w in panelRows())
      if (w is AmalfiSidebarHeader)
        AmalfiSidebarHeader(key: w.key, title: w.title)
      else
        w,
  ],
);

/// The pieces of the kit's unified window bar.
Widget windowBar({
  bool? active,
  AmalfiToolbarSurface surface = AmalfiToolbarSurface.window,
}) => AmalfiToolbar(
  active: active,
  surface: surface,
  children: [
    AmalfiControlsPiece(onClose: () {}, onMinimise: () {}, onZoom: () {}),
    AmalfiToolbarPiece(
      child: AmalfiToolbarButton(
        icon: AmalfiGlyph(AmalfiGlyphs.sidebar),
        onPressed: () {},
        semanticLabel: 'sidebar',
      ),
    ),
    navPiece(),
    AmalfiTitlePiece(title: 'Lemon cake'),
    AmalfiSpacerPiece(),
    AmalfiToolbarPiece(
      child: viewSwitcher([
        AmalfiGlyphs.listBullet,
        AmalfiGlyphs.squareGrid2x2,
      ]),
    ),
    AmalfiToolbarPiece(child: toolbarSearch()),
  ],
);

Future<void> checkWindow(
  WidgetTester tester,
  String name,
  Size size,
  Widget window, {
  Map<String, Finder> layers = const {},
  Map<String, String> deviations = const {},
  List<String> masks = const [],
  bool frame = true,
}) async {
  final master = KitMaster.load(name);
  final scene = SizedBox.fromSize(size: size, child: window);
  final root = await pumpKitScene(tester, scene, master: master);
  expectKitGeometry(
    tester,
    master,
    root: root,
    layers: {
      if (frame)
        for (final e in frameLayers().entries)
          if (master.maybeLayer(e.key) != null) e.key: e.value,
      ...layers,
    },
    deviations: deviations,
  );
  await expectKitPixels(
    tester,
    master,
    scene,
    maskLayers: masks,
    tolerance: KitPixelTolerance.withText,
  );
}

void rimTests() {
  testWidgets('a window under the compositor draws no rim of its own (#212)', (
    tester,
  ) async {
    Future<int> rims(Widget window) async {
      await pumpKitScene(
        tester,
        SizedBox(width: 200, height: 100, child: window),
      );
      return tester.widgetList<DecoratedBox>(find.byType(DecoratedBox)).where((
        d,
      ) {
        final shape = (d.decoration as dynamic);
        return shape is AmalfiShapeDecoration &&
            shape.color == null &&
            shape.shape is AmalfiSmoothBorder &&
            (shape.shape as AmalfiSmoothBorder).side != BorderSide.none;
      }).length;
    }

    expect(await rims(const AmalfiWindow(child: SizedBox())), 1);
    expect(await rims(const AmalfiWindow(shadow: false, child: SizedBox())), 0);
    expect(
      await rims(
        const AmalfiWindow(shadow: false, rim: true, child: SizedBox()),
      ),
      1,
    );
  });
}

void main() {
  rimTests();
  setUpAll(() async {
    await loadAmalfiFonts();
    registerChromeStyles();
  });

  for (final appearance in ['Light', 'Dark']) {
    group('kit $appearance', () {
      testWidgets('Window/Document', (tester) async {
        await checkWindow(
          tester,
          'Windows/Window/Document/Active/$appearance',
          const Size(540, 400),
          AmalfiWindow(
            child: AmalfiWindowLayout(
              bar: AmalfiTitleBar(
                title: 'Lemon cake.recipe',
                document: true,
                onClose: () {},
                onMinimise: () {},
                onZoom: () {},
              ),
              barHeight: AmalfiToolbarMetrics.titleBarHeight,
              content: sampleContent(
                padding: const EdgeInsets.fromLTRB(28, 28, 28, 0),
                gap: 12,
              ),
            ),
          ),
          layers: {'Title bar': find.byType(AmalfiTitleBar)},
          masks: ['Title bar', 'Options', 'Done'],
        );
      });

      for (final state in ['Active', 'Inactive']) {
        final active = state == 'Active';
        final key = state == 'Inactive'
            ? 'Windows/Window/Inactive/Inactive/$appearance'
            : 'Windows/Window/Sidebar Inspector/Active/$appearance';
        final inspector = active;
        testWidgets(
          inspector ? 'Window/Sidebar Inspector' : 'Window/Inactive',
          (tester) async {
            await checkWindow(
              tester,
              key,
              Size(inspector ? 1000 : 760, inspector ? 580 : 440),
              AmalfiWindow(
                active: active,
                child: AmalfiWindowLayout(
                  bar: windowBar(surface: AmalfiToolbarSurface.none),
                  barSeparator: inspector,
                  sidesUnderBar: true,
                  sidebar: Padding(
                    padding: const EdgeInsets.only(top: 52),
                    child: sidebarBody(full: false),
                  ),
                  inspector: inspector
                      ? SizedBox.expand(key: ValueKey('Inspector'))
                      : null,
                  inspectorWidth: AmalfiWindowMetrics.inspectorWidth,
                  content: sampleContent(
                    padding: const EdgeInsets.fromLTRB(32, 32, 32, 0),
                    gap: 12,
                    active: active,
                  ),
                ),
              ),
              layers: {
                'Sidebar region': find
                    .ancestor(
                      of: find.byType(AmalfiSidebarPanel),
                      matching: find.byType(ColoredBox),
                    )
                    .first,
                if (inspector)
                  'Inspector region': find
                      .ancestor(
                        of: find.byKey(const ValueKey('Inspector')),
                        matching: find.byType(ColoredBox),
                      )
                      .first,
              },
              masks: [
                if (inspector) 'Toolbar' else 'Toolbar inactive',
                'Sidebar',
                if (inspector) ...[
                  'Options',
                  'Inspector title',
                  'Inspector options',
                  'Inspector pop-up',
                ],
              ],
            );
          },
        );
      }

      testWidgets('Window/Panel', (tester) async {
        await checkWindow(
          tester,
          'Windows/Window/Panel/Active/$appearance',
          const Size(300, 380),
          AmalfiWindow(
            child: AmalfiWindowLayout(
              bar: AmalfiTitleBar(
                title: 'Style',
                onClose: () {},
                onMinimise: () {},
                onZoom: () {},
              ),
              barHeight: AmalfiToolbarMetrics.titleBarHeight,
              content: SizedBox.expand(),
            ),
          ),
          layers: {
            'Window controls': find.byType(AmalfiWindowControlGroup),
            'Panel title': textBox('Style'),
            'Separator': titleBarEdge(),
          },
          deviations: const {
            'Window controls': measuredPitch,
            'Panel title':
                'kit panel title at x 124, not centred; ours centred in the bar (x 132)',
            'Separator':
                'kit panel separator under the 48 pt bar (y 48); the title bar draws it '
                'inside its 48 pt (y 47), as Titlebars/Title Bar does',
          },
          masks: [
            'Window controls',
            'Panel title',
            'Separator',
            'Mode',
            'Group',
            'Choices',
          ],
        );
      });

      testWidgets('Window/Utility', (tester) async {
        await checkWindow(
          tester,
          'Windows/Window/Utility/Active/$appearance',
          const Size(260, 196),
          AmalfiWindow(
            kind: AmalfiWindowKind.utility,
            child: AmalfiWindowLayout(
              bar: AmalfiTitleBar(
                title: 'Quick find',
                style: AmalfiTitleBarStyle.utility,
                onClose: () {},
                onMinimise: () {},
                onZoom: () {},
              ),
              barHeight: AmalfiToolbarMetrics.compactHeight,
              content: SizedBox.expand(),
            ),
          ),
          layers: {
            'Window controls': find.byType(AmalfiWindowControlGroup),
            'Utility title': textBox('Quick find'),
          },
          deviations: const {
            'Window controls': measuredPlace,
            'Utility title':
                'kit title frame 54 wide (the text); ours rounded to the grid (56)',
          },
          masks: [
            'Window controls',
            'Search',
            'Match case',
            'Whole words',
            'Find',
          ],
        );
      });

      testWidgets('Window/Full Screen Strip', (tester) async {
        await checkWindow(
          tester,
          'Windows/Window/Full Screen Strip/Active/$appearance',
          const Size(1000, 116),
          AmalfiFullScreenStrip(
            menuBar: SizedBox.expand(key: ValueKey('Menu bar')),
            toolbar: windowBar(),
          ),
          frame: false,
          layers: {
            'Surface': find.byType(ColoredBox).first,
            'Menu bar': find.byKey(const ValueKey('Menu bar')),
            'Toolbar': find.byType(AmalfiToolbar),
            'Separator': find.byType(AmalfiWindowSeparator),
          },
          masks: ['Menu bar', 'Toolbar'],
        );
      });

      testWidgets('Compact Toolbar', (tester) async {
        await checkWindow(
          tester,
          'Windows/Compact Toolbar/Active/$appearance',
          const Size(520, 320),
          AmalfiWindow(
            child: AmalfiWindowLayout(
              bar: compactBar(),
              barHeight: AmalfiToolbarMetrics.compactHeight,
              barSeparator: true,
              content: sampleContent(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              ),
            ),
          ),
          layers: {
            'Toolbar': find.byType(AmalfiToolbar),
            'Separator': find.byType(AmalfiWindowSeparator),
          },
          masks: ['Toolbar'],
        );
      });

      testWidgets('Title Only', (tester) async {
        await checkWindow(
          tester,
          'Windows/Title Only/Active/$appearance',
          const Size(520, 360),
          AmalfiWindow(
            child: AmalfiWindowLayout(
              bar: AmalfiTitleBar(
                title: 'Lemon cake',
                style: AmalfiTitleBarStyle.titleOnly,
                onClose: () {},
                onMinimise: () {},
                onZoom: () {},
              ),
              barHeight: AmalfiToolbarMetrics.titleOnlyHeight,
              content: sampleContent(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
              ),
            ),
          ),
          layers: {'Title bar': find.byType(AmalfiTitleBar)},
          masks: ['Title bar', 'Done'],
        );
      });

      for (final (name, size, done) in [
        ('Unified Toolbar', const Size(720, 480), true),
        ('Sidebar Collapsed', const Size(960, 600), false),
      ]) {
        testWidgets(name, (tester) async {
          await checkWindow(
            tester,
            'Windows/$name/Active/$appearance',
            size,
            AmalfiWindow(
              child: AmalfiWindowLayout(
                bar: windowBar(),
                content: sampleContent(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                ),
              ),
            ),
            layers: {'Toolbar': find.byType(AmalfiToolbar)},
            masks: ['Toolbar', if (done) 'Done'],
          );
        });
      }

      for (final state in ['Active', 'Inactive']) {
        final active = state == 'Active';
        testWidgets('Unified Toolbar Sidebar/$state', (tester) async {
          await checkWindow(
            tester,
            'Windows/Unified Toolbar Sidebar/$state/$appearance',
            const Size(960, 600),
            AmalfiWindow(
              active: active,
              child: AmalfiWindowLayout(
                bar: windowBar(),
                barSeparator: true,
                sidebar: sidebarBody(full: false),
                content: sampleContent(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  active: active,
                ),
              ),
            ),
            layers: {
              'Toolbar': find.byType(AmalfiToolbar),
              'Sidebar': find.byType(AmalfiSidebarPanel),
              'Sidebar region': find
                  .ancestor(
                    of: find.byType(AmalfiSidebarPanel),
                    matching: find.byType(ColoredBox),
                  )
                  .first,
            },
            masks: ['Toolbar'],
          );
        });

        testWidgets('Split Toolbar/$state', (tester) async {
          await checkWindow(
            tester,
            'Windows/Split Toolbar/$state/$appearance',
            const Size(960, 600),
            AmalfiWindow(
              active: active,
              child: AmalfiSplitWindowLayout(
                columns: [
                  sidebarColumn(),
                  AmalfiWindowColumn(
                    toolbar: AmalfiToolbar.section(
                      key: const ValueKey('Content toolbar'),
                      children: contentSectionPieces(),
                    ),
                    child: sampleContent(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      active: active,
                    ),
                  ),
                ],
              ),
            ),
            layers: {
              'Sidebar': find.byType(AmalfiSidebarPanel),
              'Sidebar toolbar': find.byKey(const ValueKey('Sidebar toolbar')),
              'Content toolbar': find.byKey(const ValueKey('Content toolbar')),
            },
            masks: ['Sidebar toolbar', 'Content toolbar'],
          );
        });

        testWidgets('Split Toolbar Three Columns/$state', (tester) async {
          await checkWindow(
            tester,
            'Windows/Split Toolbar Three Columns/$state/$appearance',
            const Size(1280, 600),
            AmalfiWindow(
              active: active,
              child: AmalfiSplitWindowLayout(
                columns: [
                  sidebarColumn(),
                  AmalfiWindowColumn(
                    width: AmalfiWindowMetrics.listWidth,
                    toolbar: AmalfiToolbar.section(
                      key: const ValueKey('List toolbar'),
                      children: listSectionPieces(),
                    ),
                    child: sampleList(active: active),
                  ),
                  AmalfiWindowColumn(
                    toolbar: AmalfiToolbar.section(
                      key: const ValueKey('Content toolbar'),
                      children: contentSectionPieces(),
                    ),
                    child: sampleContent(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      active: active,
                    ),
                  ),
                ],
              ),
            ),
            layers: {
              'Sidebar': find.byType(AmalfiSidebarPanel),
              'Sidebar toolbar': find.byKey(const ValueKey('Sidebar toolbar')),
              'List toolbar': find.byKey(const ValueKey('List toolbar')),
              'Content toolbar': find.byKey(const ValueKey('Content toolbar')),
            },
            masks: ['Sidebar toolbar', 'List toolbar', 'Content toolbar'],
          );
        });
      }

      testWidgets('Split Toolbar Inspector', (tester) async {
        await checkWindow(
          tester,
          'Windows/Split Toolbar Inspector/Active/$appearance',
          const Size(1200, 600),
          AmalfiWindow(
            child: AmalfiSplitWindowLayout(
              columns: [
                sidebarColumn(),
                AmalfiWindowColumn(
                  toolbar: AmalfiToolbar.section(
                    key: const ValueKey('Content toolbar'),
                    children: contentSectionPieces(),
                  ),
                  child: sampleContent(
                    padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                  ),
                ),
                AmalfiWindowColumn(
                  width: AmalfiWindowMetrics.inspectorWidth,
                  toolbarOverChild: true,
                  toolbar: AmalfiToolbar.section(
                    key: const ValueKey('Inspector toolbar'),
                    surface: AmalfiToolbarSurface.sidebar,
                    children: inspectorSectionPieces(),
                  ),
                  child: Builder(
                    builder: (context) => ColoredBox(
                      key: const ValueKey('Inspector region'),
                      color: AmalfiTheme.of(context).colors.surfaceSidebar,
                    ),
                  ),
                ),
              ],
            ),
          ),
          layers: {
            'Sidebar': find.byType(AmalfiSidebarPanel),
            'Inspector region': find.byKey(const ValueKey('Inspector region')),
            'Sidebar toolbar': find.byKey(const ValueKey('Sidebar toolbar')),
            'Content toolbar': find.byKey(const ValueKey('Content toolbar')),
            'Inspector toolbar': find.byKey(
              const ValueKey('Inspector toolbar'),
            ),
          },
          masks: [
            'Sidebar toolbar',
            'Content toolbar',
            'Inspector toolbar',
            'Inspector title',
            'Inspector pop-up',
          ],
        );
      });

      for (final full in [true, false]) {
        final variant = full ? 'Full' : 'Below Bar';
        testWidgets('Sidebar Body/$variant', (tester) async {
          final names = [
            'Favourites',
            'Recents',
            'Documents',
            'Downloads',
            'Library',
            'Photos',
            'Music',
          ];
          await checkWindow(
            tester,
            'Windows/Sidebar Body/$variant/$appearance',
            Size(240, full ? 600 : 548),
            sidebarBody(full: full),
            frame: false,
            layers: {'Surface': find.byType(ColoredBox).first, ...keyed(names)},
          );
        });
      }
    });
  }
}

/// The sidebar column of a split window: its toolbar section over the sidebar, whose
/// surface runs up behind it (kit `Windows/Sidebar Body/Full`).
AmalfiWindowColumn sidebarColumn() => AmalfiWindowColumn(
  width: AmalfiWindowMetrics.sidebarWidth,
  toolbarOverChild: true,
  ownEdge: true,
  toolbar: AmalfiToolbar.sidebarSection(
    key: const ValueKey('Sidebar toolbar'),
    children: sidebarSectionPieces(),
  ),
  child: sidebarBody(full: true),
);

/// The list column of the three-column window: three entries 72 apart, each with a
/// separator under it.
Widget sampleList({bool active = true}) => Builder(
  builder: (context) {
    final colors = AmalfiTheme.of(context).colors;
    final ink = active ? colors.textPrimary : colors.textTertiary;
    final secondary = active ? colors.textSecondary : colors.textTertiary;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final title in ['Lemon cake', 'Orange tart', 'Almond biscuits'])
          SizedBox(
            height: 72,
            child: Stack(
              children: [
                Positioned(
                  left: 24,
                  right: 24,
                  top: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(title, style: AmalfiType.headline(color: ink)),
                      SizedBox(height: 4),
                      Text(
                        'Whisk the eggs with sugar until pale.',
                        style: AmalfiType.callout(color: secondary),
                      ),
                    ],
                  ),
                ),
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 1,
                  child: AmalfiWindowSeparator(),
                ),
              ],
            ),
          ),
      ],
    );
  },
);
