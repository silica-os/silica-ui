/// The Silica design system for Flutter.
library;

import 'package:flutter/widgets.dart';

export 'src/alert.dart';
export 'src/amalfi/amalfi.dart';
export 'src/appearance.dart' show SilicaAppearance, SilicaAppearanceScope;
export 'src/app.dart';
export 'src/share.dart';
export 'src/thumbnails.dart';
export 'src/controls/buttons/buttons.dart';
export 'src/controls/containers/containers.dart';
export 'src/controls/control_base.dart';
export 'src/controls/inputs/inputs.dart';
export 'src/drag.dart';
export 'src/glass.dart';
export 'src/glass_lens.dart';
export 'src/icons/silica_icon.dart'
    show
        SilicaIcon,
        IconSource,
        LayeredSource,
        FlatSource,
        ServiceSource,
        IconShadow,
        iconBodyPath;
export 'src/icons/file_icons.dart';
export 'src/icons/mime.dart';
export 'src/icons/silica_icons.dart';
export 'src/liquid_glass.dart';
export 'src/menu.dart';
export 'src/menu_bar.dart';
export 'src/tip_outline.dart';
export 'src/toolbar.dart';
export 'src/amalfi/components/popup_presenter.dart' show showAmalfiAsPopup;
export 'src/popups.dart'
    show
        SilicaPopupAdjust,
        SilicaPopupController,
        SilicaPopupEdge,
        SilicaPopupScope,
        SilicaPopups;
export 'src/window.dart';
export 'src/window_glass.dart';
export 'src/windows.dart';

/// The interface font: Inter (OFL), served by the package.
const String uiFontFamily = 'Inter';

/// A text style in Inter, served by this package.
TextStyle uiText({required double size, required Color color}) => TextStyle(
  fontFamily: uiFontFamily,
  package: 'silica_ui',
  fontSize: size,
  color: color,
);
