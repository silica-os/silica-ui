# Changelog

## Unreleased

- **Changed (silica-desktop#226):** clear (glass) exists only in light: `IconAppearance.clearDark` and the
  `clear-dark` rendered key are gone (the service word 5 is not sent). The app icon body is the Sketch
  outline of silica-icons (`tools/body.svg`: radius 214, smoothing 0.6) instead of a superellipse.
- **Added (silica-desktop#224):** `SilicaThumbnails` (client of `dev.frascella.Silica.Thumbnails1`:
  `thumbnail(uri, sizePx)` returns the cached PNG path or null, `invalidate(uris)`) and the
  `SilicaThumbnail` widget: it asks for `size x devicePixelRatio`, shows `fallback` (the file-type
  icon) until the PNG is ready, then `Image.file` in the `size` box; with no service the fallback
  stays. Raster images and PDF first pages only; folders keep their icon until the composed folder
  icon lands.
- **Added (silica-ui, mustache#23; silica-design 43bd510f):** `AmalfiAppIcon(id)`, the 16 pt app icon of
  a menu row (`Icons/App/16/<App>`), drawn from the app's layers in silica-icons for
  `AmalfiMenuAction.icon`; the id may also be an app's `icon/` folder (`X-Silica-Icon`).
  `AmalfiMenuAction.submenuWidth` sets the submenu width (192 for Open With).
  `SilicaMenuItem.icon` sends the same id to Silica's menu bar as `icon` (the bar must draw it).
  **Changed (silica-design a23f0d03):** the menu submenu overlaps its parent
  by 4 pt on the parent's visible body (it was 8; `AmalfiMenuMetrics.submenuOverlap` stays 4). Every
  kit fixture resynced to silica-design a23f0d03: the Light glass layers carry a ~1% white fill in
  Sketch so that it renders their shadow; the code does not add it (the geometry check reads the
  tint from the sibling layer) and the pixel harness now compares the shadow ring
  (`KitMaster.unpaintedShadows` is removed); the glass pixels needed no extra tolerance.
- **Added (silica-ui#97; silica-design 3e50109d, silica-desktop fb2989c):** `AmalfiColors.paletteArancia`
  (`Palette/Arancia`, light `#F98A17`, dark `#FF9F40`: the Orange tag and the Orange accent, never
  `paletteLimone`) and `AmalfiColors.paletteLimoneScuro` (`Palette/Limone Scuro`, light `#A67600`,
  dark `#FFCF3D`: yellow glyphs such as the Notes sidebar folders). `paletteLimone` stays the Yellow
  tag and fills. Tokens regenerated; no kit fixture changed. `SilicaAccent.orange` now uses Arancia
  for `plain` and `fill` (it was the measured reference orange).
- **Changed (Amalfi sidebars, silica-ui#95; silica-desktop 2aa9b2a, silica-design 723f76a0):**
  glyphs are coloured by section: new `AmalfiSidebarGlyphColor` scope, `AmalfiSidebarGroup.glyphColor`
  and `AmalfiSidebarRow.glyphColor`; the default is `Accent/Amalfi` and a selected row keeps its
  section colour. In an inactive window (`WindowActiveScope`) the selection is a neutral capsule
  (`Surface/Control Pressed`, dark `Surface/Control`) and every glyph and label is `Text/Secondary`
  (`Sidebars/Row/{Plain,Badge}/Selected Inactive`). No divider between sidebar and content:
  `AmalfiSidebarPanel.edge` and `AmalfiToolbar.sidebarSection(edge:)` are removed (breaking), and
  `AmalfiWindowLayout` no longer draws the sidebar line across the bar. Kit fixtures resynced for
  the sidebar masters.
- **Added (silica-ui#95):** `AmalfiSidebarReveal` and `AmalfiSidebarRevealBuilder`, the sidebar
  show/hide motion (hide 240 ms, show 230 ms after a 40 ms delay, cubic-bezier(0.42, 0, 0.58, 1);
  the sidebar slides from the leading edge, the content and its toolbar follow the content edge),
  with the timings in `AmalfiSidebarMotion`.
- **Added (silica-desktop#4):** menus and popovers as surfaces of their own. `showAmalfiMenu`,
  `showAmalfiPopover`, the pop-up and pull-down buttons and the submenus open an `xdg_popup` of
  the app's window, drawn by its own Flutter view, when Silica offers it (the app started with
  `--multi-window`, `SilicaPopups.available`): they can extend past the window's edge, Ossido keeps
  them on the output (flip or slide) and closes them with a press outside (`popup_done`), and their
  glass is the compositor's. A popover then opens without the scale (its surface appears at once)
  and its arrow follows where Ossido put it. Without popups (tests, other embedders, apps without
  `--multi-window`) they are drawn in the window's overlay as before. New: `SilicaPopups`
  (`probe`, `available`, `show`), `SilicaPopupController`, `SilicaPopupEdge`, `SilicaPopupAdjust`,
  `SilicaPopupScope`. Needs silica-desktop with `openPopup` on `silica/window`.
- **Added:** `SilicaApp.onOpen`, the files of a second launch of the running app (Open With, a share
  target), from the embedder's `open` call.
- **Added (silica-desktop#217):** `SilicaShare` (the system share service, `dev.frascella.Silica.Share1`:
  targets and sharing over the `silica/dbus` channel), `silicaShareEntries` and `showSilicaShareMenu`
  for an app's Share button. Without the service there are no targets, so the button stays hidden.
- **Changed (Amalfi readability pass, silica-ui#92; silica-desktop 3fd30a9, silica-design
  fd1719cf):** sizes are never smaller than macOS. Control icons: mini 14, small 16, regular /
  large / toolbar / menu bar / sidebar / list 20, accessory 16 (`AmalfiControlSize.iconSize`,
  `AmalfiControlIcons`: new `menuBar`, `sidebar`, `list`; `accessory` 12 -> 16). Text: Caption 11/14
  (was 10), new `AmalfiType.sidebar` (14/20) and `sidebarHeader` (12/16, 600); no text below
  11 (the legacy controls' 9 and 10 pt labels are 11). Sidebar: rows 32 with no gap, icon 20 at
  x 12, label at x 40, selected label 600, headers 28 (`AmalfiSidebarMetrics.rowHeight` 32,
  `rowGap` 0, `icon` 20, new `headerHeight`). Toolbar: items are 36 high at y 8 in the 52 bar
  (`AmalfiControlHeights.toolbar`): `AmalfiToolbarButton` 36 (glyph 20, labelled glyph at y 4),
  `AmalfiActionSegments` Large 36 with a 1 pt separator between icon segments (Back/Forward 73,
  groups of 3 and 4: 110 and 147), toolbar search field `AmalfiFieldSize.toolbar` (36, glyph 20,
  text at x 40). Compact 40 pt bars take the 24 pt `AmalfiToolbarButton(small: true)` (glyph
  16). `AmalfiSegmentedControl(toolbar: true)` with `size: large` is the toolbar's 36 high control
  (a plain Large one stays 32). Pop-up and pull-down chevrons, the submenu chevron, the clear
  and combo buttons (20 and 20/24 discs), the colour well chevron and the token cross are the
  16 pt accessory size; menu item icons 20; the full-screen strip's menu bar is 32. A Mini push
  button is 56 wide.
- **Added:** the Silica Symbols font (silica-icons ebc580b, CC BY-SA 4.0), one family per
  weight (`SilicaSymbols`, `SilicaSymbolsLight`, `SilicaSymbolsSemibold`, package `silica_ui`;
  font size = icon box): the generated icon constants `SilicaSymbols`, `SilicaSymbolsLight` and
  `SilicaSymbolsSemibold`, `silicaSymbolCodepoints` (name -> codepoint) and `silicaSymbolData`.
  `AmalfiGlyph` draws the control glyphs from the font (a glyph with its own `strokeWidth`, or
  one the font lacks, stays a vector) and `AmalfiSymbol` draws any symbol of the font by name
  before looking in the installed silica-icons. A by-name lookup is not a constant icon: apps
  that use `AmalfiSymbol` build with `--no-tree-shake-icons`. `tool/sync_symbols.dart` copies
  the fonts and regenerates the Dart files from a silica-icons checkout. Tokens regenerated
  from silica-desktop 3fd30a9 (`tool/gen_amalfi_tokens.dart` accepts `iconFont` and
  `controlHeights.toolbar`: `AmalfiControlHeights.toolbar`).
- **Changed:** the kit geometry tests follow the new masters (silica-design fd1719cf): kit icons
  are text layers in the Silica Symbols font, `Buttons/Toolbar/Icon Small` is covered, the known
  differences of the kit are in `docs/amalfi-checklist/kit-issues.md`.
- **Fixed:** `ScrollUnderToolbar.background` / `.columns` work again (silica-ui#87): given, in an
  active window the scrolled bar anchors its veil to the content colour (`ToolbarVeil.anchoredTo`)
  and shows it unchanged, like clear glass, with no colour band. Without them the measured veil
  is unchanged; an inactive window keeps the plain veil.
- **Changed:** `Glass/Regular` and `Glass/Thick` are real glass (silica-desktop 6c4105a): the
  Flutter backend of `AmalfiGlass` bends the blurred backdrop at the rim with
  `shaders/glass_edge.frag` (distortion / depth / chromatic split from the tokens, saturation,
  brightness, specular highlight) where shader image filters are available (Impeller), and
  otherwise blurs and applies saturation and brightness only. Thick blur 16 -> 10, tint alpha
  76 % -> 58 %, saturation 1.5 -> 1.1. `AmalfiMaterials.regular/thick` now carry `refraction`
  (magnification 1), `specularHighlights` and `brightness*`. The compositor backend is unchanged.
- **Added:** `AmalfiSlider.indicator`: a read-only slider with no thumb, at full strength
  (the shell's Control Center Display/Sound modules and volume/brightness HUD).
- **Added:** `AmalfiPullDownButton.entries`: a pull-down whose menu takes `AmalfiMenuEntry`
  (`AmalfiMenuAction` with `checked`, `AmalfiMenuSection`, `AmalfiMenuDivider`). Pop-up and
  pull-down menus now share one entry model and, being `AmalfiMenu`s, follow
  `AmalfiGlassBackendScope`.
- **Added:** `AmalfiGlassBackend` (`flutter`, the default, and `compositor`), set for a subtree
  with `AmalfiGlassBackendScope`, and `AmalfiGlassKind` (menu, popover, panel, module, control,
  dock, tooltip, sheet, banner: the profile of the region). With `compositor`, `AmalfiGlass`
  declares an Ossido glass region (`Glass`, material thick/regular/clear, the kind as profile,
  the profile's shadow) and paints only its child: no backdrop, tint, rims or shadow. A popover's
  arrow becomes the region's tip (20 x 8). `AmalfiGlass.kind` / `.group` and every Amalfi widget
  with glass pass their kind (menu, popover, tooltip, alert: sheet, color panel: panel,
  buttons, segmented tracks, lenses, field surfaces: control).
- **Added:** `GlassProfile.popover` (silica-glass-v1 `profile` enum).
- **Added:** `AmalfiMenu.onSubmenusChanged` / `AmalfiMenuList.onSubmenusChanged`: the global
  rectangles of the open submenu panels (nested ones included) whenever they change, so a host
  can update input regions without polling. Submenus use glass `group + 1` (`AmalfiMenu.group`).

Silica 1.0 "Amalfi", step 1: the design tokens in code. Existing widgets are unchanged.

- **Added:** `tool/gen_amalfi_tokens.dart`, which generates `lib/src/amalfi/tokens.g.dart` from
  `tool/amalfi/tokens.json` and the token tables of `tool/amalfi/motion.md` (copies of
  silica-desktop `docs/design/amalfi/` at `f17b47c`); `--check` fails when the file is stale
  (run in CI).
- **Added:** `AmalfiColors.light` / `.dark`: every colour token as a typed field
  (`accentAmalfi`, `textSecondary`, …), `byName('Text/Primary')`, and the app palettes as
  typed classes (`AmalfiColors.light.mail.flag`) or by name (`app('Mail', 'Flag')`,
  `palette('Mail')`). Dark-only apps (Calculator, Clock) give their palette in both.
- **Added:** `AmalfiType` (the 11 text styles as `TextStyle` factories and `AmalfiTextToken`s),
  `AmalfiGrid`, `AmalfiSpacing`, `AmalfiControlSize` (20 / 24 / 28 / 32 with icon sizes),
  `AmalfiControlIcons`, `AmalfiRadii`, `AmalfiShadows` (levels 1–3, light and dark),
  `AmalfiFocus`, `AmalfiStates`, `AmalfiMaterials` (Glass/Regular, Thick, Clear as data),
  `AmalfiWindowControls`, `AmalfiSprings`, `AmalfiFades`, `AmalfiCurves`, `AmalfiDelays`.
- **Added:** `AmalfiSmoothBorder` and `smoothRectPath`: smooth (continuous) corners, smoothing
  `AmalfiRadii.smoothing` (0.6) by default.
- **Added:** `AmalfiTheme` / `AmalfiThemeData`: appearance (following `SilicaAppearance` by
  default) and app palette, read with `AmalfiTheme.of(context)`.
- **Added:** fonts Inter Medium (500) and Bold (700), JetBrains Mono Regular (OFL). Text in
  weight 500 or 700 in the `Inter` family now uses the real weight instead of the nearest one.

Step 3.0: the harness for the components (tests against the kit, checklist, gallery) and the
tooltips as the worked example.

- **Added:** `AmalfiGlass`: a Glass/Regular, Glass/Thick or (static) Glass/Clear surface with
  smooth corners, drawn as `materials.md` says (blur, saturation, tint, inside rim, rim light,
  drop shadow outside the shape only), with an `opaque` fallback; `amalfiShadowSigma` (the
  kit's shadow blur is CSS-like, σ = blur / 2).
- **Added:** `AmalfiWholePoints` and `ceilToWholePoints`: round a box (text) up to whole points
  or to the 4 pt grid.
- **Added:** tooltips (`Tooltips/*` of the kit): `AmalfiTooltip` (one or more lines, optional
  shortcut, Glass/Thick, radius 8), `AmalfiTooltipRegion` (shown `delay.tooltip` after the
  pointer rests, at once while moving between items, `fade.quick` in and out, hidden on leave
  and press), `AmalfiTooltipPlacement` and `amalfiTooltipOffset` (8 from the target, centred
  across on the 4 pt grid, flipped when there is no room), `AmalfiTooltipMetrics`.
- **Added:** one barrel per component family in `lib/src/amalfi/components/`, exported.
- **Tools:** `tool/sync_kit.dart` (kit fixtures from silica-design into `test/amalfi/kit/`),
  `tool/gen_checklist.dart` (`docs/amalfi-checklist/`), the kit harness in
  `test/amalfi/support/` (`test/amalfi/README.md`), the Amalfi gallery in the example app.

## 0.38.0 · 2026-10-15

Windows close at once from their close button (silica-desktop#192).

- **Added:** `SilicaWindows.listen()`: answers the embedder's calls on `silica/window` from
  then on. The first window call (`SilicaWindow.setFullSizeContent`, `setSize`,
  `setSizeLimits`, `setAppearance`) calls it, so an app answers a close request at once even
  with no `onMainCloseRequested`; before, with no listener the engine held the request and the
  window did not close.
- **Changed:** with `onMainCloseRequested` or `SilicaWindowController.onCloseRequested` set,
  a close request is acknowledged at once with `closeAsking {viewId, request}`: the embedder
  waits for the answer (a confirmation) instead of closing the window after its short wait.
  `closeProbe` is answered true, so the embedder knows the app says it.

## 0.37.0 · 2026-10-15

App icons from silica-icons 0.6 (the `rendered` manifest field).

- **Added:** `IconAppearance` (`light`, `dark`, `clear`, `clearDark`, `tinted`,
  `tintedDark`): the six icon styles of icon-format.md. `SilicaIcon` takes `appearance` and
  `tint` (null: `defaultIconTint`, #0A84FF); `dark` still works and `appearance` wins over it.
- **Added:** `LayeredIcon.rendered` / `renderedFor`: the 1024 PNG of each style, with relief,
  shadows and glass baked in. Unknown keys, names outside the icon's folder and missing files
  are skipped.
- **Changed:** an app icon whose pack has the PNG of the style draws it (decoded at a power of
  two from 64 to 1024 pixels, mipmapped) instead of composing the SVG layers; the body mask,
  rim and drop shadow stay the shell's. Clear blurs the backdrop behind the translucent body.
  A custom tint, a pack without `rendered` (silica-icons < 0.6) or a PNG that does not decode
  compose the layers, now also for Clear and Tinted (generated glass or tint background,
  foreground recoloured by luminance). Clock hands and calendar text are drawn on top of the
  PNG, recoloured like the foreground in Clear and Tinted.

## 0.36.0 · 2026-10-15

- **Added:** `SilicaWindow.exportHandle({viewId})`: the window's identifier for another app
  (`"wayland:<handle>"`, an xdg-foreign v2 export), to pass as the portal's `parent_window`.
  The Open and Save dialogs then open over the window, stay above it and give it the focus
  back when they close. Null outside Silica or with an embedder without `exportHandle`
  (silica-desktop `dialog-parent`).

## 0.35.0 · 2026-10-15

- **Added:** `SilicaWindows.onMainCloseRequested`: asked when the user closes the app's main
  window (Logo+W, the close button), with the same contract as
  `SilicaWindowController.onCloseRequested` (false keeps the window open, true lets it close;
  without it the window closes at once). Needs an embedder that sends `closeRequested` for
  the main window (silica-desktop `main-window-close`); an older one closes it directly.

## 0.34.1 · 2026-10-15

- **Fixed:** `FocusRing` lays its child out with the incoming constraints (`StackFit.passthrough`)
  instead of loose ones, so a field in a tight box fills it. `SilicaSearchField` (toolbar and
  window styles) had its fill, magnifier and text at the top of the capsule instead of centered
  (silica-os/preview#8).
## 0.34.0 · 2026-10-15

Several windows in one app (silica-desktop#146).

- **Added:** `SilicaWindows.openWindow({title, size, builder, minSize, maxSize, kind, parent,
  toolbarHeight})` opens a window of the app's own engine (a child of `parent` when given: Get
  Info, a compose window) and returns a `SilicaWindowController` (`viewId`, `view`, `close`,
  `setTitle`, `setFullSizeContent`, `setSize`, `setSizeLimits`, `onCloseRequested`, `closed`),
  or null where Silica cannot open windows (an app without `--multi-window`, an older embedder,
  tests). `SilicaWindows.open` lists the open windows; `SilicaWindowKind` is `regular` or
  `utility`.
- **Added:** `SilicaWindowHost` builds those windows, each in its own `View`, next to the app's
  content: they share its state and what is above the host (localizations, theme).
- **Added:** `SilicaWindow.setFullSizeContent`, `setSize`, `setSizeLimits`, `setFixedSize` and
  `startMove` take a `viewId` (0, the main window, by default; the argument is left out for it,
  as earlier embedders expect). `WindowDragArea` moves the window it is in.
- **Changed:** `GlassRegistry` sends each window's regions to its own surface: the main window's
  as before (`setRegions`), another window's as `setViewRegions {viewId, regions}`.
  `GlassRegistry.regionsByView` and `GlassRegistry.viewIdOf` are new.
- **Note:** `SilicaWindows` owns the handler of the `silica/window` channel (`closeRequested`,
  `windowClosed`).
- **Changed:** the appearance override is per window: `SilicaWindow.setAppearance` takes a
  `viewId`, a `SilicaAppearanceScope` sends it for the window it is in, and
  `SilicaApp.appearance` (with no scope) goes to every open window, new ones included.

## 0.32.0 · 2026-10-15

App menus in Silica's global menu bar (silica-menu-v1, silica-desktop#25).

- **Added:** `SilicaMenuBar` publishes the app's menus to the bar and binds their shortcuts
  inside the app; `SilicaMenuDelegate` (a `PlatformMenuDelegate` on the embedder's
  `silica/menu` channel, so Flutter's `PlatformMenuBar` works too); `SilicaMenu` (top-level
  `role`, disabled submenus), `SilicaMenuItem` (`checked`, `enabled`, standard `role`,
  `SilicaMenuItem.system` for the items the bar runs); `SilicaMenus.app`, `edit`, `textEdit`,
  `window`, `help`; `silicaMenuShortcuts`, `silicaMenuShortcut`, `silicaMenuKeyName`.
- **Docs:** `docs/app-menus.md`, the adoption guide for apps.

Appearance override, as `NSApp.appearance` / `NSWindow.appearance` on macOS (an always-dark app
such as Clock).

- **Added:** `SilicaAppearance` (`system`, `light`, `dark`), `SilicaAppearanceScope(appearance:,
  child:)` (the window level) and `SilicaApp.appearance` (the app level; the window's wins unless
  it is `system`). Under an override every component, color set and token of the library
  (toolbar, segmented, push buttons, inputs, menus, alerts, window glass...) resolves against it
  instead of `MediaQuery.platformBrightness`, which the scope also overrides for the app's own
  widgets when a `MediaQuery` is above it. Put the scope above the `WidgetsApp` so the overlays
  are under it.
- **Added:** `SilicaAppearance.isDark(context)` / `brightnessOf(context)`, the single place
  that decides the brightness (the library no longer reads `MediaQuery` for it anywhere else).
- **Added:** the override is sent to the embedder (`SilicaWindow.setAppearance`,
  `silica/window` › `setAppearance {appearance}`), which forwards it to Ossido
  (`silica-window-v1` v3 `set_appearance`): traffic lights, plain title bar, shadow, the glass
  the window declares and the arrangement popover follow it. An embedder without the call is
  ignored.

## 0.31.0 · 2026-10-15

Glass regions carry their rotation.

- **Added:** `glassFrame(Matrix4, Rect, double)` and a `frame` key (`transform`, `width`, `height`,
  `radius`) in the region maps of `RenderGlass.region()` and `regions()` (body and tip), sent
  only when the region is rotated, so the compositor can draw rotated glass (silica-glass-v1 v8
  `set_rotation`). The bounding-box keys stay, for older embedders.

## 0.30.1 · 2026-10-15

- **Fixed:** the large `SegmentedControl` (Clock's section switch) pill is ~89 × 28 pt (3 pt
  from the sides of its segment), as in the capture; it was 78.5 pt wide, which is the chord of
  the capsule 2 pt below its top, not its width. The lens is unchanged.

## 0.30.0 · 2026-10-15

Sidebar and content scroll edges as measured (SIDEBAR-GLASS, silica-reference #100); the
provisional behaviour of 0.28.0 is gone.

- **Changed:** `SidebarScrollUnderBar` has no glass: rows scrolled under the top fade out
  (fully visible from +62 pt, 14 % from +32 pt to the window top, as sampled at every 4 pt) with
  a 1 to 2 pt blur, and no tint or line. The first row stays at +52 pt. The window buttons and
  `bar` items sit over the faded rows. The `veil` parameter is kept but has no effect.
- **New:** `SidebarFade` (`visibilityAt`, `blurAt`) exposes the measured fade.
- **Changed:** `ScrollUnderToolbar` is invisible at rest (the content background, no tint or
  line) and becomes a bar as soon as content scrolls under it: dark shows the content at 23 %
  over a 40 lift with a 4.5 pt blur, light is opaque white; both with the 1 pt line. The
  `background` and `columns` parameters are kept but have no effect. `ToolbarVeil.light` and
  `.dark` hold the new values. An inactive window keeps the line but has no veil at rest.
- **No app change needed:** the API is unchanged; Mustache and Mail get the new look as is.

## 0.29.2 · 2026-10-15

Fix: the segmented control's lens refracts the control under it, and the pill and lens are
centred on their segment.

- **Fix (refraction):** with Impeller the lens is now a backdrop filter clipped to the capsule
  (`ImageFilter.shader` with `shaders/glass_lens.frag`), so it refracts the window's own pixels:
  the track, its rim, the pill, the neighbouring labels and the toolbar where it overhangs. The
  shader magnifies 1.11 x, samples further outward towards the rim (none at the centre), blurs
  the rim slightly, splits red and blue on the curved ends and draws the dark outer edge and the
  1 pt light lines. Without shader filters (Skia, tests) the lens keeps the magnified copy of the
  labels. The shader's uniforms changed (`refractionDepth`, `rimBlur`, `lift` replace
  `refractionRim` and `refractionStrength` in `GlassLensMetrics`).
- **Changed:** the segmented lens no longer declares a glass region to Ossido: the compositor's
  glass shows the desktop behind the window, not the control. `GlassLens.material` stays for
  lenses over transparent content.
- **Fix (geometry):** the large control's segments share the whole track, as measured (95, 94,
  95, 94 on 378 pt), and the pill (~80 x 28 pt, `segmentedPillSideInset`) and the lens are
  centred on their segment, the first and last too (they were pushed 4 pt inward by an end
  inset). The window sizes are unchanged. The toolbar capsule pills of #89 are unchanged.
- **Fix:** the lens paints in the nearest `Overlay` (`OverlayPortal`), so it passes the control's
  edges (6 pt above and below, past the ends on narrow segments) without being clipped by the
  toolbar or covered by neighbours; without an overlay it paints in place, unclipped.
- **New:** `GlassLens.usesBackdrop`, `RenderGlassLensBackdrop`, `segmentedPillSideInset`;
  `GlassLens.content` is optional. For tests: `GlassLens.debugRefractionSupportedOverride`,
  `debugShaderFilter`, `debugReset`.

## 0.29.1 · 2026-10-15

Fix: the segmented control's lens showed the covered label twice.

- **Fix:** while the lens is up, the original labels are clipped out where the lens covers them
  (they were still painted under the clear lens, offset from its magnified copy, so "Alarms"
  appeared doubled). The lens now shows only the magnified content, as on macOS. The paint order
  is unchanged and checked by tests: track (with its rim), pill, labels, lens.

## 0.29.0 · 2026-10-15

Glass profiles (silica-desktop#168, silica-glass-v1 version 7) and the measured segmented-control
lens (LENS, silica-reference #92).

- **New:** `GlassProfile` (`menu`, `panel`, `module`, `control`, `dock`, `tooltip`, `sheet`,
  `banner`), `Glass.profile`, `LiquidGlass.profile`: the kind of surface, so Ossido picks that
  kind's blur, refraction, edge light, tint and shadow. Null (the default) leaves the choice to
  the material, as before. Sent on the `silica/glass` channel as the region's `profile` key.
- **New:** `Glass.profileShadow`, `LiquidGlass.profileShadow` (the `shadow` key): Ossido draws the
  profile's shadow under the glass. Off by default.
- **Changed:** `MenuPanel` declares `GlassProfile.menu`, `Alert` `GlassProfile.sheet`, and the
  segmented lens `GlassProfile.control`. (The toolbar capsules are not glass regions in this
  library, so they declare nothing.)
- **Changed (lens):** the pressed lens is the measured one. A capsule 91 x 48 pt, 6 pt past the
  track at the top and bottom (`GlassLensMetrics.width`, `overhang`), magnifying 1.11 x. It is
  nearly transparent: a dark outer edge, a 1 pt light line inside the top and bottom, faint
  colour fringes on the curved ends (`GlassLensStyle.fringeWarm` / `fringeCool`) and, with the
  shader, a small chromatic offset there (`GlassLensMetrics.chromaticOffset`, a new `uChroma`
  uniform). Light and dark are the same (`GlassLensStyle.clear`).
- **Changed (lens timing):** press on the selected segment, the lens shows at ~+120 ms and is full
  at ~+240 ms with a small overshoot. Press on another segment, the pill starts to slide at
  +28 ms, turns into the lens on the way and arrives at ~+400 ms (settled by ~+500 ms). The
  springs are replaced by the measured curves (`appearCurve`, `appearTravelCurve`,
  `travelCurve`, `KeyframeCurve`).
- **Changed (lens drag):** the lens follows the pointer continuously (not segment to segment),
  clamped between the first and last segment centres; releasing inside chooses the segment under
  it (the content changes after the release only) and the lens retracts in 130 ms; releasing
  outside cancels (lens 100 ms, pill back in 200 ms). Hover stays instant.
- **Removed:** `GlassLensMetrics.widthScale`, `heightScale`, `travelSpring`, `appearSpring`,
  `disappearSpring`; `glassLensRect` takes the lens size instead. The *provisional* marks on the
  lens are gone (not the stretch of the pill while it accelerates, which is not drawn).

## 0.28.2 · 2026-10-15

- **Fix:** the segmented control's pressed lens is clear Liquid Glass, not a solid body: it
  declares a `GlassMaterial.regular` region to Ossido (`GlassLens.material`) with a transparent
  fill, over the magnified content, the edge refraction, the rim and the shadow. The solid pill
  fades out as the lens swells and back in as it shrinks. Without the shader (Skia) only the
  magnified content shows. *Provisional:* the material and the clear fill (`GlassLensMetrics.material`,
  `GlassLensMetrics.clearFill`) await the LENS measurement (silica-reference #92); the pill at
  rest keeps its measured colours.

## 0.28.1 · 2026-10-15

- **Fix:** a press on a control in the toolbar (segmented controls, buttons, search fields) no
  longer moves the window. `WindowDragArea` starts a move only when the press hits no interactive
  widget, decided by hit-testing at the press.

## 0.28.0 · 2026-10-15

The full-height sidebar scrolls under a glass bar of its own, and the toolbar glass no longer
draws a colour band over the content (mustache#13, mail#7, #87). Behavior changes (minor version
in 0.x).

- **Toolbar band (#87):** `ScrollUnderToolbar.background` (the content colour under the band) and
  `ScrollUnderToolbar.columns` (`ToolbarVeilColumn`: columns with different backgrounds, such as
  a list and a reader). Given, in an active window the bar shows that colour unchanged: the veil
  is anchored to it (`ToolbarVeil.anchoredTo`, `ToolbarVeil.anchor`), the content scrolled under
  it is still blurred and tinted. In an inactive window the plain veil stays (the measured
  `#2f2f30` over `#272728`). Without a background nothing changes, as under a column header.
  *Provisional:* the anchoring fits the measured active bar (same colour as the content); it is
  not measured on scrolled content over a non-white background (SIDEBAR-GLASS requested).
- **New:** `SidebarScrollUnderBar`: a full-height sidebar whose top `toolbarHeight` is a bar of
  its own (the window buttons sit on it, it moves the window, optional items), with the list
  starting below the bar and scrolling under it behind the veil, anchored to the sidebar colour.
  *Provisional:* the sidebar's veil is the content's, no line under the bar.
- **New:** `SidebarLayout`: the sidebar and the content side by side, with the sidebar sliding out
  while hidden (`shown`), and `SidebarLayout.contentLeadingInset` for the toolbar items to clear
  the window buttons.
- **New:** `ToolbarVeilLayer.name`: the key of its filters ('toolbar veil' by default).
- **New:** `windowButtonsRight` (79): the right edge of the third window button on a 52 pt bar.

## 0.27.0 · 2026-10-15

The segmented control's glass lens (#88) and evenly inset selection pills (#89). Behavior changes
(minor version in 0.x).

- **Lens (#88, provisional):** while a `SegmentedControl` in `selectOne` is pressed, the selection
  swells into a glass lens that magnifies the labels under it (1.3×), travels on a spring with a
  slight overshoot to the enabled segment under the pointer while dragging, and shrinks back into
  the pill on release. On by default for `ControlSize.large` (Clock's section switch), off below.
  - **Release chooses the segment under the lens** (inside the control); released outside, nothing
    is chosen and the pill returns. Without the lens, a press still acts only on the segment it
    started on.
  - The pill moves on mouse-down with the lens (measured: it starts 25–52 ms after the press).
  - **Reduced motion:** the lens appears, jumps and disappears at once; the pill's move between
    segments (keyboard, app changes) is also immediate now.
- **New API:**
  - `SegmentedControl.lens` (`bool?`, null: by size) and `SegmentedControl.hasLens`.
  - `GlassLens`: a reusable lens widget that shows any content magnified inside a capsule, with
    edge refraction by a fragment shader (`shaders/glass_lens.frag`) where shader image filters
    are supported (Impeller), magnification only elsewhere. `GlassLens.refractionSupported`,
    `GlassLens.loadProgram`, `GlassLens.shaderAsset`.
  - `GlassLensStyle` (light / dark), `GlassLensPainter`, `GlassLensMetrics` (size,
    magnification, springs, refraction; provisional), `glassLensRect`.
  - `ToolbarGlassMetrics.pillInset`.
- **Toolbar selection pill (#89):** in the first and last segment of a segmented group the
  selection (and hover) pill keeps 5 pt from the capsule's round end, as from its top and bottom
  (it was centred on the segment, 4 pt from the end); middle segments unchanged.

## 0.26.0 · 2026-10-15

The toolbar glass controls as measured (TITLEBAR-GLASS, #86): back/forward, segmented groups and
view selectors, single round buttons, toolbar menu buttons and the search button. Behavior changes
(minor version in 0.x).

- **Hover:** a round highlight on the segment under the pointer, fading in and out in ~170 ms
  (it used to appear in one frame).
  - Button pairs (`separators: true`) use a 28 pt circle; segmented groups a pill the size of the
    selection (segment width − 6, 28 tall); single buttons light as a whole.
  - The neighbouring separators hide. Disabled segments get no highlight.
- **Press:** the whole capsule grows 1 pt per side in 45 ms (it used to jump) and stays grown
  while held, also with the pointer outside; disabled segments grow too.
  - **Release outside:** a spring back in ~100 ms with a ~10 % undershoot.
  - **Click:** the pressed size is held 100 ms after mouse-up, then back in 40 ms. The action
    still fires on mouse-up.
- **Pressed glow (dark):** a light spot on the pointer (`ToolbarColors.glow`, Gaussian σ 26 pt),
  clipped to the capsule. It follows the pointer with a 30 ms lag, shows on disabled segments,
  and fades with the distance outside the bounds. Light: not drawn.
- **Held groups:** the capsule tracks the pointer for all its segments. The highlight jumps to
  the enabled segment under the pointer and goes off at the capsule edge. **Releasing over
  another enabled segment acts on that segment**: before, only the pressed segment could act.
- **Reduced motion** (`MediaQuery.disableAnimations`): fades, growth and springs are immediate;
  the glow follows without lag.
- **The selection pill** is 34 × 28 on a 40 pt segment (segment width − 6; it was width − 3).
- **Disabled segments:** no pill on press (`ToolbarColors.disabledPressed` is no longer drawn,
  kept for API stability).
- **New API:**
  - `ToolbarCapsule.highlight` (`ToolbarHighlight.circle` / `.selection`; default by `separators`).
  - `ToolbarSegment.onLongPressMenu(Rect)`: the long press with the segment's global rect across
    the capsule height, so the history menu opens at `rect.bottomLeft`.
  - `ToolbarGlassMetrics`: the measured sizes and timings.
  - `ToolbarGrow`: paints a child grown by n pt per side.
  - `ToolbarGlowPainter`: the pressed glow.
  - `ToolbarColors.glow`: an optional constructor argument, transparent by default.
- **Moved:** `ToolbarCapsule`, `ToolbarSegment`, `toolbarLongPress` and the `capsuleRim*`
  constants moved from `src/window.dart` to `src/toolbar.dart`. The `package:silica_ui/silica_ui.dart`
  export is unchanged.
- **Breaking for direct use:** a `ToolbarSegment` outside a `ToolbarCapsule` no longer reacts to
  the pointer.
- **Narrow toolbars:** silica_ui has no toolbar layout widget. The overflow "»" button and the
  collapsed view selector are documented in `docs/spec/toolbar.md` › Narrowing and in
  `src/toolbar.dart`.

## 0.25.0 · 2026-10-14

- **Menus stay on screen:** `MenuHost` places the open levels inside its area and places them
  again on every layout.
  - A menu that does not fit on the right opens to the left of the anchor, its right edge at the
    pointer.
  - A menu that does not fit below shifts up, keeping `MenuMetrics.edgeMargin` (5 pt,
    provisional) from the edge, and never goes above `top` plus the margin.
  - Submenus flip to the left of their parent (5 pt overlap) and shift up.
  - Tip menus (Dock, popovers) only clamp horizontally.
- `MenuHost.top`: the bottom of the menu bar (default 0), the upper bound for shifted menus.
- `placeMenu` and `placeSubmenu`: the placement as pure functions.
- **Fix:** `withoutFilters` keeps the mask, clip-path and transform of the blurred shapes it
  rewrites, so glows stay inside their mask (209a7ab).

## 0.24.0 · 2026-10-14

The measured control gallery (INV-B, INV-D) replaces most provisional values, and the app
lifecycle comes in.

- **Accents:** `SilicaAccent` (9 measured accents, light and dark) with `AccentColors`,
  applied through `ControlAccent.palette`.
- **Focus ring:** the accent's ring colour, 3 pt outside the control.
- **Inactive windows and pressed states:** accents turn grey in inactive windows; pressed is
  one step darker; no hover fills.
- **Buttons, toggles and segmented controls:**
  - push buttons are capsules 28/24/20/16 pt;
  - checkboxes and radios 16/14/12;
  - switches 64×28 to 36×16;
  - segmented controls get an accent pill below the large size.
- **Inputs and indicators:**
  - slider, progress bar and stepper take the measured values;
  - the spinner has 8 spokes;
  - the calendar marks the selected day with a grey square;
  - the colour well and the level indicator take the measured values.
- **Tooltips:** appear after 1.54 s, move to a neighbour in 240 ms, fade out in 450 ms.
- **`SilicaApp` and `SilicaAppWindow`:** the measured app lifecycle (silica-desktop#142).
  Closing the last window keeps the app running, a reopen builds a new window, and
  single-window apps quit with their window.

## 0.23.2 · 2026-10-14

The measured tip outline (TIP-01), as Ossido now draws it.

- `TipOutline`: the outline from its four measured parameters (flank angle, apex radius, fillet
  radius, depth), with the presets `menu`, `popover` and `popoverSide`.
- Menu tip: `MenuMetrics.tipBase` 24 → 31 (depth 10), so Ossido picks the Dock-menu outline; the
  menu shadow cut-out follows the same outline instead of the per-row widths.
- Popovers: tip 32 × 11 on the top and bottom edges (`tipBase`, `tipDepth`), 39 × 12 on the sides
  (`sideTipBase`, `sideTipDepth`); `popoverPath` draws the measured outline and `placePopover`
  keeps the side tip's depth from the anchor.

## 0.23.1 · 2026-10-14

- `ScrollUnderToolbar.showLine`: false when the content draws its own line under the band
  (a column header).
- `ScrollUnderToolbar.scrollPredicate`: which scrollables move the line;
  `anyVerticalScrollUnderPredicate` for nested lists (column views, a list that also scrolls
  sideways). The default stays the vertical scrollable at depth 0.

## 0.23.0 · 2026-10-14

The controls of milestone M6 (UI components 1:1). Values not measured yet are marked
provisional in the code and will change once measured.

- **Glass toolbar over scrolling content** (silica-ui#2): `ScrollUnderToolbar(toolbar, body:
  (context, padding) => …, header, active)` lets the body scroll under the 52 pt toolbar band
  behind the measured veil (`ToolbarVeil.light` / `.dark`, two blurs), with the 1 pt line once
  the content has scrolled (always in an inactive window); toolbar capsules over content get a
  blurred rim (provisional, no refraction yet).
- **Buttons and toggles**: `SilicaButton` (normal, primary, destructive; push, bevel,
  borderless, circle bezels; mini to large), `HelpButton`, `ToggleButton`, `ImageButton`,
  `DisclosureTriangle`, `DisclosureButton`, `SilicaCheckbox` (with the mixed state),
  `SilicaRadio` and `SilicaRadioGroup`, `SilicaSwitch`, `SegmentedControl` (select one, any,
  momentary), `PopUpButton`, `PullDownButton`, `ComboBox`.
- **Inputs and indicators**: `SilicaTextField` (secure, with the caps lock sign),
  `SilicaSearchField` (recents, tokens, clear), `SilicaTokenField`, `SilicaStepper`,
  `SilicaSlider` (ticks, labels) and `SilicaCircularSlider`, `SilicaDateField`,
  `SilicaCalendar`, `SilicaClockFace`, `SilicaColorWell` and `SilicaColorPicker`,
  `SilicaLevelIndicator` (continuous, discrete, rating), `SilicaProgressBar` (determinate and
  indeterminate), `SilicaSpinner`, `SilicaProgressRing`.
- **Containers and navigation**: `SourceList` (sections, nesting, badges), `TableView` (sorting,
  resizable columns, striping, outline mode), `CollectionView`, `SilicaScrollbar` and
  `SilicaScrollBehavior` (overlay and legacy scrollers), `SplitView` (sidebar behaviour,
  dividers, collapse), `WindowTabBar` and `SilicaTabView`, `PathControl`, popovers on all four
  edges (`PopoverAnchor`, `PopoverPanel`), `showWindowSheet`, `FloatingPanel` (utility, HUD),
  `SilicaTooltip`, `ToolbarCustomizeSheet`.
- **Shared base**: `ControlPalette` (accent, focus ring colors, the inactive-window gray),
  `WindowActiveScope` (with `.follow` for the app lifecycle; it falls back to `ToolbarScope`),
  `FocusRing`, `ControlAccent`, `ChevronPainter`. Every control works light and dark, in active
  and inactive windows, with the keyboard and with semantics; visible texts are parameters.
- The example is now the catalog app: every group next to each other, light/dark and window
  state switches, plus the Liquid Glass lab.

## 0.22.0 · 2026-10-14

- **API change**: `GlassTip.up` becomes `GlassTip.edge` (`TipEdge.bottom`, `top`, `left`,
  `right`); `up` stays as a getter. Side tips need Ossido with silica-glass-v1 version 6
  (`add_side_tip`): a popover beside its control.
- The menu tip is the measured drop: 24 pt base, 10 pt deep (glass widths per row 24 20 18 16
  14 12 10 8 6 2, drawn by Ossido); the menu position is unchanged (body 8 pt above the anchor).
  The shadow cut-out follows the same drop.

## 0.21.0 · 2026-10-14

- `SilicaWindow.setSize`, `setSizeLimits`, `setFixedSize`: the app chooses its window size and
  the resize limits (min = max: a fixed-size window, the zoom button disabled by Ossido). They
  need the silica-desktop embedder with the `setSize` / `setSizeLimits` window calls.

## 0.20.0 · 2026-10-14

- The calendar icon writes the month in the language of the window (`Localizations`, or the
  platform locale): English by default, Italian when the system is Italian. Before it was
  always Italian.

## 0.19.3 · 2026-10-14

- Everything in English: comments, tests, changelog. Internal widget keys renamed:
  `'pillola'` → `'pill'`, `'menu nella finestra'` → `'in-window menu'`, `'avviso pieno'` →
  `'solid alert'`, `'avviso <label>'` → `'alert <label>'` (tests that look them up must follow).

## 0.19.2 · 2026-10-14

- `SilicaIcon`: files, folders, volumes and Trash have a ground shadow under the shape of the
  drawing (icons.md IC-01: at 128 opacity 0.28, σ 2.7, 1.2 pt down; `IconShadow`).
  silica-icons draws them flat and leaves the shadow to whoever shows them.

## 0.19.1 · 2026-10-14

- `ToolbarSegment` keeps tap and drag to itself: a click or a drag starting on a control does
  not move the window (`WindowDragArea`), as before 0.19.0 (MU-08).

## 0.19.0 · 2026-10-14

- Toolbar control states (mustache.md M6 › MU-07): a 28 pt high pill (the segment width − 3;
  for buttons with their own capsule, the capsule − 2) on hover, darker on press with the
  capsule +1 pt per side; chosen segment at rest, hovered and pressed; disabled ones without
  a pill (in dark a faint pill on press); separators hidden next to the segment under the
  pointer. The click acts on release, inside the segment.
- `ToolbarSegment.onLongPress` (after `toolbarLongPress`, 295 ms: the release does not act) and
  `onPress` (on press, for buttons with a menu).
- `ToolbarScope(active:, hovered:)`: inactive window (capsule and glyph dimmed, hovering lights
  them up again) and pointer in the bar (in dark the capsules +7 levels).
- **API change** in `ToolbarColors`: `fill`, `fillBarHover`, `fillInactive`, `hover`,
  `pressed`, `chosen*`, `icon*` instead of `fillTop`/`fillBottom`/`chosenTop`/`chosenBottom`.

## 0.18.0 · 2026-10-14

- `WindowGlass` and `WindowGlassMaterial`: glass inside a window, made by Flutter (blur σ 9 and
  the thick material matrix, light and dark, the same as Ossido's) over the app content, where
  the compositor glass does not reach.
- `MenuPanel.opaque` / `MenuHost.opaque`: the in-window menu is now glass (`WindowGlass`)
  instead of a solid fill. **API change**: `MenuColors.opaqueFill` removed.

## 0.17.0 · 2026-10-14

- **Drawing change** for the icons of files, folders, volumes and Trash (silica-icons 0.2,
  icon-format.md › "Principle"): `side` is the whole canvas, no longer the app body.
  The `min_size` bands of labels, folder symbols and badges are compared with the canvas
  side; badges stay in the box between the app body (100…924) and the golden line.
- `SilicaIcon.besideApps`: a place next to the apps (Dock) keeps `side` as its body and the
  app canvas around it. `canvasExtent` gives the canvas side.

## 0.16.0 · 2026-10-14

- `SilicaDrag` (the embedder's `silica/drag` channel): Ossido's drag and drop between apps.
  `start(paths, icon:)` carries a list of files (`text/uri-list`) out of the window with the
  image on the pointer; `events` gives enter, motion, leave and drop (`SilicaDrop` with the
  URIs and the paths) of files dragged from other apps, and the end (`SilicaDragFinished`:
  `copy`, `move`, `none`) of those that left from here.

## 0.15.1 · 2026-10-14

- `SilicaIcon`: without `dark` the icon is always the light one. The dark variant belongs to
  the icon style (a separate setting), not to the system appearance: in dark appearance the
  icons of apps and files stay the same (icons.md IC-01, silica-reference MU-20).

## 0.15.0 · 2026-10-14

- Dark appearance from the system (`MediaQuery.platformBrightness`, which the embedder
  receives from the settings portal).
- **API change**: `ToolbarColors` and `MenuColors` are no longer static constants but `light`
  / `dark` instances, with `of(context)` following the system appearance
  (`ToolbarColors.title` → `ToolbarColors.of(context).title`). `MenuColors.highlight` and
  `highlightText` stay static: they are the same in both appearances.
- Dark toolbar: fill `#4c4c4c` → `#535454`, pill `#595959`, icons and title `#e9e9e9`
  (mustache-spec 1.2).
- Dark menus: white text at 85 %, disabled at 26 %, shortcuts at 30 %, separator at 14 %;
  the solid fill `#353536` (menubar.md).

## 0.14.0 · 2026-10-14

- `GlassTip.up`: the glass tip pointing up, on the top edge (silica-glass-v1 version 5,
  `add_upward_tip`).
- `MenuHost.tipUp` / `MenuPanel.tipUp`: a menu under the tip, pointing at the button it opens
  from (the window arrangement popover).

## 0.13.1 · 2026-10-14

- Menus: a header (`MenuSection`) counts in the width as a 13 pt item and is aligned with the
  item text (at 29 with checkmarks), as in the Dock stack menu (silica-reference SH-DK-25: 220 pt).

## 0.13.0 · 2026-10-14

- `SilicaWindow` (`silica/window` channel): `setFullSizeContent(toolbar)` asks Ossido for
  full-size content (the window buttons over the app's bar), `startMove()` moves the window.
- `WindowDragArea`: the empty part of the toolbar moves the window.
- `ToolbarCapsule`, `ToolbarSegment`, `ToolbarColors`: the capsules of the unified toolbar
  (38 high, radius 19, chosen segment as a 34 × 28 pill).

## 0.12.0 · 2026-10-13

- `MenuCustom`: a menu row drawn by whoever opens the menu (`height` high, at least `width`
  wide), with the function that closes the menu: the row of tag circles.

## 0.11.1 · 2026-10-13

- silica-icons step 0b: if the type comes only from the name and `globs2` gives several types
  with the same weight (`.ts`), the extension map decides first. `MimeDatabase.isAmbiguousName`.

## 0.11.0 · 2026-10-13

- Type icons write the real extension (silica-icons `file-type-label`): box, size, light and
  dark color, `no_extension`, no label below `min_size`.
- `icons.mime` accepts `{icon, category}`: the generic file with that category (the extension
  override still comes first). Step 0: the type becomes canonical through the aliases.
- `FileIcon`: `labelBox`, `labelSize`, `labelWeight`, `labelMinSide` instead of `rules`. The
  label uses the natural line of Inter, centered in the box.

## 0.10.0 · 2026-10-13

- `MenuHost.opaque` and `MenuPanel.opaque`: solid menus (`#fcfcfd` with a hairline) instead of
  glass, for context menus drawn inside an app window (until the embedder has popups).

## 0.9.1 · 2026-10-13

- `resolveFileIcon`: an `icons.mime` entry leading to the generic file (`application/json`)
  draws it with the label and the category color, as in step 5.

## 0.9.0 · 2026-10-13

- `MimeDatabase`: the MIME type of a file from shared-mime-info (`globs2` globs with weights
  and case, `subclasses`, `aliases`) and, if the name is not enough, from the content (ELF,
  scripts with `#!`, text or binary).
- `resolveFileIcon` and `FileSource`: the icon of a file in silica-icons order (type, type with
  `*`, parents, extension, generic file with the extension written in the category color,
  sheet with the question mark); an executable without an extension takes `file-executable`.
  The map is the one in the generic file manifest (`FileLabelRules`).
- Badges (`IconBadge`, `SilicaIcon.badges`, `badgesOf`, `visibleBadges`): alias at the bottom
  left, on the right the first of unreadable, locked, cloud; from 16 to 31 pt just one, below
  16 none; dark variants.
- Volumes: `volumeIconId` (network, disk image, optical, external, internal),
  `parseMountinfo`, `blockRemovable`.

## 0.8.1 · 2026-10-13

- `SilicaAlert.opaque`: solid background (white or `#272727`, outer hairline, shadow) instead
  of glass, for an alert drawn inside a window: there the compositor glass would sit under the
  content and would not show. The normal button becomes `#e8e8e8`.

## 0.8.0 · 2026-10-13

- `SilicaAlert`: the system alert (292 pt, thick glass, 66 icon, bold title, 30 pt high buttons
  stacked full width or side by side), with the `AlertRole` roles (blue default, cancel,
  pinkish destructive); Return chooses the default, Esc the cancel one (or the only button).

## 0.7.1 · 2026-10-13

- `fileIconId(name)` and `fileIconFor(name)`: the silica-icons icon of a file from its
  extension (previously in the shell's Dock). A hidden file without an extension (`.bashrc`)
  is `file-unknown`.

## 0.7.0 · 2026-10-13

- The silica-icons icons move here from the shell, for the apps (Mustache) and the shell:
  `SilicaIcon` (formerly the shell's `ShellIcon`) with `LayeredSource`, `FolderSource`,
  `FlatSource`; the manifest (`parseManifest`, `findSilicaIcon`, `silicaIconDirs`), the generic
  folder with symbol and tint (`resolveFolderIcon`, `FolderIcon`) and the special folders
  (`xdgUserDirs`, `specialFolderKey`, `xdgDataDirs`). `iconBodyPath`: the body superellipse.
- New dependency: `flutter_svg`.

## 0.6.0 · 2026-10-13

- `Glass.group` and `LiquidGlass.group`: glass merges only with glass of the same group, and a
  higher group sits on top. Every menu level has its own: the submenu is a distinct panel over
  the parent menu, not a single shape with it.
- `Glass.tip` (`GlassTip`): a tip that is part of the glass shape, with a rounded apex and
  sides joined to the body. The Dock menu tip is no longer a triangle painted over the glass;
  the menu shadow does not fall on the tip.
- Removed `MenuColors.tipFill` and `MenuColors.tipLine` (no longer needed).
- Requires silica-glass-v1 version 4 (Ossido); with an older compositor groups are ignored and
  there is no tip.

## 0.5.1 · 2026-10-13

- `MenuHost`: when `tip` or `anchor` change (the surface hosting the menu stretches) the open
  menus move with them; before they stayed where they were.

## 0.5.0 · 2026-10-13

- `MenuHost.onRectsChanged`: the rectangles of the open menus, after the frame in which they
  change (a submenu opening or closing), so that whoever hosts the menu can widen its input
  region. Without it, on a surface with an input region the submenu did not get the pointer.

## 0.4.0 · 2026-10-13

- `MenuHost.tip` and `MenuPanel.tipX`: a menu pointing at an object below it (the Dock icons)
  has a tip 8 pt high and 22 wide at the base, with the body 27 pt to the left of the apex.

## 0.3.2 · 2026-10-13

- `MenuHost.handlesPointer`: false to pass the pointer from outside (`pointerMoved`,
  `pointerDown`, `pointerUp`, `contains`), like a bar where you press on an item and release
  on a menu item.

## 0.3.1 · 2026-10-13

- Same as 0.3.0 (tag published by mistake without the intended change).

## 0.3.0 · 2026-10-13

- Menus: `MenuHost` (a menu with its submenus in an area that contains it), `MenuPanel`, the
  `MenuAction` items (shortcut, checkmark, icon, submenu, disabled), `MenuDivider` and
  `MenuSection`; `menuSize` and `menuRowTops` to place them. 24 pt items, 11 pt separators,
  blue highlight, thick glass with the shadow outside the panel; submenus after ~295 ms with
  triangle tolerance; ↑ ↓ → ← Return Esc and letters; the choice blinks and the menu fades in
  ~190 ms.

## 0.2.0 · 2026-10-13

- Glass carries the ancestors' opacity (`Opacity`, `FadeTransition`, `AnimatedOpacity`): the
  region sent to the compositor has an `opacity` field (0–1) and Ossido composes the glass
  fading together with the panel (`silica-glass-v1` version 3). With an older compositor the
  glass stays solid.

## 0.1.0 · 2026-10-13

First version as a standalone package (previously in `silica/packages/silica_ui`).

- `uiFontFamily` and `uiText`: Inter Regular and SemiBold.
- `Glass` and `GlassMaterial` (`clear`, `thick`, `regular`, `notification`) on the
  `silica/glass` channel.
- `LiquidGlass`: press, release with bounce, highlight following the pointer.
- `GlassRegistry` checks the regions at every frame: glass under an ancestor changing
  transform or opacity follows even without repainting.
- `example/`: the glass lab.
