// Glass computed by Ossido (silica-glass-v1, docs/protocols.md): the widget declares its
// area, the compositor puts the blurred background of the material behind it. The child
// draws on top (text, icons) and leaves the rest transparent.

import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// The measured glasses: clear (Dock), thick (menus, search), regular (the Liquid Glass of
/// controls, with the strong lens on the edge) and notification (banners and Notification Center).
enum GlassMaterial { clear, thick, regular, notification }

/// The kind of surface a glass belongs to (silica-glass-v1 version 7): Ossido picks the blur,
/// refraction, edge light, tint and shadow of that kind. Without one, the material decides
/// (clear: Dock, thick: menu, regular: Control Center module, notification: banner).
enum GlassProfile {
  /// Menus and context menus.
  menu,

  /// Popovers (Ossido: Thick, like a menu, with its own tip outline).
  popover,

  /// Large panels: Notification Center, Faro, the launcher, an expanded module.
  panel,

  /// Control Center modules and HUDs.
  module,

  /// Small controls on glass: toolbar buttons, pills, round buttons. The lens is gentler and
  /// narrower than a module's.
  control,

  /// The Dock and the app switcher.
  dock,

  /// Tooltips and labels.
  tooltip,

  /// Sheets and alerts.
  sheet,

  /// Notification banners.
  banner,
}

/// A glass area as large as its child, with circular-arc corners.
class Glass extends SingleChildRenderObjectWidget {
  const Glass({
    super.key,
    this.radius = 0,
    this.material = GlassMaterial.clear,
    this.group = 0,
    this.tip,
    this.profile,
    this.profileShadow = false,
    this.smoothing = 0,
    super.child,
  });

  final double radius;

  /// Continuous corners (silica-glass-v1 version 9): 0–1, how far the corner spreads along the
  /// edges, `radius` being the equivalent circular radius; 0 is a circular arc. The app icon
  /// body is radius 214/824 of its side with 0.6. An older compositor draws a circle that
  /// stands for it.
  final double smoothing;
  final GlassMaterial material;

  /// The kind of surface (null: from [material]).
  final GlassProfile? profile;

  /// Ossido draws the [profile]'s shadow under the glass (the widget then draws none).
  final bool profileShadow;

  /// Glass merges only with glass of the same group; a higher group sits on top
  /// (a submenu on its menu: two distinct panels even where they overlap).
  final int group;

  /// A tip under the glass, in the same shape: the edge runs from the body to the tip.
  final GlassTip? tip;

  @override
  RenderGlass createRenderObject(BuildContext context) => RenderGlass(
    radius: radius,
    material: material,
    group: group,
    tip: tip,
    profile: profile,
    profileShadow: profileShadow,
    smoothing: smoothing,
  );

  @override
  void updateRenderObject(BuildContext context, RenderGlass renderObject) {
    renderObject
      ..radius = radius
      ..material = material
      ..group = group
      ..tip = tip
      ..profile = profile
      ..profileShadow = profileShadow
      ..smoothing = smoothing;
  }
}

/// The edge of the glass a tip sits on, pointing away from the body.
enum TipEdge { bottom, top, left, right }

/// The tip of a glass, a drop shape that merges into the body (silica-glass-v1 versions 4–6).
/// `x` is the center along the edge (from the left for top and bottom, from the top for left
/// and right), `width` the base along the edge, `height` the depth away from it. Ossido draws
/// the measured outline (TIP-01, `TipOutline`) picked by this rectangle: the Dock menu tip is
/// 31 × 10 pt, the popover tip 32 × 11 pt on the top and bottom edges and 39 × 12 pt on the sides.
@immutable
class GlassTip {
  const GlassTip({
    required this.x,
    required this.width,
    required this.height,
    this.edge = TipEdge.bottom,
  });

  final double x;
  final double width;
  final double height;
  final TipEdge edge;

  /// On the top edge, pointing up (a popover under its button).
  bool get up => edge == TipEdge.top;

  @override
  bool operator ==(Object other) =>
      other is GlassTip &&
      other.x == x &&
      other.width == width &&
      other.height == height &&
      other.edge == edge;

  @override
  int get hashCode => Object.hash(x, width, height, edge);
}

/// The render object of [Glass]: it registers itself while attached to the tree.
class RenderGlass extends RenderProxyBox {
  RenderGlass({
    required double radius,
    required GlassMaterial material,
    int group = 0,
    GlassTip? tip,
    GlassProfile? profile,
    bool profileShadow = false,
    double smoothing = 0,
  }) : _smoothing = smoothing,
       _radius = radius,
       _material = material,
       _group = group,
       _tip = tip,
       _profile = profile,
       _profileShadow = profileShadow;

