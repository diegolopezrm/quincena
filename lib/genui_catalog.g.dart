// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// coverage:ignore-file

import 'package:genui/genui.dart';

import 'catalog/account_choice.dart';
import 'catalog/action_button.dart';
import 'catalog/answer.dart';
import 'catalog/big_amount.dart';
import 'catalog/budget_meter.dart';
import 'catalog/category_choice.dart';
import 'catalog/goal_planner.dart';
import 'catalog/group.dart';
import 'catalog/headline.dart';
import 'catalog/insight.dart';
import 'catalog/money_field.dart';
import 'catalog/month_bars.dart';
import 'catalog/movement_list.dart';
import 'catalog/spending_donut.dart';
import 'catalog/stat_tile.dart';
import 'catalog/subscription_list.dart';
import 'catalog/subscription_row.dart';
import 'catalog/suggestions.dart';
import 'catalog/text_entry.dart';
import 'catalog/tiles.dart';
import 'functions/money_functions.dart';

/// Every [CatalogItem] generated in this package, by name.
///
/// Rebuilt whenever a `@GenUiWidget` is added, renamed or
/// removed, so a catalog composed from it cannot fall behind
/// the widgets it is meant to describe.
final List<CatalogItem> genUiCatalogItems = <CatalogItem>[
  accountChoiceCatalogItem,
  actionButtonCatalogItem,
  answerCatalogItem,
  bigAmountCatalogItem,
  budgetMeterCatalogItem,
  categoryChoiceCatalogItem,
  goalPlannerCatalogItem,
  groupCatalogItem,
  headlineCatalogItem,
  insightCatalogItem,
  moneyFieldCatalogItem,
  monthBarsCatalogItem,
  movementListCatalogItem,
  spendingDonutCatalogItem,
  statTileCatalogItem,
  subscriptionListCatalogItem,
  subscriptionRowCatalogItem,
  suggestionCatalogItem,
  suggestionsCatalogItem,
  textEntryCatalogItem,
  tilesCatalogItem,
];

/// Every [ClientFunction] generated in this package, by
/// name.
///
/// These are the other half of a catalog: what the model
/// computes a value with, through the `{"call": ...}` form
/// any bound property accepts.
final List<ClientFunction> genUiCatalogFunctions = <ClientFunction>[
  arrivalMonthGenUiFunction,
  arrivesByGenUiFunction,
  moneyGenUiFunction,
  monthlyNeededGenUiFunction,
  percentChangeGenUiFunction,
  savingsIfCancelledGenUiFunction,
];

/// Every generated [CatalogItem] of this package, as a
/// [Catalog] ready to hand to genui.
///
/// Compose it with any other catalog through
/// [Catalog.copyWith], for instance to add genui's own
/// basic components:
///
/// ```dart
/// final catalog = genUiCatalog.copyWith(
///   newItems: BasicCatalogItems.asCatalog().items.toList(),
///   newFunctions: BasicCatalogItems.asCatalog().functions.toList(),
/// );
/// ```
final Catalog genUiCatalog = Catalog(
  genUiCatalogItems,
  functions: genUiCatalogFunctions,
  catalogId: 'dev.dlsoft.quincena',
);
