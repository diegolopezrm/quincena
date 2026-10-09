import 'package:flutter/foundation.dart' show immutable;

/// The person themselves, in every group.
const String meId = 'me';

/// Someone in a group: the person, or anyone by the name they gave. Nobody
/// else needs the app, an account or a phone number.
@immutable
class Member {
  const Member({required this.id, required this.name});

  final String id;

  /// Empty for the person themselves.
  final String name;

  bool get isMe => id == meId;

  Map<String, Object?> toJson() => <String, Object?>{'id': id, 'name': name};

  static Member? fromJson(Object? json) {
    if (json is! Map || json['id'] is! String) return null;
    return Member(id: json['id']! as String, name: '${json['name'] ?? ''}');
  }
}

/// [total] in [count] parts that add up to it exactly. What rounding leaves
/// goes to the first part, so one person, the one who paid, carries it.
List<int> splitEvenly(int total, int count) {
  if (count <= 0) return const <int>[];
  final int part = total ~/ count;
  final int rest = total - part * count;
  return <int>[for (var i = 0; i < count; i++) part + (i == 0 ? rest : 0)];
}

/// An expense of a group: who paid it and each member's part of it. A loan
/// is one where the payer's own part is nothing.
@immutable
class SharedExpense {
  const SharedExpense({
    required this.id,
    required this.label,
    required this.date,
    required this.paidBy,
    required this.shares,
    this.entryId,
  });

  final String id;
  final String label;
  final DateTime date;
  final String paidBy;

  /// Each member's part, in the ledger's unit; they add up to [amount].
  final Map<String, int> shares;

  /// The movement in the person's accounts that paid it, when they did.
  final String? entryId;

  int get amount => shares.values.fold(0, (int sum, int v) => sum + v);

  /// What the others' parts add up to.
  int get othersPart => amount - (shares[paidBy] ?? 0);

  /// Whether it is a loan: the one who paid has no part of it.
  bool get isLoan => (shares[paidBy] ?? 0) == 0 && amount > 0;

  /// The same split of [total], for the movement it came from when its
  /// amount was put right: parts that were even stay even, the payer
  /// carrying what rounding leaves; uneven ones keep what each other
  /// person owes and the payer's part takes the difference, unless they
  /// owe more than the new total, which is then shared in the same
  /// proportions.
  SharedExpense resizedTo(int total) {
    if (total == amount || shares.isEmpty) return this;
    final List<String> ids = <String>[
      if (shares.containsKey(paidBy)) paidBy,
      for (final String id in shares.keys)
        if (id != paidBy) id,
    ];
    final List<int> parts = shares.values.toList();
    final int high = parts.reduce((int a, int b) => a > b ? a : b);
    final int low = parts.reduce((int a, int b) => a < b ? a : b);
    final Map<String, int> resized;
    if (high - low <= 1) {
      final List<int> even = splitEvenly(total, ids.length);
      resized = <String, int>{
        for (var i = 0; i < ids.length; i++) ids[i]: even[i],
      };
    } else if (othersPart <= total) {
      resized = <String, int>{...shares, paidBy: total - othersPart};
    } else {
      resized = <String, int>{
        for (final String id in ids)
          if (id != paidBy) id: shares[id]! * total ~/ amount,
      };
      final int rest =
          total - resized.values.fold(0, (int sum, int v) => sum + v);
      resized[paidBy] = (resized[paidBy] ?? 0) + rest;
    }
    return SharedExpense(
      id: id,
      label: label,
      date: date,
      paidBy: paidBy,
      shares: <String, int>{
        for (final MapEntry<String, int> s in resized.entries)
          if (s.value > 0) s.key: s.value,
      },
      entryId: entryId,
    );
  }

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'label': label,
    'date': date.toIso8601String(),
    'paidBy': paidBy,
    'shares': shares,
    if (entryId != null) 'entryId': entryId,
  };

  static SharedExpense? fromJson(Object? json) {
    if (json is! Map) return null;
    final DateTime? date = DateTime.tryParse('${json['date']}');
    final Object? shares = json['shares'];
    if (date == null || shares is! Map || json['paidBy'] is! String) {
      return null;
    }
    return SharedExpense(
      id: '${json['id']}',
      label: '${json['label'] ?? ''}',
      date: date,
      paidBy: json['paidBy']! as String,
      shares: <String, int>{
        for (final MapEntry<Object?, Object?> e in shares.entries)
          if (e.value is num) '${e.key}': (e.value! as num).round(),
      },
      entryId: json['entryId'] as String?,
    );
  }
}

