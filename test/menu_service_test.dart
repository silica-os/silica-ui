import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  tearDown(SilicaMenuService.reset);

  test('entries flatten to typed rows with ids and the selected row', () {
    final chosen = <String>[];
    final menu = ServiceMenu.from([
      const AmalfiMenuSection('Edit'),
      AmalfiMenuAction(
        'Copy',
        shortcut: '⌥⌘C',
        checked: true,
        iconName: 'doc',
        onSelected: () => chosen.add('copy'),
      ),
      const AmalfiMenuDivider(),
      AmalfiMenuAction(
        'Share',
        submenu: [
          AmalfiMenuAction('Mail', onSelected: () => chosen.add('mail')),
        ],
      ),
      const AmalfiMenuAction('Off', enabled: false),
      AmalfiMenuAction(
        'Delete',
        destructive: true,
        onSelected: () => chosen.add('del'),
      ),
    ], selectedIndex: 5);
    expect([for (final r in menu.rows) r['kind']], [2, 0, 1, 3, 0, 4, 0, 0]);
    expect(menu.rows[1], {
      'kind': 0,
      'id': 1,
      'label': 'Copy',
      'flags': 2,
      'icon': 'doc',
      'key': 'C',
      'modifiers': 5,
    });
    expect(menu.rows[6]['flags'], 1);
    expect(menu.selectedId, 4);
    menu.run(2);
    menu.run(1);
    menu.run(99);
    expect(chosen, ['mail', 'copy']);
  });

  testWidgets('a context menu goes through the service and its choice runs', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      'silica/popupmenu',
      (data) async {
        final call = const JSONMethodCodec().decodeMethodCall(data);
        calls.add(call);
        if (call.method == 'show') {
          // The user chooses row 2 a moment later.
          Future(() async {
            await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
              'silica/popupmenu',
              const JSONMethodCodec().encodeMethodCall(
                MethodCall('result', {
                  'token': (call.arguments as Map)['token'],
                  'id': 2,
                }),
              ),
              (_) {},
            );
          });
        }
        return const JSONMethodCodec().encodeSuccessEnvelope(true);
      },
    );
    expect(await tester.runAsync(SilicaMenuService.probe), isTrue);
    final chosen = <String>[];
    late BuildContext context;
    await tester.pumpWidget(
      Builder(
        builder: (c) {
          context = c;
          return const SizedBox();
        },
      ),
    );
    await tester.runAsync(
      () => showAmalfiMenu(
        context: context,
        position: const Offset(30, 40),
        entries: [
          AmalfiMenuAction('A', onSelected: () => chosen.add('a')),
          AmalfiMenuAction('B', onSelected: () => chosen.add('b')),
        ],
      ),
    );
    expect(chosen, ['b']);
    final show = calls.firstWhere((c) => c.method == 'show').arguments as Map;
    expect(show['anchor'], [30.0, 40.0, 0.0, 0.0]);
    expect(show['kind'], 0);
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      'silica/popupmenu',
      null,
    );
  });

  testWidgets('a pop-up button asks the service with its selected row', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMessageHandler(
      'silica/popupmenu',
      (data) async {
        final call = const JSONMethodCodec().decodeMethodCall(data);
        calls.add(call);
        return const JSONMethodCodec().encodeSuccessEnvelope(true);
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMessageHandler(
        'silica/popupmenu',
        null,
      ),
    );
    await tester.runAsync(SilicaMenuService.probe);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: AmalfiTheme(
          brightness: Brightness.light,
          child: Center(
            child: AmalfiPopUpButton<int>(
              items: const [
                AmalfiPopUpItem(value: 1, label: 'One'),
                AmalfiPopUpItem(value: 2, label: 'Two'),
              ],
              value: 2,
              onChanged: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byType(AmalfiPopUpButton<int>));
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pump();
    final show = calls.firstWhere((c) => c.method == 'show').arguments as Map;
    expect(show['kind'], 1);
    expect(show['selected'], 2);
    expect((show['anchor'] as List)[2], greaterThan(0));
    // Nothing is drawn in the window: the shell draws it.
    expect(find.text('One'), findsNothing);
  });

  testWidgets('without the service the menu is drawn in the window', (
    tester,
  ) async {
    late BuildContext context;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: AmalfiTheme(
          brightness: Brightness.light,
          child: Overlay(
            initialEntries: [
              OverlayEntry(
                builder: (c) {
                  context = c;
                  return const SizedBox();
                },
              ),
            ],
          ),
        ),
      ),
    );
    unawaited(
      showAmalfiMenu(
        context: context,
        position: const Offset(10, 10),
        entries: [AmalfiMenuAction('Only')],
      ),
    );
    await tester.pump();
    expect(find.text('Only'), findsOneWidget);
  });
}

void unawaited(Future<void> f) {}
