import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:genui/genui.dart';

import '../data/category.dart';
import '../data/clock.dart';
import '../data/ledger.dart';
import '../format/dates.dart';
import '../format/money.dart';
import '../functions/money_functions.dart' show monthlyNeeded;
import '../l10n/l10n.dart';
import 'understand.dart';

/// One answer: the components of a surface and the data they bind to.
class AgentTurn {
  const AgentTurn({required this.components, this.data = const {}});

  final List<JsonMap> components;
  final Map<String, Object?> data;

  /// The messages an agent sends for this answer, in the order A2UI expects.
  List<core.A2uiMessage> messages(
    String surfaceId,
    String catalogId,
  ) => <core.A2uiMessage>[
    core.CreateSurfaceMessage(surfaceId: surfaceId, catalogId: catalogId),
    core.UpdateComponentsMessage(surfaceId: surfaceId, components: components),
    if (data.isNotEmpty)
      core.UpdateDataModelMessage(
        surfaceId: surfaceId,
        // A data model seeded with a constant map drops every write in
        // silence, and these surfaces have sliders and checkboxes. A real
        // agent's payload arrives decoded from JSON and is mutable; this
        // makes the scripted one the same.
        value: _mutable(data)! as Map<String, Object?>,
      ),
  ];
}

/// The agent the demo runs with when there is no model behind it.
///
/// It recognizes the questions the demo is built around and answers each with
/// the surface a model would compose for it: the same components, the same
/// bindings, the same function calls. The numbers are never written here.
/// Every one comes from the [Ledger], so the answers agree with the statement
/// and with each other, and recording a saved expense changes the next answer.
class ScriptedAgent {
  ScriptedAgent(this.ledger, {this.language = 'es'});

  final Ledger ledger;

  /// The language the answers are written in: `es` or `en`.
  final String language;

  bool get _en => language == 'en';

  /// The sentence in the agent's language, with both written side by side
  /// wherever a sentence is composed, so neither drifts from the other.
  String _t(String es, String en) => _en ? en : es;

  /// The questions the demo offers, in the order they tell the story.
  static const List<String> starters = <String>[
    '¿En qué se me fue la plata en septiembre?',
    '¿Me alcanza para ir a Cartagena en diciembre?',
    '¿Qué suscripciones tengo?',
    '¿Cómo voy contra agosto?',
    'Registra 45 mil en el mercado',
  ];

  /// The same questions, in English.
  static const List<String> startersEn = <String>[
    'Where did my money go in September?',
    'Can I afford Cartagena in December?',
    'What subscriptions do I have?',
    'How am I doing compared with August?',
    'Log 45k at the grocery store',
  ];

  /// The questions in [language].
  static List<String> startersFor(String language) =>
      language == 'en' ? startersEn : starters;

  List<String> get _questions => startersFor(language);

  /// Answers [prompt], or explains what the demo can answer.
  AgentTurn answer(String prompt) => switch (intentOf(prompt)) {
    Intent.spending => _spending(),
    Intent.goal => _goal(),
    Intent.record => _record(
      amountIn(prompt) ?? 0,
      categoryIn(prompt) ?? Category.groceries,
    ),
    Intent.subscriptions => _subscriptions(),
    Intent.compare => _compare(),
    null => _unknown(),
  };

  /// Answers something the person did on a surface.
  AgentTurn? react(String name, Map<String, Object?> context) {
    switch (name) {
      case 'ask':
        final Object? question = context['question'];
        return question is String ? answer(question) : null;
      case 'show_category':
        final Category? category = Category.values
            .where((Category c) => c.name == context['category'])
            .firstOrNull;
        return category == null ? null : _category(category);
      case 'save_expense':
        return _saved(context);
      case 'save_goal_plan':
        return _planSaved(context);
      case 'review_cancellation':
        return _review(context);
      case 'change_cancellation':
        return _subscriptions(<String>{
          for (final Map<Object?, Object?> row in _ticked(context))
            '${row['name']}',
        });
      case 'cancel_subscriptions':
        return _cancelled(context);
    }
    return null;
  }

  int get _year => appToday.year;
  int get _month => appToday.month;

  /// The month the questions are about: the last complete one.
  (int, int) get _lastMonth =>
      _month == 1 ? (_year - 1, 12) : (_year, _month - 1);

  (int, int) get _monthBefore {
    final (int y, int m) = _lastMonth;
    return m == 1 ? (y - 1, 12) : (y, m - 1);
  }

  String _monthName(int year, int month) => monthName(DateTime(year, month));

  String _label(Category c) => c.labelIn(language);

  /// A category's name inside a sentence, where it is not capitalized.
  String _inline(Category c) => _label(c).toLowerCase();

  /// Names in a sentence: "a", "a y b", "a, b y c".
  String _and(List<String> items) => items.length < 2
      ? items.join()
      : '${items.take(items.length - 1).join(', ')} ${_t('y', 'and')} '
            '${items.last}';

