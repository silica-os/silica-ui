import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

/// The calls on `silica/menu`, answered as the embedder does.
List<MethodCall> mockChannel(WidgetTester tester) {
  final calls = <MethodCall>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SilicaMenuDelegate.defaultChannel,
    (call) async {
      calls.add(call);
      return true;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SilicaMenuDelegate.defaultChannel,
      null,
    ),
  );
  return calls;
}

/// The bar chooses item `id`.
Future<void> choose(WidgetTester tester, int id) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SilicaMenuDelegate.defaultChannel.name,
    const JSONMethodCodec().encodeMethodCall(MethodCall('activated', id)),
    (_) {},
  );
}

const SingleActivator cmd1 = SingleActivator(
  LogicalKeyboardKey.digit1,
  meta: true,
);

class Calc extends StatefulWidget {
  const Calc({super.key, required this.log});
  final List<String> log;

  @override
  State<Calc> createState() => CalcState();
}

class CalcState extends State<Calc> {
  String mode = 'basic';
  int places = 8;
  final FocusNode focus = FocusNode();

  /// A rebuild with the same state.
  void rebuild() => setState(() {});

  @override
  void dispose() {
    focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SilicaMenuBar(
    menus: [
      SilicaMenus.app('Calculator', onAbout: () => widget.log.add('about')),
      SilicaMenus.edit('Edit', copy: () => widget.log.add('copy')),
      SilicaMenu(
        label: 'View',
        menus: [
          PlatformMenuItemGroup(
            members: [
              SilicaMenuItem(
                label: 'Basic',
                checked: mode == 'basic',
                icon: 'notes',
                shortcut: cmd1,
                onSelected: () => setState(() => mode = 'basic'),
              ),
              SilicaMenuItem(
                label: 'Scientific',
                checked: mode == 'scientific',
                shortcut: const SingleActivator(
                  LogicalKeyboardKey.digit2,
                  meta: true,
                ),
                onSelected: () => setState(() => mode = 'scientific'),
              ),
            ],
          ),
          SilicaMenu(
            label: 'Decimal Places',
            menus: [
              for (final p in [0, 8])
                SilicaMenuItem(
                  label: '$p',
                  checked: places == p,
                  onSelected: () => setState(() => places = p),
                ),
            ],
          ),
          const SilicaMenuItem.system(
            SilicaMenuItemRole.fullScreen,
            enabled: false,
          ),
        ],
      ),
      SilicaMenus.window('Window', close: true),
      SilicaMenus.help('Help'),
    ],
    child: Focus(focusNode: focus, autofocus: true, child: const SizedBox()),
  );
}

void main() {
  testWidgets('the menus become the protocol model', (tester) async {
    final calls = mockChannel(tester);
    final log = <String>[];
    await tester.pumpWidget(Calc(log: log));
    await tester.pump();
    final sets = calls.where((c) => c.method == 'setMenus').toList();
    // Clear and set when the bar starts: only the set goes out.
    expect(calls.map((c) => c.method), ['setMenus']);
    final model = sets.single.arguments as Map;
    final menus = model['menus'] as List;
    expect(menus.map((m) => (m as Map)['label']), [
      'Calculator',
      'Edit',
      'View',
      'Window',
      'Help',
    ]);
    expect(menus.map((m) => (m as Map)['role']), [
      'app',
      null,
      null,
      'window',
      'help',
    ]);
    final app = (menus[0] as Map)['items'] as List;
    expect(app.map((i) => (i as Map)['role'] ?? (i['separator'] ? '—' : '')), [
      'about',
      '—',
      'services',
      '—',
      'hide',
      'hide_others',
      'show_all',
      '—',
      'quit',
    ]);
    // About has an action (an id); the system items have none and are enabled.
    expect((app[0] as Map)['id'], isA<int>());
    expect((app.last as Map).containsKey('id'), isFalse);
    expect((app.last as Map)['enabled'], isTrue);

    final edit = (menus[1] as Map)['items'] as List;
    final copy = edit.cast<Map>().firstWhere((i) => i['role'] == 'copy');
    expect(copy['enabled'], isTrue);
    expect(copy['shortcut'], {'key': 'C', 'meta': true});
    final undo = edit.cast<Map>().firstWhere((i) => i['role'] == 'undo');
    expect(undo['enabled'], isFalse);
    expect(undo.containsKey('id'), isFalse);

    final view = (menus[2] as Map)['items'] as List;
    expect(view[0], {
      'id': (view[0] as Map)['id'],
      'label': 'Basic',
      'enabled': true,
      'checked': true,
      'icon': 'notes',
      'shortcut': {'key': '1', 'meta': true},
    });
    expect((view[1] as Map)['checked'], isNull);
    expect(view[2], {'separator': true});
    final places = (view[3] as Map)['items'] as List;
    expect(places.map((p) => (p as Map)['checked']), [null, true]);
    expect(view[4], {'label': '', 'enabled': false, 'role': 'fullscreen'});

    final window = (menus[3] as Map)['items'] as List;
    expect(window.single, {'label': '', 'enabled': true, 'role': 'close'});
    final help = (menus[4] as Map)['items'] as List;
    expect(help, isEmpty);
  });

  testWidgets(
    'a choice in the bar runs the item; the model follows the state',
    (tester) async {
      final calls = mockChannel(tester);
      final log = <String>[];
      await tester.pumpWidget(Calc(log: log));
      await tester.pump();
      final state = tester.state<CalcState>(find.byType(Calc));
      int idOf(String label) {
        Map? find(List items) {
          for (final i in items.cast<Map>()) {
            if (i['label'] == label) return i;
            if (i['items'] case final List sub) {
              if (find(sub) case final found?) return found;
            }
          }
          return null;
        }

        final model = calls.lastWhere((c) => c.method == 'setMenus').arguments;
        for (final menu in (model as Map)['menus'] as List) {
          if (find((menu as Map)['items'] as List) case final item?) {
            return item['id'] as int;
          }
        }
        throw StateError('no $label');
      }

      final scientific = idOf('Scientific');
      final basic = idOf('Basic');
      await choose(tester, scientific);
      await tester.pump();
      expect(state.mode, 'scientific');
      // The checkmark moved: a new model went out.
      expect(calls.where((c) => c.method == 'setMenus').length, 2);
      // A choice made in the bar just before the change still reaches its item.
      await choose(tester, basic);
      await tester.pump();
      expect(state.mode, 'basic');
      // An id nobody knows does nothing.
      await choose(tester, 999999);
      await tester.pump();
      // A rebuild with the same menus sends nothing.
      final count = calls.length;
      state.rebuild();
      await tester.pump();
      expect(calls.length, count);
      // The submenu's items and the app menu's About come back too.
      await choose(tester, idOf('0'));
      await tester.pump();
      expect(state.places, 0);
      final model = calls.lastWhere((c) => c.method == 'setMenus').arguments;
      final about =
          (((model as Map)['menus'] as List)[0] as Map)['items'] as List;
      await choose(tester, (about.first as Map)['id'] as int);
      expect(log, ['about']);
    },
  );

  testWidgets('the shortcuts work inside the app; disabled items do not', (
    tester,
  ) async {
    mockChannel(tester);
    final log = <String>[];
    await tester.pumpWidget(Calc(log: log));
    await tester.pump();
    final state = tester.state<CalcState>(find.byType(Calc));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
    // ⌘Z: Undo is disabled in this app.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(state.mode, 'scientific');
    expect(log, ['copy']);
  });

  testWidgets('the bar is cleared when the menus go away', (tester) async {
    final calls = mockChannel(tester);
    await tester.pumpWidget(Calc(log: const []));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(calls.map((c) => c.method), ['setMenus', 'clearMenus']);
  });

  testWidgets('Flutter\'s own PlatformMenuBar publishes too', (tester) async {
    final calls = mockChannel(tester);
    var chosen = 0;
    SilicaMenuDelegate.install();
    await tester.pumpWidget(
      PlatformMenuBar(
        menus: [
          PlatformMenu(
            label: 'Notes',
            menus: [
              const PlatformProvidedMenuItem(
                type: PlatformProvidedMenuItemType.about,
              ),
              const PlatformProvidedMenuItem(
                type: PlatformProvidedMenuItemType.quit,
              ),
              // Not offered in Silica: left out.
              const PlatformProvidedMenuItem(
                type: PlatformProvidedMenuItemType.startSpeaking,
              ),
            ],
          ),
          PlatformMenu(
            label: 'File',
            menus: [
              PlatformMenuItem(
                label: 'New Note',
                shortcut: const SingleActivator(
                  LogicalKeyboardKey.keyN,
                  meta: true,
                ),
                onSelected: () => chosen++,
              ),
              const PlatformMenuItem(label: 'Nothing to do'),
              PlatformMenuItem(
                label: 'Help',
                shortcut: const CharacterActivator('?', meta: true),
                onSelected: () {},
              ),
            ],
          ),
        ],
        child: const SizedBox(),
      ),
    );
    await tester.pump();
    final model = calls.single.arguments as Map;
    final menus = model['menus'] as List;
    // The standard app menu first, then the app's own, then Window and Help (silica-ui#99).
    expect(menus.map((m) => (m as Map)['role']), [
      'app',
      null,
      null,
      'window',
      'help',
    ]);
    expect((menus[1] as Map)['items'], [
      {'role': 'about', 'enabled': true},
      {'role': 'quit', 'enabled': true},
    ]);
    final file = (menus[2] as Map)['items'] as List;
    expect((file[0] as Map)['shortcut'], {'key': 'N', 'meta': true});
    expect(file[1], {'label': 'Nothing to do', 'enabled': false});
    expect((file[2] as Map)['shortcut'], {'key': '?', 'meta': true});
    await choose(tester, (file[0] as Map)['id'] as int);
    expect(chosen, 1);
  });

  test('key names as the bar shows them', () {
    expect(silicaMenuKeyName(LogicalKeyboardKey.keyA), 'A');
    expect(silicaMenuKeyName(LogicalKeyboardKey.arrowLeft), 'Left');
    expect(silicaMenuKeyName(LogicalKeyboardKey.enter), 'Return');
    expect(silicaMenuKeyName(LogicalKeyboardKey.f5), 'F5');
    expect(silicaMenuKeyName(LogicalKeyboardKey.comma), ',');
    expect(silicaMenuShortcut(null), isNull);
    expect(
      silicaMenuShortcut(
        const SingleActivator(
          LogicalKeyboardKey.keyS,
          control: true,
          meta: true,
          shift: true,
          alt: true,
        ),
      ),
      {'key': 'S', 'meta': true, 'ctrl': true, 'alt': true, 'shift': true},
    );
  });

  testWidgets('File › Close All is a standard item with ⌥⌘W', (tester) async {
    final calls = mockChannel(tester);
    await tester.pumpWidget(
      SilicaMenuBar(
        menus: [
          SilicaMenu(label: 'File', menus: [SilicaMenuItem.closeAll()]),
        ],
        child: const SizedBox(),
      ),
    );
    await tester.pump();
    final model = calls.single.arguments as Map;
    final file = (model['menus'] as List).cast<Map>().firstWhere(
      (m) => m['label'] == 'File',
    );
    final item = file['items'] as List;
    expect(item.single, containsPair('role', 'close_all'));
    expect(item.single, containsPair('enabled', true));
    expect(item.single, contains('id'));
    expect((item.single as Map)['shortcut'], containsPair('key', 'W'));
  });
}
