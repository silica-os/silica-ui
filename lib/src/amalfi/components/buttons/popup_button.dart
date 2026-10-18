// Pop-up and pull-down buttons (kit `Buttons/<Pop-up|Pull-down>/<size>/<state>` and
// `…/Open`): the opaque control look, a label on the left and a chevron on the right; pressed,
// they open a menu 4 below.

import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../menu_service.dart';
import '../../foundation/foundation.dart';
import '../../smooth_border.dart';
import '../../theme.dart';
import '../../tokens.g.dart';
import '../menus/menu.dart';
import 'button_base.dart';
import 'button_surface.dart';

/// The measures of pop-up and pull-down buttons per size, from the kit masters.
abstract final class AmalfiPopUpButtonMetrics {
  /// Between the button and its menu (`Buttons/Pop-up/Open`).
  static const double menuDistance = 4;

  /// The narrowest menu (`Buttons/Pop-up/Open` nests the 200 wide `Menus/Menu/Simple`); it
  /// is at least as wide as the button, and wider when its rows need it.
  static const double menuMinWidth = 200;

  /// The default width: 92 / 108 / 124 / 148.
  static double width(AmalfiControlSize size) => switch (size) {
    AmalfiControlSize.mini => 92,
    AmalfiControlSize.small => 108,
    AmalfiControlSize.regular => 124,
    AmalfiControlSize.large => 148,
  };

  /// Before the label.
  static double leading(AmalfiControlSize size) => switch (size) {
    AmalfiControlSize.mini || AmalfiControlSize.small => 8,
    _ => 12,
  };

  /// After the chevron.
  static double trailing(AmalfiControlSize size) => switch (size) {
    AmalfiControlSize.mini || AmalfiControlSize.small => 4,
    _ => 8,
  };

  /// Between the label and the chevron.
  static const double gap = 4;

  /// The chevron's size: the accessory glyph size, 16 at every control size (kit
  /// `Buttons/Pop-up`, `controlIcons.accessory`).
  static double chevron(AmalfiControlSize size) => AmalfiControlIcons.accessory;

  /// The label style: Caption, Label, Body, Body.
  static TextStyle labelStyle(AmalfiControlSize size, Color color) =>
      switch (size) {
        AmalfiControlSize.mini => AmalfiType.caption(color: color),
        AmalfiControlSize.small => AmalfiType.label(color: color),
        _ => AmalfiType.body(color: color),
      };
}

/// A choice of an [AmalfiPopUpButton].
@immutable
class AmalfiPopUpItem<T> {
  const AmalfiPopUpItem({
    required this.value,
    required this.label,
    this.enabled = true,
  });

  final T value;
  final String label;
  final bool enabled;
}

/// A command of an [AmalfiPullDownButton].
@immutable
class AmalfiPullDownItem {
  const AmalfiPullDownItem({required this.label, this.onSelected});

  final String label;

  /// Called when the item is chosen; null disables the item.
  final VoidCallback? onSelected;
}

/// A pop-up button: shows the label of the [items] entry whose value is [value] and, pressed,
/// a menu of every item with a checkmark on the current one and the highlight on it;
/// choosing one calls [onChanged].
///
/// [width] null takes the kit's width for [size]; longer labels end with an ellipsis.
/// [onChanged] null (or no items) disables it. Space or Return opens the menu from the
/// keyboard; the arrows, Return and Escape work in it.
class AmalfiPopUpButton<T> extends StatelessWidget {
  const AmalfiPopUpButton({
    super.key,
    required this.items,
    required this.value,
    required this.onChanged,
    this.size = AmalfiControlSize.regular,
    this.width,
    this.placeholder = '',
    this.semanticLabel,
    this.focusNode,
  });

  final List<AmalfiPopUpItem<T>> items;
  final T? value;
  final ValueChanged<T>? onChanged;
  final AmalfiControlSize size;
  final double? width;

  /// Shown when no item has [value].
  final String placeholder;

  /// What screen readers announce before the value; null: the value alone.
  final String? semanticLabel;

