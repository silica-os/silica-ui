// Menus against the kit (`Menus/*`). Checklist: docs/amalfi-checklist/menus.md.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

import 'menus_support.dart';
import 'support/harness.dart';

/// The icon of `Menus/Item/Icon` (`Regular / share`). The menus' icon rows override it
/// with symbols the fixtures name only by id: those stay masked in the menu tests.
const _icon = AmalfiGlyph(AmalfiGlyphs.share);

/// The 12 pt slot before the label (empty or with the checkmark).
Finder _checkSlot(Finder item) => find
    .descendant(
      of: item,
      matching: find.byWidgetPredicate(
        (w) => w is SizedBox && w.width == 12 && w.height == 12,
      ),
    )
    .first;

Finder _glyph(Finder item, AmalfiGlyphData glyph) => find.descendant(
  of: item,
  matching: find.byWidgetPredicate((w) => w is AmalfiGlyph && w.glyph == glyph),
);

/// The rows of `Menus/Menu/Full`.
List<AmalfiMenuEntry> fullEntries({VoidCallback? onNewWindow}) => [
  AmalfiMenuAction('New Window', shortcut: '⌘N', onSelected: onNewWindow),
  const AmalfiMenuAction('Open Recent', submenu: submenuEntries),
  const AmalfiMenuDivider(),
  const AmalfiMenuSection('Share'),
  const AmalfiMenuAction('Send a Link', icon: _icon),
  const AmalfiMenuAction('Autosave', checked: true),
  const AmalfiMenuAction('Duplicate', shortcut: '⌘D'),
  const AmalfiMenuAction('Export…', shortcut: '⇧⌘E', enabled: false),
  const AmalfiMenuDivider(),
  const AmalfiMenuAction('Move to Trash', destructive: true),
];

/// The rows of `Menus/Menu/Submenu`.
const List<AmalfiMenuEntry> submenuEntries = [
  AmalfiMenuAction('Lemon Cake'),
  AmalfiMenuAction('Fig Jam'),
  AmalfiMenuAction('Olive Oil'),
  AmalfiMenuDivider(),
  AmalfiMenuAction('Clear Menu'),
];

const List<AmalfiMenuEntry> simpleEntries = [
  AmalfiMenuAction('Orange'),
  AmalfiMenuAction('Lemon', checked: true),
  AmalfiMenuAction('Olive'),
  AmalfiMenuAction('Fig'),
];

const List<AmalfiMenuEntry> contextEntries = [
  AmalfiMenuAction('Cut', shortcut: '⌘X'),
  AmalfiMenuAction('Copy', shortcut: '⌘C'),
  AmalfiMenuAction('Paste', shortcut: '⌘V'),
  AmalfiMenuDivider(),
  AmalfiMenuAction('Look Up', icon: _icon),
  AmalfiMenuAction('Services', submenu: [AmalfiMenuAction('Make a Note')]),
  AmalfiMenuDivider(),
  AmalfiMenuAction('Delete', destructive: true),
];

