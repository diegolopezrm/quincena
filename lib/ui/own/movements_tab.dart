import 'package:flutter/material.dart';

import '../../capture/merchants.dart';
import '../../domain/records.dart';
import '../../l10n/l10n.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'look.dart';
import 'movement_list.dart';

/// Every movement, with a search over what it was, where and in which
/// account. A sliver: the days are built as they scroll into view, so a
/// long history costs only what shows.
class MovementsTab extends StatefulWidget {
  const MovementsTab({super.key, required this.own});

  final OwnController own;

  @override
  State<MovementsTab> createState() => _MovementsTabState();
}

class _MovementsTabState extends State<MovementsTab> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Whether [e] has [q], a query already [normalize]d, in what it was,
  /// its note, its category or its accounts: a transfer is found by either
  /// end. Accents do not count, as a phone's keyboard often leaves them out.
  bool _matches(BuildContext context, Entry e, String q) {
    final OwnController own = widget.own;
    final List<String> accounts = <String>[
      ?own.snapshot?.account(e.accountId)?.name,
      // The other end of a transfer: only a transfer looks for it.
      if (e.transferId case final String transfer)
        for (final Entry leg in own.snapshot?.entries ?? const <Entry>[])
          if (leg.transferId == transfer && leg.id != e.id)
            ?own.snapshot?.account(leg.accountId)?.name,
    ];
    final String category = e.category == null
        ? ''
        : categoryNameFor(context, e.category!, own.categories);
    return <String>[
      e.payee,
      e.note,
      ...accounts,
      category,
    ].any((String s) => normalize(s).contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final OwnController own = widget.own;
    final String q = normalize(_search.text);
    final List<Entry> all = visibleEntries(own);
    final List<Entry> shown = q.isEmpty
        ? all
        : all.where((Entry e) => _matches(context, e, q)).toList();
    return SliverMainAxisGroup(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 20),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: l.searchMovements,
                // Whole with large text too.
                hintMaxLines: largeText(context) ? 3 : null,
                prefixIcon: const Icon(Glyph.magnifyingGlass, size: 20),
              ),
            ),
          ),
        ),
        if (all.isEmpty)
          SliverToBoxAdapter(
            child: _Empty(title: l.noMovements, body: l.noMovementsBody),
          )
        else if (shown.isEmpty)
          SliverToBoxAdapter(
            child: Text(l.noResults, style: context.type.bodyMedium),
          )
        else
          MovementGroups.sliver(own: own, entries: shown),
      ],
    );
  }
}

/// What the list says before anything is recorded. A copy of Inicio's, so
/// the two tabs can change apart.
class _Empty extends StatelessWidget {
  const _Empty({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: context.colors.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(title, style: context.type.titleSmall),
        const SizedBox(height: 4),
        Text(body, style: context.type.bodyMedium),
      ],
    ),
  );
}
