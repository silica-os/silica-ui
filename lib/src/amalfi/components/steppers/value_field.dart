// The value field beside a stepper (kit `Steppers/Value Field/Regular/*`): 56 × 28,
// `Surface/Raised` with a `Line/Border` rim, radius 9, Body text 8 from the sides; focused,
// the rim turns `Accent/Amalfi` and the halo shows; disabled, the whole field is at
// `AmalfiStates.disabledOpacity`.

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../foundation/foundation.dart';
import '../../smooth_border.dart';
import '../../theme.dart';
import '../../tokens.g.dart';

/// The measures of the value field, from `Steppers/Value Field/Regular`.
abstract final class AmalfiValueFieldMetrics {
  /// The width of a field that is not given one.
  static const double width = 56;

  /// The height (the regular control height).
  static const double height = 28;

  /// The corner radius.
  static const double radius = 9;

  /// Between the edges and the text.
  static const double padding = 8;
}

/// A one-line text field for a short value, as the kit draws it next to a stepper: Body
/// text in [controller], [width] wide.
///
/// It shows the focused look whenever it has the focus. [onSubmitted] runs on Return;
/// [onStep] (when given) runs with +1 or −1 on the up and down arrows.
class AmalfiValueField extends StatefulWidget {
  const AmalfiValueField({
    super.key,
    required this.controller,
    this.focusNode,
    this.enabled = true,
    this.width = AmalfiValueFieldMetrics.width,
    this.textAlign = TextAlign.start,
    this.onChanged,
    this.onSubmitted,
    this.onStep,
    this.inputFormatters,
    this.keyboardType = const TextInputType.numberWithOptions(
      signed: true,
      decimal: true,
    ),
    this.autofocus = false,
    this.semanticLabel,
  });

  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;
  final double width;
  final TextAlign textAlign;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Called with +1 (up arrow) or −1 (down arrow); null: the arrows move the caret.
  final ValueChanged<int>? onStep;
  final List<TextInputFormatter>? inputFormatters;
  final TextInputType keyboardType;
  final bool autofocus;

  /// What the field holds, for screen readers.
  final String? semanticLabel;

  @override
  State<AmalfiValueField> createState() => _AmalfiValueFieldState();
}

class _AmalfiValueFieldState extends State<AmalfiValueField> {
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _focus.addListener(_repaint);
  }

  @override
  void didUpdateWidget(AmalfiValueField old) {
    super.didUpdateWidget(old);
    if (old.focusNode != widget.focusNode) {
      (old.focusNode ?? _ownFocus)?.removeListener(_repaint);
      _focus.addListener(_repaint);
    }
  }

  @override
  void dispose() {
    _focus.removeListener(_repaint);
    _ownFocus?.dispose();
    super.dispose();
  }

  void _repaint() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final colors = AmalfiTheme.of(context).colors;
    final enabled = widget.enabled;
    final focused = enabled && _focus.hasFocus;
    const lineHeight = 18.0;
    final onStep = widget.onStep;
    Widget editable = EditableText(
      controller: widget.controller,
      focusNode: _focus,
      readOnly: !enabled,
      autofocus: widget.autofocus,
      maxLines: 1,
      textAlign: widget.textAlign,
      style: AmalfiType.body(color: colors.textPrimary),
      cursorColor: colors.textPrimary,
      cursorWidth: 1,
      showCursor: enabled,
      backgroundCursorColor: colors.textTertiary,
      selectionColor: AmalfiTheme.of(context).selectionColor,
      enableInteractiveSelection: enabled,
      inputFormatters: widget.inputFormatters,
      keyboardType: widget.keyboardType,
      textInputAction: TextInputAction.done,
      onChanged: widget.onChanged,
      onSubmitted: widget.onSubmitted,
    );
    if (onStep != null && enabled) {
      editable = CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.arrowUp): () => onStep(1),
          const SingleActivator(LogicalKeyboardKey.arrowDown): () => onStep(-1),
        },
        child: editable,
      );
    }
    return Semantics(
      label: widget.semanticLabel,
      textField: true,
      child: Opacity(
        opacity: enabled ? 1 : AmalfiStates.disabledOpacity,
        child: SizedBox(
          width: widget.width,
          height: AmalfiValueFieldMetrics.height,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: DecoratedBox(
                  decoration: AmalfiShapeDecoration(
                    color: colors.surfaceRaised,
                    shape: AmalfiSmoothBorder(
                      radius: AmalfiValueFieldMetrics.radius,
                      side: BorderSide(
                        color: focused
                            ? colors.accentAmalfi
                            : colors.lineBorder,
                        strokeAlign: BorderSide.strokeAlignInside,
                      ),
                    ),
                  ),
                ),
              ),
              if (focused)
                const Positioned.fill(
                  child: AmalfiFocusHalo(
                    radius: AmalfiValueFieldMetrics.radius,
                  ),
                ),
              Positioned(
                left: AmalfiValueFieldMetrics.padding,
                right: AmalfiValueFieldMetrics.padding,
                top: (AmalfiValueFieldMetrics.height - lineHeight) / 2,
                height: lineHeight,
                child: editable,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
