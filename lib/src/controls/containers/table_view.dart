// Table and outline views (CT-TB-01, CT-TB-02; mustache-spec 3, MU-20, MU-25), generalized from
// Mustache's list view: header 27 pt with a 2 pt line below, rows at a 20 pt pitch starting 4 pt
// under the line, columns from x 10, 1 × 16 separators in the header, 7 × 4 sort arrow 8 pt from
// the right edge of the sorted column, labels 11 pt (sorted column in semibold). Alternating rows
// are radius 8 capsules on odd rows, continued below the last row; the selection is a block with
// rounded outer corners (7.5) and a 1 pt line between selected rows, gray in an inactive window.
// Outline rows: triangle at x 17–21, 15 pt indent per level. Header cells fill while pressed (a
// short click sorts, a long press does not); dragging a separator resizes the column on its left.

import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../double_tap.dart';
import 'common.dart';

abstract final class TableMetrics {
  static const double rowHeight = 20;
  static const double headerHeight = 27;
  static const double headerLine = 2;
  static const double firstRowGap = 4;
  static const double inset = 10;
  static const double indent = 15;
  static const double triangleLeft = 17;
  static const double headerBaseline = 18;
  static const double firstLabelLeft = 45;
  static const double labelLeft = 5;
  static const double columnMin = 75;
  static const double stripeRadius = 8;
  static const double blockRadius = 7.5;
  static const double textSize = 13;
  static const double labelSize = 11;

  /// The leading space of the first column of an outline (triangle and icon, MU-20).
  static const double outlineLead = 37;
}

/// Table colors, light and dark (mustache-spec 3.1).
@immutable
class TableColors {
  const TableColors({
    required this.background,
    required this.header,
    required this.headerPressed,
    required this.stripe,
    required this.line,
    required this.lineDark,
    required this.separator,
    required this.labelSorted,
    required this.label,
    required this.sortArrow,
    required this.text,
    required this.secondary,
    required this.triangle,
    required this.selection,
    required this.selectionLine,
    required this.selectionText,
    required this.selectionSecondary,
    required this.inactiveSelection,
    required this.inactiveLine,
    required this.inactiveText,
    required this.inactiveSecondary,
  });

  final Color background;
  final Color header;
  final Color headerPressed;
  final Color stripe;
  final Color line;
  final Color lineDark;
  final Color separator;
  final Color labelSorted;
  final Color label;
  final Color sortArrow;
  final Color text;
  final Color secondary;
  final Color triangle;
  final Color selection;
  final Color selectionLine;
  final Color selectionText;
  final Color selectionSecondary;
  final Color inactiveSelection;
  final Color inactiveLine;
  final Color inactiveText;
  final Color inactiveSecondary;

  static const TableColors light = TableColors(
    background: Color(0xFFFFFFFF),
    header: Color(0xFFFFFFFF),
    headerPressed: Color(0xFFF2F2F2),
    stripe: Color(0xFFF4F5F5),
    line: Color(0xFFE5E5E5),
    lineDark: Color(0xFFE5E5E5),
    separator: Color(0xFFE5E5E5),
    labelSorted: Color(0xFF4D4D4D),
    label: Color(0xFF808080),
    sortArrow: Color(0xFF6A6A6A),
    text: Color(0xFF252525),
    secondary: Color(0xFF7B7B7B),
    triangle: Color(0xFF808080),
    selection: Color(0xFF0064E1),
    selectionLine: Color(0xFF2673E4),
    selectionText: Color(0xFFFFFFFF),
    selectionSecondary: Color(0xFFBDCEF5),
    inactiveSelection: Color(0xFFDCDCDC),
    inactiveLine: Color(0xFFD1D1D1),
    inactiveText: Color(0xFF222222),
    inactiveSecondary: Color(0xFF6E6E6E),
  );

  static const TableColors dark = TableColors(
    background: Color(0xFF272728),
    header: Color(0xFF2F2F2F),
    headerPressed: Color(0xFF414141),
    stripe: Color(0xFF313132),
    line: Color(0xFF494949),
    lineDark: Color(0xFF363637),
    separator: Color(0xFF535353),
    labelSorted: Color(0xFFFFFFFF),
    label: Color(0xFFABABAB),
    sortArrow: Color(0xFFABABAB),
    text: Color(0xFFDFDFE0),
    secondary: Color(0xFFA2A2A2),
    triangle: Color(0xFFA2A2A2),
    selection: Color(0xFF0059D1),
    selectionLine: Color(0xFF2469D5),
    selectionText: Color(0xFFFFFFFF),
    selectionSecondary: Color(0xFFBBCBF0),
    inactiveSelection: Color(0xFF464646),
    inactiveLine: Color(0xFF424242),
    inactiveText: Color(0xFFE3E3E3),
    inactiveSecondary: Color(0xFFACACAC),
  );

