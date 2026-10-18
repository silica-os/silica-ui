// A sheet shown over a window from code (the imperative form of [AmalfiAttachedSheet]):
// `showAmalfiSheet` puts the sheet in the window's [Overlay], dims the content below the title
// bar with the scrim, hangs the sheet centred from the title bar with the same motion
// (spring.panel slide and fade.quick in, fade.instant out) and completes with the value passed
// to [AmalfiSheetRoute.close]. The window is modal while it is open; Esc cancels.

import 'dart:async';

import 'package:flutter/physics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../../../window.dart' show toolbarHeight;
import '../../tokens.g.dart';
import '../alerts/alert_surface.dart';
import 'sheet.dart';

/// An open sheet: [close] hides it and completes [showAmalfiSheet] with a value.
class AmalfiSheetRoute<T> {
  AmalfiSheetRoute._();
  final Completer<T?> _done = Completer<T?>();
  VoidCallback? _hide;

  /// Whether the sheet was closed (or is closing).
  bool get isClosed => _done.isCompleted;

  void close([T? value]) {
    if (_done.isCompleted) return;
    _done.complete(value);
    _hide?.call();
  }
}

/// Shows a sheet over the window of [context] (it needs an [Overlay], as in `WidgetsApp`).
/// [builder] makes the sheet; with [surface] it is put on the raised panel of an alert (radius
/// 20), otherwise it draws its own (an `AmalfiDialog` or `AmalfiAlert`). [top] is the height of
/// the title bar the sheet hangs from. The future completes with the value passed to
/// [AmalfiSheetRoute.close], null when Esc cancelled it.
Future<T?> showAmalfiSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext context, AmalfiSheetRoute<T> sheet)
  builder,
  double top = toolbarHeight,
  bool cancelOnEscape = true,
  bool surface = true,
  double windowRadius = AmalfiRadii.window,
  String? semanticLabel,
}) {
  final overlay = Overlay.of(context);
  final route = AmalfiSheetRoute<T>._();
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => _SheetLayer<T>(
      route: route,
      top: top,
      cancelOnEscape: cancelOnEscape,
      surface: surface,
      windowRadius: windowRadius,
      semanticLabel: semanticLabel,
      builder: builder,
      onGone: () {
        entry.remove();
        entry.dispose();
      },
    ),
  );
  overlay.insert(entry);
  return route._done.future;
}

class _SheetLayer<T> extends StatefulWidget {
  const _SheetLayer({
    required this.route,
    required this.top,
    required this.cancelOnEscape,
    required this.surface,
    required this.windowRadius,
    required this.semanticLabel,
    required this.builder,
    required this.onGone,
  });

  final AmalfiSheetRoute<T> route;
  final double top;
  final bool cancelOnEscape;
  final bool surface;
  final double windowRadius;
  final String? semanticLabel;
  final Widget Function(BuildContext context, AmalfiSheetRoute<T> sheet)
  builder;
  final VoidCallback onGone;

  @override
  State<_SheetLayer<T>> createState() => _SheetLayerState<T>();
}

class _SheetLayerState<T> extends State<_SheetLayer<T>>
    with TickerProviderStateMixin {
  late final AnimationController _slide = AnimationController.unbounded(
    vsync: this,
  );
  late final AnimationController _fade = AnimationController(vsync: this);
  final FocusScopeNode _focus = FocusScopeNode();

  @override
  void initState() {
    super.initState();
    widget.route._hide = _hide;
    _fade.animateTo(
      1,
      duration: AmalfiFades.quick.duration,
      curve: AmalfiFades.quick.curve,
    );
    _slide
        .animateWith(SpringSimulation(AmalfiSprings.panel, 0, 1, 0))
        .whenCompleteOrCancel(() {
          // Settle exactly (the simulation stops within its tolerance).
          if (mounted && !widget.route.isClosed) _slide.value = 1;
        });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _slide.dispose();
    _fade.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _hide() async {
    await _fade.animateTo(
      0,
      duration: AmalfiFades.instant.duration,
      curve: AmalfiFades.instant.curve,
    );
    if (mounted) widget.onGone();
  }

  @override
  Widget build(BuildContext context) {
    final sheet = widget.builder(context, widget.route);
    final content = widget.surface
        ? AmalfiAlertSurface(radius: AmalfiSheetMetrics.radius, child: sheet)
        : sheet;
    return FocusScope(
      node: _focus,
      child: Focus(
        autofocus: true,
        onKeyEvent: (node, event) {
          if (widget.cancelOnEscape &&
              event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.escape) {
            widget.route.close();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: Semantics(
          scopesRoute: true,
          namesRoute: widget.semanticLabel != null,
          explicitChildNodes: true,
          label: widget.semanticLabel,
          child: AnimatedBuilder(
            animation: Listenable.merge([_slide, _fade]),
            builder: (context, _) => Stack(
              children: [
                // The window behind takes no clicks, the title bar included.
                const Positioned.fill(
                  child: ModalBarrier(dismissible: false, color: null),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: widget.top,
                  bottom: 0,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: _fade.value,
                      child: AmalfiSheetScrim(radius: widget.windowRadius),
                    ),
                  ),
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  top: widget.top - AmalfiSheetMetrics.titleBarOverlap,
                  bottom: 0,
                  child: ClipRect(
                    clipBehavior: _slide.value < 1 ? Clip.hardEdge : Clip.none,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: FractionalTranslation(
                        translation: Offset(0, _slide.value - 1),
                        child: Opacity(opacity: _fade.value, child: content),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