/// Money one member gave another to settle up.
@immutable
class Settlement {
  const Settlement({
    required this.id,
    required this.from,
    required this.to,
    required this.amount,
    required this.date,
    this.entryId,
  });

  final String id;
  final String from;
  final String to;
  final int amount;
  final DateTime date;

  /// The movement in the person's accounts it came in or went out with.
  final String? entryId;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'from': from,
    'to': to,
    'amount': amount,
    'date': date.toIso8601String(),
    if (entryId != null) 'entryId': entryId,
  };

  static Settlement? fromJson(Object? json) {
    if (json is! Map) return null;
    final DateTime? date = DateTime.tryParse('${json['date']}');
    final Object? amount = json['amount'];
    if (date == null || amount is! num) return null;
    return Settlement(
      id: '${json['id']}',
      from: '${json['from']}',
      to: '${json['to']}',
      amount: amount.round(),
      date: date,
      entryId: json['entryId'] as String?,
    );
  }
}

/// One payment that settles part of a group.
@immutable
class Transfer {
  const Transfer(this.from, this.to, this.amount);

  final String from;
  final String to;
  final int amount;
}

/// People who share expenses: a trip, a flat, one dinner.
@immutable
class Group {
  const Group({
    required this.id,
    required this.name,
    required this.members,
    this.expenses = const <SharedExpense>[],
    this.settlements = const <Settlement>[],
  });

  final String id;
  final String name;

  /// The person first.
  final List<Member> members;
  final List<SharedExpense> expenses;
  final List<Settlement> settlements;

  Member? member(String id) =>
      members.where((Member m) => m.id == id).firstOrNull;

  /// Whether everything in it is a loan: what is settled in it pays a
  /// debt back, and is neither spent nor earned.
  bool get onlyLoans =>
      expenses.isNotEmpty && expenses.every((SharedExpense e) => e.isLoan);

  /// What each member is owed, positive, or owes, negative. They add up
  /// to nothing.
  Map<String, int> get balances {
    final Map<String, int> out = <String, int>{
      for (final Member m in members) m.id: 0,
    };
    void add(String id, int amount) => out[id] = (out[id] ?? 0) + amount;
    for (final SharedExpense e in expenses) {
      add(e.paidBy, e.amount);
      for (final MapEntry<String, int> s in e.shares.entries) {
        add(s.key, -s.value);
      }
    }
    for (final Settlement s in settlements) {
      add(s.from, s.amount);
      add(s.to, -s.amount);
    }
    return out;
  }

  /// The fewest payments that leave everyone even: whoever owes the most
  /// pays whoever is owed the most, until nothing is left.
  List<Transfer> get plan {
    final List<(String, int)> owe = <(String, int)>[];
    final List<(String, int)> owed = <(String, int)>[];
    for (final MapEntry<String, int> b in balances.entries) {
      if (b.value < 0) owe.add((b.key, -b.value));
      if (b.value > 0) owed.add((b.key, b.value));
    }
    int byAmount((String, int) a, (String, int) b) => b.$2.compareTo(a.$2);
    owe.sort(byAmount);
    owed.sort(byAmount);
    final List<Transfer> out = <Transfer>[];
    var i = 0;
    var j = 0;
    while (i < owe.length && j < owed.length) {
      final int amount = owe[i].$2 < owed[j].$2 ? owe[i].$2 : owed[j].$2;
      out.add(Transfer(owe[i].$1, owed[j].$1, amount));
      owe[i] = (owe[i].$1, owe[i].$2 - amount);
      owed[j] = (owed[j].$1, owed[j].$2 - amount);
      if (owe[i].$2 == 0) i++;
      if (owed[j].$2 == 0) j++;
    }
    return out;
  }

  /// Whether nobody owes anything.
  bool get settled => balances.values.every((int v) => v == 0);

