// Fields against the kit (`Fields/*`): every master in geometry and pixels, then behaviour.
// Checklist: docs/amalfi-checklist/fields.md.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';

import 'support/harness.dart';

/// The shape tolerance of the fields: the mean of [KitPixelTolerance.shapes]; the largest
/// single difference (91 measured, kit 747ea80) is on the antialiased edge of the 1 and
/// 1.5 pt inside borders and the 3 pt halo, where Sketch and Skia cover the half pixels
/// differently.
const KitPixelTolerance fieldsShapes = KitPixelTolerance(mean: 1, max: 180);

/// The shape tolerance of the masters of 24 pt or less (clear button, combo buttons,
/// tokens): a few hundred pixels compared, mostly the antialiased rim of the disc, so the
/// same edge differences weigh more in the mean (up to 3.4 measured, kit d3594d18; the
/// symbols sit where Skia centres them since the kit's glyph offset is 0 at every size).
const KitPixelTolerance smallShapes = KitPixelTolerance(mean: 3.5, max: 150);

/// The text tolerance of the fields: CoreText draws Inter visibly heavier than Skia, which
/// the text-dense masters (the text area's three lines: mean 2.76 measured) feel most.
const KitPixelTolerance fieldsText = KitPixelTolerance(mean: 3, max: 255);

/// The carets of the focused editable texts under [root], relative to it.
/// The glyphs drawn directly in the field under [root] (not in nested buttons), relative
/// to it.
List<Rect> glyphRects(WidgetTester tester, Finder root) {
  final rootBox = tester.renderObject<RenderBox>(root);
  return [
    for (final e
        in find
            .descendant(of: root, matching: find.byType(AmalfiGlyph))
            .evaluate())
      MatrixUtils.transformRect(
        (e.renderObject! as RenderBox).getTransformTo(rootBox),
        Offset.zero & (e.renderObject! as RenderBox).size,
      ),
  ];
}

List<Rect> caretRects(WidgetTester tester, Finder root) {
  final rootBox = tester.renderObject<RenderBox>(root);
  return [
    for (final state in tester.stateList<EditableTextState>(
      find.descendant(of: root, matching: find.byType(EditableText)),
    ))
      if (state.widget.focusNode.hasFocus)
        () {
          final r = state.renderEditable;
          final local = r.getLocalRectForCaret(
            TextPosition(offset: state.textEditingValue.selection.extentOffset),
          );
          return MatrixUtils.transformRect(
            r.getTransformTo(rootBox),
            local,
          ).inflate(1);
        }(),
  ];
}

Finder label(String text) => find
    .ancestor(of: find.text(text), matching: find.byType(AmalfiWholePoints))
    .first;

final Finder background = find.byType(AmalfiFieldSurface);
final Finder halo = find.byType(AmalfiFocusHalo);
final Finder value = find.byType(AmalfiEditable);
Finder glyph([int index = 0]) => find.byType(AmalfiGlyph).at(index);

/// One master: how to build the widget, which layers map to what, how to bring it into the
/// master's state.
class FieldCase {
  FieldCase(
    this.key, {
    required this.build,
    required this.layers,
    this.focus = false,
    this.prepare,
    this.deviations = const {},
    this.mask = const [],
    this.maskLayers = const [],
    this.tolerance = fieldsShapes,
    this.maskGlyphs = false,
  });

  final String key;
  final Widget Function(FocusNode focus) build;
  final Map<String, Finder> layers;

  /// Focus the field (the caret is masked out of the pixels).
  final bool focus;
  final Future<void> Function(WidgetTester tester)? prepare;
  final Map<String, String> deviations;
  final List<Rect> mask;
  final List<String> maskLayers;

  /// The shape tolerance.
  final KitPixelTolerance tolerance;

  /// Leave our glyphs out of the pixels too (where they differ from the kit's by decision).
  final bool maskGlyphs;
}

TextEditingController text(String value) => TextEditingController(text: value);

