// Buttons that open a menu: the pop-up button (a choice among values, ⌃⌄), the pull-down
// button (a fixed title and a list of actions, ⌄) and the combo box (a text field with a list).
//
// Measured: pop-up and pull-down buttons are 24 pt gray capsules with the chevrons at the
// trailing edge (CT-BTN-16/17, INV-B gallery; Clock 224 × 24; Save card 232 × 26 in AX), no hover
// look; the menu opens on press with the checked item over the control (mustache.md › MU-02
// title menu, MU-07 menus on press); the pull-down chevron is 7 × 4 (the toolbar grouping
// pull-down, mustache-spec 1.2); the combo box is a white field (`#191919` in dark) with a small
// gray chevron button at the right and the keyboard ring 3 pt outside (CT-BTN-18). Provisional:
// the paddings, the ⌃⌄ glyph's size, the gap of the pull-down menu, the combo box's border and
// arrow geometry. The menus are silica_ui's in-window menus ([MenuHost] with `opaque`), in the
// nearest [Overlay].

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../menu.dart';
import 'control_style.dart';
import 'push_button.dart';

/// The label's left padding in a pop-up or pull-down button (provisional).
const double popUpPadding = 9;

/// The gap between a pull-down button and its menu (provisional).
const double pullDownGap = 4;

/// A menu opened by a control, in the nearest [Overlay]: it follows the press that opened it
/// (press, drag to an item, release) and then works as a normal menu.
class _ControlMenu {
  OverlayEntry? _entry;
  RenderBox? _overlay;
  FocusScopeNode? _scope;
  final GlobalKey<MenuHostState> _host = GlobalKey();

  bool get isOpen => _entry != null;

  /// Opens `entries` with the top-left corner at `place(menuSize, overlaySize)` (overlay
  /// coordinates). False if there is no overlay.
  bool open(
    BuildContext context,
    List<MenuEntry> entries, {
    required Offset Function(Size menu, RenderBox overlay) place,
    required VoidCallback onClosed,
  }) {
    final overlay = Overlay.maybeOf(context);
    final box = overlay?.context.findRenderObject();
    if (overlay == null || box is! RenderBox || !box.hasSize) return false;
    final size = menuSize(entries);
    var at = place(size, box);
    // Inside the overlay.
    at = Offset(
      at.dx.clamp(0, (box.size.width - size.width).clamp(0, double.infinity)),
      at.dy.clamp(0, (box.size.height - size.height).clamp(0, double.infinity)),
    );
    _overlay = box;
    final scope = FocusScopeNode(debugLabel: 'control menu');
    _scope = scope;
    final entry = OverlayEntry(
      // A scope of its own: the menu takes the keyboard even when the control had it.
      builder: (_) => Positioned.fill(
        child: FocusScope(
          node: scope,
          child: MenuHost(
            key: _host,
            entries: entries,
            anchor: at,
            opaque: true,
            onDismissed: () {
              remove();
              onClosed();
            },
          ),
        ),
      ),
    );
    _entry = entry;
    overlay.insert(entry);
    return true;
  }

  Offset? _local(Offset global) => _overlay?.globalToLocal(global);

  void pointerMoved(Offset global) {
    final p = _local(global);
    if (p != null) _host.currentState?.pointerMoved(p);
  }

  void pointerUp(Offset global) {
    final p = _local(global);
    if (p != null) _host.currentState?.pointerUp(p);
  }

  void remove() {
    _entry?.remove();
    _entry = null;
    final scope = _scope;
    _scope = null;
    // After the frame that takes the entry away.
    if (scope != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => scope.dispose());
    }
  }
}

/// The two stacked chevrons of a pop-up button (provisional: 5 × 9 at 24 pt).
class _UpDownChevrons extends StatelessWidget {
  const _UpDownChevrons(this.color, this.scale);
  final Color color;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final w = 5 * scale, h = 3 * scale;
    final glyph = Size(w, h);
    return Column(
      key: const ValueKey('pop-up chevrons'),
      mainAxisSize: MainAxisSize.min,
      children: [
        CustomPaint(
          size: glyph,
          painter: ChevronPainter(ChevronDirection.up, color, stroke: 1.2),
        ),
        SizedBox(height: 2 * scale),
        CustomPaint(
          size: glyph,
          painter: ChevronPainter(ChevronDirection.down, color, stroke: 1.2),
        ),
      ],
    );
  }
}

