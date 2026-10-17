import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final icons = Platform.environment['SILICA_ICONS_DIR'] ?? '';
  final env = {'SILICA_ICONS_DIR': icons, 'HOME': '/nonexistent'};

  tearDown(
    () => messenger.setMockMethodCallHandler(SilicaThumbnails.channel, null),
  );

  Widget host(Widget child) => Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: const MediaQueryData(devicePixelRatio: 2),
      child: Center(child: child),
    ),
  );

  testWidgets(
    'a folder from the service draws the generic layers until the PNG '
    'arrives, and the layers also draw when the service is missing',
    (tester) async {
      final gate = Completer<List<Object?>>();
      messenger.setMockMethodCallHandler(
        SilicaThumbnails.channel,
        (call) => gate.future,
      );
      await tester.pumpWidget(
        host(
          SilicaIcon(
            ServiceSource(Uri.file('/home/a/Docs'), isFolder: true),
            side: 64,
            env: env,
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(SvgPicture), findsAtLeastNWidgets(2));
      gate.complete(const []);
      await tester.pump();
      expect(tester.getSize(find.byType(SilicaFileIcon)), const Size(64, 64));
    },
    skip: icons.isEmpty,
  );

  testWidgets('the PNG of the service replaces the layers', (tester) async {
    final png = File('${Directory.systemTemp.path}/silica-svc-icon.png');
    // 1x1 transparent PNG.
    png.writeAsBytesSync(
      Uint8List.fromList([
        0x89,
        0x50,
        0x4e,
        0x47,
        0x0d,
        0x0a,
        0x1a,
        0x0a,
        0x00,
        0x00,
        0x00,
        0x0d,
        0x49,
        0x48,
        0x44,
        0x52,
        0x00,
        0x00,
        0x00,
        0x01,
        0x00,
        0x00,
        0x00,
        0x01,
        0x08,
        0x06,
        0x00,
        0x00,
        0x00,
        0x1f,
        0x15,
        0xc4,
        0x89,
        0x00,
        0x00,
        0x00,
        0x0d,
        0x49,
        0x44,
        0x41,
        0x54,
        0x78,
        0x9c,
        0x63,
        0xf8,
        0xcf,
        0xc0,
        0xf0,
        0x1f,
        0x00,
        0x05,
        0x00,
        0x01,
        0xff,
        0x89,
        0x99,
        0x3d,
        0x1d,
        0x00,
        0x00,
        0x00,
        0x00,
        0x49,
        0x45,
        0x4e,
        0x44,
        0xae,
        0x42,
        0x60,
        0x82,
      ]),
    );
    addTearDown(png.deleteSync);
    messenger.setMockMethodCallHandler(
      SilicaThumbnails.channel,
      (call) async => [png.path, false],
    );
    await tester.pumpWidget(
      host(
        SilicaIcon(
          ServiceSource(Uri.file('/home/a/Pictures'), isFolder: true),
          side: 64,
          env: env,
        ),
      ),
    );
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump();
    }
    expect(find.byType(Image), findsOneWidget);
  });
}