AmalfiFieldSize sizeOf(String name) => switch (name) {
  'Small' => AmalfiFieldSize.small,
  'Large' => AmalfiFieldSize.large,
  _ => AmalfiFieldSize.regular,
};

List<FieldCase> textFieldCases() => [
  for (final size in ['Small', 'Regular', 'Large'])
    for (final state in [
      'Placeholder',
      'Filled',
      'Focused',
      'Disabled',
      'Error',
    ])
      FieldCase(
        'Fields/Text Field/$size/$state',
        build: (focus) => AmalfiTextField(
          size: sizeOf(size),
          focusNode: focus,
          placeholder: 'Name',
          enabled: state != 'Disabled',
          errorText: state == 'Error' ? 'Invalid' : null,
          controller: text(state == 'Placeholder' ? '' : 'Amalfi coast'),
        ),
        layers: {
          'Background': background,
          if (state == 'Focused' || state == 'Error') 'Focus Halo': halo,
          'Value': value,
          if (state == 'Error') 'Error icon': glyph(),
        },
        focus: state == 'Focused',
        deviations: size == 'Small' && state == 'Error' ? const {} : const {},
        maskLayers: size == 'Small' && state == 'Error'
            ? const ['Error icon']
            : const [],
        maskGlyphs: size == 'Small' && state == 'Error',
      ),
  for (final state in ['Placeholder', 'Filled', 'Focused', 'Disabled'])
    FieldCase(
      'Fields/Secure Field/Regular/$state',
      build: (focus) => AmalfiSecureField(
        focusNode: focus,
        placeholder: 'Password',
        enabled: state != 'Disabled',
        controller: text(state == 'Placeholder' ? '' : 'positano'),
      ),
      layers: {
        'Background': background,
        if (state == 'Focused') 'Focus Halo': halo,
        'Value': value,
        'Leading icon': glyph(),
      },
      focus: state == 'Focused',
      // The Icon Kit's lock has a narrower, taller shackle than silica-icons' lock.svg.
      maskLayers: const ['Leading icon'],
    ),
  for (final state in ['Placeholder', 'Filled', 'Focused', 'Disabled'])
    FieldCase(
      'Fields/Text Area/Regular/$state',
      build: (focus) => AmalfiTextArea(
        focusNode: focus,
        placeholder: 'Write a note',
        enabled: state != 'Disabled',
        controller: text(
          state == 'Placeholder'
              ? ''
              : 'Rooms face the sea.\nBreakfast is served on the terrace until ten.',
        ),
      ),
      layers: {
        'Background': background,
        if (state == 'Focused') 'Focus Halo': halo,
        'Value': value,
      },
      focus: state == 'Focused',
    ),
  for (final state in ['Rest', 'Focused', 'Disabled'])
    FieldCase(
      'Fields/Inline Button/Regular/$state',
      build: (focus) => AmalfiTextField(
        focusNode: focus,
        width: 260,
        enabled: state != 'Disabled',
        controller: text('Downloads'),
        trailing: AmalfiInlineButton(
          label: 'Browse',
          onPressed: state == 'Disabled' ? null : () {},
        ),
      ),
      layers: {
        'Background': background.first,
        if (state == 'Focused') 'Focus Halo': halo.first,
        'Value': value,
        'Inline button': find.byType(AmalfiInlineButton),
      },
      focus: state == 'Focused',
    ),
];

