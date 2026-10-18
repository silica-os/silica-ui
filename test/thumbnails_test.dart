import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final file = Uri.file('/home/a/My File.png');

  tearDown(
    () => messenger.setMockMethodCallHandler(SilicaThumbnails.channel, null),
  );

  test('the request carries the URI and the pixel size', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(SilicaThumbnails.channel, (call) async {
      calls.add(call);
      return ['/cache/thumbnails/large/x.png'];
    });
    expect(
      await SilicaThumbnails.thumbnail(file, 200),
      '/cache/thumbnails/large/x.png',
    );
    final args = calls.single.arguments as Map;
    expect(args['interface'], 'dev.frascella.Silica.Thumbnails1');
    expect(args['method'], 'Thumbnail');
    expect(args['signature'], 'su');
    expect(args['args'], ['file:///home/a/My%20File.png', 200]);
  });

  test(
    'an empty path, a missing service or a bad size mean no thumbnail',
    () async {
      messenger.setMockMethodCallHandler(
        SilicaThumbnails.channel,
        (call) async => [''],
      );
      expect(await SilicaThumbnails.thumbnail(file, 64), isNull);
      messenger.setMockMethodCallHandler(SilicaThumbnails.channel, (
        call,
      ) async {
        throw PlatformException(
          code: 'org.freedesktop.DBus.Error.ServiceUnknown',
        );
      });
      expect(await SilicaThumbnails.thumbnail(file, 64), isNull);
      messenger.setMockMethodCallHandler(SilicaThumbnails.channel, null);
      expect(await SilicaThumbnails.thumbnail(file, 64), isNull);
      expect(await SilicaThumbnails.thumbnail(file, 0), isNull);
      await SilicaThumbnails.invalidate([file]);
    },
  );

  test('invalidate sends the URIs', () async {
    Map? sent;
    messenger.setMockMethodCallHandler(SilicaThumbnails.channel, (call) async {
      sent = call.arguments as Map;
      return const [];
    });
    await SilicaThumbnails.invalidate([file]);
    expect(sent?['method'], 'Invalidate');
    expect(sent?['signature'], 'as');
    expect(sent?['args'], [
      ['file:///home/a/My%20File.png'],
    ]);
  });

  testWidgets('the fallback shows until the PNG is ready, at size x ratio', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetDevicePixelRatio);
    final gate = Completer<List<Object?>>();
    Map? sent;
    messenger.setMockMethodCallHandler(SilicaThumbnails.channel, (call) {
      sent = call.arguments as Map;
      return gate.future;
    });
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 2),
          child: SilicaThumbnail(
            file: file,
            size: 64,
            fallback: const SizedBox(key: Key('icon'), width: 64, height: 64),
          ),
        ),
      ),
    );
    expect(find.byKey(const Key('icon')), findsOneWidget);
    expect((sent?['args'] as List?)?.last, 128);
    gate.complete(['/cache/thumbnails/normal/x.png']);
    await tester.pump();
    await tester.pump();
    expect(find.byKey(const Key('icon')), findsNothing);
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as FileImage).file.path,
      '/cache/thumbnails/normal/x.png',
    );
    expect(image.width, 64);
    expect(image.height, 64);
  });

  testWidgets('no service: the fallback stays', (tester) async {
    messenger.setMockMethodCallHandler(SilicaThumbnails.channel, (call) async {
      throw PlatformException(
        code: 'org.freedesktop.DBus.Error.ServiceUnknown',
      );
    });
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SilicaThumbnail(
          file: file,
          size: 32,
          fallback: const SizedBox(key: Key('icon')),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('icon')), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(File('/nonexistent').existsSync(), isFalse);
  });

  test(
    'Icon carries URI, exact pixels, scale and the no-preview flag',
    () async {
      final calls = <Map>[];
      messenger.setMockMethodCallHandler(SilicaThumbnails.channel, (
        call,
      ) async {
        calls.add(call.arguments as Map);
        return ['/cache/silica/icons/128/a.png', false];
      });
      final icon = await SilicaThumbnails.icon(
        file,
        128,
        scale: 2,
        noPreview: true,
      );
      expect(icon?.path, '/cache/silica/icons/128/a.png');
      expect(icon?.preview, isFalse);
      expect(calls.single['method'], 'Icon');
      expect(calls.single['signature'], 'sudu');
      expect(calls.single['args'], [
        'file:///home/a/My%20File.png',
        128,
        2.0,
        1,
      ]);
      messenger.setMockMethodCallHandler(
        SilicaThumbnails.channel,
        (call) async => ['', false],
      );
      expect(await SilicaThumbnails.icon(file, 64), isNull);
      expect(await SilicaThumbnails.icon(file, 0), isNull);
    },
  );

  test(
    'Icon flags carry the icon style and the accent after the no-preview bit',
    () {
      int flags(IconAppearance look, {Color? accent, bool noPreview = false}) =>
          SilicaThumbnails.iconFlags(
            look: look,
            accent: accent,
            noPreview: noPreview,
          );
      expect(flags(IconAppearance.light), 0);
      expect(flags(IconAppearance.light, noPreview: true), 1);
      expect(flags(IconAppearance.dark), 4 << 1);
      expect(flags(IconAppearance.clearDark, noPreview: true), 1 | (5 << 1));
      expect(
        flags(IconAppearance.tinted, accent: const Color(0xFFD6336C)),
        (2 << 1) | (0xD6336C << 8),
      );
      // The accent only goes with the tinted styles.
      expect(
        flags(IconAppearance.clear, accent: const Color(0xFFD6336C)),
        1 << 1,
      );
    },
  );

  testWidgets('a folder icon asks for the system icon style and its accent', (
    tester,
  ) async {
    final calls = <List>[];
    messenger.setMockMethodCallHandler(SilicaThumbnails.channel, (call) async {
      calls.add((call.arguments as Map)['args'] as List);
      return ['', false];
    });
    addTearDown(SilicaSystemLook.reset);
    Future<void> pump(SystemIconStyle style) async {
      SilicaSystemLook.apply(SystemLook(iconStyle: style));
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: MediaQuery(
            data: const MediaQueryData(),
            child: SystemLookScope(
              child: SilicaFileIcon(
                file: Uri.file('/home/a/Docs'),
                size: 64,
                isFolder: true,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pump(SystemIconStyle.standard);
    expect(calls.last[3], 0);
    await pump(SystemIconStyle.dark);
    expect(calls.last[3], 4 << 1);
    await pump(SystemIconStyle.clear);
    expect(calls.last[3], 1 << 1);
    await pump(SystemIconStyle.tinted);
    expect((calls.last[3] as int) & 14, 2 << 1);
    expect((calls.last[3] as int) >> 8, isNot(0));
  });

  testWidgets('SilicaFileIcon: plain layers until the PNG, then the PNG', (
    tester,
  ) async {
    final root = Directory.systemTemp.createTempSync('file-icon-');
    addTearDown(() => root.deleteSync(recursive: true));
    const svg =
        '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1024 1024">'
        '<rect width="824" height="824" fill="#fff"/></svg>';
    final dir = Directory('${root.path}/files/file-generic')
      ..createSync(recursive: true);
    for (final n in ['back', 'front']) {
      File('${dir.path}/$n.svg').writeAsStringSync(svg);
    }
    File('${dir.path}/icon.json').writeAsStringSync(
      '{"format":1,"id":"file-generic","name":"f","kind":"file","layers":['
      '{"role":"back","file":"back.svg"},{"role":"front","file":"front.svg"}]}',
    );
    final gate = Completer<List<Object?>>();
    Map? sent;
    messenger.setMockMethodCallHandler(SilicaThumbnails.channel, (call) {
      sent = call.arguments as Map;
      return gate.future;
    });
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(devicePixelRatio: 2),
          child: SilicaFileIcon(
            file: file,
            size: 48,
            env: {'SILICA_ICONS_DIR': root.path},
          ),
        ),
      ),
    );
    expect((sent?['args'] as List).sublist(1), [96, 2.0, 0]);
    expect(find.byType(SilicaIcon), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    gate.complete(['/cache/silica/icons/96/a.png', false]);
    await tester.pump();
    await tester.pump();
    expect(find.byType(SilicaIcon), findsNothing);
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as FileImage).file.path,
      '/cache/silica/icons/96/a.png',
    );
    expect(image.width, 48);
  });

  testWidgets(
    'SilicaFileIcon.onComposed fires once the PNG is decoded, not before',
    (tester) async {
      final root = Directory.systemTemp.createTempSync('composed-');
      addTearDown(() => root.deleteSync(recursive: true));
      final png = File('${root.path}/a.png')
        ..writeAsBytesSync(
          base64Decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==',
          ),
        );
      final gate = Completer<List<Object?>>();
      messenger.setMockMethodCallHandler(
        SilicaThumbnails.channel,
        (call) => gate.future,
      );
      var composed = 0;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: SilicaFileIcon(
            file: file,
            size: 48,
            onComposed: () => composed++,
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(composed, 0);
      gate.complete([png.path, false]);
      await tester.runAsync(() async {
        for (var i = 0; i < 100 && composed == 0; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          await tester.pump();
        }
      });
      await tester.pump();
      expect(composed, 1);
      await tester.pump(const Duration(milliseconds: 100));
      expect(composed, 1);
    },
  );

  testWidgets(
    'SilicaFileIcon without the pack or the service is an empty box',
    (tester) async {
      messenger.setMockMethodCallHandler(SilicaThumbnails.channel, (
        call,
      ) async {
        throw PlatformException(code: 'x');
      });
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            child: SilicaFileIcon(
              file: file,
              size: 32,
              isFolder: true,
              env: const {
                'SILICA_ICONS_DIR': '/nonexistent',
                'HOME': '/nonexistent',
              },
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(Image), findsNothing);
      expect(
        tester.getSize(
          find.descendant(
            of: find.byType(SilicaFileIcon),
            matching: find.byType(SizedBox),
          ),
        ),
        const Size(32, 32),
      );
    },
  );

  testWidgets(
    'SilicaIcon(ServiceSource) asks the service for the whole canvas',
    (tester) async {
      Map? sent;
      messenger.setMockMethodCallHandler(SilicaThumbnails.channel, (
        call,
      ) async {
        sent = call.arguments as Map;
        return ['', false];
      });
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Align(
            child: SilicaIcon(
              ServiceSource(file, isFolder: true),
              side: 32,
              env: const {'SILICA_ICONS_DIR': '/none', 'HOME': '/none'},
            ),
          ),
        ),
      );
      await tester.pump();
      expect((sent?['args'] as List).sublist(1), [96, 3.0, 1]);
      expect(find.byType(SilicaFileIcon), findsOneWidget);
    },
  );
}