  AgentTurn _spending() {
    final (int y, int m) = _lastMonth;
    final (int py, int pm) = _monthBefore;
    final String name = _monthName(y, m);
    final String previous = _monthName(py, pm);
    final int spent = ledger.spentIn(y, m);
    final int income = ledger.incomeIn(y, m);

    final List<MapEntry<Category, int>> all = ledger.byCategory(y, m);

    // What moved, measured without each month's single largest payment, so
    // a pair of headphones reads as a purchase and not as a habit. A
    // category needs a few payments a month to have a habit at all.
    int habit(Category c, int year, int month) {
      final List<Movement> paid = ledger.inCategory(c, year, month);
      if (paid.length < 3) return 0;
      final int largest = paid
          .map((Movement x) => x.amount)
          .reduce((int a, int b) => a > b ? a : b);
      return paid.fold(0, (int s, Movement x) => s + x.amount) - largest;
    }

    MapEntry<Category, double>? up;
    MapEntry<Category, double>? down;
    for (final MapEntry<Category, int> e in all) {
      final int now = habit(e.key, y, m);
      final int before = habit(e.key, py, pm);
      if (before < 100000 || now == 0) continue;
      final double change = (now - before) / before;
      if (up == null || change > up.value) up = MapEntry(e.key, change);
      if (down == null || change < down.value) down = MapEntry(e.key, change);
    }

    final List<Movement> restaurants = ledger.inCategory(
      Category.restaurants,
      y,
      m,
    );
    final int lunches = restaurants
        .where((Movement x) => x.merchant.startsWith('Almuerzos'))
        .length;
    final int lunchesBefore = ledger
        .inCategory(Category.restaurants, py, pm)
        .where((Movement x) => x.merchant.startsWith('Almuerzos'))
        .length;
    final Movement? biggestMeal = restaurants.isEmpty
        ? null
        : (restaurants.toList()..sort(
                (Movement a, Movement b) => b.amount.compareTo(a.amount),
              ))
              .first;

    final bool tight = spent > income * 0.95;
    final int savedForGoal = ledger.movements
        .where(
          (Movement x) =>
              x.flow == Flow.saving && x.date.year == y && x.date.month == m,
        )
        .fold(0, (int s, Movement x) => s + x.amount);

    final components = <JsonMap>[
      _c('root', 'Answer', {
        'children': [
          'head',
          'tiles',
          'donut',
          if (up != null) 'up',
          if (down != null && down.value < 0) 'down',
          'largest',
          'next',
        ],
      }),
      _c('head', 'Headline', {
        'kicker': _capital(name),
        'title': tight
            ? _t(
                'Gastaste casi todo lo que entró',
                'You spent almost everything that came in',
              )
            : _t(
                'Te sobraron ${pesos(income - spent)}',
                'You had ${pesos(income - spent)} left over',
              ),
        'body': _t(
          'Salieron ${pesos(spent)} de los ${pesos(income)} que te pagaron'
              '${savedForGoal > 0 ? ', y apartaste ${pesos(savedForGoal)} para Cartagena' : ''}.',
          'You spent ${pesos(spent)} of the ${pesos(income)} you were paid'
              '${savedForGoal > 0 ? ', and set aside ${pesos(savedForGoal)} for Cartagena' : ''}.',
        ),
      }),
      _c('tiles', 'Tiles', {
        'children': ['tile_spent', 'tile_change'],
      }),
      _c('tile_spent', 'StatTile', {
        'label': _t('Gastado en $name', 'Spent in $name'),
        'value': _call('money', {'amount': _path('/spent')}),
        'caption': _t(
          'de ${pesos(income)} que entraron',
          'out of ${pesos(income)} in income',
        ),
        'tone': tight ? 'caution' : 'good',
      }),
      _c('tile_change', 'StatTile', {
        'label': _t('Contra $previous', 'vs. $previous'),
        'value': _call('percentChange', {
          'current': _path('/spent'),
          'previous': _path('/previous'),
        }),
        'caption': _t(
          '${pesos(ledger.spentIn(py, pm))} en $previous',
          '${pesos(ledger.spentIn(py, pm))} in $previous',
        ),
        'tone': spent > ledger.spentIn(py, pm) ? 'caution' : 'good',
      }),
      _c('donut', 'SpendingDonut', {
        'title': _t('Por categoría', 'By category'),
        'slices': _path('/byCategory'),
        'centerLabel': name,
      }),
      if (up != null)
        _c('up', 'Insight', {
          'tone': up.value > 0.3 ? 'alert' : 'caution',
          'title': _t(
            '${_label(up.key)} subió ${_change(ledger.spentOn(up.key, y, m), ledger.spentOn(up.key, py, pm))}',
            '${_label(up.key)} went up ${_change(ledger.spentOn(up.key, y, m), ledger.spentOn(up.key, py, pm))}',
          ),
          'body': up.key == Category.restaurants && biggestMeal != null
              ? _t(
                  'Fueron ${pesos(ledger.spentOn(up.key, y, m))} contra '
                      '${pesos(ledger.spentOn(up.key, py, pm))} en $previous: la cena del '
                      '${biggestMeal.date.day} en ${biggestMeal.merchant} y '
                      '${lunches - lunchesBefore} almuerzos más que el mes pasado.',
                  'You spent ${pesos(ledger.spentOn(up.key, y, m))}, up from '
                      '${pesos(ledger.spentOn(up.key, py, pm))} in $previous: dinner on the '
                      '${_ordinal(biggestMeal.date.day)} at ${biggestMeal.merchant} and '
                      '${lunches - lunchesBefore} more lunches than the month before.',
                )
              : _t(
                  'Fueron ${pesos(ledger.spentOn(up.key, y, m))} contra '
                      '${pesos(ledger.spentOn(up.key, py, pm))} en $previous.',
                  'You spent ${pesos(ledger.spentOn(up.key, y, m))}, up from '
                      '${pesos(ledger.spentOn(up.key, py, pm))} in $previous.',
                ),
          'actionLabel': _t('Ver esos pagos', 'See those payments'),
          'onAction': _event('show_category', {'category': up.key.name}),
        }),
      if (down != null && down.value < 0)
        _c('down', 'Insight', {
          'tone': 'good',
          'title': _t(
            '${_label(down.key)} bajó ${_change(ledger.spentOn(down.key, y, m), ledger.spentOn(down.key, py, pm))}',
            '${_label(down.key)} went down ${_change(ledger.spentOn(down.key, y, m), ledger.spentOn(down.key, py, pm))}',
          ),
          'body': _t(
            'Gastaste ${pesos(ledger.spentOn(down.key, y, m))}, contra '
                '${pesos(ledger.spentOn(down.key, py, pm))} en $previous.',
            'You spent ${pesos(ledger.spentOn(down.key, y, m))}, down from '
                '${pesos(ledger.spentOn(down.key, py, pm))} in $previous.',
          ),
        }),
      _c('largest', 'MovementList', {
        'title': _t('Los cinco pagos más grandes', 'The five largest payments'),
        'items': _path('/largest'),
      }),
      ..._suggestions(<String>[_questions[1], _questions[3]]),
    ];

    return AgentTurn(
      components: components,
      data: {
        'spent': spent,
        'previous': ledger.spentIn(py, pm),
        'byCategory': [
          for (final MapEntry<Category, int> e in all)
            {'category': e.key.name, 'amount': e.value},
        ],
        'largest': [
          for (final Movement x in ledger.largestIn(y, m)) _movement(x),
        ],
      },
    );
  }