List<FieldCase> searchCases() => [
  for (final size in ['Small', 'Regular', 'Large'])
    for (final state in ['Empty', 'Typing', 'Focused', 'Disabled'])
      FieldCase(
        'Fields/Search Field/$size/$state',
        build: (focus) => AmalfiSearchField(
          size: sizeOf(size),
          focusNode: focus,
          enabled: state != 'Disabled',
          controller: text(state == 'Typing' ? 'Limoni' : ''),
        ),
        layers: {
          'Background': find.byType(AmalfiGlass),
          if (state == 'Focused') 'Focus Halo': halo,
          'Value': value,
          'Search glyph': glyph(),
          if (state == 'Typing') 'Clear button': find.byType(AmalfiClearButton),
        },
        focus: state == 'Focused',
        deviations: size == 'Small' ? const {} : const {},
        // The text moved 2 to the right by the 14 pt glyph is checked by the geometry.
        maskLayers: size == 'Small'
            ? const ['Search glyph', 'Value']
            : const [],
        maskGlyphs: size == 'Small',
      ),
  for (final state in ['Token', 'Token Focused'])
    FieldCase(
      'Fields/Search Field/Regular/$state',
      build: (focus) => AmalfiSearchField(
        focusNode: focus,
        width: 240,
        tokens: const ['Recipes'],
        onTokensChanged: (_) {},
      ),
      layers: {
        'Background': find.byType(AmalfiGlass),
        if (state == 'Token Focused') 'Focus Halo': halo,
        'Token': find.byType(AmalfiToken),
        'Search glyph': glyph(),
      },
      focus: state == 'Token Focused',
    ),
  FieldCase(
    'Fields/Clear Button/Rest',
    build: (_) => AmalfiClearButton(onPressed: () {}),
    layers: {'Disc': find.byType(DecoratedBox), 'Clear glyph': glyph()},
    // A 16 pt disc: its antialiased rim weighs most in the mean (1.39 and 47 measured).
    tolerance: const KitPixelTolerance(mean: 2, max: 110),
  ),
];

List<FieldCase> tokenCases() => [
  for (final state in ['Rest', 'Selected'])
    FieldCase(
      'Fields/Token/$state',
      build: (_) => AmalfiToken(
        label: 'Travel',
        selected: state == 'Selected',
        onRemove: () {},
      ),
      layers: {
        'Background': find.byType(DecoratedBox).first,
        'Label': label('Travel'),
        'Remove': glyph(),
      },
      tolerance: smallShapes,
      // The kit token is 64 wide with the 16 pt cross: its label box is 32, Sketch's
      // measure of "Travel"; ours is the width rounded up to the 4 pt grid (36).
      deviations: const {
        'Label': 'kit label box is 4 narrower (Sketch text measure)',
      },
    ),
  for (final state in ['Rest', 'Focused'])
    FieldCase(
      'Fields/Token Field/Regular/$state',
      build: (focus) => _TokenFieldScene(focus: focus),
      layers: {
        'Background': background,
        if (state == 'Focused') 'Focus Halo': halo,
        'Value': value,
        'Token 1': find.byType(AmalfiToken).at(0),
        'Token 2': find.byType(AmalfiToken).at(1),
      },
      mask: const [Rect.fromLTWH(68, 0, 192, 28)],
      focus: state == 'Focused',
      // The kit's focused master shows the second token selected: Backspace selects it.
      prepare: state == 'Focused'
          ? (tester) async {
              await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
              await tester.pump();
            }
          : null,
    ),
];

class _TokenFieldScene extends StatefulWidget {
  const _TokenFieldScene({required this.focus});

  final FocusNode focus;

  @override
  State<_TokenFieldScene> createState() => _TokenFieldSceneState();
}

class _TokenFieldSceneState extends State<_TokenFieldScene> {
  List<String> tokens = ['Travel', 'Coast'];

  @override
  Widget build(BuildContext context) => AmalfiTokenField(
    focusNode: widget.focus,
    tokens: tokens,
    placeholder: 'Add tag',
    onTokensChanged: (t) => setState(() => tokens = t),
  );
}

const List<String> fruit = ['Orange', 'Lemon', 'Olive', 'Fig'];

