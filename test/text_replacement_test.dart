// Text replacements: the daemon's list becomes phrases as the user types.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:silica_ui/silica_ui.dart';
import 'package:silica_ui/src/amalfi/components/fields/text_replacement.dart';

const list = [('omw', 'On my way!'), ('addr', '1 Main St\nTown')];

TextEditingValue typed(String text, [int? caret]) => TextEditingValue(
  text: text,
  selection: TextSelection.collapsed(offset: caret ?? text.length),
);

void main() {
  const formatter = TextReplacementFormatter(replacements: list);

  test('a shortcut followed by a delimiter becomes its phrase', () {
    final out = formatter.formatEditUpdate(typed('omw'), typed('omw '));
    expect(out.text, 'On my way! ');
    expect(out.selection, const TextSelection.collapsed(offset: 11));
    // After other words, and with punctuation as the delimiter.
    expect(
      formatter
          .formatEditUpdate(typed('see you, omw'), typed('see you, omw.'))
          .text,
      'see you, On my way!.',
    );
    expect(
      formatter.formatEditUpdate(typed('addr'), typed('addr\n')).text,
      '1 Main St\nTown\n',
    );
  });

  test('only a whole word, typed one character at a time, is replaced', () {
    // Part of a longer word, or not a shortcut.
    expect(
      formatter.formatEditUpdate(typed('somw'), typed('somw ')).text,
      'somw ',
    );
    expect(formatter.formatEditUpdate(typed('hi'), typed('hi ')).text, 'hi ');
    // Typing the shortcut's last letter is not the end of the word.
    expect(formatter.formatEditUpdate(typed('om'), typed('omw')).text, 'omw');
    // A paste is left alone, and so is a selection.
    expect(formatter.formatEditUpdate(typed(''), typed('omw ')).text, 'omw ');
    expect(
      formatter
          .formatEditUpdate(
            typed('omw'),
            const TextEditingValue(
              text: 'omw ',
              selection: TextSelection(baseOffset: 0, extentOffset: 4),
            ),
          )
          .text,
      'omw ',
    );
    // Case matters, and no list means no change.
    expect(
      formatter.formatEditUpdate(typed('OMW'), typed('OMW ')).text,
      'OMW ',
    );
    expect(
      const TextReplacementFormatter(
        replacements: [],
      ).formatEditUpdate(typed('omw'), typed('omw ')).text,
      'omw ',
    );
  });

  test('the caret in the middle of the text stays after the phrase', () {
    final out = formatter.formatEditUpdate(
      typed('omw end', 3),
      typed('omw  end', 4),
    );
    expect(out.text, 'On my way!  end');
    expect(out.selection.baseOffset, 11);
  });

  test('the list comes from the daemon state, odd entries skipped', () {
    final look = SystemLook.fromState({
      'text.replacements': [
        ['omw', 'On my way!'],
        ['', 'empty'],
        ['one'],
        [1, 2],
        ['ok', 'fine'],
      ],
    });
    expect(look.textReplacements, [('omw', 'On my way!'), ('ok', 'fine')]);
    expect(SystemLook.fromState(const {}).textReplacements, isEmpty);
    expect(look, isNot(const SystemLook()));
  });

  testWidgets('a text field applies the system list, a secure field does not', (
    tester,
  ) async {
    SilicaSystemLook.apply(const SystemLook(textReplacements: list));
    addTearDown(() => SilicaSystemLook.apply(const SystemLook()));
    final text = TextEditingController();
    final secret = TextEditingController();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: Column(
            children: [
              AmalfiTextField(key: const ValueKey('plain'), controller: text),
              AmalfiSecureField(
                key: const ValueKey('secret'),
                controller: secret,
              ),
            ],
          ),
        ),
      ),
    );
    for (final (key, controller) in [('plain', text), ('secret', secret)]) {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pump();
      tester.testTextInput.updateEditingValue(typed('omw'));
      await tester.pump();
      tester.testTextInput.updateEditingValue(typed('omw '));
      await tester.pump();
      expect(
        controller.text,
        key == 'plain' ? 'On my way! ' : 'omw ',
        reason: key,
      );
    }
  });
}
