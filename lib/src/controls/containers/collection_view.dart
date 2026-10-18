// Collection view, icons in a grid (CT-TB-03; mustache-spec 4.1, 4.2, MU-21). At 64 pt icons
// and 12 pt labels: pitch y 116, the columns fill the width (pitch x = width / the columns that
// fit at the minimum pitch), the first icon 24 pt from the top. Labels below, at most 2 lines
// (truncated in the middle of the second). Selection: a 72 × 72 rounded square (4 pt around the
// icon, radius ~6) behind the icon, and the label in an accent capsule (17 pt per line, radius ~5,
// ~4 pt margins, 2 pt below the icon background); gray capsule in an inactive window.

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../double_tap.dart';
import 'common.dart';

/// Grid geometry for an icon size (measured at 64; the others from the MU-21 table).
@immutable
class CollectionLayout {
  const CollectionLayout({
    this.iconSize = 64,
    this.minPitchX = 112,
    this.pitchY = 116,
    this.top = 24,
    this.textSize = 12,
  });

  final double iconSize;

  /// The narrowest a column gets; the columns then share the width.
  final double minPitchX;
  final double pitchY;
  final double top;
  final double textSize;

  /// Selection square: 4 pt around the icon.
  double get background => iconSize + 8;

  static const CollectionLayout icons16 = CollectionLayout(
    iconSize: 16,
    minPitchX: 129,
    pitchY: 59,
    top: 21,
  );
  static const CollectionLayout icons32 = CollectionLayout(
    iconSize: 32,
    minPitchX: 129,
    pitchY: 78,
    top: 22,
  );
  static const CollectionLayout icons64 = CollectionLayout();
  static const CollectionLayout icons128 = CollectionLayout(
    iconSize: 128,
    minPitchX: 186,
    pitchY: 192,
    top: 28,
  );

  int columns(double width) => math.max(1, (width / minPitchX).floor());
}

@immutable
class CollectionColors {
  const CollectionColors({
    required this.background,
    required this.iconBackground,
    required this.label,
    required this.capsule,
    required this.capsuleInactive,
    required this.capsuleText,
    required this.capsuleTextInactive,
  });

  final Color background;
  final Color iconBackground;
  final Color label;
  final Color capsule;
  final Color capsuleInactive;
  final Color capsuleText;
  final Color capsuleTextInactive;

  static const CollectionColors light = CollectionColors(
    background: Color(0xFFFFFFFF),
    iconBackground: Color(0xFFE6E6E6),
    label: Color(0xFF252525),
    capsule: Color(0xFF0064E1),
    capsuleInactive: Color(0xFFDCDCDC),
    capsuleText: Color(0xFFFFFFFF),
    capsuleTextInactive: Color(0xFF222222),
  );

  static const CollectionColors dark = CollectionColors(
    background: Color(0xFF272728),
    iconBackground: Color(0xFF3C3C3D),
    label: Color(0xFFDFDFE0),
    capsule: Color(0xFF0059D1),
    capsuleInactive: Color(0xFF464646),
    capsuleText: Color(0xFFFFFFFF),
    capsuleTextInactive: Color(0xFFE3E3E3),
  );

  static CollectionColors of(BuildContext context) =>
      containerDark(context) ? dark : light;
}

/// A grid of icons with labels, multiple selection and arrow keys.
class CollectionView<T> extends StatefulWidget {
  const CollectionView({
    super.key,
    required this.items,
    required this.icon,
    required this.label,
    this.layout = CollectionLayout.icons64,
    this.selection = const {},
    this.onSelectionChanged,
    this.onActivate,
    this.active,
    this.padding = EdgeInsets.zero,
    this.controller,
    this.focusNode,
  });

  final List<T> items;
  final Widget Function(BuildContext context, T item, double size) icon;
  final String Function(T item) label;
  final CollectionLayout layout;
  final Set<int> selection;
  final ValueChanged<Set<int>>? onSelectionChanged;
  final ValueChanged<int>? onActivate;
  final bool? active;
  final EdgeInsets padding;
  final ScrollController? controller;
  final FocusNode? focusNode;