  GlassProfile? _profile;
  GlassProfile? get profile => _profile;
  set profile(GlassProfile? value) {
    if (value == _profile) return;
    _profile = value;
    GlassRegistry.instance.schedule();
  }

  double _smoothing;
  double get smoothing => _smoothing;
  set smoothing(double value) {
    if (value == _smoothing) return;
    _smoothing = value;
    GlassRegistry.instance.schedule();
  }

  bool _profileShadow;
  bool get profileShadow => _profileShadow;
  set profileShadow(bool value) {
    if (value == _profileShadow) return;
    _profileShadow = value;
    GlassRegistry.instance.schedule();
  }

  /// The profile keys of a region (none without a profile: an older Ossido reads the same).
  Map<String, Object> get _profileKeys => {
    if (profile case final profile?) 'profile': profile.name,
    if (profile != null && profileShadow) 'shadow': true,
  };

  int _group;
  int get group => _group;
  set group(int value) {
    if (value == _group) return;
    _group = value;
    GlassRegistry.instance.schedule();
  }

  GlassTip? _tip;
  GlassTip? get tip => _tip;
  set tip(GlassTip? value) {
    if (value == _tip) return;
    _tip = value;
    GlassRegistry.instance.schedule();
  }

  double _radius;
  double get radius => _radius;
  set radius(double value) {
    if (value == _radius) return;
    _radius = value;
    GlassRegistry.instance.schedule();
  }

  GlassMaterial _material;
  GlassMaterial get material => _material;
  set material(GlassMaterial value) {
    if (value == _material) return;
    _material = value;
    GlassRegistry.instance.schedule();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    GlassRegistry.instance.add(this);
  }

  @override
  void detach() {
    GlassRegistry.instance.remove(this);
    super.detach();
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    // After every paint the position may have changed.
    GlassRegistry.instance.schedule();
    super.paint(context, offset);
  }

  /// The region in logical pixels of the surface, with the ancestors' transforms
  /// (a swelling glass grows in the compositor too, radius included).
  ///
  /// Under a rotation (a label tilted with its object) the region also carries its `frame`
  /// (silica-glass-v1 version 8): the transform of its own rectangle, from which the embedder
  /// sends the upright rectangle and the angle. `x` … `height` stay the bounding box, for an
  /// earlier embedder or compositor.
  Map<String, Object> region() {
    final transform = getTransformTo(null);
    final rect = MatrixUtils.transformRect(transform, Offset.zero & size);
    final factor = size.width > 0 ? rect.width / size.width : 1.0;
    final frame = glassFrame(transform, Offset.zero & size, radius);
    return {
      'x': rect.left,
      'y': rect.top,
      'width': rect.width,
      'height': rect.height,
      'radius': radius * factor,
      if (smoothing > 0) 'smoothing': smoothing.clamp(0.0, 1.0),
      'material': material.name,
      'opacity': opacity,
      if (group != 0) 'group': group,
      ..._profileKeys,
      'frame': ?frame,
    };
  }

  /// The region of the body and, if there is one, of the tip.
  List<Map<String, Object>> regions() {
    final body = region();
    final tip = this.tip;
    if (tip == null) return [body];
    final transform = getTransformTo(null);
    final local = switch (tip.edge) {
      TipEdge.bottom => Rect.fromLTWH(
        tip.x - tip.width / 2,
        size.height,
        tip.width,
        tip.height,
      ),
      TipEdge.top => Rect.fromLTWH(
        tip.x - tip.width / 2,
        -tip.height,
        tip.width,
        tip.height,
      ),
      // Sideways the rectangle's width is the depth and its height the base.
      TipEdge.left => Rect.fromLTWH(
        -tip.height,
        tip.x - tip.width / 2,
        tip.height,
        tip.width,
      ),
      TipEdge.right => Rect.fromLTWH(
        size.width,
        tip.x - tip.width / 2,
        tip.height,
        tip.width,
      ),
    };
    final rect = MatrixUtils.transformRect(transform, local);
    final frame = glassFrame(transform, local, 0);
    return [
      body,
      {
        'x': rect.left,
        'y': rect.top,
        'width': rect.width,
        'height': rect.height,
        'material': material.name,
        'opacity': body['opacity'] ?? 1.0,
        'shape': switch (tip.edge) {
          TipEdge.bottom => 'tip',
          TipEdge.top => 'tip-up',
          TipEdge.left => 'tip-left',
          TipEdge.right => 'tip-right',
        },
        if (group != 0) 'group': group,
        ..._profileKeys,
        'frame': ?frame,
      },
    ];
  }