  static TableColors of(BuildContext context) =>
      containerDark(context) ? dark : light;
}

/// A table column.
@immutable
class TableColumnSpec {
  const TableColumnSpec({
    required this.id,
    required this.label,
    required this.width,
    this.minWidth = TableMetrics.columnMin,
    this.alignRight = false,
    this.descendingFirst = false,
    this.sortable = true,
  });

  final String id;

  /// The header label, in the user's language.
  final String label;
  final double width;
  final double minWidth;

  /// Numbers: right-aligned 7 pt from the edge.
  final bool alignRight;

  /// The first click sorts from the largest (dates, sizes).
  final bool descendingFirst;
  final bool sortable;
}

/// What a cell needs to draw itself.
@immutable
class TableCellStyle {
  const TableCellStyle({
    required this.selected,
    required this.primary,
    required this.secondary,
  });
  final bool selected;

  /// The text color of the main column, and of the other columns.
  final Color primary;
  final Color secondary;

  TextStyle text({bool secondary = false}) => containerText(
    TableMetrics.textSize,
    secondary ? this.secondary : primary,
  );
}

/// The header of a table: labels, separators, the sort arrow, the 2 pt line.
class TableHeaderView extends StatelessWidget {
  const TableHeaderView({
    super.key,
    required this.columns,
    required this.widths,
    this.sortColumn,
    this.descending = false,
    this.onSort,
    this.onResize,
    this.outline = false,
    this.colors,
  });

  final List<TableColumnSpec> columns;
  final List<double> widths;
  final String? sortColumn;
  final bool descending;
  final ValueChanged<String>? onSort;

  /// Dragging the separator right of column `index` by `dx`.
  final void Function(int index, double dx)? onResize;

  /// The first label after the outline triangles and icons (x 45).
  final bool outline;
  final TableColors? colors;

