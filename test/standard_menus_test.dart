import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';
import 'package:silica_ui/src/about.dart' show iconFolderNextTo;

import 'menu_bar_test.dart' show choose, mockChannel;

/// The roles of the items of a menu of the model, separators as '—'.
List<String> roles(Map menu) => [
  for (final item in (menu['items'] as List).cast<Map>())
    item['separator'] == true
        ? '—'
        : (item['role'] as String?) ?? item['label'] as String,
];

Future<List<Map>> publish(
  WidgetTester tester,
  List<PlatformMenuItem> menus,
) async {
  final calls = mockChannel(tester);
  await tester.pumpWidget(SilicaMenuBar(menus: menus, child: const SizedBox()));
  await tester.pump();
  final model = calls.lastWhere((c) => c.method == 'setMenus').arguments;
  return ((model as Map)['menus'] as List).cast<Map>();
}

void main() {
  setUp(SilicaApp.reset);
  tearDown(SilicaApp.reset);

  testWidgets(
    'an app that declares no app, Window or Help menu gets the standard ones',
    (tester) async {
      SilicaApp.info = const SilicaAppInfo(name: 'Clock', version: '0.1.0');
      final menus = await publish(tester, [
        SilicaMenu(
          label: 'View',
          menus: [SilicaMenuItem(label: 'Alarms', onSelected: () {})],
        ),
      ]);
      expect(menus.map((m) => m['role']), ['app', null, 'window', 'help']);
      expect(menus.first['label'], 'Clock');
      // About always, enabled with an action; no Settings without a settings action.
      expect(roles(menus.first), [
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
      final about = (menus.first['items'] as List).first as Map;
      expect(about['enabled'], isTrue);
      expect(about['id'], isA<int>());
      // Window and Help come with the bar's labels and items (empty label, no items).
      expect(menus[2]['label'], '');
      expect(menus[3]['label'], '');
    },
  );

  testWidgets('Settings… ⌘, is there only with a settings action', (
    tester,
  ) async {
    var opened = 0;
    SilicaApp.onSettings = () => opened++;
    final menus = await publish(tester, [SilicaMenus.app('Mail')]);
    expect(roles(menus.first).take(4), ['about', '—', 'settings', '—']);
    final settings = (menus.first['items'] as List).cast<Map>().firstWhere(
      (i) => i['role'] == 'settings',
    );
    expect(settings['enabled'], isTrue);
    expect(settings['shortcut'], {'key': ',', 'meta': true});
    await choose(tester, settings['id'] as int);
    expect(opened, 1);
  });

  testWidgets('the app\'s own app, Window and Help menus are not doubled', (
    tester,
  ) async {
    final menus = await publish(tester, [
      SilicaMenus.app('Calculator', items: [const SilicaMenuItem(label: 'X')]),
      SilicaMenus.window('Window', close: true),
      SilicaMenus.help('Help'),
    ]);
    expect(menus.map((m) => m['role']), ['app', 'window', 'help']);
    expect(roles(menus.first).take(4), ['about', '—', 'X', '—']);
  });

  testWidgets('About <App> opens the standard About panel, once', (
    tester,
  ) async {
    final windowCalls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SilicaWindow.channel,
      (call) async {
        windowCalls.add(call);
        // The test view stands for the panel's view (id 0).
        return call.method == 'openWindow' ? 0 : true;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SilicaWindow.channel,
        null,
      );
      SilicaWindows.reset();
    });
    SilicaApp.info = const SilicaAppInfo(
      name: 'Calculator',
      version: '0.1.0',
      icon: 'calculator',
    );
    final menus = await publish(tester, [SilicaMenus.app('')]);
    final about = (menus.first['items'] as List).first as Map;
    await choose(tester, about['id'] as int);
    await tester.pump();
    final open = windowCalls.where((c) => c.method == 'openWindow').toList();
    expect(open, hasLength(1));
    final info = SilicaApp.info;
    expect(open.single.arguments, containsPair('kind', 'utility'));
    expect(
      open.single.arguments,
      containsPair('width', SilicaAboutMetrics.width),
    );
    expect(
      open.single.arguments,
      containsPair('height', SilicaAboutMetrics.heightFor(info)),
    );
    // Its minimum and maximum are its size: a panel that does not resize.
    expect(
      open.single.arguments,
      containsPair('maxHeight', SilicaAboutMetrics.heightFor(info)),
    );
    // A second About while it is open opens no other.
    await choose(tester, about['id'] as int);
    await tester.pump();
    expect(windowCalls.where((c) => c.method == 'openWindow'), hasLength(1));
  });

  testWidgets('the About panel shows the icon, name, version and copyright', (
    tester,
  ) async {
    const info = SilicaAppInfo(
      name: 'Calculator',
      version: '0.1.0',
      icon: 'calculator',
    );
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: SilicaAboutMetrics.width,
            child: SilicaAboutPanel(info: info),
          ),
        ),
      ),
    );
    expect(find.text('Calculator'), findsOneWidget);
    expect(find.text('Version 0.1.0'), findsOneWidget);
    expect(find.text(SilicaAppInfo.defaultCopyright), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const ValueKey('about icon'))),
      const Size.square(SilicaAboutMetrics.iconSide),
    );
    // The window is exactly as tall as the content: nothing is cut, nothing scrolls.
    expect(
      tester.getSize(find.byType(SilicaAboutPanel)).height,
      SilicaAboutMetrics.heightFor(info),
    );
    // Without a version or a copyright their lines go, and the height with them.
    const bare = SilicaAppInfo(name: 'X', copyright: '');
    await tester.pumpWidget(
      const Directionality(
        textDirection: TextDirection.ltr,
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: SilicaAboutMetrics.width,
            child: SilicaAboutPanel(info: bare),
          ),
        ),
      ),
    );
    expect(find.byKey(const ValueKey('about version')), findsNothing);
    expect(find.byKey(const ValueKey('about copyright')), findsNothing);
    expect(
      tester.getSize(find.byType(SilicaAboutPanel)).height,
      SilicaAboutMetrics.heightFor(bare),
    );
  });

  test('the icon is the folder installed next to the bundle', () {
    final root = Directory.systemTemp.createTempSync('about-icon');
    addTearDown(() => root.deleteSync(recursive: true));
    final bundle = Directory('${root.path}/app/flutter_assets')
      ..createSync(recursive: true);
    expect(iconFolderNextTo(bundle.path), isNull);
    Directory('${root.path}/app/icon').createSync();
    File('${root.path}/app/icon/icon.assets').writeAsStringSync('x');
    expect(iconFolderNextTo(bundle.path), '${root.path}/app/icon');
    expect(iconFolderNextTo('${bundle.path}/'), '${root.path}/app/icon');
  });
}
