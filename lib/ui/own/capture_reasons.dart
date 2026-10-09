import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';

import '../../capture/capture_service.dart';
import '../../capture/inbox.dart';
import '../../capture/merchants.dart';
import '../../domain/records.dart';
import '../../l10n/l10n.dart';
import '../../own/own_controller.dart';
import 'look.dart';

/// A merchant's key the way the app writes merchants: `exito laureles`
/// becomes `Exito Laureles`, and `d1` stays `D1`.
String merchantShown(String key) => prettyMerchant(key.toUpperCase());

String _accountName(AppLocalizations l, OwnController own, String? id) {
  for (final Account a in own.accounts) {
    if (a.id == id) return a.name;
  }
  return l.ruleMissingAccount;
}

/// Why the app suggested what it did for [item], in a line: the card that
/// belongs to an account, the person's rule for a merchant. Null when it
/// had no reason to give.
String? reasonsText(BuildContext context, OwnController own, InboxItem item) {
  final List<String> reasons = reasonList(context, own, item);
  return reasons.isEmpty ? null : context.l10n.whyLabel(reasons.join(' · '));
}

/// Each reason the app had for what it suggested for [item], on its own.
List<String> reasonList(
  BuildContext context,
  OwnController own,
  InboxItem item,
) {
  final AppLocalizations l = context.l10n;
  final Suggestion s = item.suggestion;
  final String account = _accountName(l, own, s.accountId);
  final String? merchant = s.payee ?? item.parsed.merchant;
  final String asset =
      item.parsed.asset?.code ??
      own.accounts
          .where((Account a) => a.id == s.accountId)
          .map((Account a) => a.asset.code)
          .firstOrNull ??
      '';
  return <String>[
    for (final String why in s.why)
      ?switch (why) {
        'card' when item.parsed.card != null => l.whyCard(
          item.parsed.card!,
          account,
        ),
        'account' when item.parsed.account != null => l.whyAccount(
          item.parsed.account!,
          account,
        ),
        'institution' when item.parsed.institution != null =>
          normalize(item.parsed.institution!) == normalize(account)
              ? l.whyInstitutionSame(item.parsed.institution!)
              : l.whyInstitution(item.parsed.institution!, account),
        'currency' => l.whyCurrency(asset),
        'only' => l.whyOnly(asset),
        'learned' when merchant != null => l.whyLearned(merchant),
        'merchant' when merchant != null => l.whyMerchant(merchant),
        'words' => l.whyWords,
        _ => null,
      },
  ];
}

/// Why [item] has no account yet, from what the alert gave away: the bank
/// and the card it names, and how many of the person's accounts are there.
String missingAccountText(
  BuildContext context,
  OwnController own,
  InboxItem item,
) {
  final AppLocalizations l = context.l10n;
  final String? institution = item.parsed.institution;
  final String? card = item.parsed.card;
  final String? number = item.parsed.account;
  if (institution != null) {
    final List<Account> at = accountsAt(institution, own.accounts);
    if (at.isEmpty) return l.whichAccountBankNone(institution);
    if (card != null) return l.whichAccountCard(institution, card);
    if (number != null) return l.whichAccountNumber(institution, number);
    // Money that came in reached one of the bank's accounts, not its card.
    final int there = item.parsed.kind == EntryKind.income
        ? at.where((Account a) => a.kind != AccountKind.card).length
        : at.length;
    if (there > 1) return l.whichAccountBankMany(there, institution);
  }
  return item.parsed.kind == EntryKind.income
      ? l.whichAccountIn
      : l.whichAccountOut;
}

/// What [rule] does, the way the person would say it.
String ruleTarget(BuildContext context, OwnController own, CaptureRule rule) =>
    rule.kind == RuleKind.merchant
    ? categoryNameFor(context, rule.target, own.categories)
    : _accountName(context.l10n, own, rule.target);

