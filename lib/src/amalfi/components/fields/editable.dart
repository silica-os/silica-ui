// The editing core of the Amalfi fields: Flutter's EditableText (keyboard, IME and clipboard
// through the platform text input and the app's text editing shortcuts) with mouse selection
// gestures, the Amalfi caret and selection, and a placeholder.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../controls/control_base.dart' show WindowActiveScope;
import '../../theme.dart';
import 'metrics.dart';

/// Editable text in an Amalfi field: [style] text, the caret (1.5 × 16 `Accent/Amalfi`, hidden
/// in an inactive window), the selection in `Accent/Amalfi Soft`, and [placeholder] in
/// [placeholderStyle] while the text is empty.
///
/// One line by default ([maxLines] 1); the box is as wide as the constraints and as tall as
/// its lines. Typing, IME composition, selection with the pointer and the keyboard, and the
/// clipboard shortcuts work as in every Flutter text field (the shortcuts come from the
/// [DefaultTextEditingShortcuts] of the app).
class AmalfiEditable extends StatefulWidget {
  const AmalfiEditable({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.style,
    this.placeholder,
    this.placeholderStyle,
    this.enabled = true,
    this.obscureText = false,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.textInputAction,
    this.keyboardType,
    this.onChanged,
    this.onSubmitted,
    this.inputFormatters,
  });

  final TextEditingController controller;
  final FocusNode focusNode;

  /// The style of the text.
  final TextStyle style;

  /// Shown while the text is empty; null: nothing.
  final String? placeholder;

  /// The placeholder's style; the text style when null.
  final TextStyle? placeholderStyle;

  /// When false the text cannot be focused, edited or selected.
  final bool enabled;

  /// Shows every character as `•` (secure fields).
  final bool obscureText;
  final bool autofocus;

  /// The most lines shown before the text scrolls; null: no limit.
  final int? maxLines;
  final int? minLines;
  final TextInputAction? textInputAction;
  final TextInputType? keyboardType;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final List<TextInputFormatter>? inputFormatters;

  @override
  State<AmalfiEditable> createState() => AmalfiEditableState();
}

/// The state of an [AmalfiEditable]; [editableTextKey] reaches the [EditableText].
class AmalfiEditableState extends State<AmalfiEditable>
    implements TextSelectionGestureDetectorBuilderDelegate {
  @override
  final GlobalKey<EditableTextState> editableTextKey = GlobalKey();

  late final TextSelectionGestureDetectorBuilder _gestures =
      TextSelectionGestureDetectorBuilder(delegate: this);

  @override
  bool get forcePressEnabled => false;

  @override
  bool get selectionEnabled => widget.enabled;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(AmalfiEditable old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  bool _empty = true;

  // The placeholder follows the text.
  void _changed() {
    final empty = widget.controller.text.isEmpty;
    if (empty != _empty && mounted) setState(() => _empty = empty);
  }

  @override
  Widget build(BuildContext context) {
    _empty = widget.controller.text.isEmpty;
    final colors = AmalfiTheme.of(context).colors;
    final active = WindowActiveScope.of(context);
    final oneLine = widget.maxLines == 1;
    final editable = EditableText(
      key: editableTextKey,
      controller: widget.controller,
      focusNode: widget.focusNode,
      readOnly: !widget.enabled,
      obscureText: widget.obscureText,
      obscuringCharacter: '•',
      autocorrect: false,
      enableSuggestions: !widget.obscureText,
      autofocus: widget.autofocus,
      maxLines: widget.obscureText ? 1 : widget.maxLines,
      minLines: widget.minLines,
      style: widget.style,
      strutStyle: StrutStyle.fromTextStyle(
        widget.style,
        forceStrutHeight: true,
      ),
      cursorColor: colors.accentAmalfi,
      cursorWidth: AmalfiFieldMetrics.caretWidth,
      cursorHeight: AmalfiFieldMetrics.caretHeight,
      cursorOpacityAnimates: true,
      showCursor: active && widget.enabled,
      backgroundCursorColor: colors.textTertiary,
      // Assumption: the kit has no selection master; the soft accent is the selection of
      // lists and menus.
      selectionColor: AmalfiTheme.of(context).selectionColor,
      rendererIgnoresPointer: true,
      enableInteractiveSelection: widget.enabled,
      inputFormatters: widget.inputFormatters,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
      keyboardType:
          widget.keyboardType ??
          (oneLine ? TextInputType.text : TextInputType.multiline),
      textInputAction:
          widget.textInputAction ??
          (oneLine ? TextInputAction.done : TextInputAction.newline),
    );
    final placeholder = widget.placeholder;
    return MouseRegion(
      cursor: widget.enabled ? SystemMouseCursors.text : MouseCursor.defer,
      child: _gestures.buildGestureDetector(
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            if (placeholder != null && _empty)
              Positioned.fill(
                child: IgnorePointer(
                  child: Text(
                    placeholder,
                    maxLines: oneLine ? 1 : null,
                    softWrap: !oneLine,
                    overflow: TextOverflow.clip,
                    style: widget.placeholderStyle ?? widget.style,
                  ),
                ),
              ),
            editable,
          ],
        ),
      ),
    );
  }
}
