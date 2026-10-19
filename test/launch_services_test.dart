import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(SilicaDBus.channel, null));

  final viewer = {
    'id': 'dev.example.Viewer',
    'name': 'Viewer',
    'kind': 'bundle',
    'path': '/home/u/Applications/Viewer.app',
    'location': 'user',
    'names': {'it': 'Visore'},
    'exec': 'silica-launch /home/u/Applications/Viewer.app %U',
    'silica_icon': '/home/u/Applications/Viewer.app/Contents/Resources/icon',
    'keywords': ['view'],
    'keywords_l10n': {'it': 'vedere;guardare'},
    'mime_types': ['text/plain'],
    'types': {'text/plain': 'viewer'},
    'actions': [
      ['new', 'New Window', 'viewer --new'],
      ['bad', 7],
    ],
    'permissions': {'network': false, 'devices': 'gpu'},
    'new': true,
    'added': 100,
  };

  test('List parses the properties and skips malformed items', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(SilicaDBus.channel, (call) async {
      calls.add(call);
      return [
        [
          ['dev.example.Viewer', 'Viewer', 'bundle', '/x', viewer],
          ['broken'],
          [
            '',
            '',
            '',
            '',
            {'name': 'no id'},
          ],
        ],
      ];
    });
    final apps = await SilicaApps.list();
    expect(apps, hasLength(1));
    final app = apps!.single;
    expect(app.kind, SilicaInstalledAppKind.bundle);
    expect(app.removable, isTrue);
    expect(app.nameIn('it_IT.UTF-8'), 'Visore');
    expect(app.nameIn('de'), 'Viewer');
    expect(app.keywordsIn('it'), ['vedere', 'guardare']);
    expect(app.actions.single.id, 'new');
    expect(app.types['text/plain'], 'viewer');
    expect(app.permissions['devices'], 'gpu');
    expect(app.isNew, isTrue);
    expect(app.added, 100);
    final args = calls.single.arguments as Map;
    expect(args['interface'], 'dev.frascella.Silica.Apps1');
    expect(args['method'], 'List');
  });

  test('no service: null and empty answers', () async {
    messenger.setMockMethodCallHandler(SilicaDBus.channel, (call) async {
      throw PlatformException(
        code: 'org.freedesktop.DBus.Error.ServiceUnknown',
      );
    });
    expect(await SilicaApps.list(), isNull);
    expect(await SilicaApps.get('x'), isNull);
    expect(await SilicaApps.appsFor('text/plain'), isEmpty);
    expect(await SilicaApps.defaultFor('text/plain'), isNull);
    expect(await SilicaApps.setDefault('text/plain', 'x'), isFalse);
    expect(await SilicaApps.open('x'), isNull);
    expect(await SilicaApps.uninstall('x'), isFalse);
  });

  test('calls carry their signatures', () async {
    final calls = <Map>[];
    messenger.setMockMethodCallHandler(SilicaDBus.channel, (call) async {
      final args = call.arguments as Map;
      calls.add(args);
      return switch (args['method']) {
        'AppsFor' => [
          ['a', 7, 'b'],
        ],
        'DefaultFor' => [''],
        'Open' => [42],
        _ => const [],
      };
    });
    expect(await SilicaApps.appsFor('text/plain'), ['a', 'b']);
    expect(await SilicaApps.defaultFor('image/png'), isNull);
    expect(
      await SilicaApps.open('a', uris: ['file:///x'], activationToken: 't'),
      42,
    );
    expect(await SilicaApps.setDefault('text/plain', 'a'), isTrue);
    final open = calls.firstWhere((c) => c['method'] == 'Open');
    expect(open['signature'], 'sasa{sv}');
    expect(open['args'], [
      'a',
      ['file:///x'],
      {'activation_token': 't'},
    ]);
  });

  test('signals become events', () {
    SilicaAppsEvent? parse(String member, List<Object?> args) =>
        SilicaApps.parseSignal(
          SilicaDBusSignal(
            sender: ':1.1',
            path: '/dev/frascella/Silica/Apps1',
            interface: SilicaApps.interface,
            member: member,
            args: args,
          ),
        );
    expect(parse('Added', ['a'])!.change, SilicaAppsChange.added);
    expect(parse('Removed', ['a'])!.id, 'a');
    final d = parse('DefaultChanged', ['text/plain', 'b'])!;
    expect(
      (d.change, d.id, d.type),
      (SilicaAppsChange.defaultChanged, 'b', 'text/plain'),
    );
    expect(parse('Other', const []), isNull);
  });

  test('a channel mock that answers lists does not break the signals', () async {
    messenger.setMockMethodCallHandler(SilicaDBus.channel, (call) async => [1]);
    final events = <SilicaAppsEvent>[];
    final sub = SilicaApps.events().listen(events.add);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    expect(events, isEmpty);
  });
}
