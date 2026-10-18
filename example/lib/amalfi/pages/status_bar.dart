// Gallery page: the Status Bar (kit `Status Bar/*`). Every item at rest and active, the menu bar
// and the lock screen clusters in every legibility treatment, the lock screen's on a photo-like
// backdrop, and a live cluster whose items toggle their Active capsule.

import 'package:flutter/widgets.dart';
import 'package:silica_ui/silica_ui.dart';

import '../specimen.dart';

/// The Status Bar page.
final AmalfiGalleryPage statusBarPage = AmalfiGalleryPage(
  family: 'status_bar',
  title: 'Status Bar',
  build: (context) => const _StatusBarPage(),
);

const List<(String, AmalfiStatusBarLegibility)> _treatments = [
  ('Default', AmalfiStatusBarLegibility.standard),
  ('Increase Contrast', AmalfiStatusBarLegibility.increaseContrast),
  ('Reduce Transparency', AmalfiStatusBarLegibility.reduceTransparency),
];

List<Widget> _menuBarItems() => const [
  AmalfiStatusGlyphItem(symbol: 'bluetooth', label: 'Bluetooth'),
  AmalfiStatusGlyphItem(symbol: 'wifi', label: 'Wi-Fi'),
  AmalfiStatusGlyphItem(symbol: 'volume-2', label: 'Sound'),
  AmalfiStatusBatteryItem(level: 0.84, percentage: '84%', label: 'Battery'),
  AmalfiStatusGlyphItem(symbol: 'search', label: 'Search'),
  AmalfiStatusClockItem(text: 'Fri 16 Oct  09:41', label: 'Clock'),
  AmalfiStatusGlyphItem(symbol: 'control-center', label: 'Control Center'),
];

List<Widget> _lockScreenItems() => const [
  AmalfiStatusInputSourceItem(source: 'Italian', label: 'Input source'),
  AmalfiStatusGlyphItem(symbol: 'wifi', label: 'Wi-Fi'),
  AmalfiStatusBatteryItem(level: 0.84, percentage: '84%', label: 'Battery'),
];

class _StatusBarPage extends StatelessWidget {
  const _StatusBarPage();

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SpecimenSection(
        title: 'Items',
        children: [
          Specimen(
            label: 'Glyph · Rest',
            child: AmalfiStatusGlyphItem(symbol: 'wifi', label: 'Wi-Fi'),
          ),
          Specimen(
            label: 'Glyph · Active',
            child: AmalfiStatusGlyphItem(
              symbol: 'wifi',
              label: 'Wi-Fi',
              active: true,
            ),
          ),
          Specimen(
            label: 'Battery',
            child: AmalfiStatusBatteryItem(
              level: 0.84,
              percentage: '84%',
              label: 'Battery',
            ),
          ),
          Specimen(
            label: 'Input Source',
            child: AmalfiStatusInputSourceItem(
              source: 'Italian',
              label: 'Input source',
            ),
          ),
          Specimen(
            label: 'Clock',
            child: AmalfiStatusClockItem(
              text: 'Fri 16 Oct  09:41',
              label: 'Clock',
            ),
          ),
        ],
      ),
      SpecimenSection(
        title: 'Menu Bar',
        children: [
          for (final (name, legibility) in _treatments)
            Specimen(
              label: name,
              child: AmalfiStatusBar(
                placement: AmalfiStatusBarPlacement.menuBar,
                legibility: legibility,
                items: _menuBarItems(),
              ),
            ),
        ],
      ),
      SpecimenSection(
        title: 'Lock Screen',
        children: [
          for (final (name, legibility) in _treatments)
            Specimen(
              label: name,
              child: _Photo(
                child: AmalfiStatusBar(
                  placement: AmalfiStatusBarPlacement.lockScreen,
                  legibility: legibility,
                  items: _lockScreenItems(),
                ),
              ),
            ),
        ],
      ),
      const SpecimenSection(
        title: 'Live',
        children: [Specimen(label: 'Click an item', child: _Live())],
      ),
    ],
  );
}

/// A stand-in for the wallpaper behind the lock screen's cluster.
class _Photo extends StatelessWidget {
  const _Photo({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        colors: [Color(0xFF3A5A7C), Color(0xFF7FA6C9), Color(0xFFC9B48F)],
      ),
    ),
    child: Padding(padding: const EdgeInsets.all(8), child: child),
  );
}

class _Live extends StatefulWidget {
  const _Live();

  @override
  State<_Live> createState() => _LiveState();
}

class _LiveState extends State<_Live> {
  String? _open;

  void _toggle(String name) =>
      setState(() => _open = _open == name ? null : name);

  @override
  Widget build(BuildContext context) => AmalfiStatusBar(
    placement: AmalfiStatusBarPlacement.menuBar,
    items: [
      AmalfiStatusGlyphItem(
        symbol: 'wifi',
        label: 'Wi-Fi',
        active: _open == 'wifi',
        onPressed: () => _toggle('wifi'),
      ),
      AmalfiStatusBatteryItem(
        level: 0.84,
        percentage: '84%',
        label: 'Battery',
        active: _open == 'battery',
        onPressed: () => _toggle('battery'),
      ),
      AmalfiStatusGlyphItem(
        symbol: 'control-center',
        label: 'Control Center',
        active: _open == 'controls',
        onPressed: () => _toggle('controls'),
      ),
    ],
  );
}