  AgentTurn _goal() {
    final Goal goal = ledger.goal('cartagena');
    const int cut = 0;
    final int stale = ledger.subscriptions
        .where((s) => s.unusedAsOf(appToday))
        .fold(cut, (int sum, s) => sum + s.price);
    final (int y, int m) = _lastMonth;
    final (int py, int pm) = _monthBefore;
    final int restaurantsBack =
        ledger.spentOn(Category.restaurants, y, m) -
        ledger.spentOn(Category.restaurants, py, pm);
    final String deadline = _iso(goal.deadline);
    final String deadlineLabel = _t(
      'el ${dayMonth(goal.deadline)}',
      dayMonth(goal.deadline),
    );
    // The answer to the question comes first: whether the current pace
    // gets there, and what is missing each month if it does not.
    final int needed = monthlyNeeded(
      goal.target.toDouble(),
      goal.saved.toDouble(),
      deadline,
    ).round();
    final int gap = needed - goal.monthly;

    Map<String, Object?> goalArgs([bool withDeadline = false]) => {
      'target': _path('/goal/target'),
      'saved': _path('/goal/saved'),
      'monthly': _path('/goal/monthly'),
      if (withDeadline) 'deadline': _path('/goal/deadline'),
    };

    return AgentTurn(
      components: <JsonMap>[
        _c('root', 'Answer', {
          'children': ['head', 'planner', 'tiles', 'room', 'save', 'next'],
        }),
        _c('head', 'Headline', {
          'kicker': _t('Tu meta', 'Your goal'),
          'title': gap > 0
              ? _t(
                  'No con lo que apartas hoy',
                  'Not with what you put aside now',
                )
              : _t(
                  'Sí, con lo que apartas llegas',
                  'Yes, at this pace you get there',
                ),
          'body': gap > 0
              ? _t(
                  'Te faltan ${pesos(gap)} al mes para llegar $deadlineLabel: '
                      'necesitas ${pesos(needed)} y hoy apartas '
                      '${pesos(goal.monthly)}. Mueve el control para ver '
                      'cuándo llegas.',
                  'You are ${pesos(gap)} a month short of $deadlineLabel: it '
                      'takes ${pesos(needed)} and you put aside '
                      '${pesos(goal.monthly)}. Move the slider to see when '
                      'you get there.',
                )
              : _t(
                  'Con ${pesos(goal.monthly)} al mes llegas antes de '
                      '$deadlineLabel.',
                  'At ${pesos(goal.monthly)} a month you get there before '
                      '$deadlineLabel.',
                ),
        }),
        _c('planner', 'GoalPlanner', {
          'name': goal.name,
          'target': _path('/goal/target'),
          'saved': _path('/goal/saved'),
          'monthly': _path('/goal/monthly'),
          'min': 100000,
          'max': 800000,
          'step': 10000,
          'arrival': _call('arrivalMonth', goalArgs()),
          'onTime': _call('arrivesBy', goalArgs(true)),
          'deadlineLabel': dayMonth(goal.deadline),
          'needed': _call('monthlyNeeded', {
            'target': _path('/goal/target'),
            'saved': _path('/goal/saved'),
            'deadline': _path('/goal/deadline'),
          }),
        }),
        _c('tiles', 'Tiles', {
          'children': ['need', 'free'],
        }),
        _c('need', 'StatTile', {
          'label': _t('Necesitas al mes', 'You need a month'),
          'value': _call('money', {
            'amount': _call('monthlyNeeded', {
              'target': _path('/goal/target'),
              'saved': _path('/goal/saved'),
              'deadline': _path('/goal/deadline'),
            }),
          }),
          'caption': _t(
            'para llegar $deadlineLabel',
            'to get there by $deadlineLabel',
          ),
        }),
        _c('free', 'StatTile', {
          'label': _t(
            'Puedes gastar hasta el ${ledger.nextPayday.day}',
            'You can spend until the ${_ordinal(ledger.nextPayday.day)}',
          ),
          'value': _call('money', {'amount': _path('/free')}),
          'caption': _t(
            'después de arriendo y pagos fijos',
            'after rent and fixed bills',
          ),
        }),
        _c('room', 'Insight', {
          'tone': 'good',
          // What could be freed, never what the person should cut: the
          // choice is theirs.
          'title': _t(
            'Podrías liberar hasta ${pesos(stale + restaurantsBack)}',
            'You could free up to ${pesos(stale + restaurantsBack)}',
          ),
          'body': _t(
            '${pesos(stale)} de dos suscripciones sin uso hace más de un mes.\n'
                '${pesos(restaurantsBack)} si restaurantes vuelve a lo de agosto.',
            '${pesos(stale)} from two subscriptions unused for over a month.\n'
                '${pesos(restaurantsBack)} if eating out goes back to August.',
          ),
          'actionLabel': _t('Revisar suscripciones', 'Review subscriptions'),
          'onAction': _event('ask', {'question': _questions[2]}),
        }),
        _c('save', 'ActionButton', {
          'label': _t('Apartar esto cada mes', 'Set this aside every month'),
          'emphasis': 'primary',
          'onPressed': _event('save_goal_plan', {
            'monthly': _path('/goal/monthly'),
          }),
        }),
        ..._suggestions(<String>[_questions[2]]),
      ],
      data: {
        'goal': {
          'target': goal.target,
          'saved': goal.saved,
          'monthly': goal.monthly,
          'deadline': deadline,
        },
        'free': ledger.freeUntilPayday,
      },
    );
  }