void main() {
  setUpAll(() async {
    await loadAmalfiFonts();
    registerSurfaceStyles();
  });

  for (final appearance in ['Light', 'Dark']) {
    group('kit $appearance', () {
      // Items: (master variant/state, widget, layers to check).
      final items = <(String, AmalfiMenuItem)>[
        ('Plain/Rest', const AmalfiMenuItem(label: 'Menu item')),
        (
          'Plain/Highlighted',
          const AmalfiMenuItem(label: 'Menu item', highlighted: true),
        ),
        (
          'Plain/Checked',
          const AmalfiMenuItem(label: 'Menu item', checked: true),
        ),
        (
          'Plain/Disabled',
          const AmalfiMenuItem(label: 'Menu item', enabled: false),
        ),
        (
          'Checkmark/Rest',
          const AmalfiMenuItem(label: 'Menu item', checked: true),
        ),
        (
          'Checkmark/Highlighted',
          const AmalfiMenuItem(
            label: 'Menu item',
            checked: true,
            highlighted: true,
          ),
        ),
        (
          'Destructive/Rest',
          const AmalfiMenuItem(label: 'Menu item', destructive: true),
        ),
        (
          'Destructive/Highlighted',
          const AmalfiMenuItem(
            label: 'Menu item',
            destructive: true,
            highlighted: true,
          ),
        ),
        (
          'Shortcut/Rest',
          const AmalfiMenuItem(label: 'Menu item', shortcut: '⌘N'),
        ),
        (
          'Shortcut/Highlighted',
          const AmalfiMenuItem(
            label: 'Menu item',
            shortcut: '⌘N',
            highlighted: true,
          ),
        ),
        (
          'Shortcut/Disabled',
          const AmalfiMenuItem(
            label: 'Menu item',
            shortcut: '⌘N',
            enabled: false,
          ),
        ),
        (
          'Submenu/Rest',
          const AmalfiMenuItem(label: 'Menu item', submenu: true),
        ),
        (
          'Submenu/Highlighted',
          const AmalfiMenuItem(
            label: 'Menu item',
            submenu: true,
            highlighted: true,
          ),
        ),
        (
          'Submenu/Disabled',
          const AmalfiMenuItem(
            label: 'Menu item',
            submenu: true,
            enabled: false,
          ),
        ),
        ('Icon/Rest', const AmalfiMenuItem(label: 'Menu item', icon: _icon)),
        (
          'Icon/Highlighted',
          const AmalfiMenuItem(
            label: 'Menu item',
            icon: _icon,
            highlighted: true,
          ),
        ),
        (
          'Icon/Disabled',
          const AmalfiMenuItem(label: 'Menu item', icon: _icon, enabled: false),
        ),
      ];

      for (final (name, item) in items) {
        testWidgets('Item $name', (tester) async {
          final master = KitMaster.load(
            'Menus/Item/$name/Rest/$appearance'
                .replaceFirst('/Rest/Rest/', '/Rest/')
                .replaceFirst(
                  RegExp(r'/(Highlighted|Checked|Disabled)/Rest/'),
                  '/${name.split('/').last}/',
                ),
          );
          final scene = SizedBox(width: master.size.width, child: item);
          final root = await pumpKitScene(tester, scene, master: master);
          final row = find.byType(AmalfiMenuItem);
          final layers = <String, Finder>{
            'Label': textBox('Menu item'),
            if (master.maybeLayer('Highlight') != null)
              'Highlight': find.descendant(
                of: row,
                matching: find.byType(DecoratedBox),
              ),
            if (master.maybeLayer('Check slot') != null)
              'Check slot': _checkSlot(row),
            if (master.maybeLayer('Check') != null)
              'Check': _glyph(row, AmalfiGlyphs.checkmark),
            if (master.maybeLayer('Chevron') != null)
              'Chevron': _glyph(row, AmalfiGlyphs.chevronRight),
            if (master.maybeLayer('Icon') != null)
              'Icon': _glyph(row, AmalfiGlyphs.share),
            if (master.maybeLayer('Shortcut') != null)
              'Shortcut': find.ancestor(
                of: find.text('⌘N'),
                matching: find.byType(AmalfiWholePoints),
              ),
          };
          expectKitGeometry(tester, master, root: root, layers: layers);
          await expectKitPixels(
            tester,
            master,
            scene,
            maskText: true,
            tolerance: highlightCorners,
          );
          await expectKitPixels(
            tester,
            master,
            scene,
            // The 20 pt icon is drawn from the Silica Symbols font in the kit (a point
            // higher than Skia centres it): looser mean on that master.
            tolerance: master.name.contains('/Icon/')
                ? const KitPixelTolerance(mean: 8, max: 255)
                : denseText,
          );
        });
      }

      testWidgets('Header', (tester) async {
        final master = KitMaster.load('Menus/Item/Header/Rest/$appearance');
        const scene = SizedBox(
          width: 188,
          child: AmalfiMenuHeader(label: 'Section'),
        );
        final root = await pumpKitScene(tester, scene, master: master);
        expectKitGeometry(
          tester,
          master,
          root: root,
          layers: {'Label': textBox('Section')},
        );
        await expectKitPixels(
          tester,
          master,
          scene,
          tolerance: KitPixelTolerance.withText,
        );
      });

      testWidgets('Separator', (tester) async {
        final master = KitMaster.load('Menus/Item/Separator/Rest/$appearance');
        const scene = SizedBox(width: 188, child: AmalfiMenuSeparator());
        final root = await pumpKitScene(tester, scene, master: master);
        expectKitGeometry(
          tester,
          master,
          root: root,
          layers: {'Line': find.byType(ColoredBox)},
        );
        await expectKitPixels(tester, master, scene);
      });

      // Menus: (variant, entries, item to highlight, rows to check).
      final menus = <(String, List<AmalfiMenuEntry>, String?)>[
        ('Simple', simpleEntries, 'Olive'),
        ('Full', fullEntries(), 'Open Recent'),
        ('Context', contextEntries, 'Copy'),
        ('Submenu', submenuEntries, 'Fig Jam'),
      ];
      for (final (variant, entries, lit) in menus) {
        testWidgets('Menu $variant', (tester) async {
          final master = KitMaster.load('Menus/Menu/$variant/Rest/$appearance');
          final menu = AmalfiMenu(
            entries: entries,
            width: master.size.width,
            autofocus: true,
          );
          // Highlights [lit] with the keyboard (a pointer resting on "Open Recent" would
          // open its submenu).
          Future<void> highlight(WidgetTester tester) async {
            final index = entries.indexWhere(
              (e) => e is AmalfiMenuAction && e.label == lit,
            );
            final steps = entries
                .take(index + 1)
                .whereType<AmalfiMenuAction>()
                .where((a) => a.selectable)
                .length;
            for (var i = 0; i < steps; i++) {
              await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
            }
            await tester.pump();
          }

          final root = await pumpKitScene(tester, menu, master: master);
          await highlight(tester);
          final layers = <String, Finder>{
            'Surface': find.byType(AmalfiGlass),
            for (final l in master.root.children)
              if (l.isKitInstance && !l.name.startsWith('Separator'))
                l.name: l.master!.contains('/Header/')
                    ? find.byType(AmalfiMenuHeader)
                    : menuItem(l.name),
          };
          expectKitGeometry(tester, master, root: root, layers: layers);
          final icons = [
            for (final l in master.root.children)
              if (l.master?.contains('/Icon/') ?? false)
                Rect.fromLTWH(l.frame.left + 8, l.frame.top + 4, 16, 16),
          ];
          // The masked text frames are the nested 188 pt master's, so the shortcuts of
          // wider rows fall outside them: mask those by hand (in the text-free pass; the
          // text pass compares them). Kit defect: `Export…` keeps the master's shortcut
          // (⌘N, no override) where the code shows its own (⇧⌘E): masked in both passes.
          final shortcuts = [
            for (final l in master.root.children)
              if (l.master?.contains('/Shortcut/') ?? false)
                Rect.fromLTWH(l.frame.right - 48, l.frame.top, 40, 24),
          ];
          final export = [
            for (final l in master.root.children)
              if (l.name == 'Export…')
                Rect.fromLTWH(l.frame.right - 48, l.frame.top, 40, 24),
          ];
          await expectKitPixels(
            tester,
            master,
            menu,
            maskText: true,
            mask: [...icons, ...shortcuts],
            prepare: highlight,
          );
          await expectKitPixels(
            tester,
            master,
            menu,
            mask: [...icons, ...export],
            tolerance: KitPixelTolerance.withText,
            prepare: highlight,
          );
        });
      }

      testWidgets('Menu Cascade', (tester) async {
        final master = KitMaster.load('Menus/Menu/Cascade/Rest/$appearance');
        final scene = SizedBox(
          width: master.size.width,
          height: master.size.height,
          child: Align(
            alignment: Alignment.topLeft,
            child: AmalfiMenu(entries: fullEntries(), width: 232),
          ),
        );
        Future<void> open(WidgetTester tester) async {
          await hover(tester, menuItem('Open Recent'));
          await tester.pump(AmalfiMenuMetrics.submenuDelay);
          await tester.pump();
          await moveMouse(tester, tester.getCenter(menuItem('Fig Jam')));
        }

        final root = await pumpKitScene(tester, scene, master: master);
        await open(tester);
        final menus = find.byType(AmalfiMenu);
        expect(menus, findsNWidgets(2));
        expectKitGeometry(
          tester,
          master,
          root: root,
          layers: {'Parent menu': menus.first, 'Submenu': menus.last},
        );
        expect(
          tester.getTopLeft(menus.last),
          master.layer('Submenu').rectInMaster.topLeft,
        );
      });
    });
  }

  group('behaviour', () {
    testWidgets(
      'a submenu takes the width its action asks for (Open With: 192)',
      (tester) async {
        await pumpKitScene(
          tester,
          AmalfiMenu(
            width: 232,
            entries: [
              AmalfiMenuAction(
                'Open With',
                submenu: [
                  const AmalfiMenuAction('Photo Viewer (default)'),
                  const AmalfiMenuAction('Other…'),
                ],
                submenuWidth: 192,
              ),
            ],
          ),
        );
        await hover(tester, menuItem('Open With'));
        await tester.pump(AmalfiMenuMetrics.submenuDelay);
        await tester.pump();
        final menus = find.byType(AmalfiMenu);
        expect(menus, findsNWidgets(2));
        expect(tester.getSize(menus.last).width, 192);
      },
    );

    testWidgets('sizes itself to its widest row, on the 4 pt grid', (
      tester,
    ) async {
      await pumpKitScene(tester, const AmalfiMenu(entries: simpleEntries));
      final size = tester.getSize(find.byType(AmalfiMenu));
      expect(size.width, AmalfiMenuMetrics.minWidth);
      expect(size.height, 4 * 24 + 8);
    });

    testWidgets('a long row widens it', (tester) async {
      await pumpKitScene(
        tester,
        const AmalfiMenu(
          entries: [
            AmalfiMenuAction(
              'A rather long menu item label to widen it',
              shortcut: '⇧⌘E',
            ),
          ],
        ),
      );
      final wide = tester.getSize(find.byType(AmalfiMenu)).width;
      expect(wide, greaterThan(AmalfiMenuMetrics.minWidth));
      expect(wide % 4, 0);
    });

    testWidgets('keyboard: arrows skip disabled rows, Return chooses', (
      tester,
    ) async {
      var chosen = '';
      var dismissed = 0;
      await pumpKitScene(
        tester,
        AmalfiMenu(
          autofocus: true,
          onDismiss: () => dismissed++,
          entries: [
            AmalfiMenuAction('One', onSelected: () => chosen = 'One'),
            const AmalfiMenuAction('Two', enabled: false),
            const AmalfiMenuDivider(),
            AmalfiMenuAction('Three', onSelected: () => chosen = 'Three'),
          ],
        ),
      );
      bool lit(String label) => tester
          .widget<AmalfiMenuItem>(find.widgetWithText(AmalfiMenuItem, label))
          .highlighted;

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(lit('One'), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(lit('Three'), isTrue);
      expect(lit('One'), isFalse);
      await tester.sendKeyEvent(LogicalKeyboardKey.home);
      await tester.pump();
      expect(lit('One'), isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyT);
      await tester.pump();
      expect(lit('Three'), isTrue);

      // Return: the highlight blinks off, back on at +74 ms, the choice lands at +114 ms.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(lit('Three'), isFalse);
      await tester.pump(AmalfiMenuMetrics.blinkOn);
      expect(lit('Three'), isTrue);
      expect(chosen, '');
      await tester.pump(
        AmalfiMenuMetrics.chooseClose - AmalfiMenuMetrics.blinkOn,
      );
      expect(chosen, 'Three');
      expect(dismissed, 1);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      expect(dismissed, 2);
    });

    testWidgets('pointer: hover highlights, a click chooses, leaving clears', (
      tester,
    ) async {
      var chosen = '';
      await pumpKitScene(
        tester,
        AmalfiMenu(
          entries: [
            AmalfiMenuAction('One', onSelected: () => chosen = 'One'),
            AmalfiMenuAction('Two', onSelected: () => chosen = 'Two'),
          ],
        ),
      );
      AmalfiMenuItem item(String l) =>
          tester.widget<AmalfiMenuItem>(menuItem(l));
      await hover(tester, menuItem('Two'));
      expect(item('Two').highlighted, isTrue);
      await moveMouse(tester, const Offset(600, 600));
      expect(item('Two').highlighted, isFalse);
      await tester.tap(menuItem('One'));
      await tester.pump(AmalfiMenuMetrics.chooseClose);
      expect(chosen, 'One');
    });

    testWidgets('submenu: opens after the delay, → and ← with the keyboard', (
      tester,
    ) async {
      await pumpKitScene(
        tester,
        AmalfiMenu(entries: fullEntries(), autofocus: true),
      );
      await hover(tester, menuItem('Open Recent'));
      await tester.pump(
        AmalfiMenuMetrics.submenuDelay - const Duration(milliseconds: 1),
      );
      expect(find.text('Fig Jam'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump();
      expect(find.text('Fig Jam'), findsOneWidget);
      // Back onto another item of the parent: the submenu closes.
      await moveMouse(tester, tester.getCenter(menuItem('New Window')));
      expect(find.text('Fig Jam'), findsNothing);

      // Keyboard: → opens it with its first item highlighted and focused; ← closes it.
      await moveMouse(tester, const Offset(900, 900));
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.pump();
      expect(
        tester.widget<AmalfiMenuItem>(menuItem('Lemon Cake')).highlighted,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(
        tester.widget<AmalfiMenuItem>(menuItem('Fig Jam')).highlighted,
        isTrue,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
      await tester.pump();
      expect(find.text('Fig Jam'), findsNothing);
      expect(
        tester.widget<AmalfiMenuItem>(menuItem('Open Recent')).highlighted,
        isTrue,
      );
    });

    testWidgets('showAmalfiMenu: fades in, a press outside closes it', (
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
      var closed = false;
      showAmalfiMenu(
        context: context,
        position: const Offset(1500, 100),
        entries: simpleEntries,
      ).then((_) => closed = true);
      await tester.pump();
      await tester.pump(AmalfiFades.instant.duration);
      expect(find.byType(AmalfiMenu), findsOneWidget);
      // Kept inside the overlay.
      expect(
        tester.getTopRight(find.byType(AmalfiMenu)).dx,
        lessThanOrEqualTo(1600),
      );
      await tester.tapAt(const Offset(10, 10));
      await tester.pump();
      await tester.pump(AmalfiFades.instant.duration * 2);
      await tester.pump();
      expect(find.byType(AmalfiMenu), findsNothing);
      expect(closed, isTrue);
    });

    testWidgets('semantics: buttons with their state', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpKitScene(tester, const AmalfiMenu(entries: simpleEntries));
      expect(
        tester.getSemantics(menuItem('Lemon')),
        matchesSemantics(
          label: 'Lemon',
          isButton: true,
          hasEnabledState: true,
          isEnabled: true,
          hasCheckedState: true,
          isChecked: true,
          hasSelectedState: true,
          hasTapAction: true,
        ),
      );
      semantics.dispose();
    });
  });

  testWidgets(
    'a menu that goes away during the blink still runs its choice and '
    'closes its root',
    (tester) async {
      final log = <String>[];
      final show = ValueNotifier(true);
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ValueListenableBuilder<bool>(
            valueListenable: show,
            builder: (_, on, _) => on
                ? Align(
                    alignment: Alignment.topLeft,
                    child: AmalfiMenu(
                      autofocus: true,
                      onDismiss: () => log.add('dismissed'),
                      entries: [
                        AmalfiMenuAction('Go', onSelected: () => log.add('go')),
                      ],
                    ),
                  )
                : const SizedBox(),
          ),
        ),
      );
      await tester.tap(find.text('Go'));
      await tester.pump(const Duration(milliseconds: 20));
      show.value = false;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(log, ['go', 'dismissed']);
    },
  );
}
