// Every page of the Amalfi gallery, in the order of the checklist. A family edits only its
// own file under `pages/`.

import 'pages/alerts.dart';
import 'pages/buttons.dart';
import 'pages/dialogs.dart';
import 'pages/disclosure.dart';
import 'pages/fields.dart';
import 'pages/forms.dart';
import 'pages/group_boxes.dart';
import 'pages/lists.dart';
import 'pages/menus.dart';
import 'pages/popovers.dart';
import 'pages/progress.dart';
import 'pages/scrollbars.dart';
import 'pages/segmented.dart';
import 'pages/sheets.dart';
import 'pages/sidebars.dart';
import 'pages/sliders.dart';
import 'pages/status_bar.dart';
import 'pages/steppers.dart';
import 'pages/titlebars.dart';
import 'pages/toggles.dart';
import 'pages/tooltips.dart';
import 'pages/wells.dart';
import 'pages/windows.dart';
import 'specimen.dart';

/// The gallery pages.
final List<AmalfiGalleryPage> amalfiGalleryPages = [
  buttonsPage,
  segmentedPage,
  togglesPage,
  fieldsPage,
  menusPage,
  popoversPage,
  tooltipsPage,
  slidersPage,
  steppersPage,
  progressPage,
  scrollbarsPage,
  sidebarsPage,
  listsPage,
  disclosurePage,
  groupBoxesPage,
  formsPage,
  titlebarsPage,
  windowsPage,
  alertsPage,
  dialogsPage,
  sheetsPage,
  wellsPage,
  statusBarPage,
];