  AgentTurn _record(int amount, Category category) {
    final String label = _inline(category);
    return AgentTurn(
      components: <JsonMap>[
        _c('root', 'Answer', {
          'children': ['head', 'form'],
        }),
        _c('head', 'Headline', {
          'kicker': _t('Nuevo gasto', 'New expense'),
          'title': amount > 0
              ? _t(
                  'Anoto ${pesos(amount)} en $label',
                  'Logging ${pesos(amount)} under $label',
                )
              : _t(
                  'Anoto un gasto en $label',
                  'Logging an expense under $label',
                ),
          'body': _t(
            'Corrige lo que haga falta antes de guardar.',
            "Fix anything that's off before saving.",
          ),
        }),
        _c('form', 'Group', {
          'title': _t(
            'Hoy, ${dayMonth(appToday)}',
            'Today, ${dayMonth(appToday)}',
          ),
          'children': ['amount', 'category', 'note', 'save'],
        }),
        _c('amount', 'MoneyField', {
          'label': _t('Monto', 'Amount'),
          'value': _path('/draft/amount'),
          'checks': [
            {
              'condition': _call('numeric', {
                'value': _path('/draft/amount'),
                'min': 1,
              }),
              'message': _t(
                'Escribe un monto mayor que cero.',
                'Enter an amount above zero.',
              ),
            },
            {
              'condition': _call('numeric', {
                'value': _path('/draft/amount'),
                'max': ledger.balance,
              }),
              'message': _t(
                'Es más de lo que hay en la cuenta.',
                "That's more than the account has.",
              ),
            },
          ],
        }),
        _c('category', 'CategoryChoice', {
          'label': _t('Categoría', 'Category'),
          'value': _path('/draft/category'),
        }),
        _c('note', 'TextEntry', {
          'label': _t('Dónde', 'Where'),
          'value': _path('/draft/note'),
          'hint': _t(
            'Opcional, como "Tienda Don Pacho"',
            'Optional, such as "Tienda Don Pacho"',
          ),
        }),
        _c('save', 'ActionButton', {
          'label': _t('Guardar gasto', 'Save expense'),
          'emphasis': 'primary',
          'onPressed': _event('save_expense', {
            'amount': _path('/draft/amount'),
            'category': _path('/draft/category'),
            'note': _path('/draft/note'),
          }),
        }),
      ],
      data: {
        'draft': {'amount': amount, 'category': category.name, 'note': ''},
      },
    );
  }