List<FieldCase> comboCases() => [
  for (final size in ['Small', 'Regular', 'Large'])
    for (final state in ['Rest', 'Focused', 'Disabled'])
      FieldCase(
        'Fields/Combo Box/$size/$state',
        build: (focus) => AmalfiComboBox(
          options: fruit,
          size: sizeOf(size),
          focusNode: focus,
          enabled: state != 'Disabled',
          controller: text('Lemon'),
        ),
        layers: {
          'Background': background,
          if (state == 'Focused') 'Focus Halo': halo,
          'Value': value,
          'Inline button': find.byType(AmalfiComboButton),
        },
        focus: state == 'Focused',
      ),
  for (final size in ['Small', 'Regular', 'Large'])
    for (final state in ['Rest', 'Pressed', 'Disabled'])
      FieldCase(
        'Fields/Combo Button/$size/$state',
        build: (_) => AmalfiComboButton(
          size: sizeOf(size),
          onPressed: state == 'Disabled' ? null : () {},
        ),
        layers: {'Disc': find.byType(DecoratedBox), 'Chevron': glyph()},
        tolerance: smallShapes,
        prepare: state == 'Pressed'
            ? (tester) async {
                final g = await tester.startGesture(
                  tester.getCenter(find.byType(AmalfiComboButton)),
                );
                addTearDown(g.up);
                await tester.pump();
              }
            : null,
      ),
  FieldCase(
    'Fields/Combo Box/Open/Rest',
    build: (focus) => SizedBox(
      width: 200,
      height: 136,
      child: Align(
        alignment: Alignment.topLeft,
        child: AmalfiComboBox(
          options: fruit,
          focusNode: focus,
          controller: text('Lemon'),
        ),
      ),
    ),
    layers: {
      'Combo box': find.byType(AmalfiComboBox),
      'List': find.byType(AmalfiMenu),
    },
    // The kit checks the option equal to the text (Lemon) and highlights the next one
    // (Olive): the button opens the list, ↓ moves the highlight.
    prepare: (tester) async {
      await tester.tap(find.byType(AmalfiComboButton));
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.pump(AmalfiFades.quick.duration);
      await tester.pump();
    },
    tolerance: smallShapes,
  ),
];

void main() {
  setUpAll(loadAmalfiFonts);
  behaviour();

  final cases = [
    ...textFieldCases(),
    ...searchCases(),
    ...tokenCases(),
    ...comboCases(),
  ];

  for (final appearance in ['Light', 'Dark']) {
    group('kit $appearance', () {
      for (final c in cases) {
        testWidgets(c.key, (tester) async {
          final master = KitMaster.load('${c.key}/$appearance');
          final focus = FocusNode();
          addTearDown(focus.dispose);
          final widget = c.build(focus);
          Future<void> prepare(WidgetTester tester) async {
            if (c.focus) {
              focus.requestFocus();
              await tester.pump();
              await tester.pump(AmalfiFades.quick.duration);
              await tester.pump();
            }
            await c.prepare?.call(tester);
          }

          final root = await pumpKitScene(tester, widget, master: master);
          await prepare(tester);
          expectKitGeometry(
            tester,
            master,
            root: root,
            layers: c.layers,
            deviations: c.deviations,
          );
          // The caret blinks and sits after the text, whose width differs from CoreText's:
          // leave out the kit's caret and ours.
          final caret = master.maybeLayer('Caret');
          final mask = [
            ...c.mask,
            if (caret != null) caret.rectInMaster.inflate(1),
            if (c.focus) ...caretRects(tester, root),
            if (c.maskGlyphs) ...glyphRects(tester, root),
          ];
          await expectKitPixels(
            tester,
            master,
            widget,
            tolerance: c.tolerance,
            maskText: true,
            mask: mask,
            maskLayers: c.maskLayers,
            prepare: prepare,
          );
          await expectKitPixels(
            tester,
            master,
            widget,
            mask: mask,
            maskLayers: c.maskLayers,
            tolerance: c.tolerance.mean > fieldsShapes.mean
                ? KitPixelTolerance(mean: c.tolerance.mean, max: 255)
                : fieldsText,
            prepare: prepare,
          );
        });
      }
    });
  }
}

