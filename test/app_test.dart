import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

class _Counter extends StatefulWidget {
  const _Counter();
  @override
  State<_Counter> createState() => _CounterState();
}

class _CounterState extends State<_Counter> {
  int taps = 0;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: () => setState(() => taps++),
    child: Text('$taps', textDirection: TextDirection.ltr),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    SilicaApp.reset();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SilicaApp.channel, (call) async {
          calls.add(call);
          return call.method == 'isHidden' ? true : null;
        });
  });

  test('settings reach the embedder', () async {
    SilicaApp.quitWhenLastWindowCloses = true;
    SilicaApp.quitEnabled = false;
    await Future<void>.delayed(Duration.zero);
    expect(calls.map((c) => c.method), [
      'setQuitWhenLastWindowCloses',
      'setQuitEnabled',
    ]);
    expect(calls.first.arguments, {'value': true});
    expect(calls.last.arguments, {'value': false});
    expect(await SilicaApp.isHidden(), isTrue);
  });

  test('setting onReopen tells the embedder the app answers reopens', () async {
    SilicaApp.onReopen = () async {};
    await Future<void>.delayed(Duration.zero);
    expect(calls.single.method, 'setHandlesReopen');
    expect(calls.single.arguments, {'value': true});
  });

  testWidgets('a reopen builds a new window: the closed one does not come back', (
    tester,
  ) async {
    await tester.pumpWidget(
      SilicaAppWindow(builder: (context) => const Center(child: _Counter())),
    );
    await tester.tap(find.text('0'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);

    // The last window closes: its widgets go, the app keeps running.
    await SilicaApp.handle('lastWindowClosed', const {});
    await tester.pump();
    expect(find.byType(_Counter), findsNothing);

    // A reopen with no window: a new window, built from scratch, then openWindow.
    calls.clear();
    await SilicaApp.handle('reopen', const {'windowless': true});
    await tester.pump();
    expect(find.text('0'), findsOneWidget);
    await tester.pump();
    expect(calls.map((c) => c.method), contains('openWindow'));
  });

  testWidgets('a reopen with a window on screen changes nothing', (
    tester,
  ) async {
    await tester.pumpWidget(
      SilicaAppWindow(builder: (context) => const Center(child: _Counter())),
    );
    await tester.tap(find.text('0'));
    await tester.pump();
    calls.clear();
    await SilicaApp.handle('reopen', const {'windowless': false});
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    expect(calls.map((c) => c.method), isNot(contains('openWindow')));
  });

  test('open hands the files of a second launch to onOpen', () async {
    final got = <List<String>>[];
    SilicaApp.onOpen = got.add;
    addTearDown(() => SilicaApp.onOpen = null);
    expect(
      await SilicaApp.handle('open', const {
        'args': ['/home/a/b.png', 3],
      }),
      isTrue,
    );
    expect(got, [
      ['/home/a/b.png'],
    ]);
  });

  group(
    'a document app with nothing to show (APP-LC: its Open panel, no empty window)',
    () {
      late List<Completer<bool>> asked;
      Future<bool> choose() {
        final c = Completer<bool>();
        asked.add(c);
        return c.future;
      }

      Widget app({bool startsWithDocument = false}) => SilicaAppWindow(
        builder: (context) => const Center(child: _Counter()),
        chooseDocument: choose,
        startsWithDocument: startsWithDocument,
        windowlessBuilder: (context, open) => GestureDetector(
          onTap: () => open(),
          child: const Text('File › Open…', textDirection: TextDirection.ltr),
        ),
      );

      setUp(() => asked = []);

      testWidgets('launched without a document: no window, only the Open panel', (
        tester,
      ) async {
        await tester.pumpWidget(app());
        // The window goes before its first frame and the panel is asked for.
        expect(calls.map((c) => c.method), contains('closeWindow'));
        expect(asked, hasLength(1));
        expect(find.byType(_Counter), findsNothing);
        // Cancelled: still no window, the windowless menus stay.
        asked.single.complete(false);
        await tester.pump();
        await tester.pump();
        expect(find.byType(_Counter), findsNothing);
        expect(calls.map((c) => c.method), isNot(contains('openWindow')));
        // File › Open… from them asks again; a document chosen builds and shows the window.
        await tester.tap(find.text('File › Open…'));
        expect(asked, hasLength(2));
        asked.last.complete(true);
        // Asked at once, before any frame: with no window the engine draws none until the
        // embedder shows the window.
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        expect(calls.map((c) => c.method), contains('openWindow'));
        await tester.pump();
        expect(find.text('0'), findsOneWidget);
      });

      testWidgets('launched with a document: the window as usual', (
        tester,
      ) async {
        await tester.pumpWidget(app(startsWithDocument: true));
        expect(asked, isEmpty);
        expect(find.text('0'), findsOneWidget);
        expect(calls.map((c) => c.method), isNot(contains('closeWindow')));
      });

      testWidgets(
        'a reopen shows the Open panel; cancelled, the window stays hidden',
        (tester) async {
          await tester.pumpWidget(app(startsWithDocument: true));
          await SilicaApp.handle('lastWindowClosed', const {});
          await tester.pump();
          calls.clear();
          await SilicaApp.handle('reopen', const {'windowless': true});
          await tester.pump();
          expect(asked, hasLength(1));
          // While the panel is up the embedder does not show the hidden window by itself.
          expect(calls.map((c) => c.method), contains('stayWindowless'));
          asked.single.complete(false);
          await tester.pump();
          await tester.pump();
          expect(find.byType(_Counter), findsNothing);
          expect(calls.map((c) => c.method), isNot(contains('openWindow')));
          // Chosen at the next reopen: the new window, shown after its frame.
          await SilicaApp.handle('reopen', const {'windowless': true});
          await tester.pump();
          asked.last.complete(true);
          await tester.pump();
          await tester.pump();
          expect(find.text('0'), findsOneWidget);
          expect(calls.map((c) => c.method), contains('openWindow'));
        },
      );

      testWidgets(
        'a reopen with files (a second launch) builds the window at once',
        (tester) async {
          await tester.pumpWidget(app(startsWithDocument: true));
          await SilicaApp.handle('lastWindowClosed', const {});
          await tester.pump();
          calls.clear();
          await SilicaApp.handle('reopen', const {
            'windowless': true,
            'files': true,
          });
          await tester.pump();
          expect(asked, isEmpty);
          expect(find.text('0'), findsOneWidget);
          await tester.pump();
          expect(calls.map((c) => c.method), contains('openWindow'));
        },
      );
    },
  );
}