  AgentTurn _saved(Map<String, Object?> context) {
    final num amount = context['amount'] is num ? context['amount']! as num : 0;
    final Category category =
        Category.values
            .where((Category c) => c.name == context['category'])
            .firstOrNull ??
        Category.other;
    final String note = (context['note'] as String?)?.trim() ?? '';
    if (amount <= 0) return _record(0, category);

    ledger.record(
      Movement(
        id: 'manual-${ledger.movements.length}',
        date: appToday,
        merchant: note.isEmpty ? _label(category) : note,
        amount: amount.round(),
        category: category,
      ),
    );

    final (int y, int m) = _lastMonth;
    return AgentTurn(
      components: <JsonMap>[
        _c('root', 'Answer', {
          'children': ['head', 'meter', 'next'],
        }),
        _c('head', 'Headline', {
          'kicker': _t('Guardado', 'Saved'),
          'title': _t(
            'Listo: ${pesos(amount)} en ${_inline(category)}',
            'Done: ${pesos(amount)} under ${_inline(category)}',
          ),
          'body': _t(
            'Ahora puedes gastar ${pesos(ledger.freeUntilPayday)} hasta el '
                '${dayMonth(ledger.nextPayday)}.',
            'Now you can spend ${pesos(ledger.freeUntilPayday)} until '
                '${dayMonth(ledger.nextPayday)}.',
          ),
        }),
        _c('meter', 'BudgetMeter', {
          'category': category.name,
          'spent': ledger.spentOn(category, _year, _month),
          'limit': ledger.spentOn(category, y, m),
          'caption': _capital(_monthName(y, m)),
        }),
        ..._suggestions(<String>[_questions[1]]),
      ],
    );
  }

  AgentTurn _planSaved(Map<String, Object?> context) {
    final num monthly = context['monthly'] is num
        ? context['monthly']! as num
        : 0;
    final Goal goal = ledger.goal('cartagena');
    return AgentTurn(
      components: <JsonMap>[
        _c('root', 'Answer', {
          'children': ['head', 'next'],
        }),
        _c('head', 'Headline', {
          'kicker': _t('Meta ${goal.name}', '${goal.name} goal'),
          'title': _t(
            'Cada día 16 aparto ${pesos(monthly)}',
            'I will set aside ${pesos(monthly)} every 16th',
          ),
          'body': _t(
            'Empiezo el ${dayMonth(DateTime(_year, _month, 16))}. Si un mes '
                'no alcanza, te aviso antes de mover la plata.',
            'Starting ${dayMonth(DateTime(_year, _month, 16))}. If a month '
                'falls short, I will tell you before moving any money.',
          ),
        }),
        ..._suggestions(<String>[_questions[2]]),
      ],
    );
  }

  /// The subscriptions, each with a box the person ticks to cancel it.
  ///
  /// Nothing comes ticked: which ones to drop is the person's choice, so the
  /// answer only names the ones that went unused. [ticked] holds the names
  /// they had already chosen, when they come back to change the choice.
  AgentTurn _subscriptions([Set<String> ticked = const <String>{}]) {
    final List<Subscription> subs = ledger.subscriptions;
    final List<Subscription> stale = subs
        .where((Subscription s) => s.unusedAsOf(appToday))
        .toList();
    final Subscription? newest = subs.isEmpty
        ? null
        : (subs.toList()..sort(
                (Subscription a, Subscription b) => b.since.compareTo(a.since),
              ))
              .first;
    final String unused = _and(<String>[
      for (final Subscription s in stale) s.name,
    ]);

    return AgentTurn(
      components: <JsonMap>[
        _c('root', 'Answer', {
          'children': [
            'head',
            'list',
            if (newest != null) 'newest',
            'review',
            'next',
          ],
        }),
        _c('head', 'Headline', {
          'kicker': _t('Suscripciones', 'Subscriptions'),
          'title': _t(
            'Pagas ${pesos(ledger.subscriptionsMonthly)} al mes en suscripciones',
            'You pay ${pesos(ledger.subscriptionsMonthly)} a month for subscriptions',
          ),
          'body': _t(
            'Son ${_count(subs.length)}. '
                '${stale.isEmpty ? 'Todas se usaron en el último mes.' : '${_capital(_count(stale.length))} ${stale.length == 1 ? 'lleva' : 'llevan'} más de un mes sin usarse: $unused.'} '
                'Marca las que quieras cancelar.',
            'There are ${_count(subs.length)}. '
                '${stale.isEmpty ? 'You used all of them in the last month.' : '${_capital(_count(stale.length))} ${stale.length == 1 ? 'has' : 'have'} gone unused for over a month: $unused.'} '
                'Check the ones you want to cancel.',
          ),
        }),
        _c('list', 'SubscriptionList', {
          'title': _t('Tus suscripciones', 'Your subscriptions'),
          'rows': {'componentId': 'row', 'path': '/subscriptions'},
          'savings': _call('money', {
            'amount': _call('savingsIfCancelled', {
              'items': _path('/subscriptions'),
            }),
          }),
        }),
        _c('row', 'SubscriptionRow', {
          'name': _path('name'),
          'price': _path('price'),
          'lastUsed': _path('lastUsed'),
          'keep': _path('keep'),
        }),
        if (newest != null)
          _c('newest', 'Insight', {
            'tone': 'caution',
            'title': _t(
              '${newest.name} empezó en ${_monthName(newest.since.year, newest.since.month)}',
              '${newest.name} started in ${_monthName(newest.since.year, newest.since.month)}',
            ),
            'body': _t(
              'Es tu segundo servicio de video, y a Cineplus le sacaste '
                  'más uso este mes.',
              "It's your second video service, and you used Cineplus more "
                  'this month.',
            ),
          }),
        // Reviewing commits to nothing: the summary it brings is where the
        // person says what they did.
        _c('review', 'ActionButton', {
          'label': _t('Revisar las marcadas', 'Review the ones you checked'),
          'emphasis': 'secondary',
          'onPressed': _event('review_cancellation', {
            'items': _path('/subscriptions'),
          }),
        }),
        ..._suggestions(<String>[_questions[1]]),
      ],
      data: {'subscriptions': _subscriptionRows(ticked)},
    );
  }

