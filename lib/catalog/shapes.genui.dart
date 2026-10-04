// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'shapes.dart';

// **************************************************************************
// GenUiDataGenerator
// **************************************************************************

/// Generated schema for [CategorySlice].
final ObjectSchema categorySliceGenUiSchema = ObjectSchema(
  description:
      'How much went to one spending category in a period. A list '
      'of these is what a SpendingDonut draws.',
  properties: {
    'category': S.string(
      description: 'The spending category.',
      enumValues: [
        'housing',
        'groceries',
        'restaurants',
        'transport',
        'utilities',
        'subscriptions',
        'health',
        'shopping',
        'leisure',
        'debt',
        'other',
      ],
    ),
    'amount': S.number(
      description:
          'Pesos spent on it in the period, as a positive whole number.',
    ),
  },
  required: ['category', 'amount'],
);

/// Decodes a [CategorySlice] from the map the model produced.
///
/// Values are coerced the same way genui's `Bound*` widgets coerce a
/// widget property, so a field of the wrong type degrades instead of
/// throwing. Every required field that had to fall back is reported
/// through [onMissing], when one is given.
CategorySlice categorySliceFromGenUiJson(
  Map<String, Object?> json, [
  GenUiMissingFieldReporter? onMissing,
]) => CategorySlice(
  category:
      Category.values.asNameMap()[genUiAsString(json['category'])] ??
      genUiMissingField<Category>(onMissing, 'category', Category.values.first),
  amount:
      (genUiAsNum(json['amount']) ??
              genUiMissingField<num>(onMissing, 'amount', 0))
          .toDouble(),
);

/// Generated schema for [MonthTotal].
final ObjectSchema monthTotalGenUiSchema = ObjectSchema(
  description:
      'What was spent in one month. A list of these, oldest first, '
      'is what a MonthBars chart draws.',
  properties: {
    'month': S.string(description: 'The month, written as YYYY-MM.'),
    'amount': S.number(
      description: 'Pesos spent that month, as a positive whole number.',
    ),
    'highlight': S.boolean(
      description:
          'Whether this is the month the answer is about. At most one '
          'month in a chart should be highlighted.',
    ),
  },
  required: ['month', 'amount'],
);

/// Decodes a [MonthTotal] from the map the model produced.
///
/// Values are coerced the same way genui's `Bound*` widgets coerce a
/// widget property, so a field of the wrong type degrades instead of
/// throwing. Every required field that had to fall back is reported
/// through [onMissing], when one is given.
MonthTotal monthTotalFromGenUiJson(
  Map<String, Object?> json, [
  GenUiMissingFieldReporter? onMissing,
]) => MonthTotal(
  month:
      genUiAsString(json['month']) ??
      genUiMissingField<String>(onMissing, 'month', ''),
  amount:
      (genUiAsNum(json['amount']) ??
              genUiMissingField<num>(onMissing, 'amount', 0))
          .toDouble(),
  highlight: genUiAsBool(json['highlight']) ?? false,
);

/// Generated schema for [MovementItem].
final ObjectSchema movementItemGenUiSchema = ObjectSchema(
  description:
      'One payment from the account statement, as the bank lists '
      'it.',
  properties: {
    'merchant': S.string(
      description: 'Who was paid, exactly as the statement names them.',
    ),
    'category': S.string(
      description: 'The spending category the payment belongs to.',
      enumValues: [
        'housing',
        'groceries',
        'restaurants',
        'transport',
        'utilities',
        'subscriptions',
        'health',
        'shopping',
        'leisure',
        'debt',
        'other',
      ],
    ),
    'amount': S.number(description: 'Pesos paid, as a positive whole number.'),
    'date': S.string(
      description: 'The day it was charged, written as YYYY-MM-DD.',
    ),
  },
  required: ['merchant', 'category', 'amount', 'date'],
);

/// Decodes a [MovementItem] from the map the model produced.
///
/// Values are coerced the same way genui's `Bound*` widgets coerce a
/// widget property, so a field of the wrong type degrades instead of
/// throwing. Every required field that had to fall back is reported
/// through [onMissing], when one is given.
MovementItem movementItemFromGenUiJson(
  Map<String, Object?> json, [
  GenUiMissingFieldReporter? onMissing,
]) => MovementItem(
  merchant:
      genUiAsString(json['merchant']) ??
      genUiMissingField<String>(onMissing, 'merchant', ''),
  category:
      Category.values.asNameMap()[genUiAsString(json['category'])] ??
      genUiMissingField<Category>(onMissing, 'category', Category.values.first),
  amount:
      (genUiAsNum(json['amount']) ??
              genUiMissingField<num>(onMissing, 'amount', 0))
          .toDouble(),
  date:
      genUiAsString(json['date']) ??
      genUiMissingField<String>(onMissing, 'date', ''),
);

/// Generated schema for [SubscriptionItem].
final ObjectSchema subscriptionItemGenUiSchema = ObjectSchema(
  description:
      'A subscription charged every month, whether the person wants '
      'to keep it, and whether they already cancelled it.',
  properties: {
    'name': S.string(description: 'The service, as the statement names it.'),
    'price': S.number(description: 'What it costs every month, in pesos.'),
    'keep': S.boolean(
      description: 'Whether the person wants to keep paying for it.',
    ),
    'cancelled': S.boolean(
      description:
          'Whether the person says they already cancelled it with the '
          'service.',
    ),
  },
  required: ['name', 'price', 'keep'],
);

/// Decodes a [SubscriptionItem] from the map the model produced.
///
/// Values are coerced the same way genui's `Bound*` widgets coerce a
/// widget property, so a field of the wrong type degrades instead of
/// throwing. Every required field that had to fall back is reported
/// through [onMissing], when one is given.
SubscriptionItem subscriptionItemFromGenUiJson(
  Map<String, Object?> json, [
  GenUiMissingFieldReporter? onMissing,
]) => SubscriptionItem(
  name:
      genUiAsString(json['name']) ??
      genUiMissingField<String>(onMissing, 'name', ''),
  price:
      (genUiAsNum(json['price']) ??
              genUiMissingField<num>(onMissing, 'price', 0))
          .toDouble(),
  keep:
      genUiAsBool(json['keep']) ??
      genUiMissingField<bool>(onMissing, 'keep', false),
  cancelled: genUiAsBool(json['cancelled']) ?? false,
);