  /// The ancestors' opacity (`Opacity`, `FadeTransition`, `AnimatedOpacity`): the glass
  /// fades in and out together with the panel that contains it.
  double get opacity {
    var value = 1.0;
    for (RenderObject? node = parent; node != null; node = node.parent) {
      if (node is RenderOpacity) {
        value *= node.opacity;
      } else if (node is RenderAnimatedOpacity) {
        value *= node.opacity.value;
      }
    }
    return value.clamp(0.0, 1.0);
  }
}

/// The `frame` of a glass region whose transform to the surface turns it (silica-glass-v1
/// version 8): `transform` [a, b, c, d, tx, ty] takes the region's own rectangle
/// (0, 0)–(width, height) to the surface (x' = a·x + c·y + tx, y' = b·x + d·y + ty), with
/// `local`'s size and `radius` before the transform. Null for an upright transform
/// (translated or scaled): the bounding box is already the shape.
@visibleForTesting
Map<String, Object>? glassFrame(Matrix4 transform, Rect local, double radius) {
  final m = transform.storage;
  final (a, b, c, d) = (m[0], m[1], m[4], m[5]);
  if (b.abs() < 1e-9 && c.abs() < 1e-9) return null;
  return {
    'transform': [
      a,
      b,
      c,
      d,
      m[12] + a * local.left + c * local.top,
      m[13] + b * local.left + d * local.top,
    ],
    'width': local.width,
    'height': local.height,
    'radius': radius,
  };
}

/// Collects the glass areas after every frame and sends them to the embedder when they change.
///
/// It is checked at every frame, not only when a [RenderGlass] repaints: an ancestor that
/// changes transform or opacity (a panel opening) can move the glass without repainting
/// it, and the compositor would keep the old geometry.
///
/// Every window has its own regions (silica-desktop#146): the main window's go as
/// `setRegions [regions]`, those of a window opened with `SilicaWindows.openWindow` as
/// `setViewRegions {viewId, regions}`, in the coordinates of that window.
class GlassRegistry {
  GlassRegistry._();

  static final GlassRegistry instance = GlassRegistry._();

  static const MethodChannel channel = MethodChannel(
    'silica/glass',
    JSONMethodCodec(),
  );

  final Set<RenderGlass> _glasses = {};

  /// The regions last sent, by view.
  Map<int, List<Map<String, Object>>> _sent = const {};
  bool _scheduled = false;
  bool _everyFrame = false;

  void add(RenderGlass glass) {
    _glasses.add(glass);
    if (!_everyFrame) {
      _everyFrame = true;
      // After the paint of every frame (persistent callbacks run in registration order,
      // after the rendering one).
      SchedulerBinding.instance.addPersistentFrameCallback((_) {
        if (_glasses.isNotEmpty || _sent.values.any((r) => r.isNotEmpty)) {
          _send();
        }
      });
    }
    schedule();
  }

  void remove(RenderGlass glass) {
    _glasses.remove(glass);
    schedule();
  }

  /// The current regions of the main window, in registration order.
  @visibleForTesting
  List<Map<String, Object>> get regions => regionsByView[0] ?? const [];

  /// The current regions of every window with glass, by view id, in registration order.
  @visibleForTesting
  Map<int, List<Map<String, Object>>> get regionsByView {
    final byView = <int, List<Map<String, Object>>>{};
    for (final glass in _glasses) {
      if (!glass.attached || !glass.hasSize) continue;
      byView.putIfAbsent(viewIdOf(glass), () => []).addAll(glass.regions());
    }
    return byView;
  }

  /// The view (window) a render object is drawn in: its [RenderView]'s.
  static int viewIdOf(RenderObject node) {
    for (RenderObject? n = node; n != null; n = n.parent) {
      if (n is RenderView) return n.flutterView.viewId;
    }
    return 0;
  }

  void schedule() {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      _send();
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }

  Future<void> _send() async {
    final current = regionsByView;
    final previous = _sent;
    _sent = current;
    for (final view in {...previous.keys, ...current.keys}) {
      final regions = current[view] ?? const <Map<String, Object>>[];
      final sent = previous[view] ?? const <Map<String, Object>>[];
      if (listEquals(regions.map(_key).toList(), sent.map(_key).toList())) {
        continue;
      }
      try {
        if (view == 0) {
          await channel.invokeMethod<Object?>('setRegions', regions);
        } else {
          await channel.invokeMethod<Object?>('setViewRegions', {
            'viewId': view,
            'regions': regions,
          });
        }
      } on MissingPluginException {
        // Outside Silica (tests, other embedders) there is no glass.
      }
    }
  }

  static String _key(Map<String, Object> region) =>
      region.entries.map((entry) => '${entry.key}=${entry.value}').join(',');
}