  /// Every subscription as a row of the list, with [ticked] ones not kept.
  List<Map<String, Object?>> _subscriptionRows(Set<String> ticked) => [
    for (final Subscription s in ledger.subscriptions)
      {
        'name': s.name,
        'price': s.price,
        if (s.lastUsed case final DateTime used) 'lastUsed': _iso(used),
        'keep': !ticked.contains(s.name),
      },
  ];

  /// The rows of an action's list that the person ticked to cancel.
  static List<Map<Object?, Object?>> _ticked(Map<String, Object?> context) {
    final Object? items = context['items'];
    return items is List
        ? items
              .whereType<Map<Object?, Object?>>()
              .where((Map<Object?, Object?> row) => row['keep'] == false)
              .toList()
        : const <Map<Object?, Object?>>[];
  }

  /// What cancelling the ticked ones means, before the person does it: what
  /// they save, when each is charged next, and that Quincena cannot cancel
  /// them. Only "Ya las cancelé" says it happened.
  AgentTurn _review(Map<String, Object?> context) {
    final Set<String> names = <String>{
      for (final Map<Object?, Object?> row in _ticked(context))
        '${row['name']}',
    };
    final List<Subscription> chosen = ledger.subscriptions
        .where((Subscription s) => names.contains(s.name))
        .toList();
    if (chosen.isEmpty) return _noneTicked();
    final bool one = chosen.length == 1;
    final int saves = chosen.fold(
      0,
      (int sum, Subscription s) => sum + s.price,
    );

    return AgentTurn(
      components: <JsonMap>[
        _c('root', 'Answer', {
          'children': ['head', 'charges', 'change', 'done'],
        }),
        _c('head', 'Headline', {
          'kicker': _t('Antes de cancelar', 'Before you cancel'),
          'title': _t(
            'Vas a cancelar ${_count(chosen.length)}: te ahorras ${pesos(saves)} al mes',
            "You're canceling ${_count(chosen.length)}: you save ${pesos(saves)} a month",
          ),
          'body': one
              ? _t(
                  'Quincena no la cancela por ti: cancélala en el servicio '
                      'antes de su próximo cobro.',
                  "Quincena can't cancel it for you: cancel it with the "
                      'service before its next charge.',
                )
              : _t(
                  'Quincena no las cancela por ti: cancela cada una en su '
                      'servicio antes de su próximo cobro.',
                  "Quincena can't cancel them for you: cancel each one with "
                      'its service before its next charge.',
                ),
        }),
        _c('charges', 'MovementList', {
          'title': one
              ? _t('Su próximo cobro', 'Its next charge')
              : _t('El próximo cobro de cada una', 'The next charge of each'),
          'items': _path('/charges'),
        }),
        _c('change', 'ActionButton', {
          'label': _t('Cambiar selección', 'Change selection'),
          'emphasis': 'secondary',
          'onPressed': _event('change_cancellation', {
            'items': _path('/subscriptions'),
          }),
        }),
        _c('done', 'ActionButton', {
          'label': one
              ? _t('Ya la cancelé', 'I canceled it')
              : _t('Ya las cancelé', 'I canceled them'),
          'emphasis': 'primary',
          'onPressed': _event('cancel_subscriptions', {
            'items': _path('/subscriptions'),
          }),
        }),
      ],
      data: {
        'subscriptions': _subscriptionRows(names),
        'charges': [
          for (final Subscription s in chosen)
            {
              'merchant': s.name,
              'category': Category.subscriptions.name,
              'amount': s.price,
              'date': _iso(s.nextCharge(appToday)),
            },
        ],
      },
    );
  }