  Group copyWith({
    String? name,
    List<Member>? members,
    List<SharedExpense>? expenses,
    List<Settlement>? settlements,
  }) => Group(
    id: id,
    name: name ?? this.name,
    members: members ?? this.members,
    expenses: expenses ?? this.expenses,
    settlements: settlements ?? this.settlements,
  );

  /// With [expense], or replacing the one with its id.
  Group withExpense(SharedExpense expense) => copyWith(
    expenses: <SharedExpense>[
      for (final SharedExpense e in expenses)
        if (e.id != expense.id) e,
      expense,
    ]..sort((SharedExpense a, SharedExpense b) => a.date.compareTo(b.date)),
  );

  Group withoutExpense(String id) => copyWith(
    expenses: <SharedExpense>[
      for (final SharedExpense e in expenses)
        if (e.id != id) e,
    ],
  );

  Group withSettlement(Settlement settlement) =>
      copyWith(settlements: <Settlement>[...settlements, settlement]);

  Group withoutSettlement(String id) => copyWith(
    settlements: <Settlement>[
      for (final Settlement s in settlements)
        if (s.id != id) s,
    ],
  );

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'name': name,
    'members': <Object?>[for (final Member m in members) m.toJson()],
    'expenses': <Object?>[for (final SharedExpense e in expenses) e.toJson()],
    'settlements': <Object?>[
      for (final Settlement s in settlements) s.toJson(),
    ],
  };

  static Group? fromJson(Object? json) {
    if (json is! Map || json['id'] is! String) return null;
    List<Object?> list(String key) => switch (json[key]) {
      final List<Object?> l => l,
      _ => const <Object?>[],
    };
    final List<Member> members = <Member>[
      for (final Object? m in list('members')) ?Member.fromJson(m),
    ];
    return Group(
      id: json['id']! as String,
      name: '${json['name'] ?? ''}',
      members: <Member>[
        if (!members.any((Member m) => m.isMe))
          const Member(id: meId, name: ''),
        ...members,
      ],
      expenses: <SharedExpense>[
        for (final Object? e in list('expenses')) ?SharedExpense.fromJson(e),
      ],
      settlements: <Settlement>[
        for (final Object? s in list('settlements')) ?Settlement.fromJson(s),
      ],
    );
  }
}

/// How the groups change the person's own movements, so nothing counts
/// twice: of an expense they paid for others, only their part is spending,
/// the rest is money lent; a repayment that came into an account is money
/// back, not income.
@immutable
class SharedLinks {
  const SharedLinks({
    this.lent = const <String, int>{},
    this.repaid = const <String, int>{},
  });

  /// What of each movement out is not spent, by its id: what others owe
  /// of what the person paid, a loan the person made, or a loan paid back.
  final Map<String, int> lent;

  /// What of each movement in is not earned, by its id: money paid back to
  /// the person, or lent to them.
  final Map<String, int> repaid;

  bool get isEmpty => lent.isEmpty && repaid.isEmpty;

  static SharedLinks of(Iterable<Group> groups) {
    final Map<String, int> lent = <String, int>{};
    final Map<String, int> repaid = <String, int>{};
    for (final Group g in groups) {
      for (final SharedExpense e in g.expenses) {
        final String? entry = e.entryId;
        if (entry == null) continue;
        if (e.paidBy == meId) {
          lent[entry] = (lent[entry] ?? 0) + e.othersPart;
        } else if (e.isLoan) {
          // Lent to the person: it came in, and it is owed, not earned.
          repaid[entry] = (repaid[entry] ?? 0) + (e.shares[meId] ?? 0);
        }
      }
      for (final Settlement s in g.settlements) {
        final String? entry = s.entryId;
        if (entry == null) continue;
        if (s.to == meId) {
          repaid[entry] = (repaid[entry] ?? 0) + s.amount;
        } else if (s.from == meId && g.onlyLoans) {
          // A loan paid back is not spent: the money was spent, or not,
          // when it came. The person's part of a shared bill is.
          lent[entry] = (lent[entry] ?? 0) + s.amount;
        }
      }
    }
    return SharedLinks(lent: lent, repaid: repaid);
  }
}
