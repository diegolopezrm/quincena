// GENERATED CODE - DO NOT MODIFY BY HAND
// dart format width=80

// ignore_for_file: type=lint
// coverage:ignore-file

part of 'goal_planner.dart';

// **************************************************************************
// GenUiGenerator
// **************************************************************************

/// Generated [CatalogItem] for [GoalPlanner].
final CatalogItem goalPlannerCatalogItem = CatalogItem(
  name: 'GoalPlanner',
  dataSchema: S.object(
    description:
        'A savings goal with its progress and a slider for how much '
        'to put aside each month. Bind `monthly` to a data path: the '
        'slider writes there as it moves. Bind `arrival` to the '
        '`arrivalMonth` function and `onTime` to the `arrivesBy` '
        'function over the same paths, and the answer recalculates on '
        'the device as the person drags, with no new message from '
        'you. Bind `needed` to the `monthlyNeeded` function over the '
        'same paths and deadline: the slider marks the amount that '
        'reaches the goal in time and stops on it. Moving it saves '
        'nothing.',
    properties: {
      'name': A2uiSchemas.stringReference(
        description: 'What the money is for, such as "Cartagena".',
      ),
      'target': A2uiSchemas.numberReference(
        description: 'The full amount the goal needs, in pesos.',
      ),
      'saved': A2uiSchemas.numberReference(
        description: 'What is already put aside, in pesos.',
      ),
      'monthly': A2uiSchemas.numberReference(
        description:
            'How much goes into the goal each month. Bind it to a data '
            'path so the slider can change it. The component writes the '
            'value the user chooses back to this property, so bind it to '
            'a data path if you need to read the result.',
      ),
      'max': A2uiSchemas.numberReference(
        description:
            'The highest monthly amount the slider offers. Keep it within '
            'what the person could actually put aside.',
      ),
      'arrival': A2uiSchemas.stringReference(
        description:
            'When the goal is reached at the current pace, as text such '
            'as "mayo de 2027". Bind it to the `arrivalMonth` function.',
      ),
      'onTime': A2uiSchemas.booleanReference(
        description:
            'Whether the goal is reached by the deadline at the current '
            'pace. Bind it to the `arrivesBy` function.',
      ),
      'deadlineLabel': A2uiSchemas.stringReference(
        description:
            'The deadline as day and month, such as "20 de diciembre".',
      ),
      'min': A2uiSchemas.numberReference(
        description: 'The lowest monthly amount the slider offers.',
      ),
      'step': A2uiSchemas.numberReference(
        description: 'How far one notch of the slider moves, in pesos.',
      ),
      'needed': A2uiSchemas.numberReference(
        description:
            'The monthly amount that reaches the goal by the deadline. '
            'Bind it to the `monthlyNeeded` function over the same paths: '
            'the slider marks it, stops on it when dragged near, and the '
            'phone ticks as it is reached.',
      ),
      'current': A2uiSchemas.numberReference(
        description:
            'Today\'s monthly amount, at a path of its own: away from it, '
            'the planner says it is a simulation and offers to go back.',
      ),
      'deadline': A2uiSchemas.stringReference(
        description:
            'The deadline, YYYY-MM-DD, at the path the functions read.',
      ),
      'contributionDay': A2uiSchemas.numberReference(
        description: 'The day of the month contributions land.',
      ),
      'spendable': A2uiSchemas.numberReference(
        description:
            'What can be spent until payday: freeUntilPayday. With '
            '`payday`, the planner says what the monthly amount changes '
            'in it.',
      ),
      'payday': A2uiSchemas.stringReference(
        description: 'The next payday, YYYY-MM-DD.',
      ),
    },
    required: [
      'name',
      'target',
      'saved',
      'monthly',
      'max',
      'arrival',
      'onTime',
      'deadlineLabel',
    ],
  ),
  exampleData: [
    () => r'''
[
  {
    "id": "root",
    "component": "GoalPlanner",
    "name": "Sample name",
    "target": 19.99,
    "saved": 42.5,
    "monthly": 1.0,
    "max": 19.99,
    "arrival": "Sample arrival",
    "onTime": true,
    "deadlineLabel": "Sample deadline label"
  }
]''',
  ],
  widgetBuilder: (ctx) {
    final data = ctx.data as JsonMap;
    T missing<T>(String property, T fallback) {
      genUiReportMissing(ctx, 'GoalPlanner', property);
      return fallback;
    }

    return GenUiBindings(
      dataContext: ctx.dataContext,
      bindings: {
        'name': GenUiBinding.string(data['name']),
        'target': GenUiBinding.number(data['target']),
        'saved': GenUiBinding.number(data['saved']),
        'monthly': GenUiBinding.number(
          genUiWriteReference(ctx, data['monthly'], 'monthly'),
        ),
        'max': GenUiBinding.number(data['max']),
        'arrival': GenUiBinding.string(data['arrival']),
        'onTime': GenUiBinding.bool(data['onTime']),
        'deadlineLabel': GenUiBinding.string(data['deadlineLabel']),
        'min': GenUiBinding.number(data['min']),
        'step': GenUiBinding.number(data['step']),
        'needed': GenUiBinding.number(data['needed']),
        'current': GenUiBinding.number(data['current']),
        'deadline': GenUiBinding.string(data['deadline']),
        'contributionDay': GenUiBinding.number(data['contributionDay']),
        'spendable': GenUiBinding.number(data['spendable']),
        'payday': GenUiBinding.string(data['payday']),
      },
      builder: (context, v) => GoalPlanner(
        name: v.string('name') ?? missing<String>('name', ''),
        target: (v.number('target') ?? missing<num>('target', 0)).toDouble(),
        saved: (v.number('saved') ?? missing<num>('saved', 0)).toDouble(),
        monthly:
            ((v.number('monthly') ?? genUiAsNum(data['monthly'])) ??
                    missing<num>('monthly', 0))
                .toDouble(),
        max: (v.number('max') ?? missing<num>('max', 0)).toDouble(),
        arrival: v.string('arrival') ?? missing<String>('arrival', ''),
        onTime: v.boolean('onTime') ?? missing<bool>('onTime', false),
        deadlineLabel:
            v.string('deadlineLabel') ?? missing<String>('deadlineLabel', ''),
        onMonthlyChanged: genUiValueWriter<double>(
          ctx,
          data['monthly'],
          'monthly',
        ),
        min: v.number('min')?.toDouble() ?? 0,
        step: v.number('step')?.toDouble() ?? 10000,
        needed: v.number('needed')?.toDouble(),
        current: v.number('current')?.toDouble(),
        deadline: v.string('deadline'),
        contributionDay: v.number('contributionDay')?.toInt() ?? 16,
        spendable: v.number('spendable')?.toDouble(),
        payday: v.string('payday'),
      ),
    );
  },
);
