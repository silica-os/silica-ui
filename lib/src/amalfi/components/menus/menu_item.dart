// The rows of an Amalfi menu (kit `Menus/Item/*`): the item (plain, with a shortcut, a
// submenu chevron, an icon, destructive, checked; at rest, highlighted or disabled), the
// section header and the separator.

import 'package:flutter/widgets.dart';

import '../../foundation/foundation.dart';
import '../../smooth_border.dart';
import '../../theme.dart';
import '../../tokens.g.dart';
import '../../whole_points.dart';

/// The measures of menus and their rows, from the kit masters `Menus/*`.
abstract final class AmalfiMenuMetrics {
  /// The height of an item and of a section header.
  static const double itemHeight = 24;

  /// The height of a separator.
  static const double separatorHeight = 8;

  /// The space between the menu's edge and its rows, on every side.
  static const double padding = 4;

  /// The corner radius of the menu (`materials.md`: Glass/Thick, radius 12).
  static const double radius = AmalfiRadii.menu;

  /// The corner radius of the highlight (`materials.md`: radius 7).
  static const double highlightRadius = 7;

  /// The space between an item's edge and its content.
  static const double itemPadding = 8;

  /// The slot of the checkmark, before the label.
  static const double checkSlot = 12;

  /// The slot of an icon, before the label (it replaces the checkmark slot).
  static const double iconSlot = 20;

  /// The space between the slots of an item (checkmark, label, shortcut, chevron).
  static const double gap = 4;

  /// The side of the checkmark.
  static const double glyph = 12;

  /// The side of the submenu chevron (`controlIcons.accessory`).
  static const double chevron = 16;

  /// The inset of a section header's label: 12 from the leading edge, 4 from the top.
  static const EdgeInsets headerPadding = EdgeInsets.only(
    left: 12,
    top: 4,
    right: 8,
  );

  /// The inset of a separator's line from both sides.
  static const double separatorInset = 12;

  /// How far a submenu overlaps its parent menu (`Menus/Menu/Cascade`).
  static const double submenuOverlap = 4;

  /// The narrowest menu.
  static const double minWidth = 160;

  /// The narrowest submenu: the `Menus/Menu/Submenu` master's 188.
  static const double submenuMinWidth = 188;

  /// The time the pointer rests on an item before its submenu opens (`docs/spec/menubar.md`,
  /// M-01: about 295 ms).
  static const Duration submenuDelay = Duration(milliseconds: 295);

  /// When a chosen item's highlight comes back after blinking off (M-01: +74 ms).
  static const Duration blinkOn = Duration(milliseconds: 74);

  /// When the menu starts closing after a choice (M-01: +114 ms).
  static const Duration chooseClose = Duration(milliseconds: 114);
}

/// One item of a menu, as drawn: [label], and optionally a [shortcut] (`⌘N`) at the trailing
/// edge, a submenu chevron ([submenu]), a checkmark ([checked]) or an [icon] before the
/// label.
///
/// [highlighted] draws the `Accent/Amalfi` highlight (`Palette/Terracotta` when
/// [destructive]) with the text in `Text/On Accent`; a disabled item ([enabled] false) is
/// drawn whole at `AmalfiStates.disabledOpacity`. The checkmark slot (12) is always kept, so
/// labels line up; an [icon] takes a 16 pt slot instead and gets the text colour through
/// [IconTheme]. The shortcut sits at the trailing edge, its box rounded up to whole points,
/// and the label takes the rest of the row.
///
/// This is the row only; [AmalfiMenu] lays items out and makes them interactive.
class AmalfiMenuItem extends StatelessWidget {
  const AmalfiMenuItem({
    super.key,
    required this.label,
    this.shortcut,
    this.icon,
    this.checked = false,
    this.submenu = false,
    this.destructive = false,
    this.enabled = true,
    this.highlighted = false,
    this.height = AmalfiMenuMetrics.itemHeight,
  });

  /// The row's height: 24; a pop-up button's menu uses 22 or 19 for small controls.
  final double height;

