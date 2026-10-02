import 'package:flutter/material.dart';

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
  final List<String> reasons = <String>[
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
  return reasons.isEmpty ? null : l.whyLabel(reasons.join(' · '));
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

/// Tells the person what confirming [changes] taught, with a way to take
/// it back.
void showLearned(
  ScaffoldMessengerState messenger,
  BuildContext context,
  OwnController own,
  List<RuleChange> changes,
) {
  if (changes.isEmpty) return;
  final AppLocalizations l = context.l10n;
  messenger.showSnackBar(
    SnackBar(
      content: Text(learnedText(context, own, changes)),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: l.undo,
        onPressed: () => own.capture.forget(changes),
      ),
    ),
  );
}
