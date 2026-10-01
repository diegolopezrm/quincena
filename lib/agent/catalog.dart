import 'package:genui/genui.dart';

import '../genui_catalog.g.dart';

/// Everything the agent may compose with.
///
/// The generated catalog is the app's own components and functions, derived
/// from their constructors and signatures by `genui_gen`. Added to it are
/// genui's `Text`, for the odd line no component covers, and genui's basic
/// functions, because the `checks` an agent writes call `required` and
/// `numeric`, and those live there.
final Catalog quincenaCatalog = genUiCatalog.copyWith(
  newItems: <CatalogItem>[BasicCatalogItems.text],
  newFunctions: BasicCatalogItems.asCatalog().functions.toList(),
);
