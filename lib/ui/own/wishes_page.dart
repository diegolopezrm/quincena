import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/ledger.dart';
import '../../domain/plan.dart';
import '../../format/dates.dart';
import '../../format/money.dart';
import '../../l10n/l10n.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import '../kit.dart';
import 'amount_input.dart';
import 'coming_days_page.dart';
import 'look.dart';

/// Things wanted for later: a price typed by hand, a priority, and maybe a
/// wait before deciding. No shop is watched and nothing is bought here.
class WishesPage extends StatelessWidget {
  const WishesPage({super.key, required this.own});

  final OwnController own;

  Future<void> _add(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: context.colors.surface,
    constraints: const BoxConstraints(maxWidth: 560),
    builder: (BuildContext context) => _WishSheet(own: own),
  );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: own,
    builder: (BuildContext context, _) {
      final AppLocalizations l = context.l10n;
      final Ledger? ledger = own.ledger;
      final List<Wish> wishes = <Wish>[...own.wishes]
        ..sort((Wish a, Wish b) => a.priority.compareTo(b.priority));
      return Scaffold(
        appBar: AppBar(
          backgroundColor: context.colors.canvas,
          surfaceTintColor: Colors.transparent,
          title: Text(l.wishesTitle, style: context.type.titleLarge),
        ),
        floatingActionButton: ScrollAwareFab(
          child: FloatingActionButton.extended(
            onPressed: () => _add(context),
            icon: const Icon(Glyph.plus),
            label: Text(l.wishAdd),
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: <Widget>[
                Text(l.wishesBody, style: context.type.bodyMedium),
                const SizedBox(height: 16),
                if (wishes.isEmpty)
                  Block(
                    child: Text(l.wishesEmpty, style: context.type.bodyMedium),
                  ),
                if (ledger != null)
                  for (final Wish w in wishes) ...<Widget>[
                    _WishCard(own: own, ledger: ledger, wish: w),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

class _WishCard extends StatelessWidget {
  const _WishCard({
    required this.own,
    required this.ledger,
    required this.wish,
  });

  final OwnController own;
  final Ledger ledger;
  final Wish wish;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    String amount(int minor) => pesos(ledger.major(minor));
    final DateTime? wait = wish.waitUntil;
    final bool waiting = wait != null && wait.isAfter(ledger.today);
    final DateTime from = own.today;
    return Block(
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(wish.name, style: context.type.titleSmall),
                    Text(switch (wish.priority) {
                      1 => l.wishPriorityHigh,
                      3 => l.wishPriorityLow,
                      _ => l.wishPriorityMedium,
                    }, style: context.type.bodySmall),
                  ],
                ),
              ),
              Figures(amount(wish.price), style: context.type.titleSmall),
              IconButton(
                tooltip: l.wishRemove,
                onPressed: () => own.saveWishes(<Wish>[
                  for (final Wish w in own.wishes)
                    if (w.id != wish.id) w,
                ]),
                icon: Icon(
                  Glyph.trash,
                  size: 18,
                  color: context.colors.inkFaint,
                ),
              ),
            ],
          ),
          if (waiting)
            Text(
              l.wishWaiting(dayMonth(wait)),
              style: context.type.bodySmall?.copyWith(
                color: context.colors.brand,
              ),
            ),
          // What it would do to each goal that gets money every month.
          for (final GoalShare g in own.goalShares)
            if (arrival(g, from: from) case final DateTime before)
              if (arrival(g, from: from, extra: -wish.price)
                  case final DateTime after)
                if (after != before)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 8),
                    child: Text(
                      l.wishAgainstGoal(
                        g.name,
                        monthYear(after),
                        monthYear(before),
                      ),
                      style: context.type.bodySmall,
                    ),
                  ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => ComingDaysPage(
                    own: own,
                    tryPurchase: true,
                    price: wish.price,
                    label: wish.name,
                  ),
                ),
              ),
              icon: const Icon(Glyph.shoppingBag, size: 18),
              label: Text(l.buyTitle),
            ),
          ),
        ],
      ),
    );
  }
}

class _WishSheet extends StatefulWidget {
  const _WishSheet({required this.own});

  final OwnController own;

  @override
  State<_WishSheet> createState() => _WishSheetState();
}

class _WishSheetState extends State<_WishSheet> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _price = TextEditingController();
  int _priority = 2;
  bool _wait = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final AppLocalizations l = context.l10n;
    final Ledger? ledger = widget.own.ledger;
    final Decimal? price = parseAmount(_price.text);
    if (ledger == null ||
        _name.text.trim().isEmpty ||
        price == null ||
        price <= Decimal.zero) {
      setState(() => _error = l.wishIncomplete);
      return;
    }
    final DateTime today = widget.own.today;
    await widget.own.saveWishes(<Wish>[
      ...widget.own.wishes,
      Wish(
        id: 'wish-${DateTime.now().microsecondsSinceEpoch}',
        name: _name.text.trim(),
        price: ledger.minor(price.toDouble()),
        priority: _priority,
        waitUntil: _wait
            ? DateTime(today.year, today.month, today.day + 30)
            : null,
      ),
    ]);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(l.wishAdd, style: context.type.headlineMedium),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.wishName),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: <TextInputFormatter>[AmountInputFormatter()],
              decoration: InputDecoration(
                labelText: l.wishPrice,
                prefixText: r'$ ',
              ),
            ),
            const SizedBox(height: 16),
            SegmentedButton<int>(
              showSelectedIcon: false,
              segments: <ButtonSegment<int>>[
                ButtonSegment<int>(value: 1, label: Text(l.wishPriorityHigh)),
                ButtonSegment<int>(value: 2, label: Text(l.wishPriorityMedium)),
                ButtonSegment<int>(value: 3, label: Text(l.wishPriorityLow)),
              ],
              selected: <int>{_priority},
              onSelectionChanged: (Set<int> s) =>
                  setState(() => _priority = s.single),
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _wait,
              onChanged: (bool v) => setState(() => _wait = v),
              title: Text(l.wishWait, style: context.type.titleSmall),
              subtitle: Text(l.wishWaitHelp, style: context.type.bodySmall),
            ),
            if (_error case final String error)
              Text(
                error,
                style: context.type.bodySmall?.copyWith(
                  color: context.colors.negative,
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: Text(l.save)),
          ],
        ),
      ),
    );
  }
}
