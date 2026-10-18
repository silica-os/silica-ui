// Text replacements (Settings › Keyboard › Text Replacements): typing a delimiter after a
// word that is one of the system's shortcuts replaces the word with its phrase (`omw` followed
// by a space becomes `On my way! `). The list is the system look's [SystemLook.textReplacements].

import 'package:flutter/services.dart';

import '../../../system_look.dart';

/// Replaces a shortcut by its phrase when the character typed after it ends the word.
class TextReplacementFormatter extends TextInputFormatter {
  /// The replacements to apply; the system's by default.
  const TextReplacementFormatter({this.replacements});

  final List<(String, String)>? replacements;

  static final RegExp _delimiter = RegExp(r'''[\s.,;:!?)\]}"']''');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final list = replacements ?? SilicaSystemLook.current.textReplacements;
    final selection = newValue.selection;
    final text = newValue.text;
    // Only one character typed at the caret.
    if (list.isEmpty ||
        !selection.isCollapsed ||
        selection.baseOffset < 1 ||
        text.length != oldValue.text.length + 1 ||
        !newValue.composing.isCollapsed) {
      return newValue;
    }
    final end = selection.baseOffset - 1;
    if (end >= text.length ||
        !_delimiter.hasMatch(text[end]) ||
        text.substring(0, end) + text.substring(end + 1) != oldValue.text) {
      return newValue;
    }
    var start = end;
    while (start > 0 && !_isSpace(text[start - 1])) {
      start--;
    }
    if (start == end) return newValue;
    final word = text.substring(start, end);
    final phrase = list.where((r) => r.$1 == word).map((r) => r.$2).firstOrNull;
    if (phrase == null) return newValue;
    return TextEditingValue(
      text: text.substring(0, start) + phrase + text.substring(end),
      selection: TextSelection.collapsed(offset: start + phrase.length + 1),
    );
  }

  static bool _isSpace(String c) => c.trim().isEmpty;
}