  /// What the person says they did: cancelled the ticked ones, each with its
  /// service. Only now do the rows show struck through.
  AgentTurn _cancelled(Map<String, Object?> context) {
    final List<Map<Object?, Object?>> rows = _ticked(context);
    if (rows.isEmpty) return _noneTicked();
    final String names = _and(<String>[
      for (final Map<Object?, Object?> row in rows) '${row['name']}',
    ]);
    final num saved = rows.fold<num>(
      0,
      (num s, Map<Object?, Object?> row) => s + ((row['price'] as num?) ?? 0),
    );

    return AgentTurn(
      components: <JsonMap>[
        _c('root', 'Answer', {
          'children': ['head', 'done', 'next'],
        }),
        _c('head', 'Headline', {
          'kicker': _t('Hecho por ti', 'Done by you'),
          'title': rows.length == 1
              ? _t('Cancelada: $names', 'Canceled: $names')
              : _t('Canceladas: $names', 'Canceled: $names'),
          'body': _t(
            'Desde el próximo cobro te ahorras ${pesos(saved)} al mes. En la '
                'demo esto no cambia tus datos.',
            'From the next charge on, you save ${pesos(saved)} a month. In '
                "the demo, this doesn't change your data.",
          ),
        }),
        _c('done', 'Group', {
          'title': _t('Las que cancelaste', 'What you canceled'),
          'children': [for (var i = 0; i < rows.length; i++) 'row$i'],
        }),
        for (var i = 0; i < rows.length; i++)
          _c('row$i', 'SubscriptionRow', {
            'name': '${rows[i]['name']}',
            'price': (rows[i]['price'] as num?) ?? 0,
            if (rows[i]['lastUsed'] case final String used) 'lastUsed': used,
            'keep': false,
            'cancelled': true,
          }),
        ..._suggestions(<String>[_questions[1]]),
      ],
    );
  }

  /// The answer when the person reviews or confirms without ticking any.
  AgentTurn _noneTicked() => AgentTurn(
    components: <JsonMap>[
      _c('root', 'Answer', {
        'children': ['head', 'next'],
      }),
      _c('head', 'Headline', {
        'kicker': _t('Suscripciones', 'Subscriptions'),
        'title': _t('No marcaste ninguna', "You didn't check any"),
        'body': _t(
          'Todas siguen activas. Marca en la lista las que quieras cancelar.',
          'All of them are still active. Check the ones you want to cancel '
              'in the list.',
        ),
      }),
      ..._suggestions(<String>[_questions[1]]),
    ],
  );

  AgentTurn _compare() {
    final (int y, int m) = _lastMonth;
    final (int py, int pm) = _monthBefore;
    final String name = _monthName(y, m);
    final String previous = _monthName(py, pm);
    final int spent = ledger.spentIn(y, m);
    final int before = ledger.spentIn(py, pm);

    final List<(Category, int, int)> moves =
        <(Category, int, int)>[
          for (final Category c in Category.values)
            if (c != Category.housing && c != Category.debt)
              (c, ledger.spentOn(c, y, m), ledger.spentOn(c, py, pm)),
        ]..sort(
          ((Category, int, int) a, (Category, int, int) b) =>
              (b.$2 - b.$3).abs().compareTo((a.$2 - a.$3).abs()),
        );
    final List<(Category, int, int)> top = moves.take(3).toList();
    final String grew = _and(<String>[
      for (final (Category c, int now, int then) in top)
        if (now > then) _inline(c),
    ]);

    return AgentTurn(
      components: <JsonMap>[
        _c('root', 'Answer', {
          'children': ['head', 'tiles', 'bars', 'moved', 'next'],
        }),
        _c('head', 'Headline', {
          'kicker': _t(
            '${_capital(name)} contra $previous',
            '$name vs. $previous',
          ),
          'title': spent > before
              ? _t(
                  'Gastaste ${pesos(spent - before)} más que en $previous',
                  'You spent ${pesos(spent - before)} more than in $previous',
                )
              : _t(
                  'Gastaste ${pesos(before - spent)} menos que en $previous',
                  'You spent ${pesos(before - spent)} less than in $previous',
                ),
          'body': _t(
            'El salto está en $grew.',
            'Most of the increase is in $grew.',
          ),
        }),
        _c('tiles', 'Tiles', {
          'children': ['now', 'then'],
        }),
        _c('now', 'StatTile', {
          'label': _capital(name),
          'value': _call('money', {'amount': spent}),
          'caption': _call('percentChange', {
            'current': spent,
            'previous': before,
          }),
          'tone': spent > before ? 'caution' : 'good',
        }),
        _c('then', 'StatTile', {
          'label': _capital(previous),
          'value': _call('money', {'amount': before}),
        }),
        _c('bars', 'MonthBars', {
          'title': _t('Últimos seis meses', 'The last six months'),
          'months': _path('/months'),
          'reference': ledger.incomeIn(y, m),
          'referenceLabel': _t('Ingresos', 'Income'),
        }),
        _c('moved', 'Group', {
          'title': _t('Lo que más cambió', 'What changed most'),
          'children': [for (var i = 0; i < top.length; i++) 'meter$i'],
        }),
        for (var i = 0; i < top.length; i++)
          _c('meter$i', 'BudgetMeter', {
            'category': top[i].$1.name,
            'spent': top[i].$2,
            'limit': top[i].$3,
            'caption': _capital(previous),
          }),
        ..._suggestions(<String>[_questions[0]]),
      ],
      data: {
        'months': [
          for (var i = 5; i >= 0; i--)
            () {
              final DateTime d = DateTime(y, m - i);
              return {
                'month': '${d.year}-${d.month.toString().padLeft(2, '0')}',
                'amount': ledger.spentIn(d.year, d.month),
                'highlight': i == 0,
              };
            }(),
        ],
      },
    );
  }

