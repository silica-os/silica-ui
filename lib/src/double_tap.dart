// Double click with the speed chosen in Settings › Mouse (the system look's `doubleClickMs`).
// Flutter's own double tap has a fixed 300 ms timeout; this one is a tap recognizer that counts
// two taps near each other within the chosen time.

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'system_look.dart';

/// How far the second click may be from the first, in logical pixels (Flutter's slop).
const double doubleClickSlop = kDoubleTapSlop / 4;

/// A tap recognizer that also reports double clicks within [SystemLook.doubleClickMs].
class SilicaDoubleTapRecognizer extends TapGestureRecognizer {
  // A tap recognizer only takes pointers when it has a tap callback.
  SilicaDoubleTapRecognizer({super.debugOwner, this.onDoubleTap}) {
    onTap = () {};
  }

  /// Called on the second click.
  VoidCallback? onDoubleTap;

  Duration? _lastAt;
  Offset? _lastPosition;

  @override
  void handleTapUp({
    required PointerDownEvent down,
    required PointerUpEvent up,
  }) {
    super.handleTapUp(down: down, up: up);
    final last = _lastAt;
    final lastPosition = _lastPosition;
    final limit = Duration(
      milliseconds: SilicaSystemLook.current.doubleClickMs,
    );
    if (last != null &&
        lastPosition != null &&
        up.timeStamp - last <= limit &&
        (up.position - lastPosition).distance <= doubleClickSlop) {
      _lastAt = null;
      _lastPosition = null;
      onDoubleTap?.call();
    } else {
      _lastAt = up.timeStamp;
      _lastPosition = up.position;
    }
  }
}

/// Calls [onDoubleTap] on a double click of [child], at the speed chosen in Settings.
class SilicaDoubleTap extends StatelessWidget {
  const SilicaDoubleTap({
    super.key,
    required this.onDoubleTap,
    this.behavior,
    this.child,
  });

  /// Null: no double click handling.
  final VoidCallback? onDoubleTap;
  final HitTestBehavior? behavior;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    if (onDoubleTap == null) return child ?? const SizedBox.shrink();
    return RawGestureDetector(
      behavior: behavior,
      gestures: {
        SilicaDoubleTapRecognizer:
            GestureRecognizerFactoryWithHandlers<SilicaDoubleTapRecognizer>(
              SilicaDoubleTapRecognizer.new,
              (r) => r.onDoubleTap = onDoubleTap,
            ),
      },
      child: child,
    );
  }
}
