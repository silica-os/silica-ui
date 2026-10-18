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

  testWidgets(
    'a reopen builds a new window: the closed one does not come back',
    (tester) async {
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
    },
  );

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
}
