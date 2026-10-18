// The pointer and keyboard interaction of an Amalfi control: hover, press (with the pointer
// still inside), keyboard focus (the halo shows only with keyboard navigation), activation on
// release inside or with the activation keys, and optionally a drag of the primary button.
// A click does not move the keyboard focus, as on the desktop.

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../system_look.dart';

/// Activates the focused Amalfi control (the keys in [AmalfiInteraction.activators]).
class AmalfiActivateIntent extends Intent {
  const AmalfiActivateIntent();
}

/// The interaction state of a control.
@immutable
class AmalfiInteractionState {
  const AmalfiInteractionState({
    this.enabled = true,
    this.hovered = false,
    this.pressed = false,
    this.focused = false,
  });

  /// Whether the control reacts to input.
  final bool enabled;

  /// The pointer is over the control.
  final bool hovered;

  /// The primary button is down on the control and the pointer is still over it (or it is
  /// dragging).
  final bool pressed;

  /// The control has the keyboard focus (shown with the halo).
  final bool focused;

  @override
  bool operator ==(Object other) =>
      other is AmalfiInteractionState &&
      other.enabled == enabled &&
      other.hovered == hovered &&
      other.pressed == pressed &&
      other.focused == focused;

  @override
  int get hashCode => Object.hash(enabled, hovered, pressed, focused);

  @override
  String toString() =>
      'AmalfiInteractionState(enabled: $enabled, hovered: $hovered, '
      'pressed: $pressed, focused: $focused)';
}

/// Pointer and keyboard handling of a control: hover, press (with the pointer still inside),
/// keyboard focus (the halo shows only with keyboard navigation), activation on release
/// inside or with one of [activators] while focused, and optionally a drag of the primary
/// button. A control nested in another takes the press for itself (the outer one does not see
/// it).
///
/// [builder] draws the control in its [AmalfiInteractionState]; [onStateChanged] reports
/// each change (to drive animations). With [onActivate] null the control is disabled: no
/// hover, press, focus or activation.
class AmalfiInteraction extends StatefulWidget {
  const AmalfiInteraction({
    super.key,
    required this.builder,
    this.onActivate,
    this.onPressDown,
    this.onStateChanged,
    this.onKey,
    this.onDragStart,
    this.onDragUpdate,
    this.onDragEnd,
    this.dragSlop = 2,
    this.activators = spaceActivates,
    this.focusNode,
    this.autofocus = false,
    this.cursor = SystemMouseCursors.basic,
  });

  /// Space activates: checkboxes, radio buttons, switches, disclosure controls (Return is
  /// left to the window's default button).
  static const Map<ShortcutActivator, Intent> spaceActivates = {
    SingleActivator(LogicalKeyboardKey.space): AmalfiActivateIntent(),
  };

  /// Space and Return activate: buttons.
  static const Map<ShortcutActivator, Intent> buttonActivates = {
    SingleActivator(LogicalKeyboardKey.space): AmalfiActivateIntent(),
    SingleActivator(LogicalKeyboardKey.enter): AmalfiActivateIntent(),
    SingleActivator(LogicalKeyboardKey.numpadEnter): AmalfiActivateIntent(),
  };

  final Widget Function(BuildContext context, AmalfiInteractionState state)
  builder;

  /// A release inside the control, or an activation key with the keyboard focus; null:
  /// disabled.
  final VoidCallback? onActivate;

  /// The primary button went down on the enabled control (a pull-down opens its menu then).
  final VoidCallback? onPressDown;

  /// The state changed because of input (hover, press, focus).
  final ValueChanged<AmalfiInteractionState>? onStateChanged;

  /// Other keys with the keyboard focus.
  final KeyEventResult Function(KeyEvent event)? onKey;

  /// The pointer moved [dragSlop] points with the primary button down: a drag starts (the
  /// release then ends it instead of activating). Positions are local.
  final ValueChanged<Offset>? onDragStart;
  final ValueChanged<Offset>? onDragUpdate;
  final VoidCallback? onDragEnd;

  /// How far the pointer moves before a press becomes a drag.
  final double dragSlop;

  /// The keys that activate the focused control.
  final Map<ShortcutActivator, Intent> activators;

  final FocusNode? focusNode;
  final bool autofocus;
  final MouseCursor cursor;

  @override
  State<AmalfiInteraction> createState() => _AmalfiInteractionState();
}

class _AmalfiInteractionState extends State<AmalfiInteraction> {
  /// The pointers whose press a control has taken: a control nested in another (a tab's
  /// close button) receives the press first and keeps it from the outer one.
  static final Set<int> _claimed = {};