  @override
  State<CollectionView<T>> createState() => _CollectionViewState<T>();
}

class _CollectionViewState<T> extends State<CollectionView<T>> {
  int _columns = 1;
  int? _anchor;
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void dispose() {
    _ownFocus?.dispose();
    super.dispose();
  }

  void _select(Set<int> s) => widget.onSelectionChanged?.call(s);

  void _click(int i) {
    final keys = HardwareKeyboard.instance;
    final current = widget.selection;
    if (keys.isMetaPressed || keys.isControlPressed || keys.isShiftPressed) {
      _select(
        current.contains(i) ? ({...current}..remove(i)) : {...current, i},
      );
    } else {
      _select({i});
    }
    _anchor = i;
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final n = widget.items.length;
    if (n == 0) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final keys = HardwareKeyboard.instance;
    final step = switch (key) {
      LogicalKeyboardKey.arrowRight => 1,
      LogicalKeyboardKey.arrowLeft => -1,
      LogicalKeyboardKey.arrowDown => _columns,
      LogicalKeyboardKey.arrowUp => -_columns,
      _ => 0,
    };
    if (step != 0) {
      final from = _anchor ?? (step > 0 ? -1 : n);
      final next = (from + step).clamp(0, n - 1);
      _anchor = next;
      _select(keys.isShiftPressed ? {...widget.selection, next} : {next});
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyA &&
        (keys.isMetaPressed || keys.isControlPressed)) {
      _select({for (var i = 0; i < n; i++) i});
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter && widget.selection.length == 1) {
      widget.onActivate?.call(widget.selection.first);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colors = CollectionColors.of(context);
    final active = containerActive(context, widget.active);
    final layout = widget.layout;
    return Focus(
      focusNode: _focus,
      onKeyEvent: _key,
      child: ColoredBox(
        color: colors.background,
        child: LayoutBuilder(
          builder: (context, box) {
            final width = box.maxWidth - widget.padding.horizontal;
            _columns = layout.columns(width);
            final pitchX = width / _columns;
            final rows = (widget.items.length / _columns).ceil();
            return ListView.builder(
              controller: widget.controller,
              padding: widget.padding.add(EdgeInsets.only(top: layout.top - 4)),
              itemExtent: layout.pitchY,
              itemCount: rows,
              itemBuilder: (context, r) => Row(
                children: [
                  for (var c = 0; c < _columns; c++)
                    SizedBox(
                      width: pitchX,
                      child: r * _columns + c < widget.items.length
                          ? _cell(r * _columns + c, colors, active)
                          : null,
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _cell(int i, CollectionColors colors, bool active) {
    final layout = widget.layout;
    final item = widget.items[i];
    final selected = widget.selection.contains(i);
    final label = widget.label(item);
    final style = containerText(
      layout.textSize,
      selected
          ? (active ? colors.capsuleText : colors.capsuleTextInactive)
          : colors.label,
    ).copyWith(height: 17 / layout.textSize);
    return Semantics(
      selected: selected,
      label: label,
      button: true,
      child: Listener(
        key: ValueKey('collection item $i'),
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          if (e.buttons & kPrimaryButton == 0) return;
          _focus.requestFocus();
          _click(i);
        },
        child: SilicaDoubleTap(
          onDoubleTap: widget.onActivate == null
              ? null
              : () => widget.onActivate!(i),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                key: selected ? ValueKey('collection selection $i') : null,
                width: layout.background,
                height: layout.background,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? colors.iconBackground : null,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: SizedBox.square(
                  dimension: layout.iconSize,
                  child: widget.icon(context, item, layout.iconSize),
                ),
              ),
              const SizedBox(height: 2),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: math.max(layout.background + 30, 0),
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: selected
                        ? (active ? colors.capsule : colors.capsuleInactive)
                        : null,
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: Text(
                    label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: style,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