/// What a rule matches, the way the person would say it: a merchant as
/// the card showed it, accents and all, when the app kept that name.
String ruleSubject(BuildContext context, OwnController own, CaptureRule rule) =>
    switch (rule.kind) {
      RuleKind.merchant =>
        own.captureSettings.merchantNames[rule.key] ?? merchantShown(rule.key),
      RuleKind.card => context.l10n.ruleCardKey(rule.key),
      RuleKind.account => context.l10n.ruleAccountKey(rule.key),
      RuleKind.institution => rule.key,
    };

/// What a confirmation taught, for the message that offers to undo it:
/// every rule, each by its name.
String learnedText(
  BuildContext context,
  OwnController own,
  List<RuleChange> changes,
) {
  final AppLocalizations l = context.l10n;
  final List<String> rules = <String>[
    for (final RuleChange c in changes)
      switch (c.rule.kind) {
        RuleKind.merchant => l.ruleGoesMerchant(
          c.name ?? ruleSubject(context, own, c.rule),
          ruleTarget(context, own, c.rule),
        ),
        RuleKind.card => l.ruleGoesCard(
          c.rule.key,
          ruleTarget(context, own, c.rule),
        ),
        RuleKind.account => l.ruleGoesAccount(
          c.rule.key,
          ruleTarget(context, own, c.rule),
        ),
        RuleKind.institution => l.ruleGoesInstitution(
          c.rule.key,
          ruleTarget(context, own, c.rule),
        ),
      },
  ];
  return l.ruleLearned(
    rules.length < 2
        ? rules.join()
        : l.listAnd(
            rules.take(rules.length - 1).join(', '),
            rules.last,
            _sound(rules.last),
          ),
  );
}

/// The sound [words] start with, as listAnd picks its conjunction: Spanish
/// says «y» before most words and «e» before an «i».
String _sound(String words) =>
    RegExp(r'^[«"]?h?[ií](?![aeoáéó])', caseSensitive: false).hasMatch(words)
    ? 'i'
    : 'other';

/// Says where [done] was recorded and what it taught, with one way to take
/// both back: the movement goes, and the capture waits in Por revisar
/// again. It is written from [messenger]'s context, so it shows even when
/// the card that recorded it has already folded away.
void showRecorded(
  ScaffoldMessengerState messenger,
  OwnController own,
  Accepted done,
) {
  final BuildContext context = messenger.context;
  final AppLocalizations l = context.l10n;
  final Entry entry = done.entry;
  final String account = _accountName(l, own, entry.accountId);
  final String said = switch (entry.kind) {
    EntryKind.transfer when done.toAccountId != null =>
      l.recordedTransferBetween(
        account,
        _accountName(l, own, done.toAccountId),
      ),
    EntryKind.transfer => l.recordedTransfer,
    _ when entry.amount > Decimal.zero => l.recordedIncomeIn(account),
    _ => l.recordedExpenseIn(account),
  };
  _offerUndo(messenger, own, <Accepted>[done], said);
}

/// Says how many of [done] were recorded at once, with one way to take
/// them all back.
void showRecordedMany(
  ScaffoldMessengerState messenger,
  OwnController own,
  List<Accepted> done,
) {
  if (done.isEmpty) return;
  _offerUndo(
    messenger,
    own,
    done,
    messenger.context.l10n.inboxRecordedMany(done.length),
  );
}

/// [said], then what [done] taught and the captures waiting that it left
/// ready, with a way to take all of it back.
void _offerUndo(
  ScaffoldMessengerState messenger,
  OwnController own,
  List<Accepted> done,
  String said,
) {
  final BuildContext context = messenger.context;
  final List<RuleChange> learned = <RuleChange>[
    for (final Accepted a in done) ...a.learned,
  ];
  final int resolved = done.fold(0, (int n, Accepted a) => n + a.resolved);
  final bool joined = done.any((Accepted a) => a.joined.isNotEmpty);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          <String>[
            said,
            if (learned.isNotEmpty) learnedText(context, own, learned),
            if (resolved > 0) context.l10n.ruleResolved(resolved),
            if (joined) context.l10n.transferJoined,
          ].join(' '),
        ),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: context.l10n.undo,
          onPressed: () => own.capture.takeBack(done),
        ),
      ),
    );
}