  @override
  Widget build(BuildContext context) {
    final colors = this.colors ?? TableColors.of(context);
    final children = <Widget>[];
    final handles = <Widget>[];
    var x = TableMetrics.inset;
    for (var i = 0; i < columns.length; i++) {
      final column = columns[i];
      final width = widths[i];
      final sorted = column.id == sortColumn;
      final left = i == 0 && outline
          ? TableMetrics.firstLabelLeft
          : TableMetrics.labelLeft;
      children.add(
        Positioned(
          left: x,
          top: 0,
          width: width,
          height: TableMetrics.headerHeight,
          child: Semantics(
            button: column.sortable,
            label: column.label,
            sortKey: OrdinalSortKey(i.toDouble()),
            child: _HeaderCell(
              key: ValueKey('table header ${column.id}'),
              pressed: colors.headerPressed,
              onTap: column.sortable && onSort != null
                  ? () => onSort!(column.id)
                  : null,
              child: Padding(
                padding: EdgeInsets.only(left: left, right: sorted ? 20 : 4),
                child: Baseline(
                  baseline: TableMetrics.headerBaseline,
                  baselineType: TextBaseline.alphabetic,
                  child: SizedBox(
                    width: double.infinity,
                    child: Text(
                      column.label,
                      maxLines: 1,
                      softWrap: false,
                      overflow: TextOverflow.ellipsis,
                      textAlign: column.alignRight
                          ? TextAlign.right
                          : TextAlign.left,
                      style: containerText(
                        TableMetrics.labelSize,
                        sorted ? colors.labelSorted : colors.label,
                        weight: sorted ? FontWeight.w600 : null,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      if (sorted) {
        children.add(
          Positioned(
            left: x + width - 14,
            top: 12,
            width: 7,
            height: 4,
            child: IgnorePointer(
              child: CustomPaint(
                key: const ValueKey('table sort arrow'),
                painter: ChevronPainter(
                  descending ? ChevronDirection.down : ChevronDirection.up,
                  colors.sortArrow,
                  stroke: 1.2,
                ),
              ),
            ),
          ),
        );
      }
      x += width;
      children.add(
        Positioned(
          left: x - 1,
          top: 6,
          width: 1,
          height: 16,
          child: ColoredBox(color: colors.separator),
        ),
      );
      // The separator grip: 5 pt, 3 left of the line and 1 to the right (MU-25).
      if (onResize != null) {
        handles.add(
          Positioned(
            left: x - 4,
            top: 0,
            width: 5,
            height: TableMetrics.headerHeight,
            child: MouseRegion(
              cursor: SystemMouseCursors.resizeColumn,
              child: GestureDetector(
                key: ValueKey('table edge ${column.id}'),
                behavior: HitTestBehavior.opaque,
                onHorizontalDragUpdate: (d) => onResize!(i, d.delta.dx),
              ),
            ),
          ),
        );
      }
    }
    return Container(
      key: const ValueKey('table header'),
      height: TableMetrics.headerHeight + TableMetrics.headerLine,
      color: colors.header,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: TableMetrics.headerHeight,
            child: Stack(
              clipBehavior: Clip.none,
              children: [...children, ...handles],
            ),
          ),
          SizedBox(height: 1, child: ColoredBox(color: colors.line)),
          SizedBox(height: 1, child: ColoredBox(color: colors.lineDark)),
        ],
      ),
    );
  }
}

class _HeaderCell extends StatefulWidget {
  const _HeaderCell({
    super.key,
    required this.pressed,
    required this.onTap,
    required this.child,
  });

  final Color pressed;
  final VoidCallback? onTap;
  final Widget child;

  @override
  State<_HeaderCell> createState() => _HeaderCellState();
}

class _HeaderCellState extends State<_HeaderCell> {
  bool _pressed = false;

  void _set(bool pressed) {
    if (pressed != _pressed) setState(() => _pressed = pressed);
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: widget.onTap == null ? null : (_) => _set(true),
    onTapUp: (_) => _set(false),
    onTapCancel: () => _set(false),
    onTap: widget.onTap,
    // Held long: no sorting on release.
    onLongPress: widget.onTap == null ? null : () {},
    onLongPressStart: (_) => _set(true),
    onLongPressEnd: (_) => _set(false),
    child: ColoredBox(
      color: _pressed ? widget.pressed : const Color(0x00000000),
      child: widget.child,
    ),
  );
}

/// The background of a row: the alternating capsule on odd rows, or the selection block.
class TableRowBackground extends StatelessWidget {
  const TableRowBackground({
    super.key,
    required this.index,
    required this.width,
    required this.colors,
    this.selected = false,
    this.selectedAbove = false,
    this.selectedBelow = false,
    this.active = true,
    this.dropTarget = false,
  });

  final int index;
  final double width;
  final TableColors colors;
  final bool selected;
  final bool selectedAbove;
  final bool selectedBelow;
  final bool active;
  final bool dropTarget;

  @override
  Widget build(BuildContext context) {
    final right = math.max(TableMetrics.inset, width);
    Widget shape(BoxDecoration decoration, {Key? key}) => Positioned(
      left: TableMetrics.inset,
      width: right - TableMetrics.inset,
      top: 0,
      bottom: 0,
      child: DecoratedBox(key: key, decoration: decoration),
    );
    final children = <Widget>[];
    if (selected || dropTarget) {
      final fill = active || dropTarget
          ? colors.selection
          : colors.inactiveSelection;
      final above = selected && selectedAbove;
      final below = selected && selectedBelow;
      const r = Radius.circular(TableMetrics.blockRadius);
      children.add(
        shape(
          key: ValueKey('table selection $index'),
          BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.only(
              topLeft: above ? Radius.zero : r,
              topRight: above ? Radius.zero : r,
              bottomLeft: below ? Radius.zero : r,
              bottomRight: below ? Radius.zero : r,
            ),
          ),
        ),
      );
      if (below) {
        children.add(
          Positioned(
            left: TableMetrics.inset,
            width: right - TableMetrics.inset,
            bottom: 0,
            height: 1,
            child: ColoredBox(
              color: active ? colors.selectionLine : colors.inactiveLine,
            ),
          ),
        );
      }
    } else if (index.isOdd) {
      children.add(
        shape(
          BoxDecoration(
            color: colors.stripe,
            borderRadius: BorderRadius.circular(TableMetrics.stripeRadius),
          ),
        ),
      );
    }
    return Stack(children: children);
  }
}

/// The tree of an outline view: what [TableView] asks about each row.
@immutable
class OutlineDelegate<T> {
  const OutlineDelegate({
    required this.depth,
    required this.expandable,
    required this.expanded,
    required this.onToggle,
  });

  final int Function(T row) depth;
  final bool Function(T row) expandable;
  final bool Function(T row) expanded;
  final void Function(T row, bool expand) onToggle;
}

/// A table with a header, sorting, resizable columns, striping, multiple selection and keyboard
/// navigation; with [outline] the first column shows the tree (triangles and indent).
///
/// Clicks: a click selects one row, ⌘ toggles it, ⇧ extends the range; a double click or Return
/// activates. Keys: ↑ ↓ (⇧ extends), ⌘A, ← → collapse and expand in an outline.
class TableView<T> extends StatefulWidget {
  const TableView({
    super.key,
    required this.columns,
    required this.rows,
    required this.cell,
    this.selection = const {},
    this.onSelectionChanged,
    this.onActivate,
    this.sortColumn,
    this.descending = false,
    this.onSort,
    this.showHeader = true,
    this.padding = EdgeInsets.zero,
    this.active,
    this.outline,
    this.controller,
    this.focusNode,
    this.semanticLabel,
  });

  final List<TableColumnSpec> columns;
  final List<T> rows;

  /// A cell of `row` in `column` (the outline triangle and indent are drawn by the table).
  final Widget Function(
    BuildContext context,
    T row,
    TableColumnSpec column,
    TableCellStyle style,
  )
  cell;

  /// Indexes of the selected rows.
  final Set<int> selection;
  final ValueChanged<Set<int>>? onSelectionChanged;
  final ValueChanged<int>? onActivate;

  final String? sortColumn;
  final bool descending;

  /// A click on a header: the column id. The table does not reorder the rows.
  final ValueChanged<String>? onSort;

  /// Without the header (when it lives in the toolbar band, [ScrollUnderToolbar.header]).
  final bool showHeader;

  /// Around the rows (the band of [ScrollUnderToolbar]).
  final EdgeInsets padding;
  final bool? active;
  final OutlineDelegate<T>? outline;
  final ScrollController? controller;
  final FocusNode? focusNode;
  final String? semanticLabel;

  @override
  State<TableView<T>> createState() => _TableViewState<T>();
}

class _TableViewState<T> extends State<TableView<T>> {
  late List<double> _widths = [for (final c in widget.columns) c.width];
  int? _anchor;
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void dispose() {
    _ownFocus?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(TableView<T> old) {
    super.didUpdateWidget(old);
    if (old.columns.length != widget.columns.length) {
      _widths = [for (final c in widget.columns) c.width];
    }
  }

  void _resize(int index, double dx) => setState(
    () => _widths[index] = math.max(
      widget.columns[index].minWidth,
      _widths[index] + dx,
    ),
  );

  void _select(Set<int> selection) =>
      widget.onSelectionChanged?.call(selection);

  void _click(int index) {
    final keys = HardwareKeyboard.instance;
    final current = widget.selection;
    if (keys.isMetaPressed || keys.isControlPressed) {
      _anchor = index;
      _select(
        current.contains(index)
            ? ({...current}..remove(index))
            : {...current, index},
      );
    } else if (keys.isShiftPressed && _anchor != null) {
      final a = _anchor!;
      _select({
        for (var i = math.min(a, index); i <= math.max(a, index); i++) i,
      });
    } else {
      _anchor = index;
      _select({index});
    }
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final count = widget.rows.length;
    if (count == 0) return KeyEventResult.ignored;
    final keys = HardwareKeyboard.instance;
    final current = widget.selection;
    if (key == LogicalKeyboardKey.arrowDown ||
        key == LogicalKeyboardKey.arrowUp) {
      final down = key == LogicalKeyboardKey.arrowDown;
      final from = current.isEmpty
          ? (down ? -1 : count)
          : (down ? current.reduce(math.max) : current.reduce(math.min));
      final next = (from + (down ? 1 : -1)).clamp(0, count - 1);
      if (keys.isShiftPressed && current.isNotEmpty) {
        _select({...current, next});
      } else {
        _anchor = next;
        _select({next});
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.keyA &&
        (keys.isMetaPressed || keys.isControlPressed)) {
      _select({for (var i = 0; i < count; i++) i});
      return KeyEventResult.handled;
    }
    if ((key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.numpadEnter) &&
        current.length == 1) {
      widget.onActivate?.call(current.first);
      return KeyEventResult.handled;
    }
    final outline = widget.outline;
    if (outline != null &&
        current.length == 1 &&
        (key == LogicalKeyboardKey.arrowRight ||
            key == LogicalKeyboardKey.arrowLeft)) {
      final row = widget.rows[current.first];
      final expand = key == LogicalKeyboardKey.arrowRight;
      if (outline.expandable(row) && outline.expanded(row) != expand) {
        outline.onToggle(row, expand);
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final colors = TableColors.of(context);
    final active = containerActive(context, widget.active);
    final tableWidth = TableMetrics.inset + _widths.fold(0.0, (a, b) => a + b);
    final rows = LayoutBuilder(
      builder: (context, box) {
        final width = math.max(tableWidth, box.maxWidth - TableMetrics.inset);
        // The stripes go on below the last row.
        final filler = box.maxHeight.isFinite
            ? (box.maxHeight / TableMetrics.rowHeight).ceil() + 1
            : 0;
        final count = math.max(widget.rows.length, filler);
        return ListView.builder(
          controller: widget.controller,
          padding: widget.padding.add(
            const EdgeInsets.only(top: TableMetrics.firstRowGap),
          ),
          itemExtent: TableMetrics.rowHeight,
          itemCount: count,
          itemBuilder: (context, i) => i < widget.rows.length
              ? _row(context, i, width, colors, active)
              : TableRowBackground(index: i, width: width, colors: colors),
        );
      },
    );
    return Semantics(
      label: widget.semanticLabel,
      container: true,
      child: Focus(
        focusNode: _focus,
        onKeyEvent: _key,
        child: ColoredBox(
          color: colors.background,
          child: widget.showHeader
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TableHeaderView(
                      columns: widget.columns,
                      widths: _widths,
                      sortColumn: widget.sortColumn,
                      descending: widget.descending,
                      onSort: widget.onSort,
                      onResize: _resize,
                      outline: widget.outline != null,
                      colors: colors,
                    ),
                    Expanded(child: rows),
                  ],
                )
              : rows,
        ),
      ),
    );
  }

  Widget _row(
    BuildContext context,
    int i,
    double width,
    TableColors colors,
    bool active,
  ) {
    final selected = widget.selection.contains(i);
    final style = TableCellStyle(
      selected: selected,
      primary: selected
          ? (active ? colors.selectionText : colors.inactiveText)
          : colors.text,
      secondary: selected
          ? (active ? colors.selectionSecondary : colors.inactiveSecondary)
          : colors.secondary,
    );
    final row = widget.rows[i];
    final outline = widget.outline;
    final cells = <Widget>[];
    var x = TableMetrics.inset;
    for (var c = 0; c < widget.columns.length; c++) {
      final column = widget.columns[c];
      final w = _widths[c];
      var lead = 7.0;
      if (c == 0 && outline != null) {
        final depth = outline.depth(row) * TableMetrics.indent;
        lead = TableMetrics.outlineLead - TableMetrics.inset + depth;
        if (outline.expandable(row)) {
          final open = outline.expanded(row);
          cells.add(
            Positioned(
              left: TableMetrics.triangleLeft - 4 + depth,
              top: 0,
              bottom: 0,
              width: 13,
              child: GestureDetector(
                key: ValueKey('table disclose $i'),
                behavior: HitTestBehavior.opaque,
                onTap: () => outline.onToggle(row, !open),
                child: Semantics(
                  button: true,
                  expanded: open,
                  child: Center(
                    child: OutlineTriangle(
                      open: open,
                      color: selected ? style.primary : colors.triangle,
                    ),
                  ),
                ),
              ),
            ),
          );
        }
      }
      cells.add(
        Positioned(
          left: x + lead,
          width: math.max(0, w - lead - 7),
          top: 0,
          bottom: 0,
          child: Align(
            alignment: column.alignRight
                ? Alignment.centerRight
                : Alignment.centerLeft,
            child: widget.cell(context, row, column, style),
          ),
        ),
      );
      x += w;
    }
    return Semantics(
      selected: selected,
      child: Listener(
        key: ValueKey('table row $i'),
        behavior: HitTestBehavior.opaque,
        // The selection follows the press at once (no wait for a double click).
        onPointerDown: (e) {
          if (e.buttons & kPrimaryButton == 0) return;
          _focus.requestFocus();
          _click(i);
        },
        child: SilicaDoubleTap(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: widget.onActivate == null
              ? null
              : () => widget.onActivate!(i),
          child: Stack(
            children: [
              Positioned.fill(
                child: TableRowBackground(
                  index: i,
                  width: width,
                  colors: colors,
                  selected: selected,
                  selectedAbove: widget.selection.contains(i - 1),
                  selectedBelow: widget.selection.contains(i + 1),
                  active: active,
                ),
              ),
              ...cells,
            ],
          ),
        ),
      ),
    );
  }
}