  AgentTurn _category(Category category) {
    final (int y, int m) = _lastMonth;
    final List<Movement> all = ledger.inCategory(category, y, m);
    final List<Movement> sorted = all.toList()
      ..sort((Movement a, Movement b) => b.amount.compareTo(a.amount));
    return AgentTurn(
      components: <JsonMap>[
        _c('root', 'Answer', {
          'children': ['head', 'list'],
        }),
        _c('head', 'Headline', {
          'kicker': '${_label(category)} · ${_monthName(y, m)}',
          'title': _t(
            '${all.length} pagos por ${pesos(ledger.spentOn(category, y, m))}',
            '${all.length} payments totaling ${pesos(ledger.spentOn(category, y, m))}',
          ),
          'body': sorted.isEmpty
              ? null
              : _t(
                  'El más grande fue ${sorted.first.merchant}, el '
                      '${dayMonth(sorted.first.date)}.',
                  'The largest was ${sorted.first.merchant}, on '
                      '${dayMonth(sorted.first.date)}.',
                ),
        }),
        _c('list', 'MovementList', {
          'title': _t('Los diez más grandes', 'The ten largest'),
          'items': _path('/items'),
        }),
      ],
      data: {
        'items': [for (final Movement x in sorted.take(10)) _movement(x)],
      },
    );
  }

  AgentTurn _unknown() => AgentTurn(
    components: <JsonMap>[
      _c('root', 'Answer', {
        'children': ['head', 'next'],
      }),
      _c('head', 'Headline', {
        'kicker': _t('Modo demo', 'Demo mode'),
        'title': _t(
          'En la demo respondo estas preguntas',
          'In the demo, I can answer these questions',
        ),
        'body': _t(
          'Con un modelo conectado puedes preguntar lo que quieras. Sin él, '
              'prueba una de estas.',
          'With a model connected, you can ask anything. Without one, try '
              'one of these.',
        ),
      }),
      ..._suggestions(_questions),
    ],
  );

  List<JsonMap> _suggestions(List<String> questions) => <JsonMap>[
    _c('next', 'Suggestions', {
      'children': [for (var i = 0; i < questions.length; i++) 'ask$i'],
    }),
    for (var i = 0; i < questions.length; i++)
      _c('ask$i', 'Suggestion', {
        'label': questions[i],
        'onPressed': _event('ask', {'question': questions[i]}),
      }),
  ];

  Map<String, Object?> _movement(Movement x) => {
    'merchant': x.merchant,
    'category': x.category.name,
    'amount': x.amount,
    'date': _iso(x.date),
  };
}

JsonMap _c(String id, String component, Map<String, Object?> properties) => {
  'id': id,
  'component': component,
  for (final MapEntry<String, Object?> e in properties.entries)
    if (e.value != null) e.key: e.value,
};

JsonMap _path(String path) => {'path': path};

JsonMap _call(String name, Map<String, Object?> args) => {
  'call': name,
  'args': args,
};

JsonMap _event(String name, Map<String, Object?> context) => {
  'event': {'name': name, 'context': context},
};

String _iso(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// How far [now] moved from [before], as a share of [before]: `75 %`.
///
/// Always against the earlier month. A fall from 700 to 616 is 12 %, not the
/// 14 % that dividing by the later month gives.
String _change(int now, int before) => before <= 0
    ? ''
    : '${((now - before).abs() / before * 100).round()}'
          '${englishFormatting ? '' : '\u00a0'}%';

/// The 1st, the 2nd, the 19th.
String _ordinal(int n) {
  if (n % 100 >= 11 && n % 100 <= 13) return '${n}th';
  return switch (n % 10) {
    1 => '${n}st',
    2 => '${n}nd',
    3 => '${n}rd',
    _ => '${n}th',
  };
}

/// Small counts in words, as they are written in a sentence.
String _count(int n) => englishFormatting ? _countEn(n) : _countEs(n);

String _countEn(int n) => switch (n) {
  0 => 'none',
  1 => 'one',
  2 => 'two',
  3 => 'three',
  4 => 'four',
  5 => 'five',
  6 => 'six',
  7 => 'seven',
  8 => 'eight',
  9 => 'nine',
  _ => '$n',
};

String _countEs(int n) => switch (n) {
  0 => 'ninguna',
  1 => 'una',
  2 => 'dos',
  3 => 'tres',
  4 => 'cuatro',
  5 => 'cinco',
  6 => 'seis',
  7 => 'siete',
  8 => 'ocho',
  9 => 'nueve',
  _ => '$n',
};

String _capital(String s) =>
    s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

Object? _mutable(Object? value) => switch (value) {
  final Map<Object?, Object?> map => <String, Object?>{
    for (final MapEntry<Object?, Object?> e in map.entries)
      '${e.key}': _mutable(e.value),
  },
  final List<Object?> list => <Object?>[
    for (final Object? e in list) _mutable(e),
  ],
  _ => value,
};
