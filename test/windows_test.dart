import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

void main() {
  late List<MethodCall> calls;
  Object? Function(MethodCall call) answer = (_) => null;

  setUp(() {
    calls = [];
    answer = (_) => null;
    SilicaWindows.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SilicaWindow.channel, (call) async {
          calls.add(call);
          return answer(call);
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SilicaWindow.channel, null);
    SilicaWindows.reset();
  });

  Widget content(BuildContext context) => const SizedBox();

  testWidgets('openWindow asks the embedder for a window and tracks it', (
    tester,
  ) async {
    // The test view stands for the new window's view (id 0 here).
    answer = (call) => call.method == 'openWindow' ? 0 : true;
    final window = await SilicaWindows.openWindow(
      title: 'Notes Info',
      size: const Size(265, 520),
      minSize: const Size(265, 300),
      kind: SilicaWindowKind.utility,
      parent: 0,
      toolbarHeight: 52,
      builder: content,
    );
    expect(window, isNotNull);
    expect(window!.viewId, 0);
    expect(window.isOpen, isTrue);
    expect(SilicaWindows.open.value, [window]);
    expect(calls.single.method, 'openWindow');
    expect(calls.single.arguments, {
      'title': 'Notes Info',
      'width': 265.0,
      'height': 520.0,
      'minWidth': 265.0,
      'minHeight': 300.0,
      'kind': 'utility',
      'parent': 0,
      'toolbarHeight': 52.0,
    });

    // Its calls name its view.
    expect(await window.setTitle('Other Info'), isTrue);
    expect(calls.last.arguments, {'viewId': 0, 'title': 'Other Info'});
  });

  testWidgets('without the embedder there is no window', (tester) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SilicaWindow.channel,
          (call) async => throw MissingPluginException(),
        );
    final window = await SilicaWindows.openWindow(
      title: 'x',
      size: const Size(100, 100),
      builder: content,
    );
    expect(window, isNull);
    expect(SilicaWindows.open.value, isEmpty);
  });

  testWidgets('a window the embedder could not open is null', (tester) async {
    answer = (_) => null;
    final window = await SilicaWindows.openWindow(
      title: 'x',
      size: const Size(100, 100),
      builder: content,
    );
    expect(window, isNull);
  });

  testWidgets('the close button asks the window, which may keep itself open', (
    tester,
  ) async {
    answer = (call) => call.method == 'openWindow' ? 0 : null;
    final window = (await SilicaWindows.openWindow(
      title: 'Compose',
      size: const Size(600, 500),
      builder: content,
    ))!;
    calls.clear();

    // Kept: the app says it is asking, then answers; nothing is closed.
    window.onCloseRequested = () async => false;
    expect(
      await SilicaWindows.handle('closeRequested', {'viewId': 0, 'request': 3}),
      isTrue,
    );
    expect(calls.single.method, 'closeAsking');
    expect(calls.single.arguments, {'viewId': 0, 'request': 3});
    calls.clear();

    // Agreed: the window closes itself.
    window.onCloseRequested = () async => true;
    expect(await SilicaWindows.handle('closeRequested', {'viewId': 0}), isTrue);
    expect(calls.map((call) => call.method), ['closeAsking', 'closeWindow']);
    expect(calls.last.arguments, {'viewId': 0});

    // No question: it closes without asking.
    window.onCloseRequested = null;
    calls.clear();
    expect(await SilicaWindows.handle('closeRequested', {'viewId': 0}), isTrue);
    expect(calls.single.method, 'closeWindow');

    // Gone: the controller completes and leaves the list.
    var closed = false;
    window.closed.then((_) => closed = true);
    await SilicaWindows.handle('windowClosed', {'viewId': 0});
    await tester.pump();
    expect(closed, isTrue);
    expect(window.isOpen, isFalse);
    expect(SilicaWindows.open.value, isEmpty);

    // An unknown window: the embedder closes it by itself.
    expect(
      await SilicaWindows.handle('closeRequested', {'viewId': 9}),
      isFalse,
    );
  });

  test('the main window asks the app before it closes', () async {
    // No handler: the embedder closes the window, nothing is asked.
    expect(
      await SilicaWindows.handle('closeRequested', {'viewId': 0, 'request': 1}),
      isFalse,
    );
    expect(calls, isEmpty);
    // Kept (a confirmation said no): the app says it is asking (the embedder waits with no
    // limit), then answers; the embedder keeps the window.
    SilicaWindows.onMainCloseRequested = () async => false;
    expect(
      await SilicaWindows.handle('closeRequested', {'viewId': 0, 'request': 2}),
      isTrue,
    );
    expect(calls.single.method, 'closeAsking');
    expect(calls.single.arguments, {'viewId': 0, 'request': 2});
    // Agreed: the embedder closes it.
    SilicaWindows.onMainCloseRequested = () async => true;
    expect(
      await SilicaWindows.handle('closeRequested', {'viewId': 0}),
      isFalse,
    );
    // Another window is not the main one.
    SilicaWindows.onMainCloseRequested = () async => false;
    expect(
      await SilicaWindows.handle('closeRequested', {'viewId': 9}),
      isFalse,
    );
    SilicaWindows.onMainCloseRequested = null;
    expect(SilicaWindows.onMainCloseRequested, isNull);
    // The probe after a request: this app says closeAsking when it asks.
    expect(await SilicaWindows.handle('closeProbe', {'viewId': 0}), isTrue);
  });

  test('the first window call answers close requests from then on', () async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    Future<Object?> request() async {
      final reply = await messenger.handlePlatformMessage(
        SilicaWindow.channel.name,
        const JSONMethodCodec().encodeMethodCall(
          const MethodCall('closeRequested', {'viewId': 0, 'request': 1}),
        ),
        null,
      );
      return reply == null
          ? null
          : const JSONMethodCodec().decodeEnvelope(reply);
    }

    // No listener yet: nobody answers (the engine would hold the request).
    expect(await request(), isNull);
    await SilicaWindow.setFullSizeContent(52);
    // Listening: the main window with no handler closes at once.
    expect(await request(), isFalse);
  });

  test('window calls name their view, the main one as before', () async {
    await SilicaWindow.setSize(const Size(300, 200), viewId: 4);
    expect(calls.last.arguments, {
      'width': 300.0,
      'height': 200.0,
      'viewId': 4,
    });
    await SilicaWindow.setSize(const Size(300, 200));
    expect(calls.last.arguments, {'width': 300.0, 'height': 200.0});
    await SilicaWindow.startMove(viewId: 4);
    expect(calls.last.arguments, {'viewId': 4});
    await SilicaWindow.startMove();
    expect(calls.last.arguments, isNull);
    await SilicaWindow.setAppearance(SilicaAppearance.dark, viewId: 4);
    expect(calls.last.arguments, {'appearance': 'dark', 'viewId': 4});
    await SilicaWindow.setAppearance(SilicaAppearance.dark);
    expect(calls.last.arguments, {'appearance': 'dark'});
  });

  testWidgets('the host builds nothing more without other windows', (
    tester,
  ) async {
    await tester.pumpWidget(
      const SilicaWindowHost(
        child: Directionality(
          textDirection: TextDirection.ltr,
          child: Text('main'),
        ),
      ),
    );
    expect(find.text('main'), findsOneWidget);
  });

  testWidgets('closeAll closes the other windows, then the main one', (
    tester,
  ) async {
    final appCalls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SilicaApp.channel, (call) async {
          appCalls.add(call.method);
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SilicaApp.channel, null),
    );
    answer = (call) => call.method == 'openWindow' ? 0 : true;
    final window = await SilicaWindows.openWindow(
      title: 'Info',
      size: const Size(200, 200),
      builder: content,
    );
    expect(window, isNotNull);
    calls.clear();

    // A window that refuses stays, and so does the main window.
    window!.onCloseRequested = () async => false;
    await SilicaWindows.closeAll();
    expect(calls, isEmpty);
    expect(appCalls, isEmpty);

    window.onCloseRequested = null;
    SilicaWindows.onMainCloseRequested = () async => false;
    await SilicaWindows.closeAll();
    expect(calls.map((call) => call.method), ['closeWindow']);
    expect(appCalls, isEmpty);

    SilicaWindows.onMainCloseRequested = null;
    await SilicaWindows.closeAll();
    expect(appCalls, ['closeWindow']);
  });

  testWidgets(
    'a host under another host passes its child through (one host builds)',
    (tester) async {
      await tester.pumpWidget(
        const SilicaWindowHost(
          child: SilicaWindowHost(child: SilicaWindowHost(child: SizedBox())),
        ),
      );
      expect(
        find.byType(ValueListenableBuilder<List<SilicaWindowController>>),
        findsOneWidget,
      );
    },
  );
}
