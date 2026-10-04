import 'package:flutter/material.dart';

import '../../domain/records.dart';
import '../../l10n/l10n.dart';
import '../../money/asset.dart';
import '../../money/money.dart';
import '../../own/own_controller.dart';
import '../../theme/tokens.dart';
import '../icons.dart';
import 'account_sheet.dart';
import 'balance_explained.dart';
import 'entry_sheet.dart';
import 'look.dart';
import 'movement_list.dart';
import 'portfolio_page.dart';
import 'position_panel.dart';
import 'statement_page.dart';

/// One account: what it holds today and every movement in it.
class AccountPage extends StatelessWidget {
  const AccountPage({super.key, required this.own, required this.accountId});

  final OwnController own;
  final String accountId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: own,
      builder: (BuildContext context, _) {
        final AppLocalizations l = context.l10n;
        final Account? account = own.snapshot?.account(accountId);
        if (account == null) {
          // Deleted from its own sheet: nothing left to show.
          return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
        }
        final Money balance = own.balances[account.id] ?? account.openingMoney;
        // A card's balance is what is owed on it, never money of another
        // sign, as in its row.
        final bool card = account.kind == AccountKind.card;
        final Money shown = card ? balance.abs() : balance;
        final Money? converted = account.asset == own.profile?.base
            ? null
            : own.inBase(shown);
        final Asset? base = own.profile?.base;
        // What is left of a card's limit, under what it owes.
        final Money? left = account.creditLeft(balance);
        final String detail = <String>[
          if (converted != null) '≈ ${moneyText(converted, base: base)}',
          if (left != null)
            l.cardCreditLeftOf(
              moneyText(left, base: base),
              moneyText(Money(account.creditLimit!, account.asset), base: base),
            ),
        ].join('\n');
        final List<Entry> entries = visibleEntries(own, accountId: account.id);
        return Scaffold(
          appBar: AppBar(
            backgroundColor: context.colors.canvas,
            surfaceTintColor: Colors.transparent,
            title: Text(account.name, style: context.type.titleLarge),
            actions: <Widget>[
              if (!account.asset.isCrypto)
                IconButton(
                  tooltip: l.statementTitle,
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (BuildContext context) =>
                          StatementPage(own: own, accountId: account.id),
                    ),
                  ),
                  icon: const Icon(Glyph.fileText),
                ),
              IconButton(
                tooltip: l.editAccount,
                onPressed: () =>
                    showAccountSheet(context, own: own, account: account),
                icon: const Icon(Glyph.pencilSimple),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            tooltip: l.addMovement,
            onPressed: () =>
                showEntrySheet(context, own: own, accountId: account.id),
            child: const Icon(Glyph.plus),
          ),
          body: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      if (account.asset.isCrypto)
                        CoinMark(account.asset, size: 48)
                      else
                        AccountTile(account.kind, size: 48),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Headline(
                          caption: !card || balance.isZero
                              ? l.balanceToday
                              : balance.isNegative
                              ? l.cardOwedLabel
                              : l.cardInFavorLabel,
                          onExplain: () =>
                              showAccountExplained(context, own, account),
                          value: card && balance.isZero
                              ? l.cardClear
                              : moneyText(shown, base: own.profile?.base),
                          detail: detail.isEmpty ? null : detail,
                        ),
                      ),
                    ],
                  ),
                  if (account.asset.isCrypto) ...<Widget>[
                    const SizedBox(height: 20),
                    PositionPanel(own: own, account: account),
                  ],
                  const SizedBox(height: 28),
                  if (entries.isEmpty)
                    Text(l.noMovements, style: context.type.bodyMedium)
                  else
                    MovementGroups(own: own, entries: entries, inAccount: true),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