  int? _pointer;
  bool _hovered = false;
  bool _focused = false;
  bool _down = false;
  bool _inside = false;
  bool _dragging = false;
  Offset _downAt = Offset.zero;
  AmalfiInteractionState? _reported;

  /// The focus node when the caller gives none: Tab skips it unless keyboard navigation is on
  /// (Settings › Keyboard › Keyboard navigation), as it skips controls on the reference.
  FocusNode? _ownNode;

  bool get _enabled => widget.onActivate != null;

  AmalfiInteractionState get _state {
    final enabled = _enabled;
    return AmalfiInteractionState(
      enabled: enabled,
      hovered: enabled && _hovered,
      pressed: enabled && _down && (_inside || _dragging),
      focused: enabled && _focused,
    );
  }

  void _update(VoidCallback change) {
    if (!mounted) return;
    setState(change);
    final state = _state;
    if (state != _reported) {
      _reported = state;
      widget.onStateChanged?.call(state);
    }
  }

  @override
  void didUpdateWidget(AmalfiInteraction old) {
    super.didUpdateWidget(old);
    if (!_enabled) {
      if (_dragging) widget.onDragEnd?.call();
      _down = _dragging = false;
      _release();
    }
  }

  bool _contains(Offset local) {
    final box = context.findRenderObject();
    return box is RenderBox && box.hasSize && box.size.contains(local);
  }

  void _release() {
    final pointer = _pointer;
    if (pointer != null) _claimed.remove(pointer);
    _pointer = null;
  }

  @override
  void dispose() {
    _release();
    _ownNode?.dispose();
    super.dispose();
  }

  void _pointerDown(PointerDownEvent e) {
    if (!_enabled || e.buttons & kPrimaryButton == 0) return;
    if (!_claimed.add(e.pointer)) return;
    _pointer = e.pointer;
    _update(() {
      _down = true;
      _inside = true;
      _dragging = false;
      _downAt = e.localPosition;
    });
    widget.onPressDown?.call();
  }

  void _pointerMove(PointerMoveEvent e) {
    if (!_down) return;
    final drags = widget.onDragStart != null;
    if (drags &&
        !_dragging &&
        (e.localPosition - _downAt).distance >= widget.dragSlop) {
      _update(() => _dragging = true);
      widget.onDragStart?.call(_downAt);
    }
    if (_dragging) {
      widget.onDragUpdate?.call(e.localPosition);
      return;
    }
    final inside = _contains(e.localPosition);
    if (inside != _inside) _update(() => _inside = inside);
  }

  void _pointerUp(PointerUpEvent e) {
    if (e.pointer == _pointer) _release();
    if (!_down) return;
    final dragged = _dragging;
    final fire = !dragged && _inside && _contains(e.localPosition);
    _update(() {
      _down = false;
      _dragging = false;
      _hovered = _contains(e.localPosition);
    });
    if (dragged) {
      widget.onDragEnd?.call();
    } else if (fire && _enabled) {
      widget.onActivate?.call();
    }
  }

  void _pointerCancel() {
    _release();
    if (!_down) return;
    final dragged = _dragging;
    _update(() => _down = _dragging = false);
    if (dragged) widget.onDragEnd?.call();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _enabled;
    final onKey = widget.onKey;
    var node = widget.focusNode;
    if (node == null) {
      node = _ownNode ??= FocusNode(debugLabel: 'AmalfiInteraction');
      node.skipTraversal = !SystemLookScope.of(context).keyboardNavigation;
    }
    Widget child = FocusableActionDetector(
      enabled: enabled,
      focusNode: node,
      autofocus: widget.autofocus,
      mouseCursor: enabled ? widget.cursor : MouseCursor.defer,
      shortcuts: widget.activators,
      // Only the control's own activators: the app maps Return to [ActivateIntent] too,
      // which must reach the window's default button rather than a focused checkbox.
      actions: {
        AmalfiActivateIntent: CallbackAction<AmalfiActivateIntent>(
          onInvoke: (_) {
            widget.onActivate?.call();
            return null;
          },
        ),
      },
      onShowFocusHighlight: (on) {
        if (on != _focused) _update(() => _focused = on);
      },
      child: MouseRegion(
        onEnter: (_) => _update(() => _hovered = true),
        onExit: (_) => _update(() => _hovered = false),
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _pointerDown,
          onPointerMove: _pointerMove,
          onPointerUp: _pointerUp,
          onPointerCancel: (_) => _pointerCancel(),
          child: widget.builder(context, _state),
        ),
      ),
    );
    if (onKey != null) {
      child = Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onKeyEvent: (_, event) =>
            enabled ? onKey(event) : KeyEventResult.ignored,
        child: child,
      );
    }
    return child;
  }
}
