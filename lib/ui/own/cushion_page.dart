import 'package:flutter/material.dart';

import '../../data/category.dart';
import '../../data/ledger.dart';
import '../../domain/plan.dart';
import '../../domain/records.dart';
import '../../format/dates.dart';
import '../../format/money.dart';
import '../../l10n/l10n.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../kit.dart';
import 'look.dart';

/// What the emergency fund the person chose adds up to.
int reserveOf(OwnController own, CushionSettings settings) {
  final Ledger? ledger = own.ledger;
  if (ledger == null) return 0;
  var sum = 0;
  for (final Account a in own.accounts) {
    if (!settings.accounts.contains(a.id)) continue;
    final Money? part = own.partOfTotal(a);
    if (part != null) sum += ledger.minor(part.amount.toDouble());
  }
  return sum;
}

/// The emergency fund as days of essential spending: which accounts hold
/// it, what counts as essential, how many days the person wants, and the
/// arithmetic in plain sight. No number is imposed.
class CushionPage extends StatelessWidget {
  const CushionPage({super.key, required this.own});

  final OwnController own;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: own,
    builder: (BuildContext context, _) {
      final AppLocalizations l = context.l10n;
      final String lang = Localizations.localeOf(context).languageCode;
      final Ledger? ledger = own.ledger;
      if (ledger == null) return Scaffold(appBar: AppBar());
      final CushionSettings s = own.cushionSettings;
      final CushionDays c = cushionDays(
        ledger,
        reserve: reserveOf(own, s),
        essentials: s.essentials,
      );
      String amount(int minor) => pesos(ledger.major(minor));
      Future<void> save(CushionSettings next) => own.saveCushionSettings(next);
      final int? target = s.targetDays;
      return Scaffold(
        appBar: AppBar(
          backgroundColor: context.colors.canvas,
          surfaceTintColor: Colors.transparent,
          title: Text(l.cushionDaysTitle, style: context.type.titleLarge),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: <Widget>[
                Block(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        switch (c.gap) {
                          null => l.cushionDaysCovers(c.days!),
                          CushionGap.noReserve => l.cushionDaysNoReserve,
                          CushionGap.shortHistory => l.cushionDaysShortHistory,
                          CushionGap.noEssentialSpending =>
                            l.cushionDaysNoEssential,
                        },
                        style: c.gap == null
                            ? context.type.headlineMedium
                            : context.type.titleMedium,
                      ),
                      if (c.gap == null) ...<Widget>[
                        const SizedBox(height: 6),
                        Text(
                          l.cushionDaysHow(
                            amount(c.reserve),
                            amount(c.dailyEssential),
                            dayShortMonth(c.from),
                            dayShortMonth(c.to),
                          ),
                          style: context.type.bodyMedium,
                        ),
                        if (target != null) ...<Widget>[
                          const SizedBox(height: 12),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(99),
                            child: LinearProgressIndicator(
                              value: (c.days! / target).clamp(0, 1).toDouble(),
                              minHeight: 8,
                              backgroundColor: context.colors.sunken,
                              color: context.colors.positive,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            c.days! >= target
                                ? l.cushionDaysReached(target)
                                : l.cushionDaysToGo(
                                    target - c.days!,
                                    amount(
                                      (target - c.days!) * c.dailyEssential,
                                    ),
                                  ),
                            style: context.type.bodySmall,
                          ),
                        ],
                      ],
                      const SizedBox(height: 8),
                      Text(
                        l.cushionDaysEstimate,
                        style: context.type.bodySmall,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SectionLabel(l.cushionDaysAccounts),
                Panel(
                  indent: 16,
                  children: <Widget>[
                    // Where an emergency fund can be: money, not a card's
                    // debt or coins whose price moves; one chosen before
                    // stays, to take it out.
                    for (final Account a in own.accounts)
                      if ((a.kind != AccountKind.card &&
                              a.kind != AccountKind.exchange &&
                              !a.asset.isCrypto) ||
                          s.accounts.contains(a.id))
                        CheckboxListTile(
                          value: s.accounts.contains(a.id),
                          onChanged: (bool? on) => save(
                            s.copyWith(
                              accounts: <String>{
                                for (final String id in s.accounts)
                                  if (id != a.id) id,
                                if (on ?? false) a.id,
                              },
                            ),
                          ),
                          title: Text(a.name, style: context.type.titleSmall),
                          subtitle: Text(
                            moneyText(
                              own.balances[a.id] ?? a.openingMoney,
                              base: own.profile?.base,
                            ),
                            style: context.type.bodySmall,
                          ),
                        ),
                  ],
                ),
                // Two things carry the cushion's name: this only measures.
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l.cushionDaysOnlyMeasures,
                    style: context.type.bodySmall,
                  ),
                ),
                const SizedBox(height: 24),
                SectionLabel(l.cushionDaysEssentials),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    for (final Category cat in Category.values)
                      if (cat != Category.other)
                        FilterChip(
                          label: Text(cat.labelIn(lang)),
                          selected: s.essentials.contains(cat),
                          onSelected: (bool on) => save(
                            s.copyWith(
                              essentials: <Category>{
                                for (final Category x in s.essentials)
                                  if (x != cat) x,
                                if (on) cat,
                              },
                            ),
                          ),
                        ),
                  ],
                ),
                const SizedBox(height: 24),
                SectionLabel(l.cushionDaysTarget),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    ChoiceChip(
                      label: Text(l.cushionDaysNoTarget),
                      selected: target == null,
                      onSelected: (_) => save(s.copyWith(clearTarget: true)),
                    ),
                    for (final int days in <int>[30, 60, 90, 180])
                      ChoiceChip(
                        label: Text(l.cushionDaysOption(days)),
                        selected: target == days,
                        onSelected: (_) => save(s.copyWith(targetDays: days)),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(l.cushionDaysTargetNote, style: context.type.bodySmall),
              ],
            ),
          ),
        ),
      );
    },
  );
}