  final FocusNode? focusNode;

  int get _selected => items.indexWhere((i) => i.value == value);

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    final onChanged = this.onChanged;
    return _MenuButton(
      label: selected < 0 ? placeholder : items[selected].label,
      chevron: AmalfiGlyphs.chevronUpDown,
      size: size,
      width: width,
      semanticLabel: semanticLabel,
      focusNode: focusNode,
      entries: [
        for (final item in items)
          AmalfiMenuAction(
            item.label,
            checked: item.value == value,
            enabled: item.enabled && onChanged != null,
            onSelected: onChanged == null ? null : () => onChanged(item.value),
          ),
      ],
      highlighted: selected,
    );
  }
}

/// A pull-down button: [label] and a chevron; pressed, a menu of [items] (commands) opens
/// below it. [items] all disabled (or none) disables it.
///
/// [AmalfiPullDownButton.entries] opens a menu of [AmalfiMenuEntry] instead, with section
/// headers, separators and checked items.
class AmalfiPullDownButton extends StatelessWidget {
  const AmalfiPullDownButton({
    super.key,
    required this.label,
    required List<AmalfiPullDownItem> this.items,
    this.size = AmalfiControlSize.regular,
    this.width,
    this.semanticLabel,
    this.focusNode,
  }) : menuEntries = null;

  /// A pull-down button whose menu is [entries]: [AmalfiMenuAction] (with `checked`),
  /// [AmalfiMenuSection] and [AmalfiMenuDivider]. It is disabled when no action is
  /// selectable. Actions run their own `onSelected`.
  const AmalfiPullDownButton.entries({
    super.key,
    required this.label,
    required List<AmalfiMenuEntry> entries,
    this.size = AmalfiControlSize.regular,
    this.width,
    this.semanticLabel,
    this.focusNode,
  }) : menuEntries = entries,
       items = null;

  final String label;

  /// The commands ([AmalfiPullDownButton.new]); null with [menuEntries].
  final List<AmalfiPullDownItem>? items;

  /// The menu entries ([AmalfiPullDownButton.entries]); null with [items].
  final List<AmalfiMenuEntry>? menuEntries;
  final AmalfiControlSize size;
  final double? width;
  final String? semanticLabel;
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context) {
    final entries = menuEntries ?? _commands(items!);
    return _MenuButton(
      label: label,
      chevron: AmalfiGlyphs.chevronDown,
      size: size,
      width: width,
      semanticLabel: semanticLabel,
      focusNode: focusNode,
      entries: entries,
      highlighted: -1,
    );
  }

  static List<AmalfiMenuEntry> _commands(List<AmalfiPullDownItem> items) => [
    for (final item in items)
      AmalfiMenuAction(
        item.label,
        enabled: item.onSelected != null,
        onSelected: item.onSelected,
      ),
  ];
}

class _MenuButton extends StatefulWidget {
  const _MenuButton({
    required this.label,
    required this.chevron,
    required this.size,
    required this.width,
    required this.semanticLabel,
    required this.focusNode,
    required this.entries,
    required this.highlighted,
  });

  final String label;
  final AmalfiGlyphData chevron;
  final AmalfiControlSize size;
  final double? width;
  final String? semanticLabel;
  final FocusNode? focusNode;
  final List<AmalfiMenuEntry> entries;

  /// The index in [entries] highlighted when the menu opens; -1: none.
  final int highlighted;

  /// Whether some action can be chosen.
  bool get enabled => entries.any((e) => e is AmalfiMenuAction && e.selectable);

  @override
  State<_MenuButton> createState() => _MenuButtonState();
}

