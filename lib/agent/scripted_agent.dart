import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:genui/genui.dart';

import '../data/category.dart';
import '../data/clock.dart';
import '../data/ledger.dart';
import '../format/dates.dart';
import '../format/money.dart';
import '../functions/money_functions.dart'
    show
        arrivalMonth,
        arrivesBy,
        contributionDay,
        contributionDays,
        contributionOn,
        monthlyNeeded;
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
        // silence, and these surfaces have sliders and switches. A real
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
    'How am I doing against August?',
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
                '${pesos(income - spent)} was left over',
              ),
        'body': _t(
          'Salieron ${pesos(spent)} de los ${pesos(income)} que te pagaron'
              '${savedForGoal > 0 ? ', y apartaste ${pesos(savedForGoal)} para Cartagena' : ''}.',
          '${pesos(spent)} went out of the ${pesos(income)} you were paid'
              '${savedForGoal > 0 ? ', and you put ${pesos(savedForGoal)} aside for Cartagena' : ''}.',
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
          'of ${pesos(income)} that came in',
        ),
        'tone': tight ? 'caution' : 'good',
      }),
      _c('tile_change', 'StatTile', {
        'label': _t('Contra $previous', 'Against $previous'),
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
                  'It came to ${pesos(ledger.spentOn(up.key, y, m))} against '
                      '${pesos(ledger.spentOn(up.key, py, pm))} in $previous: dinner on the '
                      '${_ordinal(biggestMeal.date.day)} at ${biggestMeal.merchant} and '
                      '${lunches - lunchesBefore} more lunches than the month before.',
                )
              : _t(
                  'Fueron ${pesos(ledger.spentOn(up.key, y, m))} contra '
                      '${pesos(ledger.spentOn(up.key, py, pm))} en $previous.',
                  'It came to ${pesos(ledger.spentOn(up.key, y, m))} against '
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
            'You spent ${pesos(ledger.spentOn(down.key, y, m))}, against '
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
    // The answer to the question comes first: what it takes each month,
    // what is set aside today and the contributions counted, none of which
    // the slider changes. What does change with it lives in the planner.
    final int needed = monthlyNeeded(
      goal.target.toDouble(),
      goal.saved.toDouble(),
      deadline,
    ).round();
    final int gap = needed - goal.monthly;
    final String counted = _contributions(
      contributionDays(until: goal.deadline),
    );

    Map<String, Object?> goalArgs([bool withDeadline = false]) => {
      'target': _path('/goal/target'),
      'saved': _path('/goal/saved'),
      'monthly': _path('/goal/monthly'),
      if (withDeadline) 'deadline': _path('/goal/deadline'),
    };

    return AgentTurn(
      components: <JsonMap>[
        _c('root', 'Answer', {
          'children': ['head', 'planner', 'save', 'room', 'next'],
        }),
        _c('head', 'Headline', {
          'kicker': _t('Tu meta', 'Your goal'),
          'title': gap > 0
              ? _t(
                  'Para llegar $deadlineLabel necesitas ${pesos(needed)} al '
                      'mes',
                  'To get there by $deadlineLabel you need ${pesos(needed)} '
                      'a month',
                )
              : _t(
                  'Sí: con ${pesos(goal.monthly)} al mes llegas antes del '
                      '${dayMonth(goal.deadline)}',
                  'Yes: at ${pesos(goal.monthly)} a month you get there '
                      'before ${dayMonth(goal.deadline)}',
                ),
          'body': gap > 0
              ? _t(
                  'Hoy apartas ${pesos(goal.monthly)}: te faltan '
                      '${pesos(gap)} al mes. $counted',
                  'You set aside ${pesos(goal.monthly)} now, so you are '
                      '${pesos(gap)} a month short. $counted',
                )
              : _t(
                  'Para llegar $deadlineLabel bastan ${pesos(needed)} al '
                      'mes. $counted',
                  'To get there by $deadlineLabel, ${pesos(needed)} a month '
                      'is enough. $counted',
                ),
        }),
        _c('planner', 'GoalPlanner', {
          'name': goal.name,
          'target': _path('/goal/target'),
          'saved': _path('/goal/saved'),
          'monthly': _path('/goal/monthly'),
          'current': _path('/goal/current'),
          'deadline': _path('/goal/deadline'),
          'contributionDay': contributionDay,
          'spendable': _path('/free'),
          'payday': _path('/payday'),
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
        // Right under what it saves: the slider is a simulation until this.
        _c('save', 'ActionButton', {
          'label': _t('Guardar este plan', 'Save this plan'),
          'emphasis': 'primary',
          'onPressed': _event('save_goal_plan', {
            'monthly': _path('/goal/monthly'),
          }),
        }),
        _c('room', 'Insight', {
          'tone': 'good',
          // What could be freed, never what the person should cut: the
          // choice is theirs.
          'title': _t(
            'Podrías liberar hasta ${pesos(stale + restaurantsBack)} al mes',
            'You could free up to ${pesos(stale + restaurantsBack)} a month',
          ),
          'body': _t(
            '${pesos(stale)} de dos suscripciones sin uso hace más de un mes.\n'
                '${pesos(restaurantsBack)} si restaurantes vuelve a lo de agosto.',
            '${pesos(stale)} from two subscriptions you haven\'t used in over '
                'a month.\n'
                '${pesos(restaurantsBack)} if eating out drops back to '
                'August\'s level.',
          ),
          'actionLabel': _t('Revisar suscripciones', 'Review subscriptions'),
          'onAction': _event('ask', {'question': _questions[2]}),
        }),
        ..._suggestions(<String>[_questions[2]]),
      ],
      data: {
        'goal': {
          'target': goal.target,
          'saved': goal.saved,
          'monthly': goal.monthly,
          'current': goal.monthly,
          'deadline': deadline,
        },
        'free': ledger.freeUntilPayday,
        'payday': _iso(ledger.nextPayday),
      },
    );
  }

  /// The contributions that land before a deadline, with their days.
  String _contributions(List<DateTime> days) {
    final String dates = listed(<String>[
      for (final DateTime d in days) dayMonthAhead(d),
    ]);
    return switch (days.length) {
      0 => _t(
        'Antes de esa fecha no cae ningún aporte.',
        'No contribution lands before then.',
      ),
      1 => _t('Cuento 1 aporte: el $dates.', 'One contribution fits: $dates.'),
      final int n => _t(
        'Cuento $n aportes: $dates.',
        '${_capital(_countEn(n))} contributions fit: $dates.',
      ),
    };
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
            'Fix anything that is off before saving.',
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
                'That is more than the account holds.',
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
            'Te quedan ${pesos(ledger.freeUntilPayday)} libres hasta el '
                '${dayMonth(ledger.nextPayday)}.',
            'You have ${pesos(ledger.freeUntilPayday)} free until '
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
    final Goal before = ledger.goal('cartagena');
    if (monthly <= 0) return _goal();
    // The plan is what the person chose, kept in the account's memory like
    // an expense, so the next answer starts from it. The money stays where
    // it is: the person moves it.
    final Goal goal = Goal(
      id: before.id,
      name: before.name,
      target: before.target,
      saved: before.saved,
      monthly: monthly.round(),
      deadline: before.deadline,
    );
    ledger.goals[ledger.goals.indexOf(before)] = goal;
    final String arrival = arrivalMonth(
      goal.target.toDouble(),
      goal.saved.toDouble(),
      monthly.toDouble(),
    );
    final bool onTime = arrivesBy(
      goal.target.toDouble(),
      goal.saved.toDouble(),
      monthly.toDouble(),
      _iso(goal.deadline),
    );
    final String first = dayMonthAhead(contributionOn(0));
    final String deadline = dayMonth(goal.deadline);
    return AgentTurn(
      components: <JsonMap>[
        _c('root', 'Answer', {
          'children': ['head', 'next'],
        }),
        _c('head', 'Headline', {
          'kicker': _t('Plan guardado', 'Plan saved'),
          'title': _t(
            'Tu plan: ${pesos(monthly)} al mes para ${goal.name}',
            'Your plan: ${pesos(monthly)} a month for ${goal.name}',
          ),
          'body': _t(
            'Quincena no mueve tu plata: pásala tú a tu bolsillo '
                '${goal.name} el $contributionDay de cada mes, desde el '
                '$first. Con este plan llegas en $arrival, '
                '${onTime ? 'antes' : 'después'} del $deadline.',
            'Quincena doesn\'t move your money: move it to your '
                '${goal.name} pocket yourself on the '
                '${_ordinal(contributionDay)} of each month, starting $first. '
                'With this plan you get there in $arrival, '
                '${onTime ? 'before' : 'after'} $deadline.',
          ),
        }),
        ..._suggestions(<String>[_questions[2]]),
      ],
    );
  }

  AgentTurn _subscriptions() {
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

    return AgentTurn(
      components: <JsonMap>[
        _c('root', 'Answer', {
          'children': [
            'head',
            'list',
            if (newest != null) 'newest',
            'cancel',
            'next',
          ],
        }),
        _c('head', 'Headline', {
          'kicker': _t('Suscripciones', 'Subscriptions'),
          'title': _t(
            'Pagas ${pesos(ledger.subscriptionsMonthly)} al mes en suscripciones',
            'You pay ${pesos(ledger.subscriptionsMonthly)} a month in subscriptions',
          ),
          'body': _t(
            'Son ${_count(subs.length)}. ${_capital(_count(stale.length))} '
                '${stale.length == 1 ? 'lleva' : 'llevan'} más de un mes sin '
                'usarse; ${stale.length == 1 ? 'la dejé apagada' : 'las dejé apagadas'} '
                'para que veas lo que ahorras.',
            'There are ${_count(subs.length)}. ${_capital(_count(stale.length))} '
                '${stale.length == 1 ? 'has' : 'have'} gone unused for over a '
                'month; I switched ${stale.length == 1 ? 'it' : 'them'} off so '
                'you can see what you would save.',
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
              'It is your second video service, and you used Cineplus more '
                  'this month.',
            ),
          }),
        _c('cancel', 'ActionButton', {
          'label': _t('Cancelar las apagadas', 'Cancel the ones switched off'),
          'emphasis': 'secondary',
          'onPressed': _event('cancel_subscriptions', {
            'items': _path('/subscriptions'),
          }),
        }),
        ..._suggestions(<String>[_questions[1]]),
      ],
      data: {
        'subscriptions': [
          for (final Subscription s in subs)
            {
              'name': s.name,
              'price': s.price,
              if (s.lastUsed case final DateTime used) 'lastUsed': _iso(used),
              'keep': !stale.contains(s),
            },
        ],
      },
    );
  }

  AgentTurn _cancelled(Map<String, Object?> context) {
    final Object? items = context['items'];
    final List<Map<Object?, Object?>> rows = items is List
        ? items.whereType<Map<Object?, Object?>>().toList()
        : const <Map<Object?, Object?>>[];
    final List<String> names = <String>[
      for (final Map<Object?, Object?> row in rows)
        if (row['keep'] == false) '${row['name']}',
    ];
    final num saved = rows
        .where((Map<Object?, Object?> row) => row['keep'] == false)
        .fold<num>(
          0,
          (num s, Map<Object?, Object?> row) =>
              s + ((row['price'] as num?) ?? 0),
        );

    return AgentTurn(
      components: <JsonMap>[
        _c('root', 'Answer', {
          'children': ['head', 'next'],
        }),
        _c('head', 'Headline', {
          'kicker': _t('Suscripciones', 'Subscriptions'),
          'title': names.isEmpty
              ? _t('No cancelé ninguna', 'Nothing was cancelled')
              : _t(
                  'Cancelo ${names.join(' y ')}',
                  'Cancelling ${names.join(' and ')}',
                ),
          'body': names.isEmpty
              ? _t('Todas siguen activas.', 'All of them are still active.')
              : _t(
                  'Te ahorras ${pesos(saved)} al mes desde el próximo cobro. '
                      'En la demo no se cancela nada de verdad.',
                  'You save ${pesos(saved)} a month from the next charge. '
                      'Nothing is really cancelled in the demo.',
                ),
        }),
        ..._suggestions(<String>[_questions[1]]),
      ],
    );
  }

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

    return AgentTurn(
      components: <JsonMap>[
        _c('root', 'Answer', {
          'children': ['head', 'tiles', 'bars', 'moved', 'next'],
        }),
        _c('head', 'Headline', {
          'kicker': _t(
            '${_capital(name)} contra $previous',
            '$name against $previous',
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
            'El salto está en ${top.where((t) => t.$2 > t.$3).map((t) => _inline(t.$1)).join(' y ')}.',
            'The jump is in ${top.where((t) => t.$2 > t.$3).map((t) => _inline(t.$1)).join(' and ')}.',
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
            '${all.length} payments for ${pesos(ledger.spentOn(category, y, m))}',
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
          'In the demo I answer these questions',
        ),
        'body': _t(
          'Con un modelo conectado puedes preguntar lo que quieras. Sin él, '
              'prueba una de estas.',
          'With a model connected you can ask anything. Without one, try '
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
