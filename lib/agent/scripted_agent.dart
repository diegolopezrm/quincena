import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:genui/genui.dart';

import '../data/category.dart';
import '../data/clock.dart';
import '../data/ledger.dart';
import '../format/dates.dart';
import '../format/money.dart';
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
  ScriptedAgent(this.ledger);

  final Ledger ledger;

  /// The questions the demo offers, in the order they tell the story.
  static const List<String> starters = <String>[
    '¿En qué se me fue la plata en septiembre?',
    '¿Me alcanza para ir a Cartagena en diciembre?',
    '¿Qué suscripciones tengo?',
    '¿Cómo voy contra agosto?',
    'Registra 45 mil en el mercado',
  ];

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

  String _monthName(int year, int month) =>
      monthYear(DateTime(year, month)).split(' ').first;

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
            ? 'Gastaste casi todo lo que entró'
            : 'Te sobraron ${pesos(income - spent)}',
        'body':
            'Salieron ${pesos(spent)} de los ${pesos(income)} que te pagaron'
            '${savedForGoal > 0 ? ', y apartaste ${pesos(savedForGoal)} para Cartagena' : ''}.',
      }),
      _c('tiles', 'Tiles', {
        'children': ['tile_spent', 'tile_change'],
      }),
      _c('tile_spent', 'StatTile', {
        'label': 'Gastado en $name',
        'value': _call('money', {'amount': _path('/spent')}),
        'caption': 'de ${pesos(income)} que entraron',
        'tone': tight ? 'caution' : 'good',
      }),
      _c('tile_change', 'StatTile', {
        'label': 'Contra $previous',
        'value': _call('percentChange', {
          'current': _path('/spent'),
          'previous': _path('/previous'),
        }),
        'caption': '${pesos(ledger.spentIn(py, pm))} en $previous',
        'tone': spent > ledger.spentIn(py, pm) ? 'caution' : 'good',
      }),
      _c('donut', 'SpendingDonut', {
        'title': 'Por categoría',
        'slices': _path('/byCategory'),
        'centerLabel': name,
      }),
      if (up != null)
        _c('up', 'Insight', {
          'tone': up.value > 0.3 ? 'alert' : 'caution',
          'title':
              '${categoryLabel[up.key]} subió '
              '${_change(ledger.spentOn(up.key, y, m), ledger.spentOn(up.key, py, pm))}',
          'body': up.key == Category.restaurants && biggestMeal != null
              ? 'Fueron ${pesos(ledger.spentOn(up.key, y, m))} contra '
                    '${pesos(ledger.spentOn(up.key, py, pm))} en $previous: la cena del '
                    '${biggestMeal.date.day} en ${biggestMeal.merchant} y '
                    '${lunches - lunchesBefore} almuerzos más que el mes pasado.'
              : 'Fueron ${pesos(ledger.spentOn(up.key, y, m))} contra '
                    '${pesos(ledger.spentOn(up.key, py, pm))} en $previous.',
          'actionLabel': 'Ver esos pagos',
          'onAction': _event('show_category', {'category': up.key.name}),
        }),
      if (down != null && down.value < 0)
        _c('down', 'Insight', {
          'tone': 'good',
          'title':
              '${categoryLabel[down.key]} bajó '
              '${_change(ledger.spentOn(down.key, y, m), ledger.spentOn(down.key, py, pm))}',
          'body':
              'Gastaste ${pesos(ledger.spentOn(down.key, y, m))}, contra '
              '${pesos(ledger.spentOn(down.key, py, pm))} en $previous.',
        }),
      _c('largest', 'MovementList', {
        'title': 'Los cinco pagos más grandes',
        'items': _path('/largest'),
      }),
      ..._suggestions(<String>[
        '¿Me alcanza para ir a Cartagena en diciembre?',
        '¿Cómo voy contra agosto?',
      ]),
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
        .where((s) => appToday.difference(s.lastUsed).inDays > 30)
        .fold(cut, (int sum, s) => sum + s.price);
    final (int y, int m) = _lastMonth;
    final (int py, int pm) = _monthBefore;
    final int restaurantsBack =
        ledger.spentOn(Category.restaurants, y, m) -
        ledger.spentOn(Category.restaurants, py, pm);
    final String deadline = _iso(goal.deadline);
    final String deadlineLabel = 'el ${dayMonth(goal.deadline)}';

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
          'kicker': 'Tu meta',
          'title': 'A este ritmo llegas después del viaje',
          'body':
              'Llevas ${pesos(goal.saved)} de ${pesos(goal.target)}. Con '
              '${pesos(goal.monthly)} al mes no alcanzas para $deadlineLabel. '
              'Mueve el control para ver cuánto necesitas.',
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
        }),
        _c('tiles', 'Tiles', {
          'children': ['need', 'free'],
        }),
        _c('need', 'StatTile', {
          'label': 'Necesitas al mes',
          'value': _call('money', {
            'amount': _call('monthlyNeeded', {
              'target': _path('/goal/target'),
              'saved': _path('/goal/saved'),
              'deadline': _path('/goal/deadline'),
            }),
          }),
          'caption': 'para llegar $deadlineLabel',
        }),
        _c('free', 'StatTile', {
          'label': 'Libre hasta el ${ledger.nextPayday.day}',
          'value': _call('money', {'amount': _path('/free')}),
          'caption': 'después de arriendo y pagos fijos',
        }),
        _c('room', 'Insight', {
          'tone': 'good',
          'title': 'Hay de dónde sacar ${pesos(stale + restaurantsBack)}',
          'body':
              'Dos suscripciones llevan más de un mes sin uso '
              '(${pesos(stale)}), y si restaurantes vuelve a lo de agosto son '
              '${pesos(restaurantsBack)} más.',
          'actionLabel': 'Revisar suscripciones',
          'onAction': _event('ask', {'question': '¿Qué suscripciones tengo?'}),
        }),
        _c('save', 'ActionButton', {
          'label': 'Apartar esto cada mes',
          'emphasis': 'primary',
          'onPressed': _event('save_goal_plan', {
            'monthly': _path('/goal/monthly'),
          }),
        }),
        ..._suggestions(<String>['¿Qué suscripciones tengo?']),
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
    final String label = categoryLabel[category]!.toLowerCase();
    return AgentTurn(
      components: <JsonMap>[
        _c('root', 'Answer', {
          'children': ['head', 'form'],
        }),
        _c('head', 'Headline', {
          'kicker': 'Nuevo gasto',
          'title': amount > 0
              ? 'Anoto ${pesos(amount)} en $label'
              : 'Anoto un gasto en $label',
          'body': 'Corrige lo que haga falta antes de guardar.',
        }),
        _c('form', 'Group', {
          'title': 'Hoy, ${dayMonth(appToday)}',
          'children': ['amount', 'category', 'note', 'save'],
        }),
        _c('amount', 'MoneyField', {
          'label': 'Monto',
          'value': _path('/draft/amount'),
          'checks': [
            {
              'condition': _call('numeric', {
                'value': _path('/draft/amount'),
                'min': 1,
              }),
              'message': 'Escribe un monto mayor que cero.',
            },
            {
              'condition': _call('numeric', {
                'value': _path('/draft/amount'),
                'max': ledger.balance,
              }),
              'message': 'Es más de lo que hay en la cuenta.',
            },
          ],
        }),
        _c('category', 'CategoryChoice', {
          'label': 'Categoría',
          'value': _path('/draft/category'),
        }),
        _c('note', 'TextEntry', {
          'label': 'Dónde',
          'value': _path('/draft/note'),
          'hint': 'Opcional, como "Tienda Don Pacho"',
        }),
        _c('save', 'ActionButton', {
          'label': 'Guardar gasto',
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
        merchant: note.isEmpty ? categoryLabel[category]! : note,
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
          'kicker': 'Guardado',
          'title':
              'Listo: ${pesos(amount)} en ${categoryLabel[category]!.toLowerCase()}',
          'body':
              'Te quedan ${pesos(ledger.freeUntilPayday)} libres hasta el '
              '${dayMonth(ledger.nextPayday)}.',
        }),
        _c('meter', 'BudgetMeter', {
          'category': category.name,
          'spent': ledger.spentOn(category, _year, _month),
          'limit': ledger.spentOn(category, y, m),
          'caption': 'lo de ${_monthName(y, m)}',
        }),
        ..._suggestions(<String>[
          '¿Me alcanza para ir a Cartagena en diciembre?',
        ]),
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
          'kicker': 'Meta ${goal.name}',
          'title': 'Cada día 16 aparto ${pesos(monthly)}',
          'body':
              'Empiezo el ${dayMonth(DateTime(_year, _month, 16))}. Si un mes '
              'no alcanza, te aviso antes de mover la plata.',
        }),
        ..._suggestions(<String>['¿Qué suscripciones tengo?']),
      ],
    );
  }

  AgentTurn _subscriptions() {
    final List<Subscription> subs = ledger.subscriptions;
    final List<Subscription> stale = subs
        .where((Subscription s) => appToday.difference(s.lastUsed).inDays > 30)
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
          'kicker': 'Suscripciones',
          'title':
              'Pagas ${pesos(ledger.subscriptionsMonthly)} al mes en suscripciones',
          'body':
              'Son ${subs.length}. ${stale.length == 2 ? 'Dos' : stale.length} '
              'llevan más de un mes sin usarse; las dejé apagadas para que '
              'veas lo que ahorras.',
        }),
        _c('list', 'SubscriptionList', {
          'title': 'Tus suscripciones',
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
            'title':
                '${newest.name} empezó en ${_monthName(newest.since.year, newest.since.month)}',
            'body':
                'Es tu segundo servicio de video, y a Cineplus le sacaste '
                'más uso este mes.',
          }),
        _c('cancel', 'ActionButton', {
          'label': 'Cancelar las apagadas',
          'emphasis': 'secondary',
          'onPressed': _event('cancel_subscriptions', {
            'items': _path('/subscriptions'),
          }),
        }),
        ..._suggestions(<String>[
          '¿Me alcanza para ir a Cartagena en diciembre?',
        ]),
      ],
      data: {
        'subscriptions': [
          for (final Subscription s in subs)
            {
              'name': s.name,
              'price': s.price,
              'lastUsed': _iso(s.lastUsed),
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
          'kicker': 'Suscripciones',
          'title': names.isEmpty
              ? 'No cancelé ninguna'
              : 'Cancelo ${names.join(' y ')}',
          'body': names.isEmpty
              ? 'Todas siguen activas.'
              : 'Te ahorras ${pesos(saved)} al mes desde el próximo cobro. '
                    'En la demo no se cancela nada de verdad.',
        }),
        ..._suggestions(<String>[
          '¿Me alcanza para ir a Cartagena en diciembre?',
        ]),
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
          'kicker': '${_capital(name)} contra $previous',
          'title': spent > before
              ? 'Gastaste ${pesos(spent - before)} más que en $previous'
              : 'Gastaste ${pesos(before - spent)} menos que en $previous',
          'body':
              'El salto está en ${top.where((t) => t.$2 > t.$3).map((t) => categoryLabel[t.$1]!.toLowerCase()).join(' y ')}.',
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
          'title': 'Últimos seis meses',
          'months': _path('/months'),
          'reference': ledger.incomeIn(y, m),
          'referenceLabel': 'Ingresos',
        }),
        _c('moved', 'Group', {
          'title': 'Lo que más cambió',
          'children': [for (var i = 0; i < top.length; i++) 'meter$i'],
        }),
        for (var i = 0; i < top.length; i++)
          _c('meter$i', 'BudgetMeter', {
            'category': top[i].$1.name,
            'spent': top[i].$2,
            'limit': top[i].$3,
            'caption': 'lo de $previous',
          }),
        ..._suggestions(<String>['¿En qué se me fue la plata en septiembre?']),
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
          'kicker': '${categoryLabel[category]} · ${_monthName(y, m)}',
          'title':
              '${all.length} pagos por ${pesos(ledger.spentOn(category, y, m))}',
          'body': sorted.isEmpty
              ? null
              : 'El más grande fue ${sorted.first.merchant}, el '
                    '${dayMonth(sorted.first.date)}.',
        }),
        _c('list', 'MovementList', {
          'title': 'Los diez más grandes',
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
        'kicker': 'Modo demo',
        'title': 'En la demo respondo estas preguntas',
        'body':
            'Con un modelo conectado puedes preguntar lo que quieras. Sin él, '
            'prueba una de estas.',
      }),
      ..._suggestions(starters),
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
String _change(int now, int before) =>
    before <= 0 ? '' : '${((now - before).abs() / before * 100).round()} %';

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