class _MenuButtonState extends State<_MenuButton>
    with SingleTickerProviderStateMixin {
  final OverlayPortalController _portal = OverlayPortalController();
  final Object _tapGroup = Object();
  final FocusNode _menuFocus = FocusNode(debugLabel: 'AmalfiPopUpMenu');

  /// What had the focus before the menu opened; it gets it back when the menu closes.
  FocusNode? _returnFocus;
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: AmalfiFades.instant.duration,
  );
  late final Animation<double> _opacity = CurvedAnimation(
    parent: _fade,
    curve: AmalfiFades.instant.curve,
  );

  /// The menu while the system's menu service shows it (silica-desktop#241); the portal
  /// above is the menu drawn in the window, outside Silica.
  ServiceMenuHandle? _service;
  bool _opening = false;

  bool get _open =>
      _opening ||
      _service != null ||
      (_portal.isShowing && _fade.status != AnimationStatus.reverse);

  @override
  void didUpdateWidget(_MenuButton old) {
    super.didUpdateWidget(old);
    if (!widget.enabled && _portal.isShowing) _closeNow();
    if (!widget.enabled) unawaited(_service?.cancel());
  }

  @override
  void dispose() {
    unawaited(_service?.cancel());
    _fade.dispose();
    _menuFocus.dispose();
    super.dispose();
  }

  void _toggle() {
    final service = _service;
    if (service != null) {
      unawaited(service.cancel());
    } else if (_open) {
      _close();
    } else {
      _show();
    }
  }

  /// Asks the system to show the menu: a pop-up button's with the chosen row over the button,
  /// a pull-down's below it. False if the system does not offer the service.
  Future<bool> _showService() async {
    final box = context.findRenderObject();
    final view = View.maybeOf(context);
    if (SilicaMenuService.available != true ||
        box is! RenderBox ||
        !box.hasSize ||
        view == null) {
      if (SilicaMenuService.available == null) {
        unawaited(SilicaMenuService.probe());
      }
      return false;
    }
    final rect = box.localToGlobal(Offset.zero) & box.size;
    final menu = ServiceMenu.from(
      widget.entries,
      selectedIndex: widget.highlighted < 0 ? null : widget.highlighted,
    );
    setState(() => _opening = true);
    final handle = await SilicaMenuService.show(
      viewId: view.viewId,
      menu: menu,
      anchor: rect,
      popUp: menu.selectedId != 0,
    );
    if (!mounted) {
      unawaited(handle?.cancel());
      return true;
    }
    if (handle == null) {
      setState(() => _opening = false);
      return false;
    }
    setState(() {
      _opening = false;
      _service = handle;
    });
    unawaited(
      handle.result.whenComplete(() {
        if (mounted && identical(_service, handle)) {
          setState(() => _service = null);
        }
      }),
    );
    return true;
  }

  void _show() {
    if (!widget.enabled || _opening) return;
    if (SilicaMenuService.available == true) {
      unawaited(
        _showService().then((shown) {
          if (!shown && mounted) _showInWindow();
        }),
      );
      return;
    }
    if (SilicaMenuService.available == null) {
      unawaited(SilicaMenuService.probe());
    }
    _showInWindow();
  }

  void _showInWindow() {
    if (!widget.enabled) return;
    _returnFocus = FocusManager.instance.primaryFocus;
    setState(_portal.show);
    _fade.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _portal.isShowing) _menuFocus.requestFocus();
    });
  }

  void _close() {
    if (!_portal.isShowing) return;
    _restoreFocus();
    _fade.reverse().whenComplete(() {
      if (mounted && _fade.value == 0) _closeNow();
    });
    setState(() {});
  }

  void _restoreFocus() {
    final back = _returnFocus;
    _returnFocus = null;
    if (_menuFocus.hasFocus && back != null && back.context != null) {
      back.requestFocus();
    } else if (_menuFocus.hasFocus) {
      _menuFocus.unfocus();
    }
  }

  void _closeNow() {
    _restoreFocus();
    _fade.value = 0;
    if (_portal.isShowing) setState(_portal.hide);
  }

  @override
  Widget build(BuildContext context) {
    final colors = AmalfiTheme.of(context).colors;
    final look = amalfiControlLook(colors);
    final size = widget.size;
    final height = size.height;
    final shape = AmalfiSmoothBorder(radius: AmalfiRadii.capsule(height));
    final enabled = widget.enabled;
    return OverlayPortal(
      controller: _portal,
      overlayChildBuilder: _menu,
      child: TapRegion(
        groupId: _tapGroup,
        child: AmalfiButtonBehavior(
          onPressed: enabled ? _toggle : null,
          focusNode: widget.focusNode,
          pressed: _open,
          semanticLabel: widget.semanticLabel == null
              ? widget.label
              : '${widget.semanticLabel}, ${widget.label}',
          builder: (context, visual) {
            final color = look.content;
            final chevronColor = colors.textSecondary;
            return AmalfiButtonSurface(
              look: look,
              shape: shape,
              visual: visual,
              child: SizedBox(
                width: widget.width ?? AmalfiPopUpButtonMetrics.width(size),
                height: height,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: AmalfiPopUpButtonMetrics.leading(size),
                    right: AmalfiPopUpButtonMetrics.trailing(size),
                  ),
                  child: LayoutBuilder(
                    builder: (context, box) {
                      final row = Row(
                        children: [
                          Expanded(
                            child: Text(
                              widget.label,
                              maxLines: 1,
                              softWrap: false,
                              overflow: TextOverflow.ellipsis,
                              style: AmalfiPopUpButtonMetrics.labelStyle(
                                size,
                                color,
                              ),
                            ),
                          ),
                          const SizedBox(width: AmalfiPopUpButtonMetrics.gap),
                          AmalfiGlyph(
                            widget.chevron,
                            size: AmalfiPopUpButtonMetrics.chevron(size),
                            color: chevronColor,
                          ),
                        ],
                      );
                      // Narrower than the chevron: clip instead of overflowing.
                      final least =
                          AmalfiPopUpButtonMetrics.gap +
                          AmalfiPopUpButtonMetrics.chevron(size);
                      return box.maxWidth >= least
                          ? row
                          : ClipRect(
                              child: OverflowBox(
                                alignment: AlignmentDirectional.centerStart,
                                minWidth: least,
                                maxWidth: least,
                                child: row,
                              ),
                            );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _menu(BuildContext overlayContext) {
    final target = context.findRenderObject() as RenderBox?;
    final overlay =
        Overlay.of(context).context.findRenderObject() as RenderBox?;
    if (target == null || overlay == null || !target.hasSize) {
      return const SizedBox.shrink();
    }
    final rect = MatrixUtils.transformRect(
      target.getTransformTo(overlay),
      Offset.zero & target.size,
    );
    final minWidth = rect.width > AmalfiPopUpButtonMetrics.menuMinWidth
        ? rect.width
        : AmalfiPopUpButtonMetrics.menuMinWidth;
    return AmalfiTheme(
      brightness: AmalfiTheme.of(context).brightness,
      child: CustomSingleChildLayout(
        delegate: _MenuLayout(rect),
        child: TapRegion(
          groupId: _tapGroup,
          onTapOutside: (_) => _close(),
          child: FadeTransition(
            opacity: _opacity,
            child: AmalfiMenu(
              entries: widget.entries,
              initialHighlight: widget.highlighted < 0
                  ? null
                  : widget.highlighted,
              minWidth: minWidth,
              onDismiss: _close,
              focusNode: _menuFocus,
            ),
          ),
        ),
      ),
    );
  }
}

/// Puts the menu 4 below the button, its leading edge on the button's; above it when there is
/// no room below; always inside the overlay.
class _MenuLayout extends SingleChildLayoutDelegate {
  const _MenuLayout(this.target);

  final Rect target;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size child) {
    const d = AmalfiPopUpButtonMetrics.menuDistance;
    var y = target.bottom + d;
    if (y + child.height > size.height && target.top - d - child.height >= 0) {
      y = target.top - d - child.height;
    }
    var x = target.left;
    if (x + child.width > size.width) x = size.width - child.width;
    if (x < 0) x = 0;
    if (y < 0) y = 0;
    return Offset(x, y);
  }

  @override
  bool shouldRelayout(_MenuLayout old) => old.target != target;
}
