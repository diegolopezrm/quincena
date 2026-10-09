import 'package:genui/genui.dart' show JsonMap;

import '../data/category.dart';
import '../format/dates.dart';
import '../format/money.dart';
import 'scripted_agent.dart' show AgentTurn, expenseTitle;

/// What the phone answers itself to what a person commits on a surface a
/// model wrote: an expense saved, a goal's plan saved, subscriptions marked
/// as cancelled.
///
/// The model wrote the form; saving it needs no model. The phone calls the
/// tool the model would have called and says what came of it, from what
/// the tool returned, in the catalog's components. So committing takes no
/// question of the day, works with no connection, and every figure in the
/// answer still comes from a tool.
class Receipts {
  const Receipts({this.language = 'es'});

  /// The language the answers are written in: `es` or `en`.
  final String language;

  bool get _en => language == 'en';

  /// The sentence in the answer's language, both written side by side.
  String _t(String es, String en) => _en ? en : es;

  /// An expense of [amount], in whole units, saved in [category]: from
  /// which account, and what can be spent until payday now. [saved] is
  /// what record_expense returned.
  AgentTurn expense(
    num amount,
    Category category,
    Map<Object?, Object?> saved,
  ) {
    final Object? free = saved['freeUntilPayday'];
    final DateTime? payday = parseDay(saved['nextPayday'] as String?);
    final Object? from = saved['account'];
    return AgentTurn(
      components: <JsonMap>[
        _c('root', 'Answer', <String, Object?>{
          'children': <String>['head', 'next'],
        }),
        _c('head', 'Headline', <String, Object?>{
          'kicker': _t('Guardado', 'Saved'),
          'title': expenseTitle(
            pesos(amount),
            category.labelIn(language).toLowerCase(),
            from: from is String && from.isNotEmpty ? from : null,
            language: language,
          ),
          if (free is num && payday != null)
            'body': _t(
              'Ahora puedes gastar ${pesos(free)} hasta el '
                  '${dayMonth(payday)}.',
              'Now you can spend ${pesos(free)} until ${dayMonth(payday)}.',
            ),
        }),
        ..._next(
          _t(
            '¿En qué se me fue la plata este mes?',
            'Where did my money go this month?',
          ),
        ),
      ],
    );
  }

  /// A goal's monthly amount saved: the plan, when it gets there, and that
  /// the person is the one who moves the money. [saved] is what
  /// save_goal_plan returned; null when it saved nothing.
  AgentTurn? plan(Map<Object?, Object?> saved) {
    final Object? name = saved['name'];
    final Object? monthly = saved['monthly'];
    final Object? arrival = saved['arrival'];
    final Object? day = saved['contributionDay'];
    final DateTime? deadline = parseDay(saved['deadline'] as String?);
    if (saved['saved'] != true || name is! String || monthly is! num) {
      return null;
    }
    final bool onTime = saved['arrivesByDeadline'] == true;
    final String when = switch ((arrival, deadline)) {
      (final String month, final DateTime by) => _t(
        ' Con este plan llegas en $month, '
            '${onTime ? 'antes' : 'después'} del ${dayMonth(by)}.',
        ' With this plan you get there in $month, '
            '${onTime ? 'before' : 'after'} ${dayMonth(by)}.',
      ),
      _ => '',
    };
    return AgentTurn(
      components: <JsonMap>[
        _c('root', 'Answer', <String, Object?>{
          'children': <String>['head', 'next'],
        }),
        _c('head', 'Headline', <String, Object?>{
          'kicker': _t('Plan guardado', 'Plan saved'),
          'title': _t(
            'Tu plan: ${pesos(monthly)} al mes para $name',
            'Your plan: ${pesos(monthly)} a month for $name',
          ),
          'body':
              (day is int
                  ? _t(
                      'Quincena no mueve tu plata: apártala tú el $day de '
                          'cada mes.',
                      "Quincena doesn't move your money: set it aside "
                          'yourself on the ${ordinal(day)} of each month.',
                    )
                  : _t(
                      'Quincena no mueve tu plata: apártala tú cada mes.',
                      "Quincena doesn't move your money: set it aside "
                          'yourself each month.',
                    )) +
              when,
        }),
        ..._next(
          _t(
            '¿Cuánto puedo gastar antes de que me paguen?',
            'How much can I spend before I get paid?',
          ),
        ),
      ],
    );
  }

