import 'package:flutter/material.dart';

import '../../capture/merchants.dart';
import '../../domain/records.dart';
import '../../l10n/l10n.dart';
import '../../money/money.dart';
import '../../own/movement_search.dart';
import '../../own/own_controller.dart';
import '../../store/store.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'look.dart';
import 'movement_filters.dart';
import 'movement_list.dart';

/// Every movement, with a search over what it was, where, in which account
/// and for how much, and filters by account, category, type, dates and
/// amount. A sliver: the days are built as they scroll into view, so a
/// long history costs only what shows.
class MovementsTab extends StatefulWidget {
  const MovementsTab({super.key, required this.own});

  final OwnController own;

  @override
  State<MovementsTab> createState() => _MovementsTabState();
}

class _MovementsTabState extends State<MovementsTab> {
  final TextEditingController _search = TextEditingController();
  MovementFilter _filter = const MovementFilter();

  /// The finder for the movements as they are, in the language they are
  /// searched in: made again only when either changes.
  MovementFinder? _finder;
  (StoreSnapshot, String)? _finderFor;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  MovementFinder? _finderOf(BuildContext context) {
    final OwnController own = widget.own;
    final StoreSnapshot? snapshot = own.snapshot;
    if (snapshot == null) return null;
    final String language = Localizations.localeOf(context).languageCode;
    final (StoreSnapshot, String)? made = _finderFor;
    if (made == null || !identical(made.$1, snapshot) || made.$2 != language) {
      _finderFor = (snapshot, language);
      _finder = MovementFinder(
        snapshot: snapshot,
        categoryName: (String key) =>
            categoryNameFor(context, key, own.categories),
        today: own.today,
        schedule: snapshot.profile.schedule,
      );
    }
    return _finder;
  }

  /// Whether what is typed searches anything: signs alone do not.
  bool get _searching =>
      normalize(_search.text).isNotEmpty || amountsIn(_search.text).isNotEmpty;

  void _setFilter(MovementFilter filter) => setState(() => _filter = filter);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final OwnController own = widget.own;
    final List<Entry> all = visibleEntries(own);
    final MovementFinder? finder = _finderOf(context);
    final bool narrowed = _searching || !_filter.isEmpty;
    final List<Entry> shown = !narrowed || finder == null
        ? all
        : finder.find(all, query: _search.text, filter: _filter);
    final Widget field = TextField(
      controller: _search,
      onChanged: (_) => setState(() {}),
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: l.searchMovements,
        // Whole with large text too.
        hintMaxLines: largeText(context) ? 3 : null,
        prefixIcon: const Icon(Glyph.magnifyingGlass, size: 20),
        suffixIcon: _search.text.isEmpty
            ? null
            : IconButton(
                tooltip: l.searchClear,
                onPressed: () => setState(_search.clear),
                icon: const Icon(Glyph.x, size: 18),
              ),
      ),
    );
    final Widget filters = IconButton(
      tooltip: l.filterOpen,
      isSelected: !_filter.isEmpty,
      style: IconButton.styleFrom(
        backgroundColor: _filter.isEmpty ? null : context.colors.brandSoft,
      ),
      onPressed: finder == null
          ? null
          : () => showMovementFilters(
              context,
              own: own,
              filter: _filter,
              entries: all,
              count: (MovementFilter filter) =>
                  finder.find(all, query: _search.text, filter: filter).length,
              onChanged: _setFilter,
            ),
      // How many filters are on, said in ink on the selected button: a
      // count of what was chosen, not something that waits.
      icon: Badge(
        isLabelVisible: !_filter.isEmpty,
        label: Text('${_filter.active}'),
        backgroundColor: context.colors.ink,
        textColor: context.colors.surface,
        child: const Icon(Glyph.funnel),
      ),
    );
    return SliverMainAxisGroup(
      slivers: <Widget>[
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: <Widget>[
                Expanded(child: field),
                const SizedBox(width: 8),
                filters,
              ],
            ),
          ),
        ),
        if (!_filter.isEmpty)
          SliverToBoxAdapter(
            child: ActiveFilters(
              own: own,
              filter: _filter,
              onChanged: _setFilter,
            ),
          ),
        if (all.isEmpty)
          SliverToBoxAdapter(
            child: _Empty(title: l.noMovements, body: l.noMovementsBody),
          )
        else if (shown.isEmpty)
          SliverToBoxAdapter(
            child: Text(
              !_searching
                  ? l.noResultsFilters
                  : _filter.isEmpty
                  ? l.noResults
                  : l.noResultsBoth,
              style: context.type.bodyMedium,
            ),
          )
        else ...<Widget>[
          if (narrowed && finder != null)
            SliverToBoxAdapter(
              child: _Found(own: own, finder: finder, found: shown),
            ),
          MovementGroups.sliver(own: own, entries: shown),
        ],
      ],
    );
  }
}

/// How many movements a search or a filter found, and what they add up
/// to in each currency.
class _Found extends StatelessWidget {
  const _Found({required this.own, required this.finder, required this.found});

  final OwnController own;
  final MovementFinder finder;
  final List<Entry> found;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    final List<Money> totals = finder.totals(found);
    final bool transfers =
        totals.isNotEmpty && found.any((Entry e) => e.isTransfer);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            <String>[
              l.foundCount(found.length),
              for (final Money m in totals)
                moneyText(m, base: own.profile?.base, signed: true),
            ].join(' · '),
            style: context.type.titleSmall,
          ),
          if (transfers)
            Text(l.foundLeavesTransfers, style: context.type.bodySmall),
        ],
      ),
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
