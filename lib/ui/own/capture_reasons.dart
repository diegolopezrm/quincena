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
  if (institution != null) {
    final int there = accountsAt(institution, own.accounts).length;
    if (there == 0) return l.whichAccountBankNone(institution);
    if (card != null) return l.whichAccountCard(institution, card);
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

/// What a rule matches, the way the person would say it.
String ruleSubject(BuildContext context, CaptureRule rule) =>
    switch (rule.kind) {
      RuleKind.merchant => merchantShown(rule.key),
      RuleKind.card => context.l10n.ruleCardKey(rule.key),
      RuleKind.institution => rule.key,
    };

/// What a confirmation taught, for the message that offers to undo it.
String learnedText(
  BuildContext context,
  OwnController own,
  List<RuleChange> changes,
) {
  final AppLocalizations l = context.l10n;
  final CaptureRule first = changes.first.rule;
  final String target = ruleTarget(context, own, first);
  final String said = switch (first.kind) {
    RuleKind.merchant => l.ruleLearnedMerchant(
      merchantShown(first.key),
      target,
    ),
    RuleKind.card => l.ruleLearnedCard(first.key, target),
    RuleKind.institution => l.ruleLearnedInstitution(first.key, target),
  };
  return changes.length == 1
      ? said
      : '$said ${l.ruleLearnedMore(changes.length - 1)}';
}

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

/// [said], then what [done] taught, with a way to take all of it back.
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
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(
          learned.isEmpty
              ? said
              : '$said ${learnedText(context, own, learned)}',
        ),
        duration: const Duration(seconds: 6),
        action: SnackBarAction(
          label: context.l10n.undo,
          onPressed: () => own.capture.takeBack(done),
        ),
      ),
    );
}