  /// What the person says they did: cancelled the subscriptions they
  /// ticked in [context]'s list, each with its service. Quincena cancels
  /// nothing; the rows show struck through only now.
  AgentTurn cancelled(Map<String, Object?> context) {
    // The list the event carries, under whatever name the model gave it:
    // the prompt asks for the list, not for a key.
    final Object? items =
        context['items'] ??
        context.values.whereType<List<Object?>>().firstOrNull;
    final List<Map<Object?, Object?>> rows = items is List<Object?>
        ? <Map<Object?, Object?>>[
            for (final Map<Object?, Object?> row
                in items.whereType<Map<Object?, Object?>>())
              if (row['keep'] == false) row,
          ]
        : const <Map<Object?, Object?>>[];
    final String next = _t(
      '¿Cuánto puedo gastar antes de que me paguen?',
      'How much can I spend before I get paid?',
    );
    if (rows.isEmpty) {
      return AgentTurn(
        components: <JsonMap>[
          _c('root', 'Answer', <String, Object?>{
            'children': <String>['head', 'next'],
          }),
          _c('head', 'Headline', <String, Object?>{
            'kicker': _t('Suscripciones', 'Subscriptions'),
            'title': _t('No marcaste ninguna', "You didn't check any"),
            'body': _t(
              'Todas siguen activas. Marca en la lista las que quieras '
                  'cancelar.',
              'All of them are still active. Check the ones you want to '
                  'cancel in the list.',
            ),
          }),
          ..._next(next),
        ],
      );
    }
    final String names = _and(<String>[
      for (final Map<Object?, Object?> row in rows) '${row['name']}',
    ]);
    final num saves = rows.fold<num>(
      0,
      (num sum, Map<Object?, Object?> row) =>
          sum + ((row['price'] as num?) ?? 0),
    );
    return AgentTurn(
      components: <JsonMap>[
        _c('root', 'Answer', <String, Object?>{
          'children': <String>['head', 'done', 'next'],
        }),
        _c('head', 'Headline', <String, Object?>{
          'kicker': _t('Hecho por ti', 'Done by you'),
          'title': rows.length == 1
              ? _t('Cancelada: $names', 'Canceled: $names')
              : _t('Canceladas: $names', 'Canceled: $names'),
          'body': _t(
            'Desde el próximo cobro te ahorras ${pesos(saves)} al mes.',
            "Starting with the next charge, you'll save ${pesos(saves)} a "
                'month.',
          ),
        }),
        _c('done', 'Group', <String, Object?>{
          'title': _t('Las que cancelaste', 'What you canceled'),
          'children': <String>[for (var i = 0; i < rows.length; i++) 'row$i'],
        }),
        for (var i = 0; i < rows.length; i++)
          _c('row$i', 'SubscriptionRow', <String, Object?>{
            'name': '${rows[i]['name']}',
            'price': (rows[i]['price'] as num?) ?? 0,
            if (rows[i]['lastUsed'] case final String used) 'lastUsed': used,
            'keep': false,
            'cancelled': true,
          }),
        ..._next(next),
      ],
    );
  }

  /// One question to ask next, as a model ends its answers.
  List<JsonMap> _next(String question) => <JsonMap>[
    _c('next', 'Suggestions', <String, Object?>{
      'children': <String>['ask0'],
    }),
    _c('ask0', 'Suggestion', <String, Object?>{
      'label': question,
      'onPressed': <String, Object?>{
        'event': <String, Object?>{
          'name': 'ask',
          'context': <String, Object?>{'question': question},
        },
      },
    }),
  ];

  /// Names in a sentence: "a", "a y b", "a, b y c".
  String _and(List<String> items) => items.length < 2
      ? items.join()
      : '${items.take(items.length - 1).join(', ')} ${_t('y', 'and')} '
            '${items.last}';
}

JsonMap _c(String id, String component, Map<String, Object?> properties) =>
    <String, Object?>{'id': id, 'component': component, ...properties};