  /// The text.
  final String label;

  /// The keyboard shortcut, with its modifier glyphs (`⇧⌘E`); null: none.
  final String? shortcut;

  /// A 16 pt icon before the label; null: the checkmark slot.
  final Widget? icon;

  /// Whether the checkmark shows (in the checkmark slot).
  final bool checked;

  /// Whether the item opens a submenu (a chevron at the trailing edge).
  final bool submenu;

  /// Whether the action destroys something: its highlight is `Palette/Terracotta`.
  final bool destructive;

  /// Whether the item can be chosen.
  final bool enabled;

  /// Whether the item is under the pointer or the keyboard selection.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = AmalfiTheme.of(context).colors;
    final lit = highlighted && enabled;
    final text = lit ? colors.textOnAccent : colors.textPrimary;
    final secondary = lit ? colors.textOnAccent : colors.textSecondary;
    final icon = this.icon;
    final shortcut = this.shortcut;
    Widget row = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AmalfiMenuMetrics.itemPadding,
      ),
      child: Row(
        children: [
          if (icon != null)
            SizedBox.square(
              dimension: AmalfiMenuMetrics.iconSlot,
              child: IconTheme(
                data: IconThemeData(
                  color: text,
                  size: AmalfiMenuMetrics.iconSlot,
                ),
                child: icon,
              ),
            )
          else
            SizedBox.square(
              dimension: AmalfiMenuMetrics.checkSlot,
              child: checked
                  ? AmalfiGlyph(
                      AmalfiGlyphs.checkmark,
                      color: text,
                      size: AmalfiMenuMetrics.glyph,
                    )
                  : null,
            ),
          const SizedBox(width: AmalfiMenuMetrics.gap),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: AmalfiType.body(color: text),
            ),
          ),
          if (shortcut != null) ...[
            const SizedBox(width: AmalfiMenuMetrics.gap),
            AmalfiWholePoints(
              child: Text(
                shortcut,
                maxLines: 1,
                softWrap: false,
                textAlign: TextAlign.right,
                style: AmalfiType.body(color: secondary),
              ),
            ),
          ],
          if (submenu) ...[
            const SizedBox(width: AmalfiMenuMetrics.gap),
            AmalfiGlyph(
              AmalfiGlyphs.chevronRight,
              color: secondary,
              size: AmalfiMenuMetrics.chevron,
            ),
          ],
        ],
      ),
    );
    if (lit) {
      row = DecoratedBox(
        decoration: AmalfiShapeDecoration(
          color: destructive ? colors.paletteTerracotta : colors.accentAmalfi,
          shape: const AmalfiSmoothBorder(
            radius: AmalfiMenuMetrics.highlightRadius,
          ),
        ),
        child: row,
      );
    }
    row = SizedBox(height: height, child: row);
    return enabled
        ? row
        : Opacity(opacity: AmalfiStates.disabledOpacity, child: row);
  }
}

/// A section header of a menu (kit `Menus/Item/Header`): [label] in Label `Text/Tertiary`,
/// 24 tall like an item.
class AmalfiMenuHeader extends StatelessWidget {
  const AmalfiMenuHeader({
    super.key,
    required this.label,
    this.height = AmalfiMenuMetrics.itemHeight,
  });

  final String label;

  /// The row's height.
  final double height;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: Padding(
      padding: AmalfiMenuMetrics.headerPadding,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
              style: AmalfiType.label(
                color: AmalfiTheme.of(context).colors.textTertiary,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The separator between groups of menu items (kit `Menus/Item/Separator`): a 1 pt
/// `Line/Separator` line 4 from the top of its 8, inset 12 from both sides.
class AmalfiMenuSeparator extends StatelessWidget {
  const AmalfiMenuSeparator({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: AmalfiMenuMetrics.separatorHeight,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(
        AmalfiMenuMetrics.separatorInset,
        4,
        AmalfiMenuMetrics.separatorInset,
        3,
      ),
      child: ColoredBox(color: AmalfiTheme.of(context).colors.lineSeparator),
    ),
  );
}