double _textWidth(String text, TextStyle style) => (TextPainter(
  text: TextSpan(text: text, style: style),
  textDirection: TextDirection.ltr,
  maxLines: 1,
)..layout()).width;

/// A choice of a [PopUpButton].
@immutable
class PopUpItem<T> {
  const PopUpItem(this.value, this.label, {this.enabled = true});
  final T value;
  final String label;
  final bool enabled;
}

/// Mixin for the buttons that open a menu on press.
mixin _MenuButton<W extends StatefulWidget> on State<W> {
  final _ControlMenu menu = _ControlMenu();
  FocusNode? _ownNode;
  FocusNode? get externalNode;
  FocusNode get node => externalNode ?? (_ownNode ??= FocusNode());

  @override
  void dispose() {
    menu.remove();
    _ownNode?.dispose();
    super.dispose();
  }

  Rect? buttonRect() {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  /// Opens the menu; `place` receives the button's rectangle in overlay coordinates.
  bool openMenu(
    List<MenuEntry> entries,
    Offset Function(Rect button, Size menu) place,
  ) {
    if (menu.isOpen) return true;
    final rect = buttonRect();
    if (rect == null) return false;
    final hadFocus = node.hasFocus;
    final opened = menu.open(
      context,
      entries,
      place: (size, overlay) {
        final topLeft = overlay.globalToLocal(rect.topLeft);
        return place(topLeft & rect.size, size);
      },
      onClosed: () {
        if (!mounted) return;
        setState(() {});
        if (hadFocus) node.requestFocus();
      },
    );
    if (opened) setState(() {});
    return opened;
  }

  KeyEventResult menuKey(KeyEvent event, VoidCallback open) {
    if (!isKeyPress(event)) return KeyEventResult.ignored;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp ||
        key == LogicalKeyboardKey.enter) {
      open();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }
}

/// A pop-up button: shows the chosen value and opens, on press, a menu with the chosen item
/// checked and placed over the button. Press, drag to an item and release chooses too. Space,
/// Return and the arrows open it with the keyboard focus.
class PopUpButton<T> extends StatefulWidget {
  const PopUpButton({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.size = ControlSize.regular,
    this.width,
    this.placeholder = '',
    this.focusNode,
    this.semanticLabel,
  });

  final List<PopUpItem<T>> items;
  final T? value;
  final ValueChanged<T>? onChanged;
  final ControlSize size;

  /// A fixed width; otherwise as wide as the widest item.
  final double? width;

  /// Shown when no item has `value`.
  final String placeholder;
  final FocusNode? focusNode;
  final String? semanticLabel;

  @override
  State<PopUpButton<T>> createState() => _PopUpButtonState<T>();
}

class _PopUpButtonState<T> extends State<PopUpButton<T>>
    with _MenuButton<PopUpButton<T>> {
  @override
  FocusNode? get externalNode => widget.focusNode;

  int get _chosen => widget.items.indexWhere((i) => i.value == widget.value);

  double get _chevronArea => 8 + 5 * buttonHeight(widget.size) / 24 + 7;

  double _naturalWidth() {
    final style = controlTextStyle(widget.size, const Color(0xFF000000));
    var widest = _textWidth(widget.placeholder, style);
    for (final item in widget.items) {
      final w = _textWidth(item.label, style);
      if (w > widest) widest = w;
    }
    return (popUpPadding + widest + _chevronArea).ceilToDouble();
  }

  bool _open() {
    final onChanged = widget.onChanged;
    if (onChanged == null || widget.items.isEmpty) return false;
    final rect = buttonRect();
    if (rect == null) return false;
    final chosen = _chosen;
    final items = <MenuEntry>[
      for (final item in widget.items)
        MenuAction(
          item.label,
          checked: item.value == widget.value,
          enabled: item.enabled,
          onSelected: () => onChanged(item.value),
        ),
    ];
    final textLeft = menuTextLeft(items);
    // At least as wide as the button, with the texts aligned.
    final entries = [
      ...items,
      MenuCustom(
        height: 0,
        width: rect.width + textLeft - popUpPadding,
        builder: (_, _) => const SizedBox.shrink(),
      ),
    ];
    final tops = menuRowTops(entries);
    final row = chosen < 0 ? 0 : chosen;
    return openMenu(
      entries,
      (button, menu) => Offset(
        button.left + popUpPadding - textLeft,
        button.center.dy - tops[row] - MenuMetrics.itemHeight / 2,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final chosen = _chosen;
    final text = chosen < 0 ? widget.placeholder : widget.items[chosen].label;
    final enabled = widget.onChanged != null;
    final scale = buttonHeight(widget.size) / 24;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel,
      value: text,
      child: ControlInteraction(
        enabled: enabled,
        focusNode: node,
        onActivate: _open,
        onPressDown: _open,
        onPointerMove: menu.pointerMoved,
        onPointerUp: menu.pointerUp,
        onKey: (event) => menuKey(event, _open),
        builder: (context, state) => ButtonFace(
          state: state,
          size: widget.size,
          width: widget.width ?? _naturalWidth(),
          padding: const EdgeInsets.only(left: popUpPadding, right: 7),
          child: (color) => Row(
            children: [
              Expanded(
                child: Text(
                  text,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: controlTextStyle(widget.size, color),
                ),
              ),
              const SizedBox(width: 8),
              _UpDownChevrons(color, scale),
            ],
          ),
        ),
      ),
    );
  }
}

/// A pull-down button: a fixed title (or icon) with ⌄; on press a menu of actions opens below
/// it.
class PullDownButton extends StatefulWidget {
  const PullDownButton({
    super.key,
    required this.entries,
    this.title,
    this.icon,
    this.size = ControlSize.regular,
    this.enabled = true,
    this.bezel = ButtonBezel.push,
    this.focusNode,
    this.semanticLabel,
  }) : assert(title != null || icon != null);

  final List<MenuEntry> entries;
  final String? title;
  final Widget Function(Color color)? icon;
  final ControlSize size;
  final bool enabled;
  final ButtonBezel bezel;
  final FocusNode? focusNode;
  final String? semanticLabel;

  @override
  State<PullDownButton> createState() => _PullDownButtonState();
}

class _PullDownButtonState extends State<PullDownButton>
    with _MenuButton<PullDownButton> {
  @override
  FocusNode? get externalNode => widget.focusNode;

  bool get _enabled => widget.enabled && widget.entries.isNotEmpty;

  bool _open() {
    if (!_enabled) return false;
    return openMenu(
      widget.entries,
      (button, menu) => Offset(button.left, button.bottom + pullDownGap),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scale = buttonHeight(widget.size) / 24;
    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.semanticLabel ?? widget.title,
      child: ControlInteraction(
        enabled: _enabled,
        focusNode: node,
        onActivate: _open,
        onPressDown: _open,
        onPointerMove: menu.pointerMoved,
        onPointerUp: menu.pointerUp,
        onKey: (event) => menuKey(event, _open),
        builder: (context, state) => ButtonFace(
          state: state,
          size: widget.size,
          bezel: widget.bezel,
          padding: const EdgeInsets.only(left: popUpPadding, right: 8),
          child: (color) {
            final icon = widget.icon, title = widget.title;
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) icon(color),
                if (icon != null && title != null) const SizedBox(width: 4),
                if (title != null)
                  Text(title, style: controlTextStyle(widget.size, color)),
                const SizedBox(width: 6),
                CustomPaint(
                  key: const ValueKey('pull-down chevron'),
                  // Measured: 7 × 4 (the toolbar grouping button).
                  size: Size(7 * scale, 4 * scale),
                  painter: ChevronPainter(
                    ChevronDirection.down,
                    color,
                    stroke: 1.3,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A combo box: a text field with a list of suggestions behind the ⌄ on the right. Typing
/// changes the text; choosing an item replaces it. ↓ in the field opens the list.
class ComboBox extends StatefulWidget {
  const ComboBox({
    super.key,
    required this.items,
    required this.controller,
    this.onChanged,
    this.width = 160,
    this.size = ControlSize.regular,
    this.enabled = true,
    this.focusNode,
    this.semanticLabel,
  });

  final List<String> items;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  final double width;
  final ControlSize size;
  final bool enabled;
  final FocusNode? focusNode;
  final String? semanticLabel;

  @override
  State<ComboBox> createState() => _ComboBoxState();
}

class _ComboBoxState extends State<ComboBox> with _MenuButton<ComboBox> {
  @override
  FocusNode? get externalNode => widget.focusNode;

  bool _fieldFocused = false;

  @override
  void initState() {
    super.initState();
    node.addListener(_focusChanged);
  }

  @override
  void dispose() {
    node.removeListener(_focusChanged);
    super.dispose();
  }

  void _focusChanged() {
    if (node.hasFocus != _fieldFocused) {
      setState(() => _fieldFocused = node.hasFocus);
    }
  }

  void _choose(String item) {
    widget.controller.value = TextEditingValue(
      text: item,
      selection: TextSelection.collapsed(offset: item.length),
    );
    widget.onChanged?.call(item);
  }

  bool _open() {
    if (!widget.enabled || widget.items.isEmpty) return false;
    final rect = buttonRect();
    if (rect == null) return false;
    final current = widget.controller.text;
    final entries = <MenuEntry>[
      for (final item in widget.items)
        MenuAction(
          item,
          checked: item == current,
          onSelected: () => _choose(item),
        ),
      // As wide as the field.
      MenuCustom(
        height: 0,
        width: rect.width,
        builder: (_, _) => const SizedBox.shrink(),
      ),
    ];
    return openMenu(
      entries,
      (button, menu) => Offset(button.left, button.bottom + pullDownGap),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = ControlColors.of(context);
    final size = widget.size;
    final height = buttonHeight(size);
    final radius = buttonRadius(size) - 2; // provisional
    final textColor = widget.enabled ? colors.label : colors.labelDisabled;
    final field = Container(
      key: const ValueKey('combo field'),
      width: widget.width,
      height: height,
      decoration: BoxDecoration(
        color: colors.field,
        border: Border.all(color: colors.fieldBorder),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(left: 6),
              child: Focus(
                canRequestFocus: false,
                skipTraversal: true,
                onKeyEvent: (_, event) {
                  if (isKeyPress(event) &&
                      event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    _open();
                    return KeyEventResult.handled;
                  }
                  return KeyEventResult.ignored;
                },
                child: EditableText(
                  controller: widget.controller,
                  focusNode: node,
                  readOnly: !widget.enabled,
                  style: controlTextStyle(size, textColor),
                  cursorColor: ControlAccent.of(context),
                  backgroundCursorColor: colors.textDisabled,
                  selectionColor: ControlAccent.of(
                    context,
                  ).withValues(alpha: 0.3),
                  maxLines: 1,
                  onChanged: widget.onChanged,
                ),
              ),
            ),
          ),
          // The arrow: a small push face at the right end (provisional).
          Semantics(
            button: true,
            label: 'Show suggestions',
            child: ControlInteraction(
              enabled: widget.enabled && widget.items.isNotEmpty,
              onActivate: _open,
              onPressDown: _open,
              onPointerMove: menu.pointerMoved,
              onPointerUp: menu.pointerUp,
              builder: (context, state) => SizedBox(
                key: const ValueKey('combo arrow'),
                width: height - 4,
                height: height - 4,
                child: ButtonFace(
                  state: ControlState(
                    enabled: state.enabled,
                    hovered: state.hovered,
                    pressed: state.pressed,
                    focused: false,
                    active: state.active,
                  ),
                  size: size,
                  width: height - 4,
                  padding: EdgeInsets.zero,
                  child: (color) => CustomPaint(
                    size: Size(7 * height / 24, 4 * height / 24),
                    painter: ChevronPainter(
                      ChevronDirection.down,
                      color,
                      stroke: 1.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 2),
        ],
      ),
    );
    return Semantics(
      textField: true,
      label: widget.semanticLabel,
      child: FocusRing(visible: _fieldFocused, radius: radius, child: field),
    );
  }
}
