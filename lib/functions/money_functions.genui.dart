// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'money_functions.dart';

// **************************************************************************
// GenUiFunctionGenerator
// **************************************************************************

/// Generated catalog function for [money].
final ClientFunction moneyGenUiFunction = GenUiClientFunction(
  name: 'money',
  description:
      'Formats an amount of pesos the way it is written in '
      'Colombia, such as "\$1.650.000", or in the short spoken form, '
      'such as "\$4,7 M", when `short` is true. Use it for any money '
      'shown as text, rather than writing the digits yourself.',
  argumentSchema: S.object(
    properties: {
      'amount': A2uiSchemas.numberReference(),
      'short': A2uiSchemas.booleanReference(),
    },
    required: ['amount'],
  ),
  returnType: ClientFunctionReturnType.string,
  body: (args, context) {
    final json = args;
    const GenUiMissingFieldReporter? onMissing = null;
    return money(
      (genUiAsNum(json['amount']) ??
              genUiMissingField<num>(onMissing, 'amount', 0))
          .toDouble(),
      short: genUiAsBool(json['short']) ?? false,
    );
  },
);

/// Generated catalog function for [percentChange].
final ClientFunction percentChangeGenUiFunction = GenUiClientFunction(
  name: 'percentChange',
  description:
      'The change from `previous` to `current` as a signed '
      'percentage, such as "+67 %" or "−13 %".',
  argumentSchema: S.object(
    properties: {
      'current': A2uiSchemas.numberReference(),
      'previous': A2uiSchemas.numberReference(),
    },
    required: ['current', 'previous'],
  ),
  returnType: ClientFunctionReturnType.string,
  body: (args, context) {
    final json = args;
    const GenUiMissingFieldReporter? onMissing = null;
    return percentChange(
      (genUiAsNum(json['current']) ??
              genUiMissingField<num>(onMissing, 'current', 0))
          .toDouble(),
      (genUiAsNum(json['previous']) ??
              genUiMissingField<num>(onMissing, 'previous', 0))
          .toDouble(),
    );
  },
);

/// Generated catalog function for [arrivalMonth].
final ClientFunction arrivalMonthGenUiFunction = GenUiClientFunction(
  name: 'arrivalMonth',
  description:
      'The month a savings goal is reached when `monthly` is put '
      'aside every month from now, as text such as "mayo de 2027". '
      'Says "nunca" when `monthly` is zero. Bind a GoalPlanner\'s '
      '`arrival` to it.',
  argumentSchema: S.object(
    properties: {
      'target': A2uiSchemas.numberReference(),
      'saved': A2uiSchemas.numberReference(),
      'monthly': A2uiSchemas.numberReference(),
    },
    required: ['target', 'saved', 'monthly'],
  ),
  returnType: ClientFunctionReturnType.string,
  body: (args, context) {
    final json = args;
    const GenUiMissingFieldReporter? onMissing = null;
    return arrivalMonth(
      (genUiAsNum(json['target']) ??
              genUiMissingField<num>(onMissing, 'target', 0))
          .toDouble(),
      (genUiAsNum(json['saved']) ??
              genUiMissingField<num>(onMissing, 'saved', 0))
          .toDouble(),
      (genUiAsNum(json['monthly']) ??
              genUiMissingField<num>(onMissing, 'monthly', 0))
          .toDouble(),
    );
  },
);

/// Generated catalog function for [arrivesBy].
final ClientFunction arrivesByGenUiFunction = GenUiClientFunction(
  name: 'arrivesBy',
  description:
      'Whether a savings goal is reached on or before `deadline` '
      '(written YYYY-MM-DD) when `monthly` is put aside every month '
      'from now. Bind a GoalPlanner\'s `onTime` to it.',
  argumentSchema: S.object(
    properties: {
      'target': A2uiSchemas.numberReference(),
      'saved': A2uiSchemas.numberReference(),
      'monthly': A2uiSchemas.numberReference(),
      'deadline': A2uiSchemas.stringReference(),
    },
    required: ['target', 'saved', 'monthly', 'deadline'],
  ),
  returnType: ClientFunctionReturnType.boolean,
  body: (args, context) {
    final json = args;
    const GenUiMissingFieldReporter? onMissing = null;
    return arrivesBy(
      (genUiAsNum(json['target']) ??
              genUiMissingField<num>(onMissing, 'target', 0))
          .toDouble(),
      (genUiAsNum(json['saved']) ??
              genUiMissingField<num>(onMissing, 'saved', 0))
          .toDouble(),
      (genUiAsNum(json['monthly']) ??
              genUiMissingField<num>(onMissing, 'monthly', 0))
          .toDouble(),
      genUiAsString(json['deadline']) ??
          genUiMissingField<String>(onMissing, 'deadline', ''),
    );
  },
);

/// Generated catalog function for [monthlyNeeded].
final ClientFunction monthlyNeededGenUiFunction = GenUiClientFunction(
  name: 'monthlyNeeded',
  description:
      'How much has to be put aside each month, from now, to reach '
      '`target` by `deadline` (written YYYY-MM-DD), rounded up to '
      'the next ten thousand pesos.',
  argumentSchema: S.object(
    properties: {
      'target': A2uiSchemas.numberReference(),
      'saved': A2uiSchemas.numberReference(),
      'deadline': A2uiSchemas.stringReference(),
    },
    required: ['target', 'saved', 'deadline'],
  ),
  returnType: ClientFunctionReturnType.number,
  body: (args, context) {
    final json = args;
    const GenUiMissingFieldReporter? onMissing = null;
    return monthlyNeeded(
      (genUiAsNum(json['target']) ??
              genUiMissingField<num>(onMissing, 'target', 0))
          .toDouble(),
      (genUiAsNum(json['saved']) ??
              genUiMissingField<num>(onMissing, 'saved', 0))
          .toDouble(),
      genUiAsString(json['deadline']) ??
          genUiMissingField<String>(onMissing, 'deadline', ''),
    );
  },
);

/// Generated catalog function for [savingsIfCancelled].
final ClientFunction savingsIfCancelledGenUiFunction = GenUiClientFunction(
  name: 'savingsIfCancelled',
  description:
      'What cancelling every subscription whose `keep` is false '
      'saves each month, in pesos. Pass it the same list a '
      'SubscriptionList repeats over, and wrap it in `money` to '
      'show it.',
  argumentSchema: S.object(
    properties: {
      'items': A2uiSchemas.listOrReference(items: subscriptionItemGenUiSchema),
    },
    required: ['items'],
  ),
  returnType: ClientFunctionReturnType.number,
  body: (args, context) {
    final json = args;
    const GenUiMissingFieldReporter? onMissing = null;
    return savingsIfCancelled(
      genUiAsObjectList(json['items'])
              ?.map(
                (nested) => subscriptionItemFromGenUiJson(
                  nested,
                  genUiNestedField(onMissing, 'items'),
                ),
              )
              .toList() ??
          genUiMissingField<List<SubscriptionItem>>(
            onMissing,
            'items',
            const <SubscriptionItem>[],
          ),
    );
  },
);
