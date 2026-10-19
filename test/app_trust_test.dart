import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(() => messenger.setMockMethodCallHandler(SilicaDBus.channel, null));

  test('blocked apps and Open Anyway', () async {
    final calls = <Map>[];
    messenger.setMockMethodCallHandler(SilicaDBus.channel, (call) async {
      final args = call.arguments as Map;
      calls.add(args);
      return switch (args['method']) {
        'Blocked' => [
          [
            ['/home/u/Applications/Mine.app', 'Mine', 1700000000],
            ['bad'],
          ],
        ],
        'OpenAnyway' => [true],
        'Assess' => [
          'block',
          {'developer': 'Me', 'developer_status': 'self-signed'},
        ],
        _ => const [],
      };
    });
    final blocked = await SilicaTrust.blocked();
    expect(blocked.single.name, 'Mine');
    expect(await SilicaTrust.openAnyway(blocked.single.path), (true, null));
    final a = (await SilicaTrust.assess('/x.app'))!;
    expect((a.verdict, a.developerStatus), ('block', 'self-signed'));
    expect(calls.map((c) => c['interface']).toSet(), {
      'dev.frascella.Silica.Trust1',
    });
  });

  test('volumes: attach errors, layout, list', () async {
    messenger.setMockMethodCallHandler(SilicaDBus.channel, (call) async {
      final args = call.arguments as Map;
      switch (args['method']) {
        case 'Attach':
          final options = (args['args'] as List)[1] as Map;
          if (options['accept_license'] != true) {
            throw PlatformException(
              code: 'org.freedesktop.DBus.Error.Failed',
              message:
                  'dev.frascella.Silica.Volumes1.Error.LicenseRequired: accept it',
            );
          }
          return ['/run/user/1000/silica-volumes/Hello'];
        case 'List':
          return [
            [
              [
                '/run/user/1000/silica-volumes/Hello',
                '/home/u/Downloads/Hello.sxv',
                {
                  'name': 'Hello',
                  'signature': 'valid',
                  'window': {
                    'width': 600.0,
                    'height': 400.0,
                    'items': [
                      ['Hello.app', 150.0, 200.0],
                      ['Applications', 450.0, 200.0],
                      ['bad'],
                    ],
                  },
                },
              ],
            ],
          ];
        case 'Inspect':
          return [
            {'name': 'Hello', 'signature': 'valid', 'license': 'Be nice.'},
          ];
      }
      return const [];
    });
    expect(await SilicaVolumes.attach('/home/u/Downloads/Hello.sxv'), (
      null,
      SilicaVolumeError.licenseRequired,
    ));
    expect(
      await SilicaVolumes.attach(
        '/home/u/Downloads/Hello.sxv',
        acceptLicense: true,
      ),
      ('/run/user/1000/silica-volumes/Hello', null),
    );
    final volume = (await SilicaVolumes.list()).single;
    expect(volume.window.width, 600);
    expect(volume.window.items.map((i) => i.name), [
      'Hello.app',
      'Applications',
    ]);
    expect((await SilicaVolumes.inspect('/x.sxv'))!.license, 'Be nice.');
  });

  test('no service: nothing', () async {
    messenger.setMockMethodCallHandler(SilicaDBus.channel, (call) async {
      throw PlatformException(
        code: 'org.freedesktop.DBus.Error.ServiceUnknown',
      );
    });
    expect(await SilicaTrust.blocked(), isEmpty);
    expect(await SilicaTrust.assess('/x'), isNull);
    expect(await SilicaVolumes.list(), isEmpty);
    expect(await SilicaVolumes.detach('/m'), isFalse);
    expect(
      SilicaVolumes.errorOf('x.Volumes1.Error.BadSignature: y'),
      SilicaVolumeError.badSignature,
    );
  });

  test('updates: check and update', () async {
    messenger.setMockMethodCallHandler(SilicaDBus.channel, (call) async {
      final args = call.arguments as Map;
      return switch (args['method']) {
        'Check' => [
          [
            [
              'dev.example.Hello',
              'bundle',
              'Hello',
              '1.0',
              '1.1',
              {'notes': 'Faster.', 'size': 1234},
            ],
            ['bad'],
          ],
        ],
        'Update' => ['installed'],
        _ => const [],
      };
    });
    final updates = (await SilicaUpdates.check())!;
    expect(updates.single.notes, 'Faster.');
    expect(updates.single.size, 1234);
    expect(await SilicaUpdates.update('dev.example.Hello'), 'installed');
  });
}
