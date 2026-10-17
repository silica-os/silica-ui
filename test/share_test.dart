import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final files = [Uri.file('/home/a/My File.png')];

  tearDown(() => messenger.setMockMethodCallHandler(SilicaShare.channel, null));

  test('targets come from the service, malformed entries skipped', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(SilicaShare.channel, (call) async {
      calls.add(call);
      return [
        [
          ['copy', 'Copy', ''],
          ['dev.frascella.Mail', 'Mail', 'dev.frascella.Mail'],
          ['', 7],
        ],
      ];
    });
    final targets = await SilicaShare.targets(files);
    expect(targets.map((t) => t.id), ['copy', 'dev.frascella.Mail']);
    expect(targets[1].icon, 'dev.frascella.Mail');
    final args = calls.single.arguments as Map;
    expect(args['method'], 'Targets');
    expect(args['signature'], 'as');
    expect(args['args'], [
      ['file:///home/a/My%20File.png'],
    ]);
  });

  test('no service: no targets, sharing fails', () async {
    messenger.setMockMethodCallHandler(SilicaShare.channel, (call) async {
      throw PlatformException(
        code: 'org.freedesktop.DBus.Error.ServiceUnknown',
      );
    });
    expect(await SilicaShare.targets(files), isEmpty);
    expect(
      await SilicaShare.share(
        const SilicaShareTarget(id: 'copy', name: 'Copy'),
        files,
      ),
      isFalse,
    );
    expect(await SilicaShare.targets(const []), isEmpty);
  });

  test('share sends the target id and the URIs', () async {
    Map? sent;
    messenger.setMockMethodCallHandler(SilicaShare.channel, (call) async {
      sent = call.arguments as Map;
      return [true];
    });
    final ok = await SilicaShare.share(
      const SilicaShareTarget(id: 'dev.frascella.Mail', name: 'Mail'),
      files,
    );
    expect(ok, isTrue);
    expect(sent!['method'], 'Share');
    expect(sent!['signature'], 'sas');
    expect(sent!['args'], [
      'dev.frascella.Mail',
      ['file:///home/a/My%20File.png'],
    ]);
  });

  test('the menu lists apps, a divider, then Copy', () {
    final chosen = <String>[];
    final entries = silicaShareEntries(
      const [
        SilicaShareTarget(id: 'copy', name: 'Copy'),
        SilicaShareTarget(id: 'dev.frascella.Mail', name: 'Mail'),
      ],
      copyLabel: 'Copia',
      onShare: (t) => chosen.add(t.id),
    );
    expect(entries, hasLength(3));
    expect((entries[0] as AmalfiMenuAction).label, 'Mail');
    expect(entries[1], isA<AmalfiMenuDivider>());
    final copy = entries[2] as AmalfiMenuAction;
    expect(copy.label, 'Copia');
    copy.onSelected!();
    (entries[0] as AmalfiMenuAction).onSelected!();
    expect(chosen, ['copy', 'dev.frascella.Mail']);
    // Only Copy: no divider.
    expect(
      silicaShareEntries(
        const [SilicaShareTarget(id: 'copy', name: 'Copy')],
        copyLabel: 'Copy',
        onShare: (_) {},
      ),
      hasLength(1),
    );
  });
}