/// Pumps [child] in an app (text editing shortcuts, focus) in the light appearance.
Future<void> pumpApp(WidgetTester tester, Widget child) async {
  await pumpKitScene(tester, child, brightness: Brightness.light);
}

/// Answers the clipboard calls of the platform channel.
void mockClipboard(WidgetTester tester) {
  String? data;
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      switch (call.method) {
        case 'Clipboard.setData':
          data = (call.arguments as Map)['text'] as String?;
        case 'Clipboard.getData':
          return {'text': data};
        case 'Clipboard.hasStrings':
          return {'value': data != null};
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
}

void behaviour() {
  group('behaviour', () {
    testWidgets('a text field takes typing, selection and the clipboard', (
      tester,
    ) async {
      mockClipboard(tester);
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      final changes = <String>[];
      await pumpApp(
        tester,
        AmalfiTextField(
          controller: controller,
          placeholder: 'Name',
          onChanged: changes.add,
        ),
      );
      expect(find.text('Name'), findsOneWidget);
      // A click on the padding puts the caret in the field.
      await tester.tapAt(
        tester.getTopLeft(find.byType(AmalfiTextField)) + const Offset(3, 14),
      );
      await tester.pump();
      final node = tester
          .widget<EditableText>(find.byType(EditableText))
          .focusNode;
      expect(node.hasFocus, isTrue);
      await tester.enterText(find.byType(EditableText), 'Positano');
      await tester.pump();
      expect(controller.text, 'Positano');
      expect(changes.last, 'Positano');
      expect(find.text('Name'), findsNothing);

      // Select all, copy, move to the end, paste.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(
        controller.selection,
        const TextSelection(baseOffset: 0, extentOffset: 8),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyV);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      expect(controller.text, 'PositanoPositano');
    });

    testWidgets('focus shows the accent border and the halo, Tab moves on', (
      tester,
    ) async {
      final a = FocusNode(), b = FocusNode();
      addTearDown(a.dispose);
      addTearDown(b.dispose);
      await pumpApp(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AmalfiTextField(focusNode: a),
            AmalfiTextField(focusNode: b),
          ],
        ),
      );
      AmalfiFocusHalo haloOf(int i) =>
          tester.widget<AmalfiFocusHalo>(find.byType(AmalfiFocusHalo).at(i));
      expect(haloOf(0).visible, isFalse);
      a.requestFocus();
      await tester.pump();
      await tester.pump();
      expect(haloOf(0).visible, isTrue);
      final caret = tester.widget<EditableText>(
        find.byType(EditableText).first,
      );
      expect(caret.cursorWidth, AmalfiFieldMetrics.caretWidth);
      expect(caret.cursorHeight, AmalfiFieldMetrics.caretHeight);
      expect(caret.cursorColor, AmalfiColors.light.accentAmalfi);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.pump();
      expect(b.hasFocus, isTrue);
      expect(haloOf(0).visible, isFalse);
      expect(haloOf(1).visible, isTrue);
    });

    testWidgets(
      'a disabled field takes no focus; a states controller forces a look',
      (tester) async {
        final node = FocusNode();
        addTearDown(node.dispose);
        final states = WidgetStatesController({WidgetState.focused});
        addTearDown(states.dispose);
        await pumpApp(
          tester,
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AmalfiTextField(focusNode: node, enabled: false),
              AmalfiTextField(statesController: states),
            ],
          ),
        );
        await tester.tap(find.byType(AmalfiTextField).first);
        await tester.pump();
        expect(node.hasFocus, isFalse);
        final forced = tester.widget<AmalfiFocusHalo>(
          find.byType(AmalfiFocusHalo).at(1),
        );
        expect(forced.visible, isTrue);
      },
    );

    testWidgets('a secure field hides its text', (tester) async {
      final controller = TextEditingController(text: 'secret');
      addTearDown(controller.dispose);
      await pumpApp(tester, AmalfiSecureField(controller: controller));
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.obscureText, isTrue);
      expect(editable.obscuringCharacter, '•');
    });

    testWidgets('a text area grows by lines and keeps Enter as a line break', (
      tester,
    ) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await pumpApp(tester, AmalfiTextArea(controller: controller));
      await tester.tap(find.byType(AmalfiTextArea));
      await tester.pump();
      await tester.enterText(find.byType(EditableText), 'One\nTwo');
      await tester.pump();
      expect(tester.getSize(find.byType(AmalfiEditable)).height, 36);
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.textInputAction, TextInputAction.newline);
    });

    testWidgets('search: the clear button and Esc empty it', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      var cleared = 0;
      await pumpApp(
        tester,
        AmalfiSearchField(controller: controller, onCleared: () => cleared++),
      );
      expect(find.byType(AmalfiClearButton), findsNothing);
      await tester.tap(find.byType(AmalfiSearchField));
      await tester.enterText(find.byType(EditableText), 'Limoni');
      await tester.pump();
      await tester.tap(find.byType(AmalfiClearButton));
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(cleared, 1);
      await tester.enterText(find.byType(EditableText), 'Fichi');
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(controller.text, isEmpty);
      expect(cleared, 2);
    });

    testWidgets('tokens: Backspace selects, then removes; comma commits', (
      tester,
    ) async {
      final node = FocusNode();
      addTearDown(node.dispose);
      await pumpApp(tester, _TokenFieldScene(focus: node));
      node.requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      final last = tester.widget<AmalfiToken>(find.byType(AmalfiToken).at(1));
      expect(last.selected, isTrue);
      await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
      await tester.pump();
      expect(find.byType(AmalfiToken), findsOneWidget);
      await tester.enterText(find.byType(EditableText), 'Sea,');
      await tester.pump();
      await tester.pump();
      expect(find.text('Sea'), findsOneWidget);
      expect(find.byType(AmalfiToken), findsNWidgets(2));
      // The cross removes a token.
      await tester.tap(find.byType(AmalfiGlyph).first);
      await tester.pump();
      expect(find.text('Travel'), findsNothing);
    });

    testWidgets('combo box: button, arrows, Enter, Esc and clicks', (
      tester,
    ) async {
      final controller = TextEditingController(text: 'Lemon');
      addTearDown(controller.dispose);
      final picked = <String>[];
      await pumpApp(
        tester,
        AmalfiComboBox(
          options: fruit,
          controller: controller,
          onSelected: picked.add,
        ),
      );
      await tester.tap(find.byType(AmalfiComboButton));
      await tester.pump();
      expect(find.byType(AmalfiMenu), findsOneWidget);
      expect(tester.getTopLeft(find.byType(AmalfiMenu)).dy, 28 + 4);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(controller.text, 'Olive');
      expect(picked, ['Olive']);
      expect(find.byType(AmalfiMenu), findsNothing);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.pump();
      expect(find.byType(AmalfiMenu), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pump();
      expect(find.byType(AmalfiMenu), findsNothing);
      await tester.tap(find.byType(AmalfiComboButton));
      await tester.pump();
      await tester.tap(find.text('Fig'));
      // The menu blinks the item, then closes.
      await tester.pump(AmalfiMenuMetrics.chooseClose);
      await tester.pump();
      expect(controller.text, 'Fig');
      expect(find.byType(AmalfiMenu), findsNothing);
    });

    testWidgets('the inline button runs on click', (tester) async {
      var pressed = 0;
      await pumpApp(
        tester,
        AmalfiTextField(
          width: 260,
          trailing: AmalfiInlineButton(
            label: 'Browse',
            onPressed: () => pressed++,
          ),
        ),
      );
      await tester.tap(find.text('Browse'));
      await tester.pump();
      expect(pressed, 1);
    });

    testWidgets('semantics: the field is named by its placeholder', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        const AmalfiTextField(placeholder: 'Name', errorText: 'Required'),
      );
      expect(find.bySemanticsLabel(RegExp('Name')), findsWidgets);
      semantics.dispose();
    });
  });
}
